`include "macro.vh"
`timescale 1ns/1ps

module CIMD512X64SR//cimd macro 64
#(
parameter ROW_NUM=512,
parameter COL_NUM=64,
parameter PSUM_W=13,
parameter MAC_WID=25)
(
input CLK,
input MEB,
// macro enable,active low
input WEB,
// write enable,active low
input CIMEN,//0:MEM mode,1:CIM mode[COL NUM-1:0]DIN// MEM mode: write data[$cLog2(ROW NUM)-1:0]A£¬// addressREN.// repair enable
input [ROW_NUM-1:0] NNIN,   //IM mode: input data
input [COL_NUM-1:0] DIN,    //MEM mode: write data
input [$clog2(ROW_NUM)-1:0]A,   //address
input REN,  // repair enable
input [$clog2(ROW_NUM)-1:0]RA,// repair address

output [MAC_WID*8-1:0] MAC, //CIM result
output SRDY,    //CIM result ready
output [COL_NUM-1:0] Q  //read out data
);

reg clk;
always @(*) begin
    if(!MEB)
        clk =CLK;
    end
//wire rst n;
//assign rstn=~MEB;
reg cimen;
reg wen;
reg [COL_NUM-1:0] win;//win is normal write and read
//reg pmode;
reg [$clog2(ROW_NUM)-1:0] addr;
reg ren;
reg [$clog2(ROW_NUM)-1:0]ra;
reg [ROW_NUM-1:0] din_inv;//din inv is CI input
always @(*)begin
cimen=CIMEN; //0 memory mode ;1cim mode 
wen = ~WEB;
addr= A;
ra=RA;
ren = REN;
win= DIN;
din_inv=NNIN;//in ROW64,only accept the lower 64bit
end

wire [MAC_WID*8-1:0] res;
wire [COL_NUM-1:0] wout;
wire ra_match;
wire [ROW_NUM-1:0] repair_en;
assign ra_match =(cimen ==`MEM_MODE) && (ren == 1'b1) && (addr == ra);

assign MAC= res;
assign Q=wout;
//===== Behavior of Sub Array=====:
genvar g;
generate
    for(g=0; g< COL_NUM/8; g=g+1)
    begin
    if(g ==0)begin
        cimd_colgrp #(.ROW_NUM(ROW_NUM),.PSUM_W(PSUM_W),.GROUP_NUM(8),.MAC_WID(MAC_WID)) u_cimd_colgrp512(
        .clk(clk),
        .cimen(cimen),
        .wen(wen),
        .addr(addr),
        .ra(ra),
        .din_inv(din_inv),
        .win(win[8*(g+1) -1 -:8]),
        .srdy(SRDY),
        .wout(wout[8*(g+1)-1-:8]),
        .acc_res(res[MAC_WID*(g+1) -1 -:MAC_WID]),
        .ra_match(ra_match),
        .repair_en(repair_en));
    end else begin
        cimd_colgrp_nordy #(.ROW_NUM(ROW_NUM),.PSUM_W(PSUM_W),.GROUP_NUM(8),.MAC_WID(MAC_WID)) u_cimd_colgrp_nordy512
        (
        .clk(clk),
        .cimen(cimen),
        .wen(wen),
        .addr(addr),
        .ra(ra),
        .din_inv(din_inv),
        .win(win[8*(g+1) -1 -:8]),
        .wout(wout[8*(g+1)-1-:8]),
        .acc_res(res[MAC_WID*(g+1) -1 -:MAC_WID]),
        .ra_match(ra_match),
        .repair_en(repair_en) 
        );
    end
    end
endgenerate

cimd_repair_en_512 cimd_repair_en_512_inst(.CIMEN(cimen),.REN(ren),.RA(ra),.REPAIR_EN(repair_en));

endmodule