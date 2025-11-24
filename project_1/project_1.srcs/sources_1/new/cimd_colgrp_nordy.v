
`include "macro.vh"

`timescale 1ns /1ps
//CIMD Memory Column Group
module cimd_colgrp_nordy 
#(parameter ROW_NUM=512, parameter PSUM_W=13,
parameter GROUP_NUM=8, parameter MAC_WID=25)(
input clk,
input cimen,
input wen,
input [$clog2(ROW_NUM)-1:0] addr,
input [$clog2(ROW_NUM)-1:0] ra,
input [ROW_NUM-1:0] din_inv,
input [7:0] win,
input ra_match,
input [ROW_NUM-1:0] repair_en,

output reg [7:0] wout,

output [MAC_WID-1:0] acc_res);

reg [7:0] weight [0:ROW_NUM-1];
wire [4*ROW_NUM-1:0] weight_h;
wire [4*ROW_NUM-1:0] weight_l;
reg [7:0]spare_weight;
wire [3:0] spare_weight_h;
wire [3:0] spare_weight_l;
reg spare_din_inv;
assign spare_weight_h = spare_weight[7:4];
assign spare_weight_l = spare_weight[3:0];

//Mem mode operations
always @(posedge clk)begin
    if((cimen == `MEM_MODE) && (wen == `MEM_W) && (ra_match==1'b1))
        spare_weight <= win;
    else if((cimen==`MEM_MODE) && (wen ==`MEM_W) && (ra_match==1'b0)) 
        weight[addr]<= win;
end
//assign wout =(wen == MEM R)?((ra match == 1'b1)? spare weight : weight[addr]): wout;
always @(posedge clk)
    if(wen ==`MEM_R)
        if(ra_match == 1'b1)
            wout <= spare_weight;
        else
            wout <= weight[addr];

//CIM mode repair operations
always @(*)begin
    if((cimen==`CIM_MODE) && (repair_en[ra]== 1'b1))
        spare_din_inv=din_inv[ra];
end
reg signed [10*GROUP_NUM-1:0] psum_g_1;
reg [10*GROUP_NUM-1:0] psum_g_2;
reg [PSUM_W-1:0] psum_1;
reg [PSUM_W-1:0] psum_2;

always @(posedge clk)begin
    psum_1<=sumn_s(psum_g_1);
    psum_2<=sumn_u(psum_g_2);
end

genvar i,j;
generate
    for(j=0; j< ROW_NUM; j=j+1)begin:weight_hl
        assign weight_h[4*(j+1)-1-:4] = weight[j][7:4];
        assign weight_l[4*(j+1)-1-:4]=weight[j][3:0];
    end
    for(i=0; i<GROUP_NUM; i=i+1)begin:psum_g
        always @(*)begin
            if(addr[i])begin
                psum_g_1[(i+1)*10-1-:10] = sum64_s(din_inv[(i+1)*64-1-:64],weight_h[4*64*(i+1)-1-: 4*64],repair_en[(i+1)*64-1-:64],spare_din_inv,spare_weight_h);
                psum_g_2[(i+1)*10-1-:10] = sum64_u(din_inv[(i+1)*64-1-: 64], weight_l[4*(i+1)*64-1-: 4*64],repair_en[(i+1)*64-1-:64],spare_din_inv, spare_weight_l);
                end 
            else begin
                psum_g_1[(i+1)*10-1-:10]= 0;
                psum_g_2[(i+1)*10-1-:10]=0;
            end
end
end
endgenerate

//accumulator
cimd_accu_nordy #(.ROW_NUM(ROW_NUM), .PSUM_W(PSUM_W), .RESULT_W(MAC_WID)) u_cimd_accu_nordy(
.clk(clk),
.cimen(cimen),
.psum1(psum_1),
.psum2(psum_2),
.mac_res(acc_res));

function [9:0] sum64_u;
    input [1*64-1:0] data;
    input [4*64-1:0]weight;
    input [63:0]repair_en;
    input spare_din_inv;
    input [3:0]spare_weight;
    integer i;
    reg [3:0] tmp;
begin
sum64_u=0;
tmp =spare_din_inv*spare_weight;
for(i=0;i<64;i=i+1)
    sum64_u=sum64_u + (repair_en[i]? tmp : (data[i]* weight[(i+1)*4-1 -: 4]));
end
endfunction

function signed[9:0] sum64_s;
input [1*64-1:0] data;
input [4*64-1:0]weight;
input [63:0] repair_en;
input spare_din_inv;
input signed [3:0] spare_weight;
integer i;
reg signed [3:0] tmp;
begin
sum64_s=0;
tmp =$signed({1'b0,spare_din_inv})* spare_weight;
for(i=0;i<64;i=i+1)
    sum64_s = sum64_s + (repair_en[i] ? tmp : ($signed({1'b0, data[i]})* $signed(weight[(i+1)*4-1 -: 4])));
end
endfunction

function signed [PSUM_W-1:0] sumn_s;
    input signed [10*GROUP_NUM-1:0] data;
    integer i;
begin
sumn_s=0;
for(i=0;i<GROUP_NUM;i=i+1)
sumn_s=sumn_s + $signed(data[(i+1)*10-1-: 10]);
end
endfunction

function [PSUM_W-1:0]sumn_u;
input [10*GROUP_NUM-1:0] data;
integer i;
begin
sumn_u=0;
for(i=0;i<GROUP_NUM;i=i+1)
sumn_u=sumn_u+data[(i+1)*10-1-:10];
end
endfunction

endmodule