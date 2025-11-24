`include "Header.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/23 15:19:43
// Design Name: 
// Module Name: Macro
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: macro cell, compute MAC
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Macro(
    input   wire  clk,
    input   wire  rst_n,
    input   wire  en,
    input   wire  [`Input_feature_width-1:0] i_macro_feature,
    input   wire  i_macro_feature_vld,
    input   wire  [`Input_weight_width-1:0]  i_macro_weight,
    input   wire  i_macro_weight_vld,
    input   wire  i_load_weight_to_macro,
    output  wire  o_free_input_reg,
    output  wire  [`Macro_psum_8out_width-1:0]  o_macro_psum,
    output  wire  o_macro_psum_vld,
    output  wire  o_macro_ready_to_compute,
    output  wire  o_macro_weight_buf_ready,
    output  wire  o_macro_feature_ready
    );
    
 CIMD64X64NR #(.ROW_NUM(64), .COL_NUM(64), .PSUM_W(10), .MAC_WID(22))
    u_cimd (
        .CLK(clk),
        .MEB(meb),
        .WEB(web),
        .CIMEN(cimen),
        .DIN(wgt),
        .A(addr[5:0]),
        .REN(~rstn),
        .MAC(result[22*8-1:0]),
        .SRDY(result_ready),
        .Q(out_data)
    );   
    
    
    
    
endmodule
