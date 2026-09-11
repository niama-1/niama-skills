# RuyiTrace 工具完整使用指南

本文档是 RuyiTrace 动态跟踪工具的通用操作手册，供 AI 代理和研究人员参考。

> **适用边界**：仅用于自有或明确授权的目标。本文强调证据驱动的 Web 调试、协议分析和互操作性研究；不得将测试数据中的 Cookie、Token、密钥或个人信息直接固化到共享代码中。
>
> **入口关系**：总导航见 [README.md](README.md)，标准项目流程见 [AGENTS_STANDARD_WORKFLOW.md](AGENTS_STANDARD_WORKFLOW.md)，静态分析方法论见 [AGENTS_ERROR_7.md](AGENTS_ERROR_7.md)。本文件负责工具配置、输出结构与故障排查。

## 0.1 证据优先与协议分析门槛

在下结论或开始实现前，至少完成以下闭环：

1. **静态来源**：保存 HTML、相关 JS、资源清单和加载顺序。
2. **运行时证据**：读取 `trace_init`，核对 `jscall` 调用与 `http_packet` 请求/响应。
3. **协议模型**：按时间建立接口序列、前置状态、字段来源、编码/加密边界和响应状态转换。
4. **独立验证**：用多个样本进行差分；关键算法至少记录输入、输出和首个偏差点。

结论必须标记为“已确认”“运行时观察”“推测/待验证”或“已否定”。没有证据的推测不得作为最终实现依据；动态 Cookie、Token 和随机值不得当作永久常量。

---

## 1. 工具概述

**RuyiTrace** 是一个基于 Firefox 的动态跟踪工具，用于捕获 JavaScript 运行时行为、HTTP 请求和 DOM 操作。

**核心能力**：
- JavaScript 函数调用跟踪（参数、返回值、调用栈）
- HTTP 请求/响应完整记录（headers、body、timing）
- DOM 操作和事件捕获
- Cookie、LocalStorage、SessionStorage 记录
- WebSocket 握手记录

**关键特点**：
- 通过环境变量配置（`MOZ_DOM_*` 系列）
- 输出为 JSONL 格式（每行一个 JSON 对象）
- 支持配置导入/导出（JSON 格式）
- 内置 Firefox 浏览器，无需额外安装

---

## 2. 工具启动与界面

### 2.1 启动程序

```
双击 RuyiTrace.exe
```

### 2.2 主界面组成

1. **环境变量配置区域**：显示/编辑 `MOZ_DOM_*` 变量
2. **配置导入/导出按钮**：加载或保存 JSON 配置文件
3. **Firefox 启动按钮**：使用当前配置启动浏览器
4. **输出目录显示**：显示跟踪数据保存位置
5. **状态指示器**：显示采集进程状态

**注意**：实际界面可能与上述描述有差异，以实际 GUI 为准。

---

## 3. 配置系统详解

### 3.1 配置文件格式

```json
{
  "schema": "domtrace-switch-config",
  "version": 1,
  "exportedAt": "2026-09-01T00:00:00.000Z",
  "app": "console-electron",
  "switches": {
    "环境变量名": "变量值",
    ...
  },
  "notes": "配置说明（可选）"
}
```

### 3.2 关键环境变量速查表

#### 3.2.1 通用跟踪

| 变量名 | 作用 | 推荐值 | 说明 |
|--------|------|--------|------|
| `MOZ_DOM_TRACE` | 启用跟踪系统 | `1` | 必须为 1 才能启用其他功能 |
| `MOZ_DOM_TRACE_FILE` | 输出目录前缀 | `<路径>/trace` | 实际输出在此路径的父目录（见下方详细说明） |

#### 3.2.2 JavaScript 调用跟踪

| 变量名 | 作用 | 推荐值 | 说明 |
|--------|------|--------|------|
| `MOZ_DOM_JSCALL_TRACE` | 启用 JS 调用跟踪 | `1` | 捕获函数调用 |
| `MOZ_DOM_JSCALL_LIMIT` | 记录数量限制 | `0` | 0=无限制 |
| `MOZ_DOM_JSCALL_FLUSH_INTERVAL` | 刷新间隔（秒） | `1` | 数据写入磁盘频率 |
| `MOZ_DOM_JSCALL_TARGET_ONLY` | 只跟踪目标脚本 | `1` | 减少噪音 |
| `MOZ_DOM_JSCALL_SCRIPT_URL` | 目标脚本 URL 匹配 | 部分 URL | 模糊匹配，支持子串 |
| `MOZ_DOM_JSCALL_DETAIL_FUNCS` | 详细跟踪的函数名 | 逗号分隔列表 | 如 `func1,func2,func3`，无空格 |
| `MOZ_DOM_JSCALL_DETAIL_SCRIPT_URL` | 详细跟踪的脚本 | 部分 URL | 与 SCRIPT_URL 配合使用 |
| `MOZ_DOM_JSCALL_SHALLOW` | 浅层模式 | **省略或 `1`** | 见下方重要说明 |
| `MOZ_DOM_JSCALL_MAX_VALUE_BYTES` | 参数/返回值大小限制 | `131072` ~ `524288` | 字节数 |
| `MOZ_DOM_JSCALL_DEEP_LONG_STR` | 长字符串完整捕获 | `131072` ~ `524288` | 字节数 |

#### 3.2.3 HTTP 跟踪

