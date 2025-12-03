`timescale 1ns / 1ps

module tb_serial_lock();
 reg clk = 0;
 reg rst_n = 0;
 reg [3:0] key_val = 0;
 reg key_valid = 0;
 reg backspace = 0;
 reg confirm = 0;
 wire unlock, alarm;
 wire [1:0] retry_cnt;
 wire [2:0] input_len;
 // 实例化待测模块
serial_lock u_dut(
 .clk(clk), .rst_n(rst_n),
 .key_val(key_val), .key_valid(key_valid),
 .backspace(backspace), .confirm(confirm),
 .unlock(unlock), .alarm(alarm),
 .retry_cnt(retry_cnt), .input_len(input_len)
 );
 // 时钟生成
always #5 clk = ~clk;
 initial begin
 // 1. 系统初始化
rst_n = 0;
 key_val = 0; key_valid = 0; backspace = 0; confirm = 0;
 #15 rst_n = 1;
 #10;
 // Case 1: 正常输入正确密码测试 (序列: 1-2-3-4)
 // 输入 1
 @(posedge clk); key_val = 4'd1; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk); // 间隔
// 输入 2
 @(posedge clk); key_val = 4'd2; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
// 输入 3
 @(posedge clk); key_val = 4'd3; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 4
 @(posedge clk); key_val = 4'd4; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 提交确认
@(posedge clk); confirm = 1;
 @(posedge clk); confirm = 0;
 @(posedge clk);
 // 等待开锁信号拉高再拉低
wait(unlock == 1);
 wait(unlock == 0);
 #20;
 // Case 2: 编辑与退格功能测试 (序列: 1-2-9-DEL-3-4)
 // 输入 1
 @(posedge clk); key_val = 4'd1; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 2
 @(posedge clk); key_val = 4'd2; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 9 (错误位)
 @(posedge clk); key_val = 4'd9; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 #10;
 // 按下退格键
@(posedge clk); backspace = 1;
 @(posedge clk); backspace = 0;
 @(posedge clk);
 #10;
// 输入 3
 @(posedge clk); key_val = 4'd3; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 4
 @(posedge clk); key_val = 4'd4; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 提交确认
@(posedge clk); confirm = 1;
 @(posedge clk); confirm = 0;
 @(posedge clk);
 // 检查是否成功开锁
wait(unlock == 1);
 wait(unlock == 0);
 #20;
 // Case 3: 错误尝试与次数扣减测试 (初始重试机会=2)
 // 输入 1
 @(posedge clk); key_val = 4'd1; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 2 (长度不足)
 @(posedge clk); key_val = 4'd2; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 提交确认
@(posedge clk); confirm = 1;
 @(posedge clk); confirm = 0;
 @(posedge clk);
 // 此时观察波形 retry_cnt 应变 1
 #20;
 // Case 4: 耗尽机会触发锁定测试 (再错一次)
 // 输入 0
@(posedge clk); key_val = 4'd0; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 0
 @(posedge clk); key_val = 4'd0; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 0
 @(posedge clk); key_val = 4'd0; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 输入 0
 @(posedge clk); key_val = 4'd0; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 提交确认
@(posedge clk); confirm = 1;
 @(posedge clk); confirm = 0;
 @(posedge clk);
 // 此时应触发 alarm
 wait(alarm == 1);
 // 锁定期间尝试按键 (应无效)
 #20;
 @(posedge clk); key_val = 4'd1; key_valid = 1;
 @(posedge clk); key_valid = 0;
 @(posedge clk);
 // 等待锁定自动解除
wait(alarm == 0);
 // 此时观察波形 retry_cnt 应自动恢复为 2
 #20;
 $stop;
 end
 endmodule

