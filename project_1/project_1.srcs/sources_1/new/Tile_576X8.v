`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/01 15:20:12
// Design Name: 
// Module Name: Tile_576X8
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is a CIM computing module, consisting of a 512-CIM and a 64-CIM.
// The MEB controls the storage function, equivalent to the read signal, WEB is equivalent to the write signal, 
// and pulling CIMEN high represents enabling computation. Since there is no need to use the readout function, meb is kept low.
//When writing weights, lower the web first, then write weights according to the position.
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//CIM Compute has relationship with address

module Tile_576X8(
    input                   clk,
    input                   rst_n,
    input   [1:0]           compute_mode,       //00:CNN 3x3, 576; 01:CNN 1x1, 64; 11:Transformer, 64+512 
    input                   meb,                //macro enable,active low
    input                   web,                //write enable,active low
    input                   cimen,              ////0:MEM mode,1:CIM mode
    input                   cimen_512,
    input   [63:0]          feature_din_64,
    input   [511:0]         feature_din_512,
    input   [63:0]          weight_din,
    input   [9:0]           weight_addr,
    output  [26*8-1:0]      result_data,
    output  [26*8-1:0]      result_512,
    output                  result_ready,
    output                  result_ready_512
    );

// === Feature Input Split ===
    wire [63:0]  din_64  = !web ?  weight_din:feature_din_64;   //beacause 64 CIM's weight input and feature input have same port
    wire [511:0] din_512 = feature_din_512;

    // === Weight Address Decode ===
    wire sel_64  = (weight_addr < 10'd64);    // select 64CIM
    wire sel_512 = (weight_addr >= 10'd64);   // select 512CIM

    // local address inside each CIM
    wire [5:0]  addr_64  = weight_addr > 10'd63 ? 6'd63 : weight_addr[5:0];               // 0~63
    wire [8:0]  addr_512 = weight_addr - 10'd64;           // 0~511

    // === Write Enable Decode ===
    wire web_64  = sel_64  ? web : 1'b1;    // active low
    wire web_512 = sel_512 ? web : 1'b1;

    // === Result Wires ===
    wire [22*8-1:0] result_64_22;
    wire [26*8-1:0] result_576;
    wire [25*8-1:0] result_512_25;
    wire [26*8-1:0] result_64;

    wire result_ready_64;
    
 CIMD64X64NR #(
    .ROW_NUM(64), 
    .COL_NUM(64), 
    .PSUM_W(10), 
    .MAC_WID(22))
    u_CIMD64X64NR (
        .CLK(clk                        ),
        .MEB(meb                        ),
        .WEB(web_64                     ),
        .CIMEN(cimen                    ),
        .DIN(din_64                     ),
        .A(addr_64                      ),
        .REN(~rst_n                     ),
        .MAC(result_64_22                  ),
        .SRDY(result_ready_64           )
    );   

CIMD512X64NR #(
    .ROW_NUM 	(512  ),
    .COL_NUM 	(64   ),
    .PSUM_W  	(13   ),
    .MAC_WID 	(25   ))
u_CIMD512X64NR(
    .CLK   	(clk                       ),
    .MEB   	(meb && compute_mode!=2'b01                       ),    // disable 512 CIM when compute_mode is 01
    .WEB   	(web_512                   ),
    .CIMEN 	(cimen                     ),    //
    .NNIN  	(din_512                   ),
    .DIN   	(weight_din                ),
    .A     	(addr_512                  ),
    .REN   	(~rst_n                    ),
    .MAC   	(result_512_25                ),
    .SRDY  	(result_ready_512          )
);

// === Combine Results ===
wire signed [25:0] sum_result [7:0];
genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : SUM_BLOCK
        wire signed [21:0] r64_ch  = result_64_22[22*i +: 22];
        wire signed [24:0] r512_ch = result_512_25[25*i +: 25];
        assign sum_result[i] = {{4{r512_ch[24]}}, r512_ch} + {{7{r64_ch[21]}}, r64_ch};
        assign result_64[26*i +: 26] = {{4{r64_ch[21]}}, r64_ch};
        assign result_512[26*i +: 26] = {{4{r512_ch[24]}}, r512_ch};
    end
endgenerate


    // === Pack summed outputs ===
    assign result_576 = {
        sum_result[7],
        sum_result[6],
        sum_result[5],
        sum_result[4],
        sum_result[3],
        sum_result[2],
        sum_result[1],
        sum_result[0]
    };

    assign result_ready = compute_mode == 2'b00 ? (result_ready_512 & result_ready_64) : result_ready_64;
    assign result_data = compute_mode == 2'b00 ? result_576 : result_64;


endmodule