| 变量名 | 作用 | 推荐值 | 说明 |
|--------|------|--------|------|
| `MOZ_DOM_HTTP_PACKET_TRACE` | 启用 HTTP 跟踪 | `1` | 捕获请求/响应 |

#### 3.2.4 异常跟踪

| 变量名 | 作用 | 推荐值 | 说明 |
|--------|------|--------|------|
| `MOZ_DOM_EXCEPTION_TRACE` | 启用异常跟踪 | `1` | 捕获 JS 异常 |
| `MOZ_DOM_EXCEPTION_LIMIT` | 异常记录限制 | `0` | 0=无限制 |
| `MOZ_DOM_EXCEPTION_FLUSH_INTERVAL` | 异常刷新间隔 | `1` | 秒 |

### 3.3 MOZ_DOM_TRACE_FILE 路径说明

**重要**：`MOZ_DOM_TRACE_FILE` 的值必须以 `/trace` 结尾，实际输出目录是其**父目录**。

**示例**：
```
设置：MOZ_DOM_TRACE_FILE=D:\traceOut\CSAIR\trace
实际输出：D:\traceOut\CSAIR\ 下会生成 jscall/、http_packet/ 等子目录

设置：MOZ_DOM_TRACE_FILE=D:\traceOut\mysite\round1\trace
实际输出：D:\traceOut\mysite\round1\ 下会生成子目录
```

**目录组织建议**：
```
traceOut/
├── CSAIR/                    ← 一个站点一个目录
│   ├── trace                 ← MOZ_DOM_TRACE_FILE 指向这里
│   ├── jscall/               ← 实际输出在 CSAIR/ 下
│   ├── http_packet/
│   └── ...
├── AnotherSite/              ← 另一个站点
│   ├── trace
│   ├── jscall/
│   └── ...
```

### 3.4 MOZ_DOM_JSCALL_SHALLOW 重要说明

**工作原理**：
```
shallow_values=true（默认）：
  - 对普通函数：只记录类型（如 {type: "string"}）
  - 对 DETAIL_FUNCS 中的函数：完整记录参数值（无视 shallow 设置！）
  
结果：最优配置 = 省略 MOZ_DOM_JSCALL_SHALLOW + 正确设置 DETAIL_FUNCS
```

**推荐做法**：
- ✅ **不设置** `MOZ_DOM_JSCALL_SHALLOW`（让其保持默认 true）
- ✅ 正确配置 `MOZ_DOM_JSCALL_DETAIL_FUNCS`（目标函数列表）
- ❌ 不要设置 `MOZ_DOM_JSCALL_SHALLOW=0`（会导致海量数据）

**验证方法**：
```bash
# 启动后检查 trace_init
grep '"trace_init"' jscall/trace_jscall_*.jsonl | python -m json.tool
# 应该看到 "shallow_values": true，这是正确的
```

### 3.5 URL 匹配策略

**动态 URL 处理**：
- 使用稳定的路径片段进行匹配，避免硬编码完整 URL
- 例如：使用 `captcha-frontend` 而不是完整的 CDN 路径
- 脚本文件名可能包含 hash 或日期，需要使用通用匹配

**示例**：
```
✅ 推荐：MOZ_DOM_JSCALL_SCRIPT_URL=captcha-frontend
❌ 不推荐：MOZ_DOM_JSCALL_SCRIPT_URL=https://g.alicdn.com/captcha-frontend/FeiLin/feilin003.01019983.js
```

---

## 4. 完整操作流程

### 步骤 1：准备配置文件

**选项 A：从已有配置导入**
```
1. 打开 RuyiTrace.exe
2. 点击"导入配置"按钮（或菜单）
3. 选择配置 JSON 文件
4. 确认环境变量已加载到界面
```

**选项 B：手动配置**
```
1. 打开 RuyiTrace.exe
2. 在环境变量配置区域逐个添加/编辑变量
3. 参考"关键环境变量速查表"设置推荐值
```

### 步骤 2：设置输出目录

**关键配置**：
```
MOZ_DOM_TRACE_FILE=<基础路径>/traceOut/<站点名称>/<轮次目录>/trace
```

**推荐目录组织结构**（重要！）：
```
traceOut/
├── CSAIR/                           ← 一个站点一个主目录
│   ├── csair-round1/                ← 第一轮采集
│   │   ├── trace                    ← MOZ_DOM_TRACE_FILE 指向这里
│   │   ├── jscall/                  ← 实际输出在这里
│   │   ├── http_packet/
│   │   └── ...
│   ├── csair-round2/                ← 第二轮采集
│   │   └── ...
│   └── csair-round1-explore.json    ← 配置文件保存在站点根目录
│
├── Taobao/                          ← 另一个站点
│   ├── taobao-round1/
│   └── ...
```

**目录命名规范**：
```
站点主目录：使用站点名称（如 CSAIR、Taobao、MyProject）
轮次子目录：<站点名>-round<数字>[-描述]（如 csair-round1、csair-round2-targeted）
配置文件：保存在站点主目录，命名为 <站点名>-round<数字>-<目的>.json
```

**配置示例**：
```json
{
  "switches": {
    "MOZ_DOM_TRACE_FILE": "D:\\traceOut\\CSAIR\\csair-round1\\trace"
  }
}
// 实际输出：D:\traceOut\CSAIR\csair-round1\ 下生成 jscall/、http_packet/ 等子目录
```

