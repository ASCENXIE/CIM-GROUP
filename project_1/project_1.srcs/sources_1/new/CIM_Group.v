`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/03 15:16:41
// Design Name: 
// Module Name: CIM_Group
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// fifo input shape is : data0
//                       data1
//                       data2
// fifo output shape is: data0 data1 data2
// first kernel's weight pixel(0,0)'s channel0 is stored in txt's first row's most significant 8 bits
// first feature pixel(0,0)'s channel0 is stored in txt's first row's most significant 8 bits
// weight txt's first row's most significant 8bits is mapped to Tile8's CIM64's genblk8
// feature txt's first row's most significant 8bits is mapped to feature_reg_group[0]'s most significant 8 bits
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CIM_Group#(
    parameter DATA_WIDTH = 512,
    parameter WIDTH = 64
)(
    input                  clk,
    input                  rst_n,
    // CIM cfg signals
    input wire                  en,
    input wire [2:0]            i_Cluster_cfg,
    input wire [2:0]            i_Group_cfg,
    input wire [2:0]            i_Layer_cfg,
    input wire [2:0]            i_Kernel_cfg,
    input wire [1:0]            i_Stride_cfg,
    input wire [7:0]            i_Feature_Width,
    input wire                  i_Net_cfg,
    input wire                  i_cfg_done,
    // data signals
    input wire                  i_input_done_single_fea,
    input wire [DATA_WIDTH-1:0] i_Lane_data,
    input wire                  i_Lane_data_vld,
    input wire [2:0]            i_Cluster_num,
    input wire [2:0]            i_Group_num,
    input wire [2:0]            i_Layer_num,
    input wire                  i_Is_weight,  // 1:weight;0:feature
    // output
    output wire [64*16-1:0]      o_Output_data,
    output wire [64*16-1:0]      o_Output_data_512,
    output wire                  o_Output_vld,
    output wire                  o_Output_vld_512,
    output reg [2:0]            o_Cluster_num,
    output reg [2:0]            o_Group_num,
    output reg [2:0]            o_Layer_num,
    //test signals
    output wire [64*26-1:0]     cim_result
    );

    integer m;
    //============================================================
    // 1. Sliding Window FIFO
    //============================================================
    // fifo input logic
    wire [DATA_WIDTH-1:0] fifo_feature_din;
    wire feature_din_valid;
    wire [DATA_WIDTH*3-1:0] fifo_feature_dout;
    wire fifo_feature_dout_valid;
    
    assign fifo_feature_din = i_Lane_data;
    assign feature_din_valid = i_Lane_data_vld && (!i_Is_weight); 

    Sliding_Window_FIFO #(
        .DATA_WIDTH(512),
        .DEPTH(WIDTH)          //depth is feature width max value, here set to 64, because synth tool may not support parameter which is too large
    ) u_Sliding_Window_FIFO (
        .clk(clk),
        .rst_n(rst_n),
        .input_done_single_fea(i_input_done_single_fea),
        .din(fifo_feature_din),
        .din_valid(feature_din_valid),
        .feature_width(i_Feature_Width),
        .dout(fifo_feature_dout),           //fifo_feature_dout = {data2, data1, data0} highest is data2
        .dout_valid(fifo_feature_dout_valid)
    );

    //============================================================
    // 2. REG for feature
    //============================================================
    reg [7:0] feature_reg_group [0:575];
    reg [7:0] feature_width_reg;
    reg [7:0] current_width_num;
    //reg feature_reg_group_valid;
    reg  [3:0]     cim_input_cnt;
    // record feature_width
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            feature_width_reg <= 8'd0;
        else if (en)
            feature_width_reg <= i_Feature_Width;
    end

    // current_width_num logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_width_num <= 8'd0;
        else if (fifo_feature_dout_valid) begin
            if (current_width_num == feature_width_reg - 1)
                current_width_num <= 8'd0;
            else
                current_width_num <= current_width_num + 8'd1;
        end
    end


    // feature_reg_group update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < 576; m = m + 1)
                feature_reg_group[m] <= 8'b0;
                //feature_reg_group_valid <= 1'b0;
        end
        else if (fifo_feature_dout_valid && (cim_input_cnt == 4'b0 || cim_input_cnt == 4'b1)) begin    //FIFO output valid and CIM is ready to take new input
            if (current_width_num == 8'd0) begin
                // first valid fifo output → [0:191]
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[m] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b0;
            end
            else if (current_width_num == 8'd1) begin
                // second valid fifo output → [192:383]
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[192 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b0;
            end
            else if (current_width_num == 8'd2) begin
                // third valid fifo output → [384:575]
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[384 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b1;
            end
            else begin
                // update [0:191], and shift the rest
                for (m = 0; m < 384; m = m + 1)
                    feature_reg_group[m] <= feature_reg_group[m+192];
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[m + 384] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b1;
            end
        end
        else begin
            //feature_reg_group_valid <= 1'b0;
            for(m = 0; m < 576; m = m + 1)
                feature_reg_group[m] <= feature_reg_group[m];
        end
    end
    //============================================================
    // 3. CIM Computing
    //============================================================
    reg  [576-1:0] feature_din;
    reg            cimen;
    wire           cim_result_ready;

    // weight input logic
    wire [512-1:0] weight_din;
    reg  [9:0]     weight_addr;
    assign weight_din = i_Lane_data[512-1:0];
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            weight_addr <= 10'd0;
        end
        else if(i_Is_weight && weight_addr < 10'd575) begin
            weight_addr <= weight_addr + 10'd1;
        end
        else begin
            weight_addr <= weight_addr;
        end
    end

    // feature_in assignment logic
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cim_input_cnt <= 4'b0;
            cimen <= 1'b0;
        end
        else if(current_width_num >= 8'd2 && fifo_feature_dout_valid 
                && (cim_input_cnt == 4'b0 || cim_input_cnt == 4'b1)) begin
            if(cimen == 1'b0)
                cim_input_cnt <= 4'd7;
            else if(cimen == 1'b1)
                cim_input_cnt <= 4'd7;
            cimen <= 1'b1;
        end        
        else begin
            if(cim_input_cnt > 4'd0) begin
                cim_input_cnt <= cim_input_cnt - 1 ;
                cimen <= 1'b1;
            end            
            else begin
                cimen <= 1'b0;
                cim_input_cnt <= 4'b0; 
            end
        end
    end

    always@(*) begin
        for(m = 0; m < 576; m = m + 1) begin
            if(cim_input_cnt >= 0)
                feature_din[m] = feature_reg_group[m][4'd7-cim_input_cnt];  //input from least significant bit
            // else if(cim_input_cnt == 0)
            //     feature_din[m] = feature_reg_group[m][4'd0];
            else 
                feature_din[m] = feature_reg_group[m][4'd0];
        end
    end


    CIM_576X64 u_CIM_576X64 (
        .clk(clk),
        .rst_n(rst_n),
        .meb(!en),
        .web(!i_Is_weight),
        .cimen(cimen),
        .feature_din(feature_din),
        .weight_din(weight_din),
        .weight_addr(weight_addr),
        .result_data(cim_result),
        .result_ready(cim_result_ready)
    );

    //============================================================
    // 4. Quantization
    //============================================================
    Quantization_Group u_Quantization_Group (
        .clk(clk),
        .rst_n(rst_n),
        .cim_result_valid(cim_result_ready),
        .cim_result(cim_result),
        .quant_result(o_Output_data),
        .quant_result_valid( o_Output_vld)
    );

endmodule
