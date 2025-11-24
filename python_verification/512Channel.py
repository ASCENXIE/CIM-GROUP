import numpy as np


def conv_pixel(pixel_data, kernel_weights):
    """
    计算一个像素的576个通道与8个卷积核的576个通道的乘加结果。
    """
    pixel_data = pixel_data.astype(np.int32)
    kernel_weights = kernel_weights.astype(np.int32)

    results = np.zeros(8, dtype=np.int32)
    for i in range(8):
        results[i] = np.dot(pixel_data, kernel_weights[i]).astype(np.int32)
    return results


def save_to_txt(pixel_data, kernel_weights, results):
    """
    将像素数据、卷积核数据和输出结果以16进制格式保存到txt文件。
    """
    pixel_data = pixel_data.astype(np.int8)
    kernel_weights = kernel_weights.astype(np.int8)
    results = results.astype(np.int32)

    # === 保存像素数据 ===
    with open('pixel_data_512.txt', 'w') as f:
        for val in pixel_data:
            f.write(f"{val & 0xFF:02X}\n")

    # === 保存卷积核数据 ===
    with open('kernel_weights_512.txt', 'w') as f:
        for ch in range(kernel_weights.shape[1]):  # 遍历576个通道
            for k in range(kernel_weights.shape[0]):  # 遍历8个卷积核
                f.write(f"{kernel_weights[k, ch] & 0xFF:02X}")
            f.write("\n")

    # === 保存输出结果 ===
    with open('conv_results_512.txt', 'w') as f:
        for val in results:
            val_26bit = val & 0x3FFFFFF  # 保留低26位
            if val < 0:
                val_26bit |= 0x2000000  # 设置符号位
            f.write(f"{val_26bit:07X}\n")


# ========================
# 主程序部分
# ========================
if __name__ == "__main__":
    np.random.seed(42)
    channel_size = 64
    # === 生成像素数据（全部随机） ===
    pixel_data = np.zeros(576, dtype=np.int32)
    pixel_data[64:channel_size+64] = np.random.randint(-128, 127, size=channel_size, dtype=np.int32)  # 前128通道有效

    # === 生成卷积核权重（全部随机） ===
    kernel_weights = np.zeros((8, 576), dtype=np.int32)
    kernel_weights[:, 64:channel_size+64] = np.random.randint(-128, 127, size=(8, channel_size), dtype=np.int32)  # 前128通道有效

    # === 计算卷积结果 ===
    results = conv_pixel(pixel_data, kernel_weights)

    # === 保存结果 ===
    save_to_txt(pixel_data, kernel_weights, results)

    # === 打印验证 ===
    print("Pixel Data (first 10 channels):", pixel_data[:10])
    print("Kernel Weights (first kernel, first 10 channels):", kernel_weights[0, :10])
    print("Convolution Results (8 kernels):", results)

    # === 手动验证点积计算 ===
    output = np.zeros(8, dtype=np.int32)
    for i in range(8):
        sum_result = 0
        for j in range(512):
            sum_result += pixel_data[j] * kernel_weights[i][j]
        output[i] = sum_result
    print("Manual Verify:", output)