**原则**：
- 一个站点一个主目录（便于管理所有轮次）
- 每轮采集使用独立的子目录（避免数据覆盖）
- 配置文件保存在站点主目录（便于追溯）
- 轮次目录命名清晰标注目的（如 explore、targeted、diff）

### 步骤 3：验证配置（启动前）

**检查清单**：
- [ ] `MOZ_DOM_TRACE=1`
- [ ] `MOZ_DOM_TRACE_FILE` 指向新目录
- [ ] `MOZ_DOM_JSCALL_TRACE=1`（如需 JS 跟踪）
- [ ] `MOZ_DOM_JSCALL_DETAIL_FUNCS` 包含目标函数
- [ ] `MOZ_DOM_JSCALL_SCRIPT_URL` 使用稳定匹配
- [ ] `MOZ_DOM_JSCALL_SHALLOW` **未设置或为空**（不是 0）
- [ ] `MOZ_DOM_HTTP_PACKET_TRACE=1`（如需 HTTP 跟踪）

### 步骤 4：启动 Firefox

```
1. 点击"启动 Firefox"按钮
2. 等待 Firefox 窗口出现
3. 观察 RuyiTrace 主界面的状态指示器
```

**注意**：
- 不要同时运行多个 RuyiTrace Firefox 实例
- 不要在启动后修改环境变量（需重启生效）

### 步骤 5：验证配置（启动后）

**立即检查输出目录**：
```bash
# 查看目录结构
ls -la traceOut/<本轮名称>/

# 应该看到以下子目录被创建：
jscall/
http_packet/
domtrace/
cookie/
storage/
```

**检查 trace_init**：
```bash
# 查看 jscall 初始化记录
grep '"trace_init"' traceOut/<本轮名称>/jscall/*.jsonl

# 验证关键参数：
# - shallow_values: 应为 true（正常情况）
# - detail_funcs: 应包含目标函数列表
# - detail_script_url: 应匹配目标脚本
# - target_only_enabled: 应为 true
```

**如果 trace_init 不正确**：
```
1. 关闭 Firefox
2. 回到 RuyiTrace 主界面
3. 修正环境变量
4. 删除错误的输出目录
5. 重新启动 Firefox
```

### 步骤 6：执行采集

**采集原则**：
- 一次采集只做一个完整流程
- 避免重复操作（避免数据混淆）
- 如需多个样本，分多轮采集
- 只打开一个标签页
- 等待所有异步请求完成
- 不要进行无关操作

**基本流程**：
```
1. 在 Firefox 中打开目标页面
2. 等待页面完全加载
3. 执行目标操作（如触发验证码）
4. 完成交互流程
5. 等待所有 HTTP 请求完成（观察网络活动）
6. 关闭浏览器
```

### 步骤 7：关闭与验证

```
1. 关闭 Firefox 窗口
2. 等待 3-5 秒（确保数据刷新到磁盘）
3. 回到 RuyiTrace 主界面，观察状态
```

**验证数据完整性**：
```bash
# 检查文件大小（jscall 通常较大）
ls -lh traceOut/<本轮名称>/jscall/

# 统计行数
wc -l traceOut/<本轮名称>/jscall/*.jsonl

# 检查 HTTP 请求
ls -la traceOut/<本轮名称>/http_packet/

# 验证目标函数被捕获（替换为实际函数名）
grep '"type":"jscall_detail"' traceOut/<本轮名称>/jscall/*.jsonl | grep -E '"callee_name":"(targetFunc1|targetFunc2)"' | wc -l
```

### 步骤 8：导出配置（推荐）

```
1. 在 RuyiTrace 主界面点击"导出配置"
2. 选择保存位置（建议与 traceOut 同级）
3. 文件名格式：<本轮名称>-ruyitrace-switches.json
```

**用途**：
- 记录采集时的确切配置
- 后续复现或调试
- 共享给其他研究人员

---

## 5. 输出数据结构

```
traceOut/<本轮名称>/
├── jscall/                              # JS 调用跟踪
│   ├── trace_jscall_process_<PID>.jsonl    # 主进程（通常最大）
│   └── trace_jscall_process_<PID>.jsonl    # 其他进程（较小）
├── http_packet/                         # HTTP 请求/响应
│   ├── 000001_<METHOD>_<STATUS>_<域名>_<路径>_pid<PID>_<ID>.http_packet.json
│   ├── ...
│   └── index.jsonl                         # 索引文件
├── domtrace/                            # DOM 操作
│   ├── trace_process_<PID>.jsonl
│   └── exception/
│       └── trace_exception_process_<PID>.jsonl
├── cookie/                              # Cookie 记录
│   └── trace_cookie_process_<PID>.jsonl
├── storage/                             # LocalStorage/SessionStorage
│   └── trace_storage_process_<PID>.jsonl
├── descriptor/                          # 对象描述符
│   └── trace_descriptor_process_<PID>.jsonl
├── event/                               # 事件
│   └── trace_event_process_<PID>.jsonl
├── eval/                                # eval 执行
├── wasm/                                # WebAssembly
└── websocket_handshake.jsonl            # WebSocket 握手
```

### 5.1 关键文件识别

