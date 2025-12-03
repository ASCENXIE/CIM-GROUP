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
//  4. Outputs 576-bit feature_din, CIM enable cimen
//=========================================================
module Group_Ping_Pong_REG #(
    parameter BYTE_N        = 192,        // bytes loaded per beat
    parameter GROUP_N       = 576         // total byte depth
)(
    input  wire                 clk,
    input  wire                 rst_n,
    //cfg port
    input  wire [7:0]           r_Feature_Width, 
    input  wire [2:0]           r_Kernel_cfg,   
    input  wire [1:0]           r_Stride_cfg,
    input  wire                 r_Net_cfg,
    // FIFO-side
    input  wire [1535:0]        fifo_feature_dout,
    input  wire                 fifo_feature_dout_valid,

    // Lane-side
    input  wire [511:0]         i_Lane_data,   // only lower 512b used
    input  wire                 i_Lane_data_vld,
    input  wire                 i_input_done_single_fea,
    input  wire [2:0]           Cluster_to_REG,
    input  wire [2:0]           Group_to_REG,
    // CIM interface
    output reg  [64*8-1:0]        feature_din_64,
    output reg  [512*8-1:0]       feature_din_512,
    output reg                  cimen,
    output reg                  cimen_512
);

//------------------------------------------------------------------
// 1. Register declarations
//------------------------------------------------------------------
reg [7:0] feature_reg_group_1 [0:GROUP_N-1];
reg [7:0] feature_reg_group_2 [0:GROUP_N-1];
reg feature_reg_group_1_valid;     // voltage valid flag
reg feature_reg_group_2_valid;     // voltage valid flag
reg feature_reg_group_1_512_valid;
reg feature_reg_group_2_512_valid;
reg [7:0] current_width_num;
reg [3:0] cim_input_cnt_1;
reg [3:0] cim_input_cnt_2;
reg [3:0] cim_input_cnt_1_512;
reg [3:0] cim_input_cnt_2_512;
reg [1:0] state;
// ==================================================
// 2. state machine for ping-pong buffer
// ==================================================
localparam CNN_3_1       = 2'b00;   //CNN 3x3 kernel, stride 1
localparam CNN_3_2       = 2'b01;   //CNN 3x3 kernel, stride 2
localparam CNN_1_1       = 2'b10;   //CNN 1x1 kernel, stride 1
localparam Transformer   = 2'b11;   //Transformer mode
always @(*) begin
    case({r_Net_cfg, r_Kernel_cfg, r_Stride_cfg})
            6'b0_011_01 : state = CNN_3_2;      //CNN 3x3 stride 2
            6'b0_011_00 : state = CNN_3_1;      //CNN 3x3 stride 1
            6'b0_001_00 : state = CNN_1_1;      //CNN 1x1 stride 1
            6'b1_xxx_xx : state = Transformer;  //Transformer mode
            default     : state = CNN_3_1;
    endcase
end


//------------------------------------------------------------------
// 3. current_width_num cyclic counter, After outputting each row of the feature map, the data in the REG needs to be cleared.
//------------------------------------------------------------------
reg Row_Is_Odd;     //indicates whether the current row is odd or even, used for CIM 3x3 stride 2 mode, only even rows need to be input
reg r_input_done_single_fea;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_width_num <= 8'd0;
    end
    else if (fifo_feature_dout_valid) begin
        if (current_width_num == r_Feature_Width - 1) begin
            current_width_num <= 8'd0;
        end
        else
            current_width_num <= current_width_num + 8'd1;
    end
    else
        current_width_num <= current_width_num;
end
// Row_Is_Odd is used to indicate whether the current row is odd or even, only even rows need to be input in CIM 3x3 stride 2 mode
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Row_Is_Odd <= 1'b0;
        r_input_done_single_fea <= 1'b0;
    end
    else if (i_input_done_single_fea) begin
        //Row_Is_Odd <= 1'b0;
        r_input_done_single_fea <= 1'b1;
    end 
    else if (fifo_feature_dout_valid && current_width_num == r_Feature_Width - 1) begin
        if(!r_input_done_single_fea)
            Row_Is_Odd <= ~Row_Is_Odd;
        else if(r_input_done_single_fea) begin
            Row_Is_Odd <= 1'b0;
            r_input_done_single_fea <= 1'b0;
        end
    end
    else begin
        Row_Is_Odd <= Row_Is_Odd;
    end
end

