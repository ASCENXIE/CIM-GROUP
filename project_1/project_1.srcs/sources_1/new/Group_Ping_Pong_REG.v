//=========================================================
//  Feature_Shift_CIM_Interface
//  Function:
//  1. Receives 1536-bit fifo_feature_dout and fills a
//     576×8-bit shift register (feature_reg_group) in
//     3 consecutive valid beats according to current_width_num.
//  2. When current_width_num >= 2 and CIM is ready, starts
//     a 7-cycle window (cim_input_cnt) and serializes every
//     byte LSB-first to produce 576-bit feature_din.
//  3. Manages weight-port address auto-increment.
//  4. Outputs 576-bit feature_din, CIM enable cimen and
//=========================================================
module Group_Ping_Pong_REG #(
    parameter BYTE_N        = 192,        // bytes loaded per beat
    parameter GROUP_N       = 576         // total byte depth
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [7:0]           r_Feature_Width, // not used in this module
    // FIFO-side
    input  wire [1535:0]        fifo_feature_dout,
    input  wire                 fifo_feature_dout_valid,

    // Weight port
    input  wire                 i_Is_weight,
    input  wire [511:0]         i_Lane_data,   // only lower 512b used
    output reg  [ 9:0]           weight_addr,

    // CIM interface
    output reg  [GROUP_N-1:0]   feature_din,
    output reg                  cimen
);

//------------------------------------------------------------------
// 1. Register declarations
//------------------------------------------------------------------
reg [7:0] feature_reg_group [0:GROUP_N-1];
reg [7:0] current_width_num;
reg [3:0] cim_input_cnt;
//reg [9:0] weight_addr_r;
reg       cimen_r;

//------------------------------------------------------------------
// 2. current_width_num cyclic counter
//------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_width_num <= 8'd0;
    else if (fifo_feature_dout_valid) begin
        if (current_width_num == r_Feature_Width - 1)
            current_width_num <= 8'd0;
        else
            current_width_num <= current_width_num + 8'd1;
    end
end

//------------------------------------------------------------------
// 3. Shift-register update for feature_reg_group
//------------------------------------------------------------------
integer m;
  always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < 576; m = m + 1)
                feature_reg_group[m] <= 8'b0;
                //feature_reg_group_valid <= 1'b0;
        end
        else if (fifo_feature_dout_valid && (cim_input_cnt == 4'b0 || cim_input_cnt == 4'b1)) begin    //FIFO output valid and CIM is ready to take new input
            if (current_width_num == 8'd0) begin
                // first valid fifo output → [0:191]
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[m] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b0;
            end
            else if (current_width_num == 8'd1) begin
                // second valid fifo output → [192:383]
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[192 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b0;
            end
            else if (current_width_num == 8'd2) begin
                // third valid fifo output → [384:575]
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[384 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b1;
            end
            else begin
                // update [0:191], and shift the rest
                for (m = 0; m < 384; m = m + 1)
                    feature_reg_group[m] <= feature_reg_group[m+192];
                for (m = 0; m < 192; m = m + 1)
                    feature_reg_group[m + 384] <= fifo_feature_dout[(1535-m*8) -: 8];
                //feature_reg_group_valid <= 1'b1;
            end
        end
        else begin
            //feature_reg_group_valid <= 1'b0;
            for(m = 0; m < 576; m = m + 1)
                feature_reg_group[m] <= feature_reg_group[m];
        end
    end

//------------------------------------------------------------------
// 4. Weight address auto-increment
//------------------------------------------------------------------
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            weight_addr <= 10'd0;
        end
        else if(i_Is_weight && weight_addr < 10'd575) begin
            weight_addr <= weight_addr + 10'd1;
        end
        else begin
            weight_addr <= weight_addr;
        end
    end

//------------------------------------------------------------------
// 5. CIM input window counter and enable
//------------------------------------------------------------------
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cim_input_cnt <= 4'b0;
            cimen <= 1'b0;
        end
        else if(current_width_num >= 8'd2 && fifo_feature_dout_valid 
                && (cim_input_cnt == 4'b0 || cim_input_cnt == 4'b1)) begin
            if(cimen == 1'b0)
                cim_input_cnt <= 4'd7;
            else if(cimen == 1'b1)
                cim_input_cnt <= 4'd7;
            cimen <= 1'b1;
        end        
        else begin
            if(cim_input_cnt > 4'd0) begin
                cim_input_cnt <= cim_input_cnt - 1 ;
                cimen <= 1'b1;
            end            
            else begin
                cimen <= 1'b0;
                cim_input_cnt <= 4'b0; 
            end
        end
    end

    always@(*) begin
        for(m = 0; m < 576; m = m + 1) begin
            if(cim_input_cnt >= 0)
                feature_din[m] = feature_reg_group[m][4'd7-cim_input_cnt];  //input from least significant bit
            // else if(cim_input_cnt == 0)
            //     feature_din[m] = feature_reg_group[m][4'd0];
            else 
                feature_din[m] = feature_reg_group[m][4'd0];
        end
    end

endmodule