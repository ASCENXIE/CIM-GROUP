`timescale 1ns / 1ps
module serial_lock (
    input   wire    clk,
    input   wire    rst_n,
    input   [3:0]   key_val,
    input           key_valid,
    input           backspace,
    input           confirm,        //pulse
    output          unlock,
    output          alarm,
    output  [1:0]   retry_cnt,
    output  [2:0]   input_len
    );

    reg [3:0] key_val_buf[0:3];
    reg [2:0] r_input_len;
    reg [3:0] cnt_unlock;
    reg [1:0] r_retry_cnt;
    reg       r_unlock;
    reg [6:0] cnt_locked;
    reg       r_alarm;
    reg       r_alarm_d1;
    reg       r_confirm_d1;
    reg [3:0] test_state;
    assign input_len = r_input_len;
    assign retry_cnt = r_retry_cnt;
    assign unlock = r_unlock;
    assign alarm = r_alarm;
    //对输入的维护,第一位输入到key_val_buf[0]中，第二位存入key_val_buf[1]中
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_val_buf[0] <= 4'd0;
            key_val_buf[1] <= 4'd0;
            key_val_buf[2] <= 4'd0;
            key_val_buf[3] <= 4'd0;
            r_input_len <= 3'd0;
        end
        else if(key_valid && !backspace && r_input_len <= 4 && !r_alarm) begin
            r_input_len <= r_input_len + 3'd1;
            key_val_buf[r_input_len] <= key_val;
        end
        else if(backspace && (r_input_len>=0 || key_val_buf[0] !=0) && !r_alarm) begin
            key_val_buf[r_input_len-1] <= 4'd0;
            r_input_len <= r_input_len - 3'd1;
        end
        else if(confirm && !r_alarm) begin
            key_val_buf[0] <= 4'd0;
            key_val_buf[1] <= 4'd0;
            key_val_buf[2] <= 4'd0;
            key_val_buf[3] <= 4'd0;
            r_input_len <= 3'd0;
        end
        else begin
            r_input_len <= r_input_len;
        end
    end
    //密码比对及错误记录,及locked解除后复位
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_unlock <= 4'd0;
            r_retry_cnt <= 2'd2;
            r_unlock <= 1'd0;
            test_state <= 4'd0;
        end
        else if(confirm && !r_alarm) begin
            if(r_input_len ==4'd4 && {key_val_buf[0],key_val_buf[1],key_val_buf[2],key_val_buf[3]} == {4'd1,4'd2,4'd3,4'd4}) begin
                r_retry_cnt <= 2'd2;
                cnt_unlock <= 4'd10;
            end
            else begin
                r_retry_cnt <= r_retry_cnt - 2'd1;
            end
            test_state <= 4'd1;
        end
        else if(cnt_unlock > 4'd0 && !r_alarm) begin
            cnt_unlock <= cnt_unlock - 4'd1;
            r_unlock <= 1'd1;
            test_state <= 4'd2;
        end
        else if(r_alarm == 1'd0  && r_alarm_d1 == 1'd1) begin
            r_retry_cnt <= 2'd2;
            r_unlock <= 1'd0;
            cnt_unlock <= cnt_unlock;
            test_state <= 4'd3;
        end
        else begin
            r_unlock <= 1'd0;
            cnt_unlock <= cnt_unlock;
            r_retry_cnt <= r_retry_cnt;
            test_state <= 4'd4;
        end
    end
    //锁定状态逻辑
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r_confirm_d1 <= 1'd0;
            r_alarm_d1 <= 1'd0;
        end
        else begin
            r_confirm_d1 <= confirm;
            r_alarm_d1 <= r_alarm;
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_locked <= 7'd0;
            r_alarm <= 1'd0;
        end
        else if(r_retry_cnt == 2'd0 && r_confirm_d1) begin
            cnt_locked <= 7'd50;
        end
        else if(cnt_locked > 7'd0) begin
            cnt_locked <= cnt_locked - 7'd1;
            r_alarm <= 1'd1;
        end
        else if(cnt_locked == 7'd0) begin
            r_alarm <= 1'd0;
        end
        else begin
            r_alarm <= r_alarm;
            cnt_locked <= cnt_locked;
        end
    end

endmodule
