`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/03 15:52:25
// Design Name: 
// Module Name: Sliding_Window_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
//   - FIFO0 �? FIFO1 �? FIFO2 cascaded
//   - Each FIFO: 512-bit, depth=256 (parameterized)
//   - Output valid when all three FIFOs filled >= feature_width
//   - Output window: 3x512bit = 192 Bytes
//   - FIFO output interval at least 8 clock cycles, currently only support stride=1, if stride>1, need to add more input REG
//   - now, REG is 3 groups. each time can update 1 data, if want to support stride>1, need to increase REG groups
//   - and need to modify fifo's control logic to decrease output interval to 4 clock cycles
//   - FIFO0 stores current row data
//   - FIFO1 stores previous row data
//   - FIFO2 stores data of two rows before
//   - so fifo2 and dout2 correspond to the top row of sliding window
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
module Sliding_Window_FIFO #(
    parameter DATA_WIDTH = 512,
    parameter DEPTH = 64,
    parameter ADDR_WIDTH = $clog2(DEPTH),
    parameter FIFO_delay = 1
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   en,
    input  wire                   input_done_single_fea, // indicate the last row of feature map has been input
    // input data and control
    input  wire [DATA_WIDTH-1:0]  din,
    input  wire                   din_valid,
    input  wire [ADDR_WIDTH-1:0]  feature_width, // feature width for sliding window
    input  wire [1:0]             stride_cfg, // stride configuration
    // output sliding window
    output reg  [DATA_WIDTH*3-1:0] dout,   // concat output FIFO2 | FIFO1 | FIFO0
    output reg                     dout_valid,

    // status outputs for debug
    output wire [ADDR_WIDTH-1:0]  wr_ptr0, rd_ptr0,
    output wire [ADDR_WIDTH-1:0]  wr_ptr1, rd_ptr1,
    output wire [ADDR_WIDTH-1:0]  wr_ptr2, rd_ptr2
);

    // ============================================================
    // FIFO inter signals
    // ============================================================
    wire [ADDR_WIDTH-1:0] data_count0, data_count1, data_count2;
    wire [DATA_WIDTH-1:0] fifo_dout0, fifo_dout1, fifo_dout2;
    wire fifo_full0, fifo_full1, fifo_full2;
    wire fifo_empty0, fifo_empty1, fifo_empty2;
    wire output_vld0, output_vld1, output_vld2;
    reg  output_vld0_d1, output_vld0_d2, output_vld1_d1;
    reg  wr_en0, wr_en1, wr_en2;
    reg  rd_en0, rd_en1, rd_en2;
    reg  rd_en0_d1, rd_en1_d1, rd_en2_d1;
    reg  input_done_single_fea_reg;
    reg  [2:0] fifo_output_cnt;
    // ============================================================
    // FIFO instances
    // ============================================================
    Syn_FIFO #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_fifo0 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en0), .rd_en(rd_en0),
        .din(din), .dout(fifo_dout0),.output_vld(output_vld0),
        .full(fifo_full0), .empty(fifo_empty0), .data_count(data_count0),
        .wr_ptr(wr_ptr0), .rd_ptr(rd_ptr0)
    );

    Syn_FIFO #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_fifo1 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en1), .rd_en(rd_en1),
        .din(fifo_dout0), .dout(fifo_dout1),.output_vld(output_vld1),
        .full(fifo_full1), .empty(fifo_empty1), .data_count(data_count1),
        .wr_ptr(wr_ptr1), .rd_ptr(rd_ptr1)
    );

    Syn_FIFO #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_fifo2 (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en2), .rd_en(rd_en2),
        .din(fifo_dout1), .dout(fifo_dout2),.output_vld(output_vld2),
        .full(fifo_full2), .empty(fifo_empty2), .data_count(data_count2),
        .wr_ptr(wr_ptr2), .rd_ptr(rd_ptr2)
    );

    // ============================================================
    // control logic
    // ============================================================
    reg fifo_output_cnt_done;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_en0_d1 <= 1'b0;
            rd_en1_d1 <= 1'b0;
            rd_en2_d1 <= 1'b0;
        end
        else if(en)  begin
            rd_en0_d1 <= rd_en0;
            rd_en1_d1 <= rd_en1;
            rd_en2_d1 <= rd_en2;
        end
    end
    // using fifo_output_cnt to ensure that after input_done_single_fea, every 8 clock cycles output data once, because CIM can complete one 3x3 computation in 8 clock cycles 
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_output_cnt <= 3'd0;
        end
        else if(en) begin
            if(input_done_single_fea_reg) begin
                if(stride_cfg == 2'b00) // stride=1
                    if(fifo_output_cnt == 3'd7) begin
                        fifo_output_cnt <= 3'd0;
                        fifo_output_cnt_done <= 1'b1;
                    end
                    else begin
                        fifo_output_cnt <= fifo_output_cnt + 3'd1;
                        fifo_output_cnt_done <= 1'b0;
                    end
                else if(stride_cfg == 2'b01) begin // stride=2
                    if(fifo_output_cnt == 3'd3) begin     //motify
                        fifo_output_cnt <= 3'd0;
                        fifo_output_cnt_done <= 1'b1;
                    end
                    else begin
                        fifo_output_cnt <= fifo_output_cnt + 3'd1;
                        fifo_output_cnt_done <= 1'b0;
                    end
                end
                else begin
                    fifo_output_cnt <= 3'd0;
                end
            end
            else begin
                fifo_output_cnt <= 3'd0;
            end
        end
    end

    always@(*) begin 
        if(input_done_single_fea_reg && en) begin 
            if(!fifo_empty2) begin 
                // rd_en0 = &fifo_output_cnt ? 1'b1 : 1'b0; 
                // rd_en1 = &fifo_output_cnt ? 1'b1 : 1'b0;
                // rd_en2 = &fifo_output_cnt ? 1'b1 : 1'b0;
                rd_en0 = fifo_output_cnt_done ? 1'b1 : 1'b0; 
                rd_en1 = fifo_output_cnt_done ? 1'b1 : 1'b0;
                rd_en2 = fifo_output_cnt_done ? 1'b1 : 1'b0;
                wr_en0 = din_valid && !fifo_full0; 
                wr_en1 = 1'b0;
                wr_en2 = 1'b0; 
            end 
            else begin 
                rd_en0 =  1'b0; 
                rd_en1 =  1'b0; 
                rd_en2 =  1'b0; 
                wr_en0 = din_valid && !fifo_full0; 
                wr_en1 =  1'b0; 
                wr_en2 =  1'b0; 
            end
        end 
        else begin 
            wr_en0 = din_valid && !fifo_full0; 
            rd_en0 = (!fifo_empty0) && (!fifo_full1) && (data_count0 >= feature_width) && wr_en0; 
            wr_en1 = output_vld0; 
            rd_en1 = (!fifo_empty1) && (!fifo_full2) && (data_count1 >= feature_width) && wr_en1 && rd_en0_d1; 
            wr_en2 = output_vld1; 
            rd_en2 = (!fifo_empty2) && (data_count2 >= feature_width) && wr_en2 && rd_en1_d1; 
            end 
    end

    // ============================================================
    // control logic
    // ============================================================
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            input_done_single_fea_reg <= 1'b0;
        end
        else if(en) begin
            if(input_done_single_fea)
                input_done_single_fea_reg <= input_done_single_fea;
            else if(fifo_empty2)
                input_done_single_fea_reg <= 1'b0;
            else 
                input_done_single_fea_reg <= input_done_single_fea_reg;
        end
    end


    // ============================================================
    // output logic
    // ============================================================
    reg fifo0_ready, fifo1_ready, fifo2_ready;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo0_ready <= 1'b0;
            fifo1_ready <= 1'b0;
            fifo2_ready <= 1'b0;
        end else if(input_done_single_fea_reg && en) begin
            fifo0_ready <= 1'b1;
            fifo1_ready <= 1'b1;
            fifo2_ready <= 1'b1;
        end
        else begin
            fifo0_ready <= (data_count0 >= feature_width);
            fifo1_ready <= (data_count1 >= feature_width);
            fifo2_ready <= (data_count2 >= feature_width);
        end
    end

    // when fifo0\1\2 is ready, read data out
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            output_vld0_d1 <= 1'd0;
            output_vld0_d2 <= 1'd0;
            output_vld1_d1 <= 1'd0;
        end
        else begin
            output_vld0_d1 <= output_vld0;
            output_vld0_d2 <= output_vld0_d1;
            output_vld1_d1 <= output_vld1;
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 'b0;
            dout_valid <= 1'b0;
        end else if ( en && fifo0_ready && fifo1_ready && fifo2_ready && ((output_vld0&&output_vld1&&output_vld2) || (output_vld0_d2&&output_vld1_d1&&output_vld2))) begin
            dout <= {fifo_dout2, fifo_dout1, fifo_dout0};
            dout_valid <= 1'b1;
        end else begin
            dout_valid <= 1'b0;
        end
    end

endmodule

