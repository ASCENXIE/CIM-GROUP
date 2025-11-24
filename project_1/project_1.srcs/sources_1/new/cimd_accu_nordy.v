
`timescale 1ns /1ps

module cimd_accu_nordy
(
// CIMD Accumulator
 clk,
 cimen,
 psum1,
 psum2,
 mac_res
);

parameter ROW_NUM=512;
parameter PSUM_W=13;
parameter RESULT_W=25;

localparam LEAD_ZERO_W = RESULT_W-12-PSUM_W;
localparam ACC_W = PSUM_W+12;

input clk; // clock
input cimen; // ctrl,active high,start operate CIMcimen,// ctrl,active high, start operate CIM
input [PSUM_W-1:0] psum1;// partial sum of 4 msb
input[PSUM_W-1:0] psum2;// partial sum of 4 lsb
output [RESULT_W-1:0] mac_res;//result

reg [PSUM_W-1+5:0] psum_r;
wire [PSUM_W-1+5:0] m_psum_r;

reg [PSUM_W-1+12:0] acc_r;

reg [2:0] cnt;
reg cimen_d1;

assign mac_res= {{LEAD_ZERO_W{1'b0}},acc_r};
assign m_psum_r=~psum_r + 1'b1;

always @(*)
    psum_r= {psum1[PSUM_W-1],psum1, 4'b0000} + {5'd0, psum2};

always @(posedge clk)
    cimen_d1<= cimen;

always @(posedge clk)
    if(!cimen_d1 && cimen)
        cnt <= 3'd0;
    else if(cimen_d1)
        cnt <= cnt+3'd1;

always @(posedge clk)
    if(cimen_d1)
        case(cnt)
        3'd0:begin
            acc_r<={{7{psum_r[PSUM_W-1+5]}},psum_r};
        end
        3'd1: begin
            acc_r<=acc_r+{{6{psum_r[PSUM_W-1+5]}},psum_r,1'd0};
        end
        3'd2: begin
            acc_r<=acc_r+{{5{psum_r[PSUM_W-1+5]}},psum_r,2'd0};
        end
        3'd3: begin
            acc_r<=acc_r+{{4{psum_r[PSUM_W-1+5]}},psum_r,3'd0};
        end
        3'd4: begin
            acc_r<=acc_r+{{3{psum_r[PSUM_W-1+5]}},psum_r,4'd0};
        end
        3'd5:begin
            acc_r<=acc_r+{{2{psum_r[PSUM_W-1+5]}},psum_r,5'd0};
        end
        3'd6: begin
            acc_r<=acc_r+{{psum_r[PSUM_W-1+5]},psum_r,6'd0};
        end
        3'd7: begin
            acc_r<=acc_r+{m_psum_r,7'd0};
        end
        endcase

endmodule