- **找主进程**：`jscall/` 中文件最大的那个
- **找主要 HTTP 流**：查看 `http_packet/index.jsonl`
- **验证目标函数**：`grep '"callee_name":"<函数名>"' jscall/trace_jscall_process_*.jsonl`

### 5.2 数据格式说明

**JSONL 格式**：
- 每行一个独立的 JSON 对象
- 可以使用 `jq` 或 Python 的 `json.loads()` 逐行解析
- 不要用普通的 JSON 解析器读取整个文件

**示例处理**：
```python
import json

with open('trace_jscall_process_12345.jsonl', 'r', encoding='utf-8') as f:
    for line in f:
        record = json.loads(line)
        # 处理每条记录
```

---

## 6. 常见问题排查

### 问题 1：未生成 jscall 数据

**症状**：`jscall/` 目录为空或只有很小的文件

**原因**：
- `MOZ_DOM_JSCALL_TRACE` 未设置为 1
- `MOZ_DOM_JSCALL_SCRIPT_URL` 匹配失败（页面未加载目标脚本）
- `MOZ_DOM_JSCALL_TARGET_ONLY=1` 但没有匹配的脚本

**解决**：
```
1. 检查 trace_init 中的 script_url 配置
2. 查看 http_packet/ 确认目标脚本是否被加载
3. 如果脚本 URL 变化，调整 SCRIPT_URL 为更通用的匹配
4. 临时禁用 TARGET_ONLY 以查看所有脚本
```

### 问题 2：目标函数未被详细捕获

**症状**：`jscall_detail` 中只有类型，没有值

**原因**：
- `MOZ_DOM_JSCALL_DETAIL_FUNCS` 未设置或函数名错误
- `MOZ_DOM_JSCALL_DETAIL_SCRIPT_URL` 与目标脚本不匹配
- 函数名大小写不正确

**解决**：
```
1. 确认函数名拼写正确（区分大小写）
2. 确认 DETAIL_SCRIPT_URL 与 SCRIPT_URL 一致
3. 检查函数是否真的被调用（查看 jscall 文件）
4. 重新采集
```

### 问题 3：数据量过大

**症状**：jscall 文件达到 GB 级别，分析困难

**原因**：
- `MOZ_DOM_JSCALL_TARGET_ONLY` 未设置或为 0
- `MOZ_DOM_JSCALL_SHALLOW` 设置为 0（不推荐）
- SCRIPT_URL 匹配范围过宽

**解决**：
```
1. 设置 MOZ_DOM_JSCALL_TARGET_ONLY=1
2. 移除 MOZ_DOM_JSCALL_SHALLOW 或设为 1
3. 缩小 SCRIPT_URL 匹配范围，使用更具体的路径片段
4. 减少 DETAIL_FUNCS 列表，只包含真正需要的函数
```

### 问题 4：http_packet 缺少请求

**症状**：某些预期的 HTTP 请求未被记录

**原因**：
- `MOZ_DOM_HTTP_PACKET_TRACE` 未设置
- 请求在启动前已完成
- 缓存导致请求未实际发出

**解决**：
```
1. 确认 MOZ_DOM_HTTP_PACKET_TRACE=1
2. 启动 Firefox 后再打开页面
3. 清除缓存（Ctrl+Shift+Delete）
4. 禁用浏览器缓存（开发者工具 -> 网络 -> 禁用缓存）
```

### 问题 5：配置导入后不生效

**症状**：导入 JSON 后，trace_init 显示旧配置

**原因**：
- RuyiTrace 未完全重启
- 环境变量被缓存
- JSON 文件格式错误

**解决**：
```
1. 完全关闭 RuyiTrace.exe
2. 检查 JSON 文件格式（使用 JSON 验证器）
3. 重新打开 RuyiTrace，再次导入
4. 手动检查界面上的环境变量是否正确
5. 删除旧的输出目录后重新启动
```

---

## 7. 最佳实践

### 7.1 配置管理

```
✅ 使用稳定的 URL 匹配模式（避免硬编码完整 URL）
✅ 为每轮采集创建独立目录
✅ 导出配置并保存到可追溯的位置
✅ 在配置文件 notes 字段记录采集目的

❌ 不要硬编码包含 hash 或日期的完整 URL
❌ 不要在采集进行中修改配置
❌ 不要重复使用输出目录
❌ 不要设置 MOZ_DOM_JSCALL_SHALLOW=0（除非确实需要）
```

### 7.2 采集策略

```
✅ 单一流程单次采集
✅ 只打开一个标签页
✅ 等待所有异步请求完成再关闭
✅ 差分测试时使用独立会话

❌ 不要在一次采集中重复操作
❌ 不要同时打开多个目标页面
❌ 不要在采集中途刷新页面
❌ 不要混合不同场景的数据
```

### 7.3 数据验证

```
采集后立即执行：
1. 检查主 jscall 文件大小（通常应 > 1MB）
2. 验证 trace_init 配置正确
3. 确认目标函数被捕获（grep 搜索）
4. 检查 HTTP 流程完整性
5. 记录任何异常情况
```

### 7.4 目录命名规范

```
推荐格式：<项目名>-<轮次>-<特征描述>

示例：
  myapp-round1-baseline
  myapp-round2-with-feature-x
  myapp-round3-diff-test
  myapp-round4-full-capture
```

---

## 8. 配置模板示例

### 8.1 基础 JS 跟踪配置

