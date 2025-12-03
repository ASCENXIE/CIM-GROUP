#!/usr/bin/env python3
import sys

def compare_hex_files(path1, path2):
    different_cnt = 0
    with open(path1, 'r') as f1, open(path2, 'r') as f2:
        for line_no, (l1, l2) in enumerate(zip(f1, f2), 1):
            # 去掉换行/空格，转 16 进制整数
            try:
                v1 = int(l1.strip(), 16)
                v2 = int(l2.strip(), 16)
            except ValueError as e:
                sys.exit(f'格式错误（行 {line_no}）: {e}')
            if v1 != v2:
                different_cnt += 1
                # 如需定位，可取消下行注释
                print(f'不同 @ 行 {line_no}: {l1.strip()} != {l2.strip()}')

    # 如果两个文件行数不一致，提示剩余行
        if f1.readline() or f2.readline():
            sys.exit('错误：两个文件行数不同！')

    print(f'different_cnt = {different_cnt}')
    return different_cnt

if __name__ == '__main__':
    software_result_path = "C:\\work_file\\grade1\\GROUP_RTL_CODE\\python_verification\\output_CIM_Group.txt"
    rtl_result_path = "C:\\work_file\\grade1\\GROUP_RTL_CODE\\project_1\\project_1.sim\\sim_1\\behav\\xsim\\result_group.txt"
    compare_hex_files(software_result_path, rtl_result_path)