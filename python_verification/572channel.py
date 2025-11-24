import numpy as np


def conv_pixel(pixel_data, kernel_weights):
    """
    计算一个像素的576个通道与8个卷积核的乘加结果。
    返回完整结果，以及前64通道和后512通道的分块结果。
    """
    pixel_data = pixel_data.astype(np.int32)
    kernel_weights = kernel_weights.astype(np.int32)

    results_total = np.zeros(8, dtype=np.int32)
    results_64 = np.zeros(8, dtype=np.int32)
    results_512 = np.zeros(8, dtype=np.int32)

    # 前64通道
    for i in range(8):
        results_64[i] = np.dot(pixel_data[:64], kernel_weights[i, :64]).astype(np.int32)
    # 后512通道
    for i in range(8):
        results_512[i] = np.dot(pixel_data[64:], kernel_weights[i, 64:]).astype(np.int32)
    # 总结果
    results_total = results_64 + results_512

    return results_total, results_64, results_512


def save_to_txt(pixel_data, kernel_weights, results_total, results_64, results_512):
    """
    将像素数据、卷积核数据和输出结果以16进制格式保存到txt文件。
    """
    pixel_data = pixel_data.astype(np.int8)
    kernel_weights = kernel_weights.astype(np.int8)
    results_total = results_total.astype(np.int32)
    results_64 = results_64.astype(np.int32)
    results_512 = results_512.astype(np.int32)

    # === 保存像素数据 ===
    with open('pixel_data_576.txt', 'w') as f:
        for val in pixel_data:
            f.write(f"{val & 0xFF:02X}\n")

    # === 保存卷积核数据 ===
    with open('kernel_weights_576.txt', 'w') as f:
        for ch in range(kernel_weights.shape[1]):  # 遍历576个通道
            for k in range(kernel_weights.shape[0]):  # 遍历8个卷积核
                f.write(f"{kernel_weights[k, ch] & 0xFF:02X}")
            f.write("\n")

    # === 保存结果（完整结果 + 前64 + 后512） ===
    def write_results_to_file(filename, results):
        with open(filename, 'w') as f:
            for val in results:
                val_26bit = val & 0x3FFFFFF
                if val < 0:
                    val_26bit |= 0x2000000
                f.write(f"{val_26bit:07X}\n")

    write_results_to_file('conv_results_total.txt', results_total)
    write_results_to_file('conv_results_64.txt', results_64)
    write_results_to_file('conv_results_512.txt', results_512)


# ========================
# 主程序部分
# ========================
if __name__ == "__main__":
    np.random.seed(42)
    channel_size = 576
    # === 生成像素数据（全部随机） ===
    pixel_data = np.zeros(576, dtype=np.int32)
    pixel_data[:channel_size] = np.random.randint(-128, 127, size=channel_size, dtype=np.int32)  # 前128通道有效

    # === 生成卷积核权重（全部随机） ===
    kernel_weights = np.zeros((8, 576), dtype=np.int32)
    kernel_weights[:, :channel_size] = np.random.randint(-128, 127, size=(8, channel_size), dtype=np.int32)  # 前128通道有效

    # === 计算卷积结果 ===
    results_total, results_64, results_512 = conv_pixel(pixel_data, kernel_weights)

    # === 保存结果 ===
    save_to_txt(pixel_data, kernel_weights, results_total, results_64, results_512)

    # === 打印验证 ===
    print("==== 前64通道卷积结果 ====")
    print(results_64)
    print("==== 后512通道卷积结果 ====")
    print(results_512)
    print("==== 总结果（64 + 512） ====")
    print(results_total)

    # === 验证总结果正确性 ===
    check_full = np.zeros(8, dtype=np.int32)
    for i in range(8):
        check_full[i] = np.sum(pixel_data * kernel_weights[i])
    print("==== 直接计算验证结果 ====")
    print(check_full)
    print("误差（应为全0）:", results_total - check_full)


# import numpy as np
#
#
# def conv_pixel(pixel_data, kernel_weights):
#     """
#     计算一个像素的576个通道与8个卷积核的576个通道的乘加结果。
#     """
#     pixel_data = pixel_data.astype(np.int32)
#     kernel_weights = kernel_weights.astype(np.int32)
#
#     results = np.zeros(8, dtype=np.int32)
#     for i in range(8):
#         results[i] = np.dot(pixel_data, kernel_weights[i]).astype(np.int32)
#     return results
#
#
# def save_to_txt(pixel_data, kernel_weights, results):
#     """
#     将像素数据、卷积核数据和输出结果以16进制格式保存到txt文件。
#     """
#     pixel_data = pixel_data.astype(np.int8)
#     kernel_weights = kernel_weights.astype(np.int8)
#     results = results.astype(np.int32)
#
#     # === 保存像素数据 ===
#     with open('pixel_data_576.txt', 'w') as f:
#         for val in pixel_data:
#             f.write(f"{val & 0xFF:02X}\n")
#
#     # === 保存卷积核数据 ===
#     with open('kernel_weights_576.txt', 'w') as f:
#         for ch in range(kernel_weights.shape[1]):  # 遍历576个通道
#             for k in range(kernel_weights.shape[0]):  # 遍历8个卷积核
#                 f.write(f"{kernel_weights[k, ch] & 0xFF:02X}")
#             f.write("\n")
#
#     # === 保存输出结果 ===
#     with open('conv_results_576.txt', 'w') as f:
#         for val in results:
#             val_26bit = val & 0x3FFFFFF  # 保留低26位
#             if val < 0:
#                 val_26bit |= 0x2000000  # 设置符号位
#             f.write(f"{val_26bit:07X}\n")
#
#
# # ========================
# # 主程序部分
# # ========================
# if __name__ == "__main__":
#     np.random.seed(42)
#
#     # === 生成像素数据 ===
#     pixel_data = np.zeros(576, dtype=np.int32)
#     pixel_data[:256] = np.random.randint(-128, 127, size=256, dtype=np.int32)  # 前128通道有效
#     # 后512通道全为0
#
#     # === 生成卷积核权重 ===
#     kernel_weights = np.zeros((8, 576), dtype=np.int32)
#     kernel_weights[:, :256] = np.random.randint(-128, 127, size=(8, 256), dtype=np.int32)  # 前128通道有效
#     # 后512通道全为0
#
#     # === 计算卷积结果 ===
#     results = conv_pixel(pixel_data, kernel_weights)
#
#     # === 保存结果 ===
#     save_to_txt(pixel_data, kernel_weights, results)
#
#     # === 打印验证 ===
#     print("Pixel Data (first 10 channels):", pixel_data[:10])
#     print("Kernel Weights (first kernel, first 10 channels):", kernel_weights[0, :10])
#     print("Convolution Results (8 kernels):", results)
#
#     # === 手动验证点积计算 ===
#     output = np.zeros(8, dtype=np.int32)
#     for i in range(8):
#         sum_result = 0
#         for j in range(576):
#             sum_result += pixel_data[j] * kernel_weights[i][j]
#         output[i] = sum_result
#     print("Manual Verify:", output)