```json
{
  "schema": "domtrace-switch-config",
  "version": 1,
  "exportedAt": "2026-09-01T00:00:00.000Z",
  "app": "console-electron",
  "switches": {
    "MOZ_DOM_TRACE": "1",
    "MOZ_DOM_TRACE_FILE": "D:\\environment\\RuyiTrace-2.5.5-win64\\traceOut\\SiteName\\trace",
    "MOZ_DOM_JSCALL_TRACE": "1",
    "MOZ_DOM_JSCALL_LIMIT": "0",
    "MOZ_DOM_JSCALL_FLUSH_INTERVAL": "1",
    "MOZ_DOM_JSCALL_TARGET_ONLY": "1",
    "MOZ_DOM_JSCALL_SCRIPT_URL": "target-script-identifier",
    "MOZ_DOM_JSCALL_DETAIL_FUNCS": "func1,func2,func3",
    "MOZ_DOM_JSCALL_DETAIL_SCRIPT_URL": "target-script-identifier",
    "MOZ_DOM_JSCALL_MAX_VALUE_BYTES": "262144",
    "MOZ_DOM_JSCALL_DEEP_LONG_STR": "262144"
  },
  "notes": "基础 JS 跟踪配置 - 替换 SiteName 为实际站点名称"
}
```

### 8.2 完整跟踪配置

```json
{
  "schema": "domtrace-switch-config",
  "version": 1,
  "exportedAt": "2026-09-01T00:00:00.000Z",
  "app": "console-electron",
  "switches": {
    "MOZ_DOM_TRACE": "1",
    "MOZ_DOM_TRACE_FILE": "D:\\environment\\RuyiTrace-2.5.5-win64\\traceOut\\SiteName\\trace",
    "MOZ_DOM_JSCALL_TRACE": "1",
    "MOZ_DOM_JSCALL_LIMIT": "0",
    "MOZ_DOM_JSCALL_FLUSH_INTERVAL": "1",
    "MOZ_DOM_JSCALL_TARGET_ONLY": "1",
    "MOZ_DOM_JSCALL_SCRIPT_URL": "target-script-identifier",
    "MOZ_DOM_JSCALL_DETAIL_FUNCS": "func1,func2,func3",
    "MOZ_DOM_JSCALL_DETAIL_SCRIPT_URL": "target-script-identifier",
    "MOZ_DOM_JSCALL_MAX_VALUE_BYTES": "524288",
    "MOZ_DOM_JSCALL_DEEP_LONG_STR": "524288",
    "MOZ_DOM_HTTP_PACKET_TRACE": "1",
    "MOZ_DOM_EXCEPTION_TRACE": "1",
    "MOZ_DOM_EXCEPTION_LIMIT": "0",
    "MOZ_DOM_EXCEPTION_FLUSH_INTERVAL": "1"
  },
  "notes": "完整跟踪配置（JS调用 + HTTP + 异常） - 替换 SiteName 为实际站点名称"
}
```

### 8.3 轻量级配置（仅 HTTP）

```json
{
  "schema": "domtrace-switch-config",
  "version": 1,
  "exportedAt": "2026-09-01T00:00:00.000Z",
  "app": "console-electron",
  "switches": {
    "MOZ_DOM_TRACE": "1",
    "MOZ_DOM_TRACE_FILE": "D:\\environment\\RuyiTrace-2.5.5-win64\\traceOut\\SiteName\\trace",
    "MOZ_DOM_HTTP_PACKET_TRACE": "1"
  },
  "notes": "仅 HTTP 跟踪，不捕获 JS 调用详情 - 替换 SiteName 为实际站点名称"
}
```

---

## 9. AI 代理使用指南

当 AI 代理需要操作 RuyiTrace 时，应遵循以下原则：

### 9.0 开始任何 RuyiTrace 任务前（**必须执行**）

**第一步：确认输出目录**

在生成配置或开始分析之前，**必须**先询问用户：

```
请提供完整的输出目录路径（示例）：
D:\environment\RuyiTrace-2.5.5-win64\traceOut\<站点名称>
```

**关键要点**：
1. **必须获取完整的绝对路径**（包含盘符和完整路径）
2. **一个站点一个主目录**（如 `CSAIR`、`Taobao`、`MyProject`）
3. **每轮采集使用独立子目录**（如 `csair-round1`、`csair-round2`）
4. **配置文件中 MOZ_DOM_TRACE_FILE 应设为：`<站点路径>\<轮次目录>\trace`**
5. **配置文件保存在站点主目录**，不要放在轮次子目录里

**示例对话**：
```
AI: 您好！要分析哪个网站？请提供输出目录的完整路径。
    例如：D:\environment\RuyiTrace-2.5.5-win64\traceOut\CSAIR

用户: D:\environment\RuyiTrace-2.5.5-win64\traceOut\CSAIR

AI: 好的，确认信息：
    站点主目录：D:\environment\RuyiTrace-2.5.5-win64\traceOut\CSAIR\
    第一轮输出：D:\...\CSAIR\csair-round1\
    配置文件：D:\...\CSAIR\csair-round1-explore.json
    
    正在生成第一轮探索配置...
```

