//`define FSDB
`timescale 1ns / 1ps
module tb_512CIM;
// input buffer Parameters
parameter PERIOD = 4;
integer i;
// input buffer inputs
reg clk = 0;
reg rstn = 0;
reg meb = 0;
reg web = 0;
reg cimen = 0;
reg [64-1:0] wgt = 0;
reg [512-1:0] feature_din = 0;
reg [$clog2(512)-1:0] addr = 0;

// input buffer Outputs
wire [25*8-1:0] result;
wire result_ready;

wire [24:0] result_group [0:7];
reg [63:0] weight_mem [0:511]; 

reg [7:0] feature_mem [0:511];

initial begin
    $readmemh("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/kernel_weights_512.txt", weight_mem);
end

initial begin
    $readmemh("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/pixel_data_512.txt", feature_mem);
end

initial begin
    forever #(PERIOD/2) clk = ~clk;
end

initial begin
    #(PERIOD*10) rstn = 1;
end

`ifdef FSDB
initial begin
    $fsdbDumpfile("./tb_512CIM.fsdb");
    $fsdbDumpvars(0);
    $fsdbDumpMDA();
end
`endif 

reg [9:0] cnt;

CIMD512X64NR #(.ROW_NUM(512), .COL_NUM(64), .PSUM_W(13), .MAC_WID(25))
    u_cimd (
        .CLK(clk),
        .MEB(meb),
        .WEB(web),
        .CIMEN(cimen),
        .NNIN(feature_din ),
        .DIN(wgt),
        .A(addr),
        .REN(~rstn),
        .MAC(result[25*8-1:0]),
        .SRDY(result_ready)
    );

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        wgt <= 'b0;
        addr <= 'b0;
        web <= 'd0;
        cnt <= 'b0;
        meb <= 1'b1;
        cimen <= 1'b0;
    end
    else begin       
        cnt <= cnt +1'b1;
        if (cnt > 'd511 && cnt < 'd523) begin
            meb <= 1'b0;
            web <= 1'b1;
            cimen <= 1'b1;
            addr <= addr;
            begin
                for (i = 0; i < 512; i = i + 1) begin
                    if ((cnt - 'd512) < 8) 
                        feature_din[i] <= feature_mem[i][cnt - 'd512];
                    else
                        feature_din[i] <= 1'b0; 
                end
            end
//            wgt = 1'b1;
        end
        else if(cnt <= 'd511) begin
            web <= 1'b0;
            meb <= 1'b0;
            cimen <= 1'b0;
            addr <= cnt;
            wgt <= weight_mem[cnt]; 
        end
        else begin
            web <= 1'b1;
            meb <= 1'b1;
            wgt <= wgt;
            feature_din <= feature_din ;
            addr <= addr;
        end
    end
end

genvar j;
    for(j = 0; j < 8; j = j+1) begin
        assign result_group[j] = result[25*j +:25]; 
    end

initial begin
    #60000;
    $finish;
end

endmodule