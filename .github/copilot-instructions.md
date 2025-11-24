## 快速导航 — 对 AI 代理的关键上下文

下面是使 AI 代理在此代码库中立即可用的要点（简洁、可操作、针对性强）。修改或扩展前请先阅读并保持接口宽度一致。

### 一句话概览
这是一个面向 CIM（Compute-In-Memory）硬件宏的 RTL 仓库。数据流：Sliding_Window_FIFO -> 特征寄存器 -> CIM 宏（CIM_576X64）-> Quantization -> 输出。Python 脚本用于在主机端生成测试向量/期望结果并与仿真输出比较。

### 关键模块与位置（参考实现）
- 顶层/组包装：`project_1.srcs/sources_1/new/CIM_Group.v` —— 管线/数据流与控制（en、i_Is_weight、feature_width 等）。
- CIM 宏：`project_1.srcs/sources_1/new/CIM_576X64.v` —— 计算核心，输出 `cim_result`（64 通道，每通道 26 bit）。
- Quantization：`project_1.srcs/sources_1/new/Quantization_Group.v` —— 进入量化流程（当前为简单右移截断 >>10，输出每通道16 bit）。
- 滑窗 FIFO：`Sliding_Window_FIFO.v` —— 负责输入窗口组织。
- Testbenches/仿真脚本：`project_1.sim/sim_1/behav/xsim/` 下含 `compile.bat/elaborate.bat/simulate.bat` 与 `*.tcl`，以及 `macro_test_data/` 用作仿真输入/输出。
- Python 验证：`python_verification/576x64.py`（以及其他脚本）用于生成 `pixel_data_*`、`kernel_weights_*` 和 `conv_results_*` 文本文件供仿真用。

### 重要数据尺寸 & 信号约定（不要随意更改）
- feature 通道：576 个通道，每通道 8 bit → 在 RTL 中常见为 576 位向量（按字节切分）。
- weight 宽度：512 bit（权重写入使用 `weight_addr`，地址线宽为 10）。
- CIM 输出：64 通道 × 26 bit -> 信号名 `cim_result`（在 `CIM_Group.v` 中为 `cim_result`，并作为 `Quantization_Group` 输入）。
- 量化输出：64 × 16 bit（当前实现为 cim_result >> 10）。
- 控制信号模式：`*_vld` / `*_valid` 用于数据有效性；`i_Is_weight` 切换 weight/feature 输入路径；`en/meb/web/cimen` 控制宏使能与写使能。

### 常见开发/仿真流程（可复制的步骤）
1. 生成测试向量（主机端期望值）：

```powershell
# 在 Windows PowerShell 中运行
python .\python_verification\576x64.py
```

2. 运行 Vivado 仿真（已存在的批处理脚本）：

```powershell
cd .\project_1.sim\sim_1\behav\xsim
.\compile.bat
.\elaborate.bat
.\simulate.bat
```

3. 仿真产物位置：`project_1.sim/sim_1/behav/xsim/macro_test_data/`（仿真会读取/写入与 `python_verification` 相同格式的 txt 文件）。如果移动仓库，请修正 python 脚本中硬编码的绝对路径。

### 修改/扩展时的具体建议（可操作）
- 若修改量化策略：优先修改 `Quantization_Group.v`，并同步更新 `python_verification/*` 中的输出格式（文件中结果以 26-bit 掩码保存）。
- 若调整通道或位宽：在 `CIM_Group.v`、`CIM_576X64.v` 与相关 testbench 中一致修改常量/参数（注意 Python 脚本也有硬编码的 channel_size/文件路径）。
- 新增特征/权重向量生成：在 `python_verification/` 添加脚本并把输出写到 `project_1.sim/.../macro_test_data/` 下，仿真即可使用现有 testbench。

### 项目约定与风格提示
- 文件命名：顶层/宏使用驼峰（CIM_Group.v、CIM_576X64.v）；testbench 位于 `project_1.srcs/sim_1/new/`。
- 代码风格：使用 generate 循环处理 64 路/逐位操作；尽量沿用已有 generate/for 写法以保持一致性（例如 `Quantization_Group` 的 generate 循环）。
- header/宏：`Header.vh`、`Macro.v`、`macro.vh` 被包含用于常量与宏定义，修改时检查是否影响下游模块。

### 集成/风险点（AI 代理必须注意）
- Python 脚本使用绝对路径（C:/work_file/grade1/...），在不同环境下需更改为相对路径或改写脚本。
- 仿真输入输出文本的位域格式与端到端数据宽度必须严格匹配（例如 26-bit 结果如何符号扩展、负数如何编码——脚本中用到的掩码与带符号位扩展需要一致）。
- 改动 bit-width/顺序会导致仿真/验证不匹配；任何接口变更应同时更新 testbench、python 验证脚本和 macro_test_data 文件。

如果某部分不清晰（比如你要改量化、或想跑不同 channel 配置），告诉我想改的目标和我会：1) 给出最小变更补丁；2) 更新 Python 验证；3) 运行并报告差异。
