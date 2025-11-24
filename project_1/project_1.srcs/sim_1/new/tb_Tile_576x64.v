//`define FSDB
`timescale 1ns / 1ps
module tb_Tile_576X64;
//input REG Group can be switched At the begining of Input cycle 8
// input buffer Parameters
parameter PERIOD = 4;
integer i;
// input buffer inputs
reg clk = 0;
reg rstn = 0;
reg meb = 0;
reg web = 0;
reg cimen = 0;
reg [512-1:0] wgt = 0;
reg [576-1:0] feature_din = 0;
reg [$clog2(576)-1:0] addr = 0;         //at cim mode, address should be 575

// input buffer Outputs
wire [26*64-1:0] result;
wire result_ready;

wire [25:0] result_group [0:64];
reg [512-1:0] weight_mem [0:575]; 

reg [7:0] feature_mem [0:575];
reg [7:0] feature_mem_shifted [0:575];

initial begin
    $readmemh("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/kernel_weights_576x64.txt", weight_mem);
end

initial begin
    $readmemh("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/pixel_data_576x64.txt", feature_mem);
end

initial begin
    forever #(PERIOD/2) clk = ~clk;
end

initial begin
    #(PERIOD*10) rstn = 1;
end

`ifdef FSDB
initial begin
    $fsdbDumpfile("./Tile_576X64.fsdb");
    $fsdbDumpvars(0);
    $fsdbDumpMDA();
end
`endif 

reg [9:0] cnt;

CIM_576X64 u_Tile_576X64 (
    .clk         (clk            ),
    .rst_n       (rstn          ),
    .meb         (meb            ),
    .web         (web            ),
    .cimen       (cimen          ),
    .weight_din  (wgt            ),
    .weight_addr (addr       ),
    .feature_din (feature_din),
    .result_data (result         ),
    .result_ready(result_ready )
);


always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        wgt <= 'b0;
        addr <= 'b0;
        web <= 'd0;
        cnt <= 'b0;
        meb <= 1'b1;
        cimen <= 1'b0;
        for(i = 0; i < 576; i = i + 1) begin
            feature_mem_shifted[i] <= feature_mem[i];
        end
    end
    else begin       
        cnt <= cnt +1'b1;
        if (cnt > 'd575 && cnt < 'd599) begin
            meb <= 1'b0;
            web <= 1'b1;
            cimen <= 1'b1;
            addr <= addr;
            begin
                for (i = 0; i < 576; i = i + 1) begin
                    if ((cnt - 'd576) < 8) 
                        feature_din[i] <= feature_mem_shifted[i][cnt - 'd576];
                        if((cnt - 'd576) == 7) begin
                            for(i = 0; i < 576; i = i + 1) begin
                                feature_mem_shifted[i] <= 8'd0;
                            end
                        end  
                    else if(8 <= cnt - 'd576 && (cnt - 'd576) < 16)
                        feature_din[i] <= feature_mem_shifted[i][cnt - 'd584]; 
                end
            end
//            wgt = 1'b1;
        end
        else if(cnt <= 'd575) begin
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
    for(j = 0; j < 64; j = j+1) begin
        assign result_group[j] = result[26*j +:26]; 
    end

initial begin
    #20000;
    $finish;
end

endmodule