**目录组织标准**：
```
traceOut/
├── CSAIR/                              ← 站点主目录
│   ├── csair-round1/                   ← 轮次子目录
│   │   ├── trace                       ← MOZ_DOM_TRACE_FILE 指向
│   │   ├── jscall/                     ← 实际输出
│   │   ├── http_packet/
│   │   └── ...
│   ├── csair-round2/                   ← 第二轮
│   ├── csair-round1-explore.json       ← 配置保存在主目录
│   └── csair-round2-targeted.json
```

### 9.1 读取采集数据前

1. **先读取 trace_init**：验证配置是否正确
2. **检查文件结构**：确认所有必需目录存在
3. **识别主进程**：找到最大的 jscall 文件

### 9.2 分析数据时

1. **优先使用运行时证据**：trace_init、jscall、http_packet
2. **不要依赖静态推测**：必须用实际数据验证
3. **区分不同采集轮次**：不要混淆不同目录的数据

### 9.3 建议新采集时

1. **先检查现有数据质量**：确认是否真的需要重新采集
2. **提供完整配置**：包含所有必需的环境变量
3. **说明采集目的**：在 notes 字段记录原因
4. **给出验证步骤**：告诉用户如何确认采集成功

### 9.4 报告问题时

1. **引用具体文件路径**：便于用户定位
2. **提供验证命令**：让用户可以复现发现
3. **区分已确认和推测**：明确标注证据来源
4. **记录配置状态**：包含 trace_init 的关键参数

---

## 10. 进阶技巧

### 10.1 差分分析

```
目的：对比两次采集，识别变化的部分

方法：
1. 第一轮：使用相同配置采集基准数据
2. 第二轮：改变一个变量（如不同的用户输入）
3. 使用 diff 工具对比输出
4. 重点关注 jscall 参数和 HTTP 请求的差异
```

### 10.2 性能优化

```
问题：采集数据过大，分析困难

策略：
1. 先用 TARGET_ONLY=0 识别所有脚本
2. 确定目标脚本后，启用 TARGET_ONLY=1
3. 只对关键函数启用 DETAIL_FUNCS
4. 使用合理的 MAX_VALUE_BYTES（不要过大）
```

### 10.3 调试技巧

```
1. 逐步启用功能：
   - 先只启用 HTTP_PACKET_TRACE
   - 确认 HTTP 流程后，启用 JSCALL_TRACE
   - 最后添加 DETAIL_FUNCS

2. 使用 grep 快速定位：
   grep '"type":"trace_init"' jscall/*.jsonl
   grep '"callee_name":"targetFunc"' jscall/*.jsonl
   grep 'api.example.com' http_packet/index.jsonl

3. 检查进程号：
   多个进程时，需要确定哪个是主进程
```

---

**文档版本**：2.0  
**最后更新**：2026-09-01  
**适用版本**：RuyiTrace 2.5.5-win64

---

## 11. AI 代理常见错误与最佳实践

### 11.1 错误 1: 过早宣布"完成"

**问题描述**:
在破解了核心算法（如 AES 密钥）后，立即宣布项目"100% 完成"，忽视了其他重要组件。

**实际案例**:
```
❌ 错误: "AES 解密算法 100% 破解 → 项目 100% 完成"

✅ 正确: 
  - 核心算法: 100% 破解
  - HTTP 流程: 100% 理解
  - 基础实现: 60% 完成
  - 完整实现: 40% 完成
```

**问题根源**:
- 混淆了"核心破解"和"完整实现"两个概念
- 低估了辅助组件（设备指纹、行为模拟）的复杂度
- 没有分层评估完成度

**最佳实践 - 使用分层完成度评估**:

```
层次 1: 核心算法破解
  - 定义: 关键加密/签名算法的密钥和参数
  - 标准: 可独立验证，100% 准确
  - 示例: AES 密钥、IV、模式

层次 2: 系统架构理解
  - 定义: 完整的接口关系和数据流转
  - 标准: 可绘制完整流程图
  - 示例: HTTP 接口序列、JS 文件职责

层次 3: 基础实现框架
  - 定义: HTTP 框架 + 简化辅助组件
  - 标准: 可运行，但成功率可能较低
  - 示例: 核心算法 + 基础参数生成

层次 4: 完整组件实现
  - 定义: 所有组件对照真实实现
  - 标准: 功能完整性 > 90%
  - 示例: 完整的设备指纹、真实的行为模拟

层次 5: 生产级实现
  - 定义: 可实际使用的高成功率方案
  - 标准: 成功率 > 80%，稳定可靠
  - 示例: 错误处理、重试机制、性能优化
```

**报告模板**:
```
✅ 核心算法: 100% (AES 解密完全破解)
✅ 架构理解: 100% (HTTP 流程完全理清)
⚠️  基础实现: 60% (框架完成，组件简化)
❌ 完整实现: 40% (缺少高级组件)
❌ 生产级: 0% (未优化)

综合评估: 核心破解成功，但距离实用还需大量工作
```

---

### 11.2 错误 2: 接口关联性分析滞后

**问题描述**:
在实现代码之前，没有完整分析接口调用顺序、JS 文件职责和数据流转关系。

**实际案例**:
```
❌ 错误流程:
  HTTP 追踪 → 提取密钥 → 直接写代码 → 用户质疑 → 补充分析

✅ 正确流程:
  HTTP 追踪 → JS 文件分析 → 接口关联性分析 → 
  绘制流程图 → 设计方案 → 实现代码
```

**必须完成的分析（在实现之前）**:

