# Simulink 构建步骤（对应 `modular_qs_simulation.m`）

本文目标：在 Simulink 中复现脚本里的动力学仿真与输出计算。系统状态为 \(y=[N_I, N_R, A]^T\)，其中：

- \(N_I\)：LuxI 菌密度
- \(N_R\)：LuxR 菌密度
- \(A\)：AHL 浓度（nM）

脚本中的微分方程为：

\[
\dot N_I = r_I N_I \left(1 - \frac{N_I+N_R}{K}\right)
\]
\[
\dot N_R = r_R N_R \left(1 - \frac{N_I+N_R}{K}\right)
\]
\[
\dot A = k_A N_I - d_A A - \delta (N_I + N_R) A
\]

后处理输出（协同响应）：

\[
Output = \frac{A^n}{K_A^n + A^n}
\]
以及阈值激活：

\[
Activation = (A > K_A)
\]

---

## 1. 在 MATLAB 工作区准备参数（推荐：Model Workspace）

脚本参数（与 `modular_qs_simulation.m` 一致）：

- `NI0 = 0.1`
- `NR0 = 0.1`
- `A0  = 0`
- `rI = 0.7`
- `rR = 0.6`
- `K  = 1.0`
- `kA = 0.1`
- `dA = 0.05`
- `delta = 0.01`
- `KA = 5`
- `n  = 2`

操作（两种任选其一）：

- **方式 A（推荐）**：打开模型后，进入 `Model Explorer` → 选中 `Model Workspace` → 新建上述变量并赋值。（所属：**MATLAB/Simulink 自带**，不需要额外插件）
- **方式 B**：在 MATLAB 命令行运行一段初始化脚本（你也可以把它放到模型 `PreLoadFcn` 回调里）：

```matlab
NI0 = 0.1; NR0 = 0.1; A0 = 0;
rI = 0.7; rR = 0.6; K = 1.0;
kA = 0.1; dA = 0.05; delta = 0.01;
KA = 5; n = 2;
```

---

## 2. 新建 Simulink 模型并设置求解器

1. 在 MATLAB 输入 `simulink`，新建一个空模型（Blank Model）。
2. 打开 `Model Settings`（齿轮图标）：
   - **Start time**：`0`
   - **Stop time**：`24`
   - **Solver**：
     - **Type**：`Variable-step`
     - **Solver**：`ode45 (Dormand-Prince)`
   - **Max step size**：建议先留空（自动），或设为 `0.1` 方便对齐脚本采样。

---

## 3. 顶层结构建议（模块化）

建议在顶层放 3 个子系统（逻辑清晰，后续扩展方便）：

- `Dynamics`：计算 \(\dot N_I,\dot N_R,\dot A\)
- `Integrator`：3 个状态积分得到 \(N_I,N_R,A\)
- `Readout`：计算 `Output` 与 `Activation`，并把信号送去显示/保存

信号流（从右到左更符合 Simulink 常见搭法）：

`Integrator` 输出 \(N_I,N_R,A\) → 送入 `Dynamics` 计算导数 → 回到 `Integrator` 的积分器输入；同时 \(A\) → `Readout`。

---

## 4. 搭建 3 状态积分环（`Integrator` 子系统）

在 `Integrator` 子系统内放置：

1. **3 个 `Integrator` 块**（Simulink → Continuous → Integrator）
   - （所属：**Simulink 自带库**，只要安装了 Simulink 就有）
   - 第 1 个输出命名 `NI`，**Initial condition**：`NI0`
   - 第 2 个输出命名 `NR`，**Initial condition**：`NR0`
   - 第 3 个输出命名 `A`， **Initial condition**：`A0`
2. 用 `Inport` 输入三路导数：`dNI`, `dNR`, `dA`，分别连接到对应积分器输入端。
3. 用 `Outport` 输出三路状态：`NI`, `NR`, `A`。

---

## 5. 计算导数（`Dynamics` 子系统，推荐两种实现）

你可以用“纯模块搭积木”，也可以用一个 `MATLAB Function` 块一次性算出 3 个导数。为了与你脚本完全一致、且最少出错，推荐 **方式 B**。

### 方式 A：纯 Simulink 模块（不写函数）

在 `Dynamics` 子系统内：

1. 放置 3 个 `Inport`：`NI`, `NR`, `A`
2. 计算公共项：
   - `Sum`：`NI + NR` → 得到 `Nsum`
   - `Divide`：`Nsum / K`
   - `Gain` 或 `Sum`：`1 - (Nsum/K)` → 得到 `g = 1 - (NI+NR)/K`
3. 导数：
   - `dNI = rI * NI * g`（两级 `Product` + `Gain`）
   - `dNR = rR * NR * g`
   - `dA = kA*NI - dA*A - delta*(NI+NR)*A`
     - `kA*NI`：`Gain(kA)` + `Product`
     - `dA*A`：`Gain(dA)` + `Product`
     - `delta*(NI+NR)*A`：`Nsum` 与 `A` 相乘，再乘 `delta`
     - 用 `Sum`（符号设为 `+ - -`）组合成 `dA`
4. 放置 3 个 `Outport`：`dNI`, `dNR`, `dA`

### 方式 B：一个 `MATLAB Function` 块（推荐）

在 `Dynamics` 子系统内：

1. 放 `Inport`：`NI`, `NR`, `A`
2. 放一个 `MATLAB Function` 块（Simulink → User-Defined Functions → MATLAB Function）
   - （所属：**Simulink 自带库**。注意它是“Simulink 块”，不是额外插件；需要安装 Simulink 产品）
3. 双击编辑函数为（变量名请保持一致）：

