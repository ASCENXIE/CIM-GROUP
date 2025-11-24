import numpy as np

def conv_pixel(pixel_data, kernel_weights):
    """
    计算一个像素的64个通道与8个卷积核的64个通道的乘加结果。
    
    参数:
        pixel_data: np.array, shape=(64,), 像素的64个通道数据，每个通道为8比特（uint8）
        kernel_weights: np.array, shape=(8, 64), 8个卷积核，每个有64个通道（uint8）
    
    返回:
        results: np.array, shape=(8,), 8个乘加结果（int32）
    """
    # 确保输入数据类型为uint8（8比特无符号整数）
    pixel_data = pixel_data.astype(np.int32)
    kernel_weights = kernel_weights.astype(np.int32)
    
    # 初始化输出结果，8个卷积核对应8个结果，使用int32避免溢出
    results = np.zeros(8, dtype=np.int32)
    
    # 对每个卷积核计算点积
    for i in range(8):
        # 点积：pixel_data * kernel_weights[i]
        # 使用np.dot进行高效计算，转换为int32避免溢出
        results[i] = np.dot(pixel_data, kernel_weights[i]).astype(np.int32)
    
    return results

def save_to_txt(pixel_data, kernel_weights, results):
    """
    将像素数据、卷积核数据和输出结果以16进制格式保存到txt文件。
    数据先转换为int8（像素和权重）或int32（结果），卷积核数据按通道排列。
    
    参数:
        pixel_data: np.array, shape=(64,), 像素数据
        kernel_weights: np.array, shape=(8, 64), 卷积核数据
        results: np.array, shape=(8,), 乘加结果
    """
    # 转换为int8（像素数据和卷积核数据）
    pixel_data = pixel_data.astype(np.int8)
    kernel_weights = kernel_weights.astype(np.int8)
    # 转换为int32（输出结果）
    results = results.astype(np.int32)
    
    # 保存像素数据
    with open('pixel_data.txt', 'w') as f:
        #f.write("Pixel Data (64 channels, 8-bit int8, hex):\n")
        for i, val in enumerate(pixel_data):
            # int8以16进制表示，负数为补码
            f.write(f"{val & 0xFF:02X}\n")
    
    # 保存卷积核数据（按通道排列）
    with open('kernel_weights.txt', 'w') as f:
        #f.write("Kernel Weights (64 channels, 8 kernels each, 8-bit int8, hex):\n")
        for ch in range(kernel_weights.shape[1]):  # 遍历64个通道
            #f.write(f"Channel {ch}:")
            for k in range(kernel_weights.shape[0]):  # 遍历8个卷积核
                # int8以16进制表示，负数为补码
                f.write(f"{kernel_weights[k, ch] & 0xFF:02X}")
            f.write("\n")
    
    # 保存输出结果（22位补码）
    with open('conv_results.txt', 'w') as f:
        for i, val in enumerate(results):
            # 截断到22位，负数以补码表示
            val_22bit = val & 0x3FFFFF  # 保留低22位
            if val < 0:
                # 如果是负数，确保补码正确
                val_22bit = val_22bit | 0x200000  # 设置符号位（第22位）
            f.write(f"{val_22bit:06X}\n")  # 保存为6位16进制


# 测试代码
if __name__ == "__main__":
    # 生成随机测试数据
    np.random.seed(42)  # 固定随机种子以确保可重复性
    pixel_data = np.random.randint(-128, 127, size=64, dtype=np.int32)  # 64个通道的像素数据
    kernel_weights = np.random.randint(-128, 127, size=(8, 64), dtype=np.int32)  # 8个卷积核
    

    # 调用函数
    results = conv_pixel(pixel_data, kernel_weights)
    
    # 保存数据到txt文件
    save_to_txt(pixel_data, kernel_weights, results)

    # 打印输入和输出
    print("Pixel Data (first 10 channels):", pixel_data[:10])
    print("Kernel Weights (first kernel, first 10 channels):", kernel_weights[0, :10])
    print("Convolution Results (8 kernels):", results)

    # 初始化输出数组，用于存储8个卷积结果
    output = np.zeros(8, dtype=np.int32)  # 使用int32避免溢出
    # 使用for循环进行卷积操作
    for i in range(8):  # 遍历8个卷积核
        sum_result = 0
        for j in range(64):  # 遍历64个通道
            sum_result += pixel_data[j] * kernel_weights[i][j]
        output[i] = sum_result

    # 打印结果
    print(output)