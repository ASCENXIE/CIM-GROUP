#!/usr/bin/env python3
"""
int8 卷积示例
输入 : 16×4×64  int8
核 :  64×3×3×64 int8
输出: 14×2×64  int32（可再 quantize 回 int8）
padding=0, stride=1
"""
import numpy as np
np.random.seed(86)
# ---------------------------------------------------------
# 1. 造随机 int8 数据
# ----------------------------------------------------------
def rand_int8(shape):
    return np.random.randint(-128, 127+1, size=shape, dtype=np.int8)

IH, IW, IC       = 7, 7, 64
KH, KW, KC, KN   = 1, 1, 64, 64
STRIDE = 1
OH = (IH - KH) // STRIDE + 1
OW = (IW - KW) // STRIDE + 1   

x = rand_int8((IH, IW, IC))          

mask_x = np.zeros((IH, IW, IC), dtype=bool)
mask_x[:, :, 0] = True   # 第一个像素
#mask[0, 1, :] = True   # 第二个像素
x = np.where(mask_x, x, 0)

w = rand_int8((KH, KW, KC, KN))      # 3×3×64x64
mask_w = np.zeros((KH, KW, KC, KN), dtype=bool)
#mask_w[0, 0, 0, 0] = True   # 第一行第一列第一个通道第一个卷积核
mask_w[:, :, 0, 0] = True  
w = np.where(mask_w, w, 0)

# ----------------------------------------------------------
# 2. 标准 direct 2D convolution (int8 → int32)
# ----------------------------------------------------------

def conv2d_int8_direct(x, w, stride=STRIDE, padding=0):
    """
    x: (IH, IW, IC)
    w: (KH, KW, KC, KN)
    return: (OH, OW, KN) int32
    """

    IH, IW, IC = x.shape
    KH, KW, KC, KN = w.shape
    assert IC == KC

    # output size
    OH = (IH - KH + 2 * padding) // stride + 1
    OW = (IW - KW + 2 * padding) // stride + 1

    # padding
    if padding > 0:
        x_pad = np.zeros((IH + 2*padding, IW + 2*padding, IC), dtype=np.int8)
        x_pad[padding:padding+IH, padding:padding+IW, :] = x
    else:
        x_pad = x

    y = np.zeros((OH, OW, KN), dtype=np.int32)

    # direct convolution
    for oh in range(OH):
        for ow in range(OW):
            ih0 = oh * stride
            iw0 = ow * stride

            # 取输入 patch: (KH, KW, IC)
            patch = x_pad[ih0:ih0+KH, iw0:iw0+KW, :]

            # 对每个输出通道 KN 做卷积
            for k in range(KN):
                # patch * w[:, :, :, k] → accumulate to int32
                y[oh, ow, k] = np.sum(
                    patch.astype(np.int32) * w[:, :, :, k].astype(np.int32)
                )

    return y


# 使用 direct conv
y_int32 = conv2d_int8_direct(x, w)
print("输出形状:", y_int32.shape)   # (2, 14, 64)

# ----------------------------------------------------------
# 3. （可选）requantize 回 int8
# ----------------------------------------------------------
scale = 1.0
zp    = 0
y_int8 = np.clip(np.round(y_int32 * scale) + zp, -128, 127).astype(np.int8)

# ============================================================
# 4. 按规则保存特征图与权重
# ============================================================

def int8_to_hex_str(arr):
    """int8 → 两字符十六进制字符串，无0x前缀，小写"""
    return [f"{(v&0xFF):02x}" for v in arr]

# --------------------------------------------------
# 4.1 保存特征图  (OH×OW×64) → 每行一个像素的64通道
# most significant is pixel(0,0)'s channel0
# --------------------------------------------------
with open("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/pixel_data_CIM_Group.txt", "w") as f:
    for i in range(IH):        # 4 行
        for j in range(IW):    # 16 列
            hex_line = int8_to_hex_str(x[i, j, :])  # 64 通道
            f.write("".join(hex_line) + "\n")
            # if(x[i, j, :].any() != 0):
            #     print(f"非零输入像素位置: ({i},{j}) 值: {x[i,j,:]}")

# --------------------------------------------------
# 4.2 保存权重
# 要求：64 核相同 (kh,kw,c) 位置拼成一行，共 3×3×64 行
# 即先按 c 变化，再按 kw，再按 kh
# most significant is k0's first pixel's first channel
# --------------------------------------------------
with open("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/kernel_weights_CIM_Group.txt", "w") as f:
    for kw in range(KW):               # 0,1,2
        for kh in range(KH):           # 0,1,2
            for c in range(KC):        # 0..63
                # 64 个核在 (kh,kw,c) 位置的权重
                slice_64 = w[kh, kw, c, :]  # shape=(3,3,64,64)
                hex_line = int8_to_hex_str(slice_64)
                f.write("".join(hex_line)+"\n")
                # if(np.any(slice_64 != 0)):
                #     print(f"非零权重位置: (kh={kh},kw={kw},c={c}) 值: {slice_64}")

print("已生成 feature_hex.txt 与 weight_hex.txt")

# ============================================================
# 5. 保存 64 个输出通道的卷积结果
#    形状 (2,14,64) → 按通道展开，每通道 28 行，每行 64 个数
# ============================================================
def int32_to_hex_str(arr):
    """int32 → INT26十六进制字符串，无 0x 前缀，小写"""
    return [f"{(v & 0x3FFFFFF):08x}" for v in arr]


# 把 (2,14,64) 看成 28×64 矩阵，直接写 28 行，
# 每行 64 个数
# 所以：把 64 通道的 (i,j) 位置拼成一行，写 28 行即可
y_2d = y_int32.reshape(-1, KN)  # (28, 64)
with open("C:/work_file/grade1/GROUP_RTL_CODE/python_verification/output_CIM_Group.txt", "w") as f:
    for row in y_2d:
        hex_line = int32_to_hex_str(row)  # 64 个 8 位 hex
        f.write("\n".join(hex_line) + "\n")
        # if(np.any(row != 0)):
        #     print(f"非零输出行位置: 值: {row}")

    