```
1. HTTP 接口分析
   ✅ 列出所有 HTTP 请求（按时间排序）
   ✅ 识别每个接口的作用和参数
   ✅ 绘制接口调用序列图
   ✅ 标注接口之间的依赖关系

2. JS 文件分析
   ✅ 列出所有加载的 JS 文件
   ✅ 识别每个 JS 文件的职责
   ✅ 提取关键函数的签名和逻辑
   ✅ 理解 JS 文件之间的协作关系

3. 数据流转分析
   ✅ 追踪关键数据的生成位置（哪个 JS？）
   ✅ 追踪数据的传输路径（哪个接口？）
   ✅ 追踪数据的使用位置（哪个函数？）
   ✅ 绘制完整的数据流转图

4. 完整性验证
   ✅ 对照 JS 文件验证理解的准确性
   ✅ 检查是否有遗漏的组件
   ✅ 评估各组件的实现复杂度
   ✅ 制定详细的实现计划
```

**检查清单**:
```
在实现代码前，确认以下文档已完成:

□ HTTP 接口列表和调用序列图
□ JS 文件列表和职责说明
□ 关键函数的详细分析
□ 数据流转关系图
□ 与真实实现的对照验证
□ 组件完整性评估
□ 实现计划和优先级

只有完成这些分析，才能开始写代码！
```

---

### 11.3 错误 3: JS 文件分析不足

**问题描述**:
提取了 JS 文件，但没有深入分析其具体内容，导致实现时严重简化。

**JS 文件分析的完整流程**:

```
1. 静态结构分析
   ✅ 使用 JS 美化工具格式化代码
   ✅ 识别主要的函数和类
   ✅ 提取导出的 API
   ✅ 理解模块的依赖关系

2. 关键函数分析
   ✅ 找到每个关键函数的定义
   ✅ 分析函数的参数和返回值
   ✅ 理解函数的内部逻辑
   ✅ 识别函数调用的其他函数

3. 数据结构分析
   ✅ 识别关键的数据对象
   ✅ 理解对象的字段和类型
   ✅ 追踪对象的创建和传递
   ✅ 验证数据的编码和格式

4. 动态验证
   ✅ 用 RuyiTrace 数据验证静态分析
   ✅ 对比实际调用和预期行为
   ✅ 确认所有分支和边界情况
   ✅ 记录任何不一致的地方
```

**工具推荐**:
- js-beautify: 代码格式化
- ESLint: 语法分析
- de4js: 反混淆
- RuyiTrace: 捕获运行时数据
- 浏览器 DevTools: 单步调试

---

### 11.4 错误 4: 低估辅助组件的重要性

**安全性分层理解**:

```
验证码系统的安全性分层:
  - 核心算法层: 30% (AES 解密)
  - 设备指纹层: 40% (反爬虫检测)
  - 行为分析层: 30% (轨迹、时间)

破解了核心算法，只破解了 30% 的安全防护！
```

**组件重要性评估方法**:

```
1. 文件大小作为参考
   sg.js 有 438 KB → 说明设备指纹非常复杂
   不是一个简单的 JSON 对象就能搞定的

2. 代码复杂度分析
   查看 JS 文件中关键函数的行数和逻辑
   如果超过 100 行，很可能无法简单复现

3. 实际测试验证
   用简化实现实际测试
   记录成功率和失败原因
   根据结果调整优先级
```

**对照真实实现检查清单**:
```
在实现任何组件前，回答以下问题:

□ 真实 JS 文件有多大？(如果 > 100KB，说明很复杂)
□ 关键函数有多少行？(如果 > 50 行，不能简单复制)
□ 涉及哪些浏览器 API？(Canvas? WebGL? AudioContext?)
□ 有哪些计算密集的操作？(哈希? 渲染? 测量?)
□ 输出格式是什么？(JSON? Base64? 自定义编码?)
□ 我的简化实现缺少了什么？(列出具体缺失的部分)
□ 缺失的部分会导致什么后果？(被识别? 失败?)
□ 服务器可能如何验证这些数据？(一致性? 合理性?)
```

---

### 11.5 错误 5: 成功率评估过于乐观

**正确的评估方法**:

```
场景分析 + 加权计算

场景 A: 服务器对设备指纹要求不严格
  - 特征: 只验证基础字段
  - 概率: 30%
  - 成功率: 60-70%

场景 B: 服务器有中等程度的验证
  - 特征: 检查部分高级指纹
  - 概率: 50%
  - 成功率: 30-40%

场景 C: 服务器有严格的反爬虫
  - 特征: 深度分析所有特征
  - 概率: 20%
  - 成功率: 10-20%

综合成功率 = Σ (场景概率 × 场景成功率)
```

**报告格式**:
```
成功率评估

最乐观情况: 60-70% (服务器检测宽松)
典型情况: 30-50% (服务器中等检测)
最坏情况: 10-20% (服务器严格检测)

综合预期: 30-50%

假设条件:
  - DeviceData 简化实现不被严格验证
  - 请求签名的 AccessKeySecret 可为空
  - 滑动轨迹通过基础合理性检查

风险因素:
  - 缺少 Canvas/WebGL 指纹可能触发异常检测
  - 行为模式不够真实可能被识别为机器人

建议:
  在实际使用前进行小规模测试，验证成功率
```

---

### 11.6 错误 6: 追踪失败后快速放弃

