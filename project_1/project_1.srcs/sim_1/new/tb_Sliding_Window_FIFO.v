`timescale 1ns/1ps
module tb_Sliding_Window_FIFO;

    // ============================================================
    // parameters
    // ============================================================
    parameter DATA_WIDTH = 512;
    parameter DEPTH = 256;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter PERIOD = 4;

    // ============================================================
    // signals
    // ============================================================
    reg clk;
    reg rst_n;
    reg [479:0] din_tmp;
    reg [DATA_WIDTH-1:0] din;
    reg din_valid;
    reg input_done_single_fea;
    reg [ADDR_WIDTH-1:0] feature_width;
    reg [ADDR_WIDTH -1:0] feature_height;
    
    wire [DATA_WIDTH*3-1:0] dout;
    wire [DATA_WIDTH-1:0] dout_group [0:2];
    wire dout_valid;

    wire [ADDR_WIDTH-1:0] wr_ptr0, rd_ptr0;
    wire [ADDR_WIDTH-1:0] wr_ptr1, rd_ptr1;
    wire [ADDR_WIDTH-1:0] wr_ptr2, rd_ptr2;

    // ============================================================
    // DUT
    // ============================================================
    Sliding_Window_FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) u_Sliding_Window_FIFO (
        .clk(clk),
        .rst_n(rst_n),
        .input_done_single_fea(input_done_single_fea),
        .din(din),
        .din_valid(din_valid),
        .feature_width(feature_width),
        .dout(dout),
        .dout_valid(dout_valid),
        .wr_ptr0(wr_ptr0), .rd_ptr0(rd_ptr0),
        .wr_ptr1(wr_ptr1), .rd_ptr1(rd_ptr1),
        .wr_ptr2(wr_ptr2), .rd_ptr2(rd_ptr2)
    );
    assign dout_group[0] = dout[DATA_WIDTH*1-1:DATA_WIDTH*0];
    assign dout_group[1] = dout[DATA_WIDTH*2-1:DATA_WIDTH*1];
    assign dout_group[2] = dout[DATA_WIDTH*3-1:DATA_WIDTH*2];

    // ============================================================
    // clock and reset
    // ============================================================
    initial begin
        clk = 0;
        forever #(PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #(PERIOD*10);
        rst_n = 1;
    end

    // ============================================================
    // test
    // ============================================================
    integer i;
    integer j;
    initial begin
        din = 512'b0;
        din_valid = 0;
        input_done_single_fea = 0;
        feature_width = 8'd16;  // feature width = 16
        feature_height = 8'd4;
        din_tmp = {480{1'b0}};
        @(posedge rst_n);
        @(posedge clk);

        $display("=== Start Feeding Data to FIFO0 ===");
        //input feature width data, each data width is 512 bits
        for (i = 0; i < feature_width*feature_height; i = i + 1) begin
            @(posedge clk);
                din_valid <= 1'b1;
                din <= {din_tmp, (32'h00000000 + i)};
            for(j = 0; j < 8; j = j + 1) begin
                @(posedge clk);
                din_valid <= 1'b0;
            end
        end

        @(posedge clk);
        din_valid <= 1'b0;
        din <= 'b0;
        input_done_single_fea <= 1'b1;
        @(posedge clk);
        input_done_single_fea <= 1'b0;

        $display("=== Feature input finished ===");

        //#800;
        //@(posedge clk);

        $display("=== Start Feeding Data to FIFO0 ===");
        //input feature width data, each data width is 512 bits
        for (i = 0; i < feature_width*feature_height; i = i + 1) begin
            @(posedge clk);
                din_valid <= 1'b1;
                din <= {din_tmp, (32'h00000000 + i)};
            for(j = 0; j < 8; j = j + 1) begin
                @(posedge clk);
                din_valid <= 1'b0;
            end
        end

        @(posedge clk);
        din_valid <= 1'b0;
        din <= 'b0;
        input_done_single_fea <= 1'b1;
        @(posedge clk);
        input_done_single_fea <= 1'b0;

        $display("=== Feature input finished ===");


        $display("=== Simulation Done ===");
        #2000;
        $finish;
    end

    // ============================================================
    // waveform
    // ============================================================
    initial begin
        $dumpfile("Sliding_Window_FIFO_tb.vcd");
        $dumpvars(0, tb_Sliding_Window_FIFO);
        #60000;
        $finish;
    end

endmodule