//------------------------------------------------------------------
// 4. Shift-register update for feature_reg_group
//------------------------------------------------------------------
integer m;
reg [2:0] cnt_512_input;
// reg cnt_512_input_1_d1;
//     always @(posedge clk or negedge rst_n) begin
//         if(!rst_n) begin
//             cnt_512_input_1_d1 <= 1'd0;
//         end
//         else begin
//             cnt_512_input_1_d1 <= cnt_512_input[0];
//         end
//     end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < 576; m = m + 1) begin
                feature_reg_group_1[m] <= 8'b0;
                feature_reg_group_2[m] <= 8'b0;
                //feature_reg_group_valid <= 1'b0;
            end
            cnt_512_input <= 3'b0;
        end
        else begin case(state)
            CNN_3_1: begin     // CNN 3x3 stride 1, need to shift the REG content every time when fifo_feature_dout_valid is high and CIM is ready
                if (fifo_feature_dout_valid &&  (feature_reg_group_1_valid == 1'b0 || cim_input_cnt_1 == 4'd0) ) begin    //FIFO output valid and CIM is ready to take new input
                    if (current_width_num == 8'd0) begin
                        for (m = 0; m < 192; m = m + 1)
                            feature_reg_group_1[m] <= fifo_feature_dout[(1535-m*8) -: 8];
                   end
                    else if (current_width_num == 8'd1) begin
                        for (m = 0; m < 192; m = m + 1)
                            feature_reg_group_1[192 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                    end
                    else if (current_width_num == 8'd2) begin
                        for (m = 0; m < 192; m = m + 1)
                            feature_reg_group_1[384 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                    end
                    else begin
                        for (m = 0; m < 384; m = m + 1)
                            feature_reg_group_1[m] <= feature_reg_group_1[m+192];
                        for (m = 0; m < 192; m = m + 1)
                            feature_reg_group_1[m + 384] <= fifo_feature_dout[(1535-m*8) -: 8];
                    end
                end
                else begin
                    for(m = 0; m < 576; m = m + 1)
                        feature_reg_group_1[m] <= feature_reg_group_1[m];
                end
            end
            CNN_3_2: begin
                if(fifo_feature_dout_valid && !Row_Is_Odd) begin
                    if ({current_width_num[1], current_width_num[0]} == 2'b00) begin
                        for (m = 0; m < 192; m = m + 1) begin
                            if(cim_input_cnt_1 == 4'd0)                                 //when feature_reg_group_1 is envolved in CIM computation, do not update it 
                                feature_reg_group_1[m] <= fifo_feature_dout[(1535-m*8) -: 8];
                            if(cim_input_cnt_2 == 4'd0)
                                feature_reg_group_2[384 + m] <= fifo_feature_dout[(1535-m*8) -: 8]; //ping-pong buffer
                        end
                    end
                    else if ({current_width_num[1], current_width_num[0]} == 2'b01) begin
                        for (m = 0; m < 192; m = m + 1)
                            if(cim_input_cnt_1 == 4'd0)
                                feature_reg_group_1[192 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                    end
                    else if ({current_width_num[1], current_width_num[0]} == 2'b10) begin
                        for (m = 0; m < 192; m = m + 1) begin
                            if(cim_input_cnt_1 == 4'd0)
                                feature_reg_group_1[384 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                            if(cim_input_cnt_2 == 4'd0)
                                feature_reg_group_2[m] <= fifo_feature_dout[(1535-m*8) -: 8]; //ping-pong buffer
                        end
                    end
                    else if ({current_width_num[1], current_width_num[0]} == 2'b11) begin
                        for (m = 0; m < 384; m = m + 1) begin
                            if(cim_input_cnt_2 == 4'd0)
                                feature_reg_group_2[192 + m] <= fifo_feature_dout[(1535-m*8) -: 8];
                        end    
                    end
                    else begin
                        for (m = 0; m < 384; m = m + 1) begin
                            feature_reg_group_1[m] <= feature_reg_group_1[m];
                            feature_reg_group_2[m] <= feature_reg_group_2[m];
                        end
                    end
                end
                else begin
                    for(m = 0; m < 576; m = m + 1) begin
                        feature_reg_group_1[m] <= feature_reg_group_1[m];
                        feature_reg_group_2[m] <= feature_reg_group_2[m];
                    end
                end
            end
            //CNN 1*1 and transformer mode, no need to shift the REG content, and feature set in order
            CNN_1_1: begin
                if(i_Lane_data_vld && cim_input_cnt_1 == 4'b0) begin
                    for (m = 0; m < 64; m = m + 1)
                        feature_reg_group_1[m] <= i_Lane_data[(512-1 - m*8) -: 8];
                end
                else begin
                    for(m = 0; m < 576; m = m + 1)
                        feature_reg_group_1[m] <= feature_reg_group_1[m];
                end
            end
            Transformer: begin
                if(i_Lane_data_vld && cim_input_cnt_1 == 4'b0 && Group_to_REG != 3'd0 && Cluster_to_REG == 3'd0) begin 
                    for (m = 0; m < 64; m = m + 1)
                        feature_reg_group_1[m] <= i_Lane_data[(512-1 - m*8) -: 8];
                end
                else if(i_Lane_data_vld && cim_input_cnt_1_512 == 4'b0 && Group_to_REG == 3'd0 && Cluster_to_REG != 3'd0) begin
                    for (m = 0; m < 64; m = m + 1)
                        feature_reg_group_1[m + cnt_512_input*64 + 64] <= i_Lane_data[(512-1 - m*8) -: 8];
                    cnt_512_input <= cnt_512_input + 3'd1;
                end
                else if(i_Lane_data_vld && cim_input_cnt_2 == 4'b0 && Group_to_REG != 3'd0 && Cluster_to_REG == 3'd0) begin 
                    for (m = 0; m < 64; m = m + 1)
                        feature_reg_group_2[m] <= i_Lane_data[(512-1 - m*8) -: 8];
                end
                else if(i_Lane_data_vld && cim_input_cnt_2_512 == 4'b0 && Group_to_REG == 3'd0 && Cluster_to_REG != 3'd0) begin
                    for (m = 0; m < 64; m = m + 1)
                        feature_reg_group_2[m + cnt_512_input*64 + 64] <= i_Lane_data[(512-1 - m*8) -: 8];
                    cnt_512_input <= cnt_512_input + 3'd1;
                end
                else begin
                    for(m = 0; m < 576; m = m + 1) begin
                        feature_reg_group_1[m] <= feature_reg_group_1[m];
                        feature_reg_group_2[m] <= feature_reg_group_2[m];
                    end    
                end                
            end
            default: begin
                for(m = 0; m < 576; m = m + 1) begin
                    feature_reg_group_1[m] <= feature_reg_group_1[m];
                    feature_reg_group_2[m] <= feature_reg_group_2[m];
                end    
                cnt_512_input <= cnt_512_input;
            end
        endcase
        end
    end

//------------------------------------------------------------------
// 5. CIM input window counter and fifo valid check
//------------------------------------------------------------------
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cim_input_cnt_1 <= 4'b0;
            cim_input_cnt_2 <= 4'b0;
            cim_input_cnt_1_512 <= 4'b0;
            cim_input_cnt_2_512 <= 4'b0;
            feature_reg_group_1_valid <= 1'b0;
            feature_reg_group_2_valid <= 1'b0;
            feature_reg_group_1_512_valid <= 1'b0;
            feature_reg_group_2_512_valid <= 1'b0;
            cimen <= 1'b0;
            cimen_512 <= 1'b0;
        end
        else begin case(state)
            CNN_3_1: begin
                if(current_width_num >= 8'd2 && fifo_feature_dout_valid  && cim_input_cnt_1 == 4'b0) begin // when REG is ready and old computation is done
                    cim_input_cnt_1 <= 4'd7;
                    cimen <= 1'b1;
                    cimen_512 <= 1'b1;
                    feature_reg_group_1_valid <= 1'b1;
                end        
                else begin
                    if(cim_input_cnt_1 > 4'd0) begin
                        cim_input_cnt_1 <= cim_input_cnt_1 - 1 ;
                        cimen <= 1'b1;
                        cimen_512 <= 1'b1;
                    end            
                    else begin
                        cimen <= 1'b0;
                        cimen_512 <= 1'b0;
                        cim_input_cnt_1 <= 4'b0; 
                        feature_reg_group_1_valid <= 1'b0;
                    end
                end
            end
            CNN_3_2: begin
                if(fifo_feature_dout_valid && !Row_Is_Odd && {current_width_num[1], current_width_num[0]} == 2'b10 && cim_input_cnt_1 == 4'b0) begin
                        feature_reg_group_1_valid <= 1'b1;
                        cim_input_cnt_1 <= 4'd7;        // use cim_input_cnt_1 for feature_reg_group_1 input
                        cimen <= 1'b1;
                        cimen_512 <= 1'b1;
                        feature_reg_group_2_valid <= 1'b0;   // disable feature_reg_group_2 when feature_reg_group_1 is valid
                end
                else if(fifo_feature_dout_valid && !Row_Is_Odd && {current_width_num[1], current_width_num[0]} == 2'b00 && cim_input_cnt_2 == 4'b0 && |current_width_num) begin
                        feature_reg_group_2_valid <= 1'b1;
                        cim_input_cnt_2 <= 4'd7;
                        cimen <= 1'b1;
                        cimen_512 <= 1'b1;
                        feature_reg_group_1_valid <= 1'b0;   // disable feature_reg_group_1 when feature_reg_group_2 is valid
                end   
                else begin
                    if(cim_input_cnt_1 > 4'd0) begin
                        cim_input_cnt_1 <= cim_input_cnt_1 - 1 ;
                        cimen <= 1'b1;
                        cimen_512 <= 1'b1;
                    end            
                    else if(cim_input_cnt_1 == 4'd0) begin
                        cimen <= 1'b0;
                        cimen_512 <= 1'b0;
                        cim_input_cnt_1 <= 4'b0; 
                        feature_reg_group_1_valid <= 1'b0;
                        if(cim_input_cnt_2 > 4'd0) begin
                            cim_input_cnt_2 <= cim_input_cnt_2 - 1 ;
                            cimen <= 1'b1;
                            cimen_512 <= 1'b1;
                        end            
                        else if(cim_input_cnt_2 == 4'd0) begin
                            cimen <= 1'b0;
                            cimen_512 <= 1'b0;
                            cim_input_cnt_2 <= 4'b0; 
                            feature_reg_group_2_valid <= 1'b0;
                        end
                    end
                    else begin
                        cimen <= 1'b0;
                        cimen_512 <= 1'b0;
                        cim_input_cnt_1 <= cim_input_cnt_1;
                        cim_input_cnt_2 <= cim_input_cnt_2;
                        feature_reg_group_1_valid <= feature_reg_group_1_valid;
                        feature_reg_group_2_valid <= feature_reg_group_2_valid;
                        // feature_reg_group_1_valid <= 1'd0;
                        // feature_reg_group_2_valid <= 1'd0;
                    end
                end
            end
            CNN_1_1: begin
                if(i_Lane_data_vld && cim_input_cnt_1 == 4'b0) begin
                    cim_input_cnt_1 <= 4'd7;
                    cimen <= 1'b1;
                    cimen_512 <= 1'b0;
                    feature_reg_group_1_valid <= 1'b1;
                end        
                else begin
                    if(cim_input_cnt_1 > 4'd0) begin
                        cim_input_cnt_1 <= cim_input_cnt_1 - 1 ;
                        cimen <= 1'b1;
                        cimen_512 <= 1'b0;
                    end            
                    else begin
                        cimen <= 1'b0;
                        cimen_512 <= 1'b0;
                        cim_input_cnt_1 <= 4'b0; 
                        feature_reg_group_1_valid <= 1'b0;
                    end
                end
            end
            Transformer: begin
                if(i_Lane_data_vld && cim_input_cnt_1 == 4'b0 && Group_to_REG != 3'd0 && Cluster_to_REG == 3'd0) begin
                    cim_input_cnt_1 <= 4'd7;
                    cimen <= 1'b1;
                    //cimen_512 <= 1'b0;
                    feature_reg_group_1_valid <= 1'b1;
                end    
                else if(i_Lane_data_vld && cim_input_cnt_1_512 == 4'b0 && Group_to_REG == 3'd0 && Cluster_to_REG != 3'd0 && (&cnt_512_input)) begin
                    cim_input_cnt_1_512 <= 4'd7;
                    //cimen <= 1'b0;
                    cimen_512 <= 1'b1;
                    feature_reg_group_1_512_valid <= 1'b1;
                end
                else if(i_Lane_data_vld && cim_input_cnt_2 == 4'b0 && Group_to_REG != 3'd0 && Cluster_to_REG == 3'd0) begin
                    cim_input_cnt_2 <= 4'd7;
                    cimen <= 1'b1;
                    //cimen_512 <= 1'b0;
                    feature_reg_group_2_valid <= 1'b1;
                end    
                else if(i_Lane_data_vld && cim_input_cnt_2_512 == 4'b0 && Group_to_REG == 3'd0 && Cluster_to_REG != 3'd0 && (&cnt_512_input)) begin
                    cim_input_cnt_2_512 <= 4'd7;
                    //cimen <= 1'b0;
                    cimen_512 <= 1'b1;
                    feature_reg_group_2_512_valid <= 1'b1;
                end
                else begin
                    if(cim_input_cnt_1 > 4'd0) begin
                        cim_input_cnt_1 <= cim_input_cnt_1 - 1 ;
                        cimen <= 1'b1;
                    end            
                    else if(cim_input_cnt_1 == 4'd0) begin
                        cimen <= 1'b0;
                        cim_input_cnt_1 <= 4'b0; 
                        feature_reg_group_1_valid <= 1'b0;
                        if(cim_input_cnt_2 > 4'd0) begin
                            cim_input_cnt_2 <= cim_input_cnt_2 - 1 ;
                            cimen <= 1'b1;
                        end            
                        else begin
                            cimen <= 1'b0;
                            cim_input_cnt_2 <= 4'b0; 
                            feature_reg_group_2_valid <= 1'b0;
                        end
                    end

                    if(cim_input_cnt_1_512 > 4'd0) begin
                        cim_input_cnt_1_512 <= cim_input_cnt_1_512 - 1 ;
                        cimen_512 <= 1'b1;
                    end            
                    else if(cim_input_cnt_1_512 == 4'd0) begin
                        cimen_512 <= 1'b0;
                        cim_input_cnt_1_512 <= 4'b0; 
                        feature_reg_group_1_512_valid <= 1'b0;
                        if(cim_input_cnt_2_512 > 4'd0) begin
                            cim_input_cnt_2_512 <= cim_input_cnt_2_512 - 1 ;
                            cimen_512 <= 1'b1;
                        end            
                        else begin
                            cimen_512 <= 1'b0;
                            cim_input_cnt_2_512 <= 4'b0; 
                            feature_reg_group_2_512_valid <= 1'b0;
                        end
                    end
                end
            end
            default: begin
                feature_reg_group_1_valid <= 1'b0;
                feature_reg_group_2_valid <= 1'b0;
                feature_reg_group_1_512_valid <= 1'b0;
                feature_reg_group_2_512_valid <= 1'b0;
                cim_input_cnt_1 <= 4'b0;
                cim_input_cnt_2 <= 4'b0;
                cim_input_cnt_1_512 <= 4'b0;
                cim_input_cnt_2_512 <= 4'b0;
                cimen <= 1'b0;
                cimen_512 <= 1'b0;
            end
        endcase
        end
    end

    //==================================================================
    // 6. select feature_din from ping-pong REG according to cim_input_cnt and valid flag
    //==================================================================
    always@(*) begin
        case(state)
            CNN_3_1, CNN_3_2, CNN_1_1: begin
                for(m = 0; m < 64; m = m + 1) begin
                    if(feature_reg_group_1_valid)
                        feature_din_64[m] = feature_reg_group_1[m][4'd7-cim_input_cnt_1];  //input from least significant bit
                    else if(feature_reg_group_2_valid)
                        feature_din_64[m] = feature_reg_group_2[m][4'd7-cim_input_cnt_2];
                    else
                        feature_din_64[m] = feature_reg_group_1[m][0];
                end
                for(m = 0; m < 512; m = m + 1) begin
                    if(feature_reg_group_1_valid)
                        feature_din_512[m] = feature_reg_group_1[m+64][4'd7-cim_input_cnt_1];  //input from least significant bit
                    else if(feature_reg_group_2_valid)
                        feature_din_512[m] = feature_reg_group_2[m+64][4'd7-cim_input_cnt_2];
                    else
                        feature_din_512[m] = feature_reg_group_1[m+64][0];
                end
            end
            Transformer: begin
                for(m = 0; m < 64; m = m + 1) begin
                    if(feature_reg_group_1_valid)
                        feature_din_64[m] = feature_reg_group_1[m][4'd7-cim_input_cnt_1];  //input from least significant bit
                    else if(feature_reg_group_2_valid)
                        feature_din_64[m] = feature_reg_group_2[m][4'd7-cim_input_cnt_2];
                    else
                        feature_din_64[m] = feature_reg_group_1[m][0];
                end
                for(m = 0; m < 512; m = m + 1) begin
                    if(feature_reg_group_1_512_valid)
                        feature_din_512[m] = feature_reg_group_1[m+64][4'd7-cim_input_cnt_1_512];  //input from least significant bit
                    else if(feature_reg_group_2_512_valid)
                        feature_din_512[m] = feature_reg_group_2[m+64][4'd7-cim_input_cnt_2_512];
                    else
                        feature_din_512[m] = feature_reg_group_1[m+64][0];
                end
            end
        endcase
    end

endmodule