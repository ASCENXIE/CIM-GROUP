//`define FSDB
`timescale 1ns / 1ps
module cim64_macro_tb;
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
reg [$clog2(64)-1:0] addr = 0;
reg [$clog2(64)-1:0] readdr;

// input buffer Outputs
wire [22*8-1:0] result;
wire result_ready;
wire [64-1:0] out_data;

wire [21:0] result_group [0:7];
// 权重数据存储
reg [63:0] weight_mem [0:63]; // 存储64行，每行64位（8个8位值）

// 特征数据存储
reg [7:0] nnin_mem [0:63];

initial begin
    // 读取kernel_weights_hex.txt到weight_mem
    $readmemh("C:/work_file/grade1/GROUP_RTL_CODE/project_1/macro_test_data/kernel_weights.txt", weight_mem);
end

initial begin
    // 读取kernel_weights_hex.txt到weight_mem
    $readmemh("C:/work_file/grade1/GROUP_RTL_CODE/project_1/macro_test_data/pixel_data.txt", nnin_mem);
end

initial begin
    forever #(PERIOD/2) clk = ~clk;
end

initial begin
    #(PERIOD*10) rstn = 1;
end

`ifdef FSDB
initial begin
    $fsdbDumpfile("./cim64_macro.fsdb");
    $fsdbDumpvars(0);
    $fsdbDumpMDA();
end
`endif 

reg [7:0] cnt;

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
        if (cnt > 'd63 && cnt < 'd77) begin
            meb <= 1'b0;
            web <= 1'b1;
            cimen <= 1'b1;
            addr <= 1'b1;
            begin
                for (i = 0; i < 64; i = i + 1) begin
                    if ((cnt - 'd64) < 8) // 确保索引不越界（nnin_mem[j]只有8位）
                        wgt[i] <= nnin_mem[i][cnt - 'd64];
                    else
                        wgt[i] <= 1'b0; // 索引越界时填0
                end
            end
//            wgt = 1'b1;
        end
        else if(cnt <= 'd63) begin
            web <= 1'b0;
            meb <= 1'b0;
            cimen <= 1'b0;
            addr <= cnt;
            wgt <= weight_mem[cnt]; // 前64周期使用weight
        end
        else begin
            web <= 1'b1;
            meb <= 1'b1;
        end
    end
end

genvar j;
    for(j = 0; j < 8; j = j+1) begin
        assign result_group[j] = result[22*j +:22]; //第一个通道结果在result的高22位，第八个通道结果在result的低22位
    end

initial begin
    #3000;
    $finish;
end

endmodule