**持久性原则**:

```
遇到困难时的正确态度:

1. 分析 (不要立即放弃)
   - 为什么失败了？
   - 有哪些可能的原因？
   - 哪些假设可能是错的？

2. 尝试 (多种方案)
   - 至少尝试 3 种不同的解决方案
   - 记录每次尝试的结果
   - 从失败中学习

3. 利用 (已有资源)
   - 已提取的 JS 文件
   - 历史追踪数据
   - 公开文档和研究

4. 妥协 (最后的选择)
   - 只有在尝试了所有方案后
   - 明确说明为什么放弃
   - 记录失败的经验

"完成"比"快速完成"更重要。
```

---

### 11.7 错误 7: 只分析动态数据，忽略静态代码 ⭐⭐⭐⭐⭐

**严重程度**: 最高级别  
**问题**: 过度依赖 RuyiTrace 动态数据，完全忽略 HTML/JS 静态代码分析

**实际案例 (CSAIR 项目)**:
```
❌ 只做了:
  - 分析 HTTP 请求
  - 分析 jscall 记录
  
❌ 没做:
  - 分析 HTML 源码（参数来源）
  - 深度分析 JS 文件（真实算法）
  - 建立 HTML → JS → HTTP 调用链
  
结果:
  - 硬编码应该从源码提取的参数
  - 设备指纹覆盖率仅 16% (5/30 字段)
  - 成功率 30-50%（远低于预期）
```

**核心教训**:
```
静态分析 (HTML/JS) + 动态追踪 (RuyiTrace) = 完整理解

两者缺一不可！
```

**详细分析**: 见 `AGENTS_ERROR_7.md` (13KB 完整文档)

**必须做到**:
- ✅ 在使用 RuyiTrace 之前，先收集 HTML 和 JS
- ✅ 深度分析 JS 文件，提取真实算法和常量
- ✅ 建立 HTML → JS → HTTP 完整映射
- ✅ 用 RuyiTrace 验证静态分析（不是替代）

---

### 11.8 标准化的项目流程（更新版）

```
阶段 0: 静态代码收集 ⭐ 新增（在 RuyiTrace 之前）
  ✅ 保存 HTML 页面
  ✅ 下载所有 JS 文件
  ✅ 格式化和美化代码
  ✅ 建立文件清单

阶段 1: 探索分析 (第一轮追踪)
  ✅ 识别系统架构
  ✅ 理解 HTTP 流程
  ✅ 确定追踪目标

阶段 2: 静态深度分析 ⭐⭐⭐ 最关键（在进一步追踪前）
  ✅ 分析 HTML 源码（配置参数）
  ✅ 深度分析所有 JS 文件（真实算法）
  ✅ 绘制完整调用链 (HTML → JS → HTTP)
  ✅ 提取所有参数和常量
  ✅ 理解所有算法细节
  ✅ 生成完整的架构文档

阶段 3: 精确追踪 (第二轮~第N轮)
  ✅ 基于阶段 2 的分析配置追踪
  ✅ 每轮聚焦特定目标
  ✅ 立即验证追踪结果
  ✅ 迭代优化配置

阶段 4: 完整性验证 (在实现前)
  ✅ 对照 JS 文件验证理解
  ✅ 检查是否有遗漏的组件
  ✅ 对比真实实现和简化实现的差距
  ✅ 制定详细的实现计划

阶段 5: 分层实现
  ✅ 实现核心算法
  ✅ 实现 HTTP 框架
  ✅ 实现辅助组件 (逐个对照验证)
  ✅ 集成测试
  ✅ 成功率评估

阶段 6: 文档和总结
  ✅ 完整的技术文档
  ✅ 接口和架构图
  ✅ 实现指南
  ✅ 经验教训
  ✅ 诚实的完成度评估
```

**关键: 阶段 2 (架构分析) 不能省略！**

---

### 11.9 关键原则（更新版）

1. **理解 → 设计 → 实现**
   - 顺序不能颠倒
   - 每个阶段都要充分完成

2. **静态分析 + 动态追踪 = 完整理解** ⭐⭐⭐
   - HTML/JS 源码提供真实逻辑（源头）
   - RuyiTrace 捕获运行时数据（验证）
   - 两者缺一不可
   - 静态分析在前，动态验证在后

3. **分层评估完成度**
   - 核心、架构、实现分开评估
   - 不混淆不同层次的"完成"

4. **诚实评估，明确假设**
   - 成功率要考虑多种场景
   - 明确说明假设条件
   - 不夸大实际效果

5. **对照验证，不轻易简化**
   - 实现每个组件前对照 JS
   - 列出简化的部分和影响
   - 评估风险和成功率

6. **持久性和完整性**
   - 遇到困难不轻易放弃
   - 尝试多种解决方案
   - 利用所有可用资源

7. **失败也是经验**
   - 记录失败的案例
   - 分析失败的原因
   - 提供改进的建议

---

**文档版本**：3.1  
**最后更新**：2025-01-20  
**更新内容**：
- 第 11 节：AI 代理常见错误与最佳实践
- 新增错误 7：只分析动态数据，忽略静态代码（最严重）
- 更新标准化项目流程（新增阶段 0：静态收集）
- 详细文档：`AGENTS_ERROR_7.md`  
**适用版本**：RuyiTrace 2.5.5-win64
