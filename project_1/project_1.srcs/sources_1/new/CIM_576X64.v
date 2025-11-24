`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/03 13:24:46
// Design Name: 
// Module Name: CIM_576X64
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This module includes 8 tiles, each composed of 512 CIMs and 64 CIMs.
// With a storage size of 36KB, each tile can provide 0.4 TOPS @ INT8 computing power at 400MHz.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CIM_576X64(
    input                   clk,
    input                   rst_n,
    input                   meb,                //macro enable,active low
    input                   web,                //write enable,active low
    input                   cimen,              ////0:MEM mode,1:CIM mode
    input [576-1:0]         feature_din,
    input [512-1:0]         weight_din,
    input [9:0]             weight_addr,
    output [26*64-1:0]       result_data,
    output                  result_ready
    );

wire [64-1:0] weight_din_tile [0:7];
wire [26*8-1:0] result_data_tile [0:7];
wire [7:0] result_ready_tile;

assign result_ready = &result_ready_tile;

genvar j;
generate
    for(j = 0; j < 8; j = j + 1) begin
        assign weight_din_tile[j] = weight_din[(j+1)*64-1 -: 64];
        assign result_data[(j+1)*26*8-1 -: 26*8] = result_data_tile[j]; 
    end
endgenerate

genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : TILE_INSTANCES
        Tile_576X8 u_Tile_576X8 (
            .clk(clk),
            .rst_n(rst_n),
            .meb(meb),
            .web(web),
            .cimen(cimen),
            .weight_din(weight_din_tile[i]),  
            .weight_addr(weight_addr),
            .feature_din(feature_din),
            .result_data(result_data_tile[i]),    
            .result_ready(result_ready_tile[i])  
        );
    end
endgenerate


endmodule