```matlab
function [dNI, dNR, dA] = f(NI, NR, A, rI, rR, K, kA, dA_p, delta)
% dA_p 用于避免与输出 dA 重名

g = 1 - (NI + NR)/K;
dNI = rI * NI * g;
dNR = rR * NR * g;
dA  = kA * NI - dA_p * A - delta * (NI + NR) * A;
end
```

4. 给该 `MATLAB Function` 块增加参数输入端口：`rI, rR, K, kA, dA_p, delta`
5. 用 6 个 `Constant` 块把参数送入（数值直接填变量名即可：`rI`、`rR`、`K`、`kA`、`dA`、`delta`）。
6. 把函数块输出连到 3 个 `Outport`：`dNI`, `dNR`, `dA`

---

## 6. 将 `Dynamics` 与 `Integrator` 闭环连接（顶层连线）

在顶层：

1. `Integrator` 子系统输出 `NI, NR, A` → 连接到 `Dynamics` 子系统对应输入。
2. `Dynamics` 子系统输出 `dNI, dNR, dA` → 连接回 `Integrator` 子系统对应输入。

到此为止，ODE 动力学就搭建完成了。

---

## 7. 输出计算（`Readout` 子系统）

输入：`A`（以及可选：`KA`, `n`）。

### 7.1 计算 `Output = A^n / (KA^n + A^n)`

模块搭建建议（稳妥、直观）：

1. `Math Function` 块设置为 `pow`（或 `u^k`），计算 `A^n`
   - （所属：**Simulink 自带库**，通常在 Simulink → Math Operations → Math Function）
   - 若用 `u^k`：指数 `k` 填 `n`
2. 计算 `KA^n`
   - `Constant`：`KA`
   - `Math Function`：`KA^n`（同样指数为 `n`）
3. `Sum`：`KA^n + A^n`
4. `Divide`：`A^n / (KA^n + A^n)` → 输出命名 `Output`

### 7.2 计算 `Activation = (A > KA)`

1. 放 `Relational Operator` 块
   - （所属：**Simulink 自带库**，通常在 Simulink → Logic and Bit Operations → Relational Operator）
   - Operator 选 `>`
2. 输入 1：`A`
3. 输入 2：`Constant(KA)`
4. 输出命名 `Activation`（布尔信号）

---

## 8. 显示与保存（替代脚本里的三联图）

脚本画了 3 个子图：菌群密度、AHL、Output。Simulink 里你有两种常用方式：

### 方式 A：Scope 直接看波形（最快）

1. 放 3 个 `Scope`：
   - （所属：**Simulink 自带库**，通常在 Simulink → Sinks → Scope）
   - Scope1：输入 `NI` 与 `NR`（可先用 `Mux` 合成向量）
   - Scope2：输入 `A`
   - Scope3：输入 `Output`
2. 想画阈值线（`KA`）：
   - 建一个 `Constant(KA)`，接到 Scope2 的第二路输入（用 `Mux` 合并），这样 Scope2 里会同时显示 `A` 与一条常数线。

### 方式 B：To Workspace 保存数据（更像脚本，便于出图）

1. 分别放 `To Workspace` 块保存 `NI`, `NR`, `A`, `Output`
   - （所属：**Simulink 自带库**，通常在 Simulink → Sinks → To Workspace）
   - Save format 推荐 `Timeseries`
2. 仿真结束后在 MATLAB 命令行用你习惯的画图脚本作图（可复用 `modular_qs_simulation.m` 的绘图逻辑）。

---

## 附：库浏览器“路径 → 插件/产品”速查（菜鸟版）

下面这些块/组件，**都来自 Simulink 自带库**（也就是安装了 Simulink 就会有），不是第三方插件：

- `Simulink → Continuous → Integrator`：`Integrator`
- `Simulink → User-Defined Functions → MATLAB Function`：`MATLAB Function`
- `Simulink → Math Operations`：`Gain`、`Product`、`Divide`、`Math Function`、`Sum`
- `Simulink → Sources`：`Constant`（以及 `Inport`/`Outport` 也属于 Simulink 基础块）
- `Simulink → Signal Routing`：`Mux`（如果你需要合并多路信号）
- `Simulink → Logic and Bit Operations`：`Relational Operator`
- `Simulink → Sinks`：`Scope`、`To Workspace`

如果你在“库浏览器”里找不到上述路径，通常是下面两种原因之一：

- 你打开的不是 **Simulink Library Browser**（请在 MATLAB 命令行输入 `simulink` 打开，左侧就是库浏览器）
- 你的安装里没装 Simulink（只有 MATLAB 的话看不到 Simulink 库）

---

## 9. 常见坑与对齐检查

- **初值**：确保 3 个 Integrator 的初值分别是 `NI0, NR0, A0`，否则曲线会完全不同。
- **求解器**：必须是连续系统求解器（`ode45`）。不要用离散固定步长的离散积分器来替代（除非你明确要离散化）。
- **`dA` 符号**：AHL 方程里有两项是负号：`- dA*A - delta*(NI+NR)*A`，连线时很容易接错。
- **单位/量纲**：脚本里 `KA=5` 以 nM 表示阈值，但动力学方程并未显式做单位换算；Simulink 中保持一致即可。

---

## 10. 你最终应当看到的现象（用于自检）

- `NI`、`NR` 都呈现 logistic 类型增长，并受 `K` 限制（总量 \(N_I+N_R\) 接近 `K` 后增长趋缓）。
- `A` 会随 `NI` 增长而上升，同时被降解与消耗项抑制。
- `Output` 是随 `A` 单调上升的 Hill 曲线，接近 0→1 的饱和型输出；当 `A` 接近/超过 `KA` 时上升明显。

