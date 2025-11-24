`timescale 1ns/1ps
module Syn_FIFO #(
    parameter DATA_WIDTH = 512,
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   wr_en,
    input  wire                   rd_en,
    input  wire [DATA_WIDTH-1:0]  din,
    output reg  [DATA_WIDTH-1:0]  dout,
    output reg                    output_vld, 
    output wire                   full,
    output wire                   empty,
    output reg  [ADDR_WIDTH-1:0]  data_count,
    output reg  [ADDR_WIDTH-1:0]  wr_ptr,
    output reg  [ADDR_WIDTH-1:0]  rd_ptr
);

    // -------------------------------
    // memory array
    // -------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // -------------------------------
    // write logic
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 'b0;
        end 
        else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // -------------------------------
    // read logic + output_vld generation
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr     <= 'b0;
            dout       <= 'b0;
            output_vld <= 1'b0;
        end 
        else if (rd_en && !empty) begin
            dout       <= mem[rd_ptr];
            rd_ptr     <= rd_ptr + 1'b1;
            output_vld <= 1'b1;
        end 
        else begin
            output_vld <= 1'b0;
        end
    end

    // -------------------------------
    // counter logic
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_count <= 'b0;
        end 
        else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: data_count <= data_count + 1'b1; 
                2'b01: data_count <= data_count - 1'b1; 
                default: data_count <= data_count;
            endcase
        end
    end

    // -------------------------------
    // status signals
    // -------------------------------
    assign full  = (data_count == DEPTH);
    assign empty = (data_count == 0);

endmodule
