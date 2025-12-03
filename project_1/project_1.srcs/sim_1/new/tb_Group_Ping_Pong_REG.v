`timescale 1ns/1ps
module tb_Group_Ping_Pong_REG;

// parameters (match DUT defaults)
localparam BYTE_N  = 192;
localparam GROUP_N = 576;

reg clk;
reg rst_n;

// cfg ports
reg [7:0] r_Feature_Width;
reg [2:0] r_Kernel_cfg;
reg [1:0] r_Stride_cfg;
reg       r_Net_cfg;

// FIFO-side
reg [1535:0] fifo_feature_dout;
reg          fifo_feature_dout_valid;

// Lane-side
reg [511:0] i_Lane_data;
reg         i_input_done_single_fea;

// outputs from DUT
wire [GROUP_N-1:0] feature_din;
wire               cimen;

// instantiate DUT
Group_Ping_Pong_REG #(
    .BYTE_N(BYTE_N),
    .GROUP_N(GROUP_N)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .r_Feature_Width(r_Feature_Width),
    .r_Kernel_cfg(r_Kernel_cfg),
    .r_Stride_cfg(r_Stride_cfg),
    .r_Net_cfg(r_Net_cfg),
    .fifo_feature_dout(fifo_feature_dout),
    .fifo_feature_dout_valid(fifo_feature_dout_valid),
    .i_Lane_data(i_Lane_data),
    .i_input_done_single_fea(i_input_done_single_fea),
    .feature_din(feature_din),
    .cimen(cimen)
);

// clock
initial begin
    clk = 0;
    forever #2 clk = ~clk; // 250 MHz sim clock (4ns period)
end

// reset
initial begin
    rst_n = 0;
    fifo_feature_dout = {1536{1'b0}};
    fifo_feature_dout_valid = 1'b0;
    i_Lane_data = 512'b0;
    i_input_done_single_fea = 1'b0;
    r_Feature_Width = 8'd3;
    r_Kernel_cfg = 3'b011; // 3x3
    r_Stride_cfg  = 2'b00;  // stride 1
    r_Net_cfg     = 1'b0;   // CNN
    #20;
    rst_n = 1;
end

// waveform
initial begin
    $dumpfile("tb_Group_Ping_Pong_REG.vcd");
    $dumpvars(0, tb_Group_Ping_Pong_REG);
end

// helper: create a 1536-bit beat from 192 bytes (byte0 is MSB)
function [1535:0] make_beat;
    input [1535:0] beat_vec; // packed representation of 192 bytes
    begin
        // return the packed vector directly
        make_beat = beat_vec;
    end
endfunction

// task to push a single fifo beat
task push_beat;
    input [7:0] pattern;
    reg [1535:0] vec;
    integer i;
    begin
        vec = {1536{1'b0}};
        for (i = 0; i < 192; i = i + 1)
            vec[(1535 - i*8) -: 8] = pattern + i[7:0];
        fifo_feature_dout = vec;
        @(posedge clk);
        fifo_feature_dout_valid = 1'b1;
        @(posedge clk);
        fifo_feature_dout_valid = 1'b0;
    end
endtask

// stimulus: exercise CNN_3_1 (3x3 stride1) behavior
initial begin
    // wait for reset deassert
    @(posedge rst_n);
    @(posedge clk);

    $display("[%0t] --- Test: CNN 3x3 stride 1 ---", $time);
    r_Kernel_cfg = 3'b011; // 3x3
    r_Stride_cfg  = 2'b00;  // stride1
    r_Net_cfg     = 1'b0;   // CNN
    r_Feature_Width = 8'd4; // test width >=3 to enable cim

    // push four beats (simulate 4 columns of input width)
    push_beat(8'h10);
    push_beat(8'h20);
    push_beat(8'h30);
    push_beat(8'h40);

    // wait sufficiently to observe cimen assertions and feature_din evolution
    repeat (40) @(posedge clk);

    // switch to CNN_3_2 (stride 2) test
    $display("[%0t] --- Test: CNN 3x3 stride 2 ---", $time);
    r_Stride_cfg = 2'b01; // stride2
    r_Feature_Width = 8'd6; // wider

    // ensure i_input_done_single_fea toggling interacts with Row_Is_Odd
    push_beat(8'h55); // beat 0
    push_beat(8'h66); // beat 1
    // drive input_done single feature to reset Row_Is_Odd logic
    @(posedge clk);
    i_input_done_single_fea = 1'b1;
    @(posedge clk);
    i_input_done_single_fea = 1'b0;

    push_beat(8'h77); // beat 2
    push_beat(8'h88); // beat 3

    // wait and observe
    repeat (80) @(posedge clk);

    // small additional test: transition to Transformer mode
    $display("[%0t] --- Test: Transformer mode (no CIM expected) ---", $time);
    r_Net_cfg = 1'b1;
    push_beat(8'hAA);
    repeat (20) @(posedge clk);

    $display("[%0t] Testbench finished.", $time);
    $finish;
end

// monitor some signals
always @(posedge clk) begin
    if (cimen)
        $display("%0t cimen=1 feature_din[0:15]=%b...", $time, feature_din[15:0]);
end

endmodule
