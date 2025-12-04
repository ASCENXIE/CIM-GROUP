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
    input wire [2:0]            i_Cluster_cfg,          // CNN mode: Different cluster will concat; Transformer mode: Q\K\V\Linear compute for 512 row compute, Disable: 000, Q: 001, K: 010, V: 011, Linear: 100  
    input wire [2:0]            i_Group_cfg,            // CNN mode: Different group in same cluster will be added; Transformer mode: Q*K^T\Q*V\linear compute for 64 rows compute, Disable: 000, Q*K^T: 001, Q*V: 010, Linear: 011
    input wire [2:0]            i_Layer_cfg,            // CNN mode: Different layer; Transformer mode: Different head
    input wire [2:0]            i_Kernel_cfg,           // CNN mode: Different kernel size, 1:1x1 conv. 3:3x3 conv; Transformer mode: not used
    input wire [1:0]            i_Stride_cfg,           // CNN mode: Different stride, 0:stride=1;1:stride=2; Transformer mode: not used
    input wire [7:0]            i_Feature_Width,        // input feature map width
    input wire                  i_Net_cfg,              // 0:CNN mode; 1:Transformer mode
    input wire                  i_cfg_done,             // configuration done signal
    // data signals
    input wire                  i_input_done_single_fea,
    input wire [DATA_WIDTH-1:0] i_Lane_data,
    input wire [9:0]            i_Lane_data_addr,       // because Lane_data may be weight or feature, if weight addr is needed, address should be provided by input router or output router
    input wire                  i_Lane_data_vld,        // when i_Lane_data is valid for Group, set this signal to 1
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
    output wire [64*26-1:0]     cim_result,
    output wire [64*26-1:0]     cim_result_512,
    output wire                  cim_result_ready_512
    );
    integer m;
    //============================================================
    // 0. Config Registers configuration
    // ===========================================================
    reg [2:0] r_Cluster_cfg;
    reg [2:0] r_Group_cfg;
    reg [2:0] r_Layer_cfg;
    reg [2:0] r_Kernel_cfg;
    reg [1:0] r_Stride_cfg;
    reg [7:0] r_Feature_Width;
    reg       r_Net_cfg;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r_Cluster_cfg <= 3'b0;
            r_Group_cfg   <= 3'b0;
            r_Layer_cfg   <= 3'b0;
            r_Kernel_cfg  <= 3'b0;
            r_Stride_cfg  <= 2'b0;
            r_Feature_Width <= 8'b0;
            r_Net_cfg     <= 1'b0;
        end
        else if(i_cfg_done) begin
            r_Cluster_cfg <= i_Cluster_cfg;
            r_Group_cfg   <= i_Group_cfg;
            r_Layer_cfg   <= i_Layer_cfg;
            r_Kernel_cfg  <= i_Kernel_cfg;
            r_Stride_cfg  <= i_Stride_cfg;
            r_Feature_Width <= i_Feature_Width;
            r_Net_cfg     <= i_Net_cfg;
        end
        else begin
            r_Cluster_cfg <= r_Cluster_cfg;
            r_Group_cfg   <= r_Group_cfg;
            r_Layer_cfg   <= r_Layer_cfg;
            r_Kernel_cfg  <= r_Kernel_cfg;
            r_Stride_cfg  <= r_Stride_cfg;
            r_Feature_Width <= r_Feature_Width;
            r_Net_cfg     <= r_Net_cfg;
        end
    end

    //============================================================
    // 1. Sliding Window FIFO
    //============================================================
    // fifo input logic
    wire [DATA_WIDTH-1:0] fifo_feature_din;
    wire feature_din_valid;
    wire [DATA_WIDTH*3-1:0] fifo_feature_dout;
    wire fifo_feature_dout_valid;
    wire fifo_en;

    assign fifo_en = en && (!i_Is_weight) && r_Kernel_cfg == 3'd3 ; 
    assign fifo_feature_din = i_Lane_data;
    assign feature_din_valid = i_Lane_data_vld && (!i_Is_weight); 

    //FIFO is used for feature sliding window, it's only used when conv is 3x3 and stride is 1 or 2
    //FIFO will cost a lot of resource when feature width is large, it needs to be optimized for larger feature width and higher reuse
    Sliding_Window_FIFO #(
        .DATA_WIDTH(512),
        .DEPTH(WIDTH)          //depth is feature width max value, here set to 64, because synth tool may not support parameter which is too large
    ) u_Sliding_Window_FIFO (
        .clk(clk),
        .rst_n(rst_n),
        .en(fifo_en),
        .input_done_single_fea(i_input_done_single_fea),
        .din(fifo_feature_din),
        .din_valid(feature_din_valid),
        .feature_width(r_Feature_Width),
        .stride_cfg(r_Stride_cfg),
        .dout(fifo_feature_dout),           //fifo_feature_dout = {data2, data1, data0} highest is data2
        .dout_valid(fifo_feature_dout_valid)
    );

    //============================================================
    // 2. REG for feature
    //============================================================
    wire  [64-1:0]     feature_din_64;
    wire  [512-1:0]    feature_din_512;
    wire               cimen;
    wire               cimen_512;
    wire               i_Lane_fea_data_vld;
    wire  [2:0]        Cluster_to_REG;
    wire  [2:0]        Group_to_REG;
    
    assign i_Lane_fea_data_vld = i_Lane_data_vld && (!i_Is_weight);
    assign Cluster_to_REG = i_Layer_num == r_Layer_cfg ? i_Cluster_num : 3'd0;
    assign Group_to_REG   = i_Layer_num == r_Layer_cfg ? i_Group_num : 3'd0;

    Group_Ping_Pong_REG u_Group_Ping_Pong_REG (
        .clk(clk),
        .rst_n(rst_n),
        .r_Feature_Width(r_Feature_Width),
        .r_Kernel_cfg(r_Kernel_cfg),
        .r_Stride_cfg(r_Stride_cfg),
        .r_Net_cfg(r_Net_cfg),
        .Cluster_to_REG(Cluster_to_REG),
        .Group_to_REG(Group_to_REG),
        .fifo_feature_dout(fifo_feature_dout),
        .fifo_feature_dout_valid(fifo_feature_dout_valid),
        .i_Lane_data(i_Lane_data),
        .i_Lane_data_vld(i_Lane_fea_data_vld),
        .i_input_done_single_fea(i_input_done_single_fea),
        .feature_din_64(feature_din_64),
        .feature_din_512(feature_din_512),
        .cimen(cimen),
        .cimen_512(cimen_512)
    );
    //============================================================
    // 3. CIM instance
    //============================================================
    wire  [512-1:0]          weight_din;
    wire                     cim_result_ready;
    reg  [9:0]                weight_addr;
    // for CNN, it's static matrix multiplication, so weight_addr auto increase when i_Is_weight is high, buf for Transformer, weight_addr should be controlled by external controller
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

    assign weight_din = i_Is_weight ? i_Lane_data[512-1:0] : 512'b0;

    CIM_576X64 u_CIM_576X64 (
        .clk(clk),
        .rst_n(rst_n),
        .compute_mode({r_Net_cfg, r_Kernel_cfg == 3'd3 ? 1'b0 : 1'b1}), //00:CNN 3x3, 576; 01:CNN 1x1, 64; 11:Transformer, 64+512
        .meb(!en),
        .web(!i_Is_weight),
        .cimen(cimen),
        .cimen_512(cimen_512),
        .feature_din_64(feature_din_64),
        .feature_din_512(feature_din_512),
        .weight_din(weight_din),
        .weight_addr(weight_addr),
        .result_data(cim_result),
        .result_ready(cim_result_ready),
        .result_512(cim_result_512),
        .result_ready_512( cim_result_ready_512)
    );

    //============================================================
    // 4. Quantization
    //============================================================
    Quantization_Group u_Quantization_Group (
        .clk(clk),
        .rst_n(rst_n),
        .cim_result_valid(cim_result_ready),
        .cim_result_valid_512(cim_result_ready_512),
        .cim_result(cim_result),
        .cim_result_512(cim_result_512),
        .quant_result(o_Output_data),
        .quant_result_512(o_Output_data_512),
        .quant_result_valid( o_Output_vld),
        .quant_result_valid_512( o_Output_vld_512)
    );

endmodule