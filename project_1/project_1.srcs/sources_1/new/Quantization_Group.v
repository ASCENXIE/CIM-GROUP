`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/03 15:05:28
// Design Name: 
// Module Name: Quantization_Group
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is simple module for Quantization_Group, it needs to be improved after quantization algorithm is confirmed.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Quantization_Group(
    input                   clk,
    input                   rst_n,
    input   [26*64-1:0]     cim_result,
    input   [26*64-1:0]     cim_result_512,
    input                 cim_result_valid,
    input                 cim_result_valid_512,
    //input   [3:0]           scale_factor,
    output  [16*64-1:0]     quant_result,
    output                  quant_result_valid,
    output  [16*64-1:0]     quant_result_512,
    output                  quant_result_valid_512
    );

genvar i;
generate
    for(i = 0; i < 64; i = i + 1)
    begin : QUANTIZATION_LOOP
        //simple truncate for test
        assign quant_result[(i+1)*16-1 -: 16] = cim_result[(i+1)*26-1 -: 26]>>10;
    end
endgenerate

genvar j;
generate
    for(j = 0; j < 64; j = j + 1)
    begin : QUANTIZATION_LOOP_512
        //simple truncate for test
        assign quant_result_512[(j+1)*16-1 -: 16] = cim_result_512[(j+1)*26-1 -: 26]>>10;
    end
endgenerate

assign quant_result_valid = cim_result_valid;
assign quant_result_valid_512 = cim_result_valid_512;

endmodule
