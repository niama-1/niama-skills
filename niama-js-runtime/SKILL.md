---
name: niama-js-runtime
description: 仅在用户当前会话中明确点名 niama-js-runtime 或明确指定 Node 补环境 Skill 时启用，不得因任务内容相似而主动加载；用于 Node 执行层的 JS 风控链路复现与补环境，并由 test.py 验证。
---

## 个人 Skill 源仓库规则

本模块的源文件位于本模块 `SKILL.md` 所在目录。修改或新增内容时，只编辑包含该模块的 Git 工作区；客户端安装目录是运行副本，不要直接修改。

# Skill: JS 风控链路复现（Node 补环境）

## 规则等级

- `[STOP]`：违反后必须停止当前路线，不得继续用该路线交付。
- `[MUST]`：执行和交付前必须满足的条件。
- `[SHOULD]`：默认建议；只有有证据或用户明确要求时才能偏离，并记录原因。
- 等级只统一执行优先级，不改变原条款中的具体限制、例外和暂停条件。

## 触发条件 [MUST]

### 加载硬约束 [MUST]

本 skill 默认不得主动加载。只有用户在当前会话中明确点名 `$niama-js-runtime`、`niama-js-runtime`，明确要求“加载当前 skill / 使用 Node 补环境 skill”，或以等价措辞直接要求启用本 skill 时，才允许加载。

不得仅因为任务内容涉及 JS 逆向、风控、签名、验证码、Node、`rtproxy.js`、`rtwatch`、`rt_log`、`code.js` 或 `test.py` 就自动加载本 skill。若用户没有明确要求加载本 skill，只能把这些内容当作普通任务上下文处理。

用于 JS 逆向补环境与风控请求链复现任务，且本地执行层明确为 Node / node_mode / Node 补环境，或用户要求使用 `rtproxy.js`、`rtwatch`、`rt_log`、`fun_to_native` 将浏览器环境补到本地 `code.js` / `runtime/*.code.js` 并由 `test.py` 验证。

适用于：
- 签名：签名、加密、指纹参数，例如 `h5st`、`a_bogus`、`black_box`、`sensor_data`
- 验证码：验证码、challenge、滑块、点选、九宫格/多宫格、行为证明、通过 token，例如 `vt`、`ticket`、`validate`
- 签名+验证码：验证码通过凭证 + 签名 / 加密参数，例如 JCAP `vt` + `h5st/_stk` + `aksParamsU/B`
- 完整业务链：前置挑战、验证码、签名、加密、登录态状态型业务动作、WebSocket 长连接协议到最终业务接口
- 多产品签名：一个任务中存在多个安全产品、多个签名参数、多个验证码或多个 JS runtime 入口，需要分别定位和验证

本 skill 固定执行层为 `node_mode`。如果用户明确要求非 Node 执行层，本 skill 不适用，应停止使用本 skill 并切换到对应专用 skill。

## 固定执行层 [MUST]

```text
runtime_mode = node_mode
```

别名归一：
- `node`
- `nodejs`
- `Node补环境`
- `rtwatch`
- `rtproxy`
- `rt_log`

本 skill 只使用 Node 执行层下的 `rtwatch` / Proxy / `rt_log` 作为本地缺口观察机制，不包含非 Node 执行层的迁移、对照或验收流程。

## 最高优先级反假完成门禁 [STOP]

以下问题是本 skill 的最高优先级违规项，优先级高于所有阶段推进和交付描述：

- 绝对禁止使用 `ruyitrace/`、`http_packet`、`jscall`、抓包响应体、旧浏览器响应或 trace 中已经存在的目标生成值来冒充当前项目的生成结果。
- 绝对禁止把 trace 里的参数、token、签名、密文、`captchaBody`、验证码通过凭证、业务成功响应复制进 `code.js` / `runtime/*.code.js` / `test.py`，然后声明“已生成、已跑通、已完成”。
- 绝对禁止用 `ruyitrace` 中的响应结果、浏览器原始成功响应、旧成功包或响应摘要作为当前 `test.py` 成功证据。
- 如果 runtime 或 `test.py` 在执行时读取 trace、HTTP 包、请求基线、旧响应文件来产出目标值或成功响应，必须立即标记为 `fake_completion_risk`，结论只能写“离线证据回放 / fixture 验证 / 请求面基线提取”，不得写完成。
- 完成只能由当前项目代码按显式输入实时产出：`node code.js` / `node runtime/*.code.js` 当前输出目标值，`test.py` 当前使用这些生成值发出请求并得到当前响应。没有这两类当前运行证据时，一律不得交付为完成。
- 验证码任务尤其严格：trace 中 `/captcha/verify` 成功、旧包回放成功、本地生成 body、dry-run 捕获请求面，都不能单独证明通过；只有当前 `test.py` 实时请求返回业务通过，并且后续业务接口真实放行，才允许声明验证码链路完成。

## 代理形态不可变与日志噪声分层门禁 [STOP]

以下规则优先于“降噪”“简化”“优化”“收敛日志”等任何执行建议：

- `assets/rtproxy.js` 是内联模板源文件，不是运行时 `require` 依赖。skill 的 canonical 源文件不得由 AI 擅自修改；正式进入项目时，必须把该文件当前内容原样复制到 `code.js` / `runtime/*.code.js` 顶部作为底座。内联后的代理核心仍按只读资产对待，禁止改 trap、日志、`rtwatch`、`fun_to_native`、`defaultFilterProps`、`existsobj`、输出格式或文件名逻辑；唯一允许编辑的是固定宿主对象声明里的 `{}` 对象字面量。
- 禁止为了降低日志噪声而新增、删除、合并或替换 Proxy trap，修改 target/receiver 语义、返回值包装策略、缓存策略、路径命名、`defaultFilterProps`、`existsobj`、事件顺序、日志 schema、序列化方式或异常处理。
- 禁止把 Proxy 改成普通对象、把递归观察改成非递归观察、把返回值改成 raw 值、注释掉 `rt_log`、在 trap 内增加静默丢弃条件，或另写一个“更安静”的简化版代理。
- 禁止为了让输出看起来更少而在 canonical 代理源文件或运行时内联代理核心中抽样、过滤、去重、合并或静默丢弃事件；原始代理事件必须保持原有语义和完整性。
- 允许修改的是 `code.js` / `runtime/*.code.js` 中固定宿主对象 `rtwatch({ ... }, "name")` 的 `{}` 内部，以及同一区紧邻且由证据支持的 descriptor、prototype、`fun_to_native` 收口和业务入口；这些修改不得反向改变代理实现的观察机制，也不得改写或替换固定的 `rtwatch(...)` 声明。
- 允许关闭控制台回显，例如设置 `rt_loginfo = false`；这只能影响展示，不能改变 Proxy 行为，也不能改变原始代理日志。
- 允许在事件已经写入 `proxylog.txt` 后，用独立脚本或独立命令生成过滤、聚合、去重后的分析视图；分析视图不得覆盖、回写或替代原始日志。
- 如果现有代理没有满足某项日志能力，必须记录为代理资产缺口并暂停；任何情况下都不得自行修改代理、增加代理功能或另写替代代理。

## 目标出值优先门禁 [MUST]

本 skill 的阶段目标不是补出完整浏览器，而是沿当前目标链路生成目标参数、验证码凭证、reload 请求面或业务动作所需的最小有效材料。环境质量提升必须服务于出值和验证，不得反过来阻塞目标出值。

- 阶段 4-6 的第一目标是让当前目标 JS 在本地走到目标产出边界，例如函数返回、请求组装、`/reload` 请求面、Worker 返回值或验证码凭证注入点。
- 只补目标链路必须触达的最小宿主对象集合；无关 DOM、无关指纹面、无关浏览器 API、完整类库式 DOM、完整事件系统、完整 iframe/Worker 仿真不得作为第一阶段目标。
- 目标值、reload 请求面或目标请求片段已能按当前输入实时产出后，先进入 `test.py` 或请求边界验证；只有验证失败且证据指向环境语义缺口时，才继续提升环境质量。
- 不得因为“环境不够完美”“浏览器对象不完整”“还可以补更多字段”而推迟当前可验证目标输出。
- 不得把补环境质量项当作完成前置条件，除非该质量项已被 `jscall` / `ruyitrace` 证明直接影响当前目标产出或当前请求验证。
- 每轮只修当前阻塞目标出值或验证的最小差异；完成出值前禁止进行“全局环境整理”“完整浏览器化”“批量补外观”“顺手补指纹面”。
- 出值后的环境质量提升只允许围绕失败证据展开，例如消息顺序、`source/ports` 身份、脚本执行时机、请求面缺口、descriptor/prototype 检测或最终业务失败原因。

## 公共硬门禁 [MUST]

- 阶段 0-3 必须先判定任务目标类型：`签名`、`验证码`、`签名+验证码`、`完整业务链`、`多产品签名`；证据不足时标记为 `证据不足`，继续盘点 trace / 请求链；若为 `完整业务链`，必须继续标记 `完整业务链子类型`。
- 首次建档或因冲突回退时必须读取可选目标说明文件：`target_info.md`、`param_info.md`、`目标.txt`。
- 同一任务续跑优先读取 `逆向任务分析计划.md`；已经进入阶段 4 的任务以 `target.lock`、当前代码、当前运行结果和 `proxylog.txt` 为状态源。不得因为缺少 `补环境进展清单.md` 重新盘点目标说明文件；只有目标、trace、请求链、账号/页面状态、验证口径或用户口径变化时才回退盘点。
- 用户声明只作为线索；和 trace / 请求证据冲突时，以匹配当前目标的 `ruyitrace/`、`http_packet` 和 `jscall` 证据为准。
- 进入补环境前必须具备匹配当前目标的 `ruyitrace/` 真实证据、`jscall` 定位证据、目标 JS、完整入参、生成方法和请求边界。
- 默认以匹配当前目标的 `ruyitrace/` 作为 DOM/BOM 真实值、调用链、事件顺序和行为证据基准。
- `jscall` 负责离线定位和链路还原，不单独作为环境真值来源。
- 目标生成与完成判定统一遵循“最高优先级反假完成门禁”；本节不重复定义同一规则。
- `test.py` 请求失败时，必须先把本地真实请求面与抓包目标请求面做 diff；未确认 Header/Cookie/Body/Query/前置请求一致前，不得直接定性为补环境或签名算法错误。
- 目标名称、参数名、脚本名、Cookie、Header、URL、响应体或日志出现安全产品同类特征时，必须先读取 `references/products/index.md` 并命中对应产品；命中后只读取对应产品文档。
- 原型链、`constructor` 回指、`Symbol.toStringTag`、native-like `toString` 必须集中在固定模板区，并按 `references/prototype-chain-template.md` 验收；命中原型检测后，必须把构造器静态链、`Ctor.prototype` 父链、真实实例、Document getter/查询返回身份和已命中的集合成员关系作为同一组语义核对，禁止只补 `instanceof` 外观；遵守“只定义一次，只填充不换壳”。
- Proxy 只用于基础 BOM/DOM 宿主对象，以及已由目标链路证明确实继续读取的直接返回对象的轻量观察；方法入参只用 `rt_log` 明确打印，不把 Proxy 扩成全局反射层。
- 代理形态、内联模板与原始日志规则分别遵循“代理形态不可变与日志噪声分层门禁”、“rtproxy 内联模板门禁”和“固定代理日志文件”；本节不重复定义同一规则。模板底部的 `window/document/location/navigator/screen/storage` 空 `{}` 只作为骨架，正式补环境时必须在对应对象字面量内填入已由 ruyitrace 证实的字段和方法，不得后面跨区散补或换壳；不得递归包装返回值，不得默认启用 `getOwnPropertyDescriptor/getPrototypeOf/defineProperty/setPrototypeOf/apply/construct` 等重 trap。
- `document.all`、iframe/window 身份关系、Worker 通信是关键检测点；`ruyitrace/domtrace` 命中时必须优先按专项 checklist 处理，其中 `document.all` 优先走 V8/native undetectable 底座，并按目标检测点尽量还原。
- `MessagePort`、`Worker`、iframe `postMessage` 链路必须证据驱动；不得手写猜测式队列、`localDeliver`、同步假回调或伪 source/ports 来“看起来能跑”。消息顺序、`MessageEvent.source`、`MessageEvent.ports`、transferable、异步派发必须以目标链路证据为准；证据不足时只记录缺口并暂停该项。
- 禁止把 Proxy 当作全局 VM 外壳包住目标执行环境；Proxy 只观察明确宿主对象。不得让代理污染 Node 全局定时器、Promise、module、require、vm context 或目标 JS 内部对象。
- 脚本加载和执行时机必须按证据最小复现；`currentScript`、script append/load、iframe 文档加载、anchor runtime 初始化不得过早触发。禁止为了省事在 `currentScript` 附着、DOM 构造或 script 创建阶段提前执行目标脚本。
- WebAssembly / `.wasm` / wasm-bindgen / Emscripten 命中时必须先归类加载方式、胶水层、imports/exports、memory/table、业务入口和版本材料；优先补 JS 胶水层与 importObject 需要的宿主能力，不改 wasm 二进制，不在 wasm 内部下探针。
- 补环境提速只能靠最小命中对象闭环，不能靠只补外观、空壳、空方法或假返回对象跑通。

## 反混淆 JS 可选材料门禁 [MUST]

- 用户可在阶段 0-3 提供 `反混淆js/` 目录，目录内 JS 通常是对目标补环境代码做过字面量还原、格式化或可读化后的辅助版本。该目录是可选输入；存在时必须查看，缺失时不暂停、不报缺口、不影响原流程推进。
- 阶段 0-3 读取 `反混淆js/` 时，只用于辅助定位目标参数入口、生成位置、环境读取点、检测分支、控制流意图和可能需要优先关注的宿主对象集合。
- 阶段 4-6 遇到 `proxylog.txt` 缺口、运行异常、分支不一致或疑似环境检测时，可以回查 `反混淆js/` 中对应代码，判断该缺口属于普通取值、`typeof`、`in`、枚举、descriptor、prototype、native `toString`、对象身份、事件时序或其它检测语义。
- `反混淆js/` 不是 DOM/BOM 真值来源、不是目标生成值来源、不是请求成功证据来源。字段值、返回值、descriptor、prototype、异常文本、事件顺序、对象身份和最终请求面仍必须回到匹配当前目标的 `ruyitrace/`、`jscall`、原始目标 JS 和当前运行结果核实。
- 禁止把 `反混淆js/` 中已有的签名、token、密文、验证码凭证、请求体、成功响应或中间产物复制进 `code.js` / `runtime/*.code.js` / `test.py` 来冒充实时生成。若 `反混淆js/` 与原始目标 JS、`ruyitrace` 或当前运行结果冲突，以原始目标 JS、匹配当前目标的 trace 证据和当前运行结果为准，并记录为辅助材料差异。

## 全局硬禁令 [STOP]

### VMP 插装和下探针 [STOP]

以下行为在任何阶段都绝对禁止：
- 在 VMP / VM 解释器 / opcode handler / 字节码分发循环内部做补环境
- 对 VMP 下探针、插日志、插桩、加 Proxy、加 tracer、加 instrumentation
- 改写 VMP handler、opcode、字节码、解释器调度或执行语义
- 把 VMP probe、VM tracer、解释器 proxy、opcode hook、instrumentation 写进本地 `code.js`
- 用 VMP 插装结果、探针日志或改写后的执行结果作为参数真值基准

如果推进路线看起来必须依赖 VMP 插装、下探针或改写执行语义才能继续，停止该路线，回到外围定位：
- 用 `jscall` 定位请求边界、入参、返回值、调用栈和环境读取点
- 用匹配当前目标的 `ruyitrace/` 提取 DOM/BOM 真值和行为证据
- 用 `rtwatch` / `rt_log` 只观察外部宿主对象、方法入参和返回对象
- 在 `code.js` 中只沉淀 DOM/BOM 补环境、目标 JS 原逻辑和稳定入口

### 明令禁止用自动化实现目标 [STOP]

不得使用浏览器/页面自动化、脚本接管页面、模拟用户行为或自动执行业务动作来实现本 skill 的目标。目标必须收敛到本地 `code.js` / `runtime/*.code.js` 的稳定参数生成入口，以及 `test.py` 的真实请求验证。

即使用户在当前任务中明确要求使用自动化，也只能把自动化限定为辅助取证、页面状态观察、人工授权后的最小验证或导出材料；不得把自动化跑出的页面结果、页面状态、浏览器实时执行结果或自动操作流程作为最终实现，不得用它替代本地补环境、参数生成、请求组装和 `test.py` 验证。

默认禁止：
- Playwright、Puppeteer、Selenium、Camoufox 自动驱动或同类浏览器控制程序
- 页面自动化工具的自动点击、登录、翻页、滑动、输入、拖拽、触发业务动作
- 用脚本接管浏览器去生成参数、刷新页面状态、模拟事件轨迹或补齐缺失证据
- 用自动化程序跑出的页面结果替代本地 `code.js` / `runtime/*.code.js` 实现

允许：
- 本地执行 `node code.js`、`test.py`
- 读取和分析当前目录已有的 `ruyitrace/`、`jscall`、根目录 `*.http_packet.json` 和旧版离线抓包归档
- 使用 `ruyitrace/index.jsonl` 与根目录 `*.http_packet.json` 读取请求详情和请求面基线，不接管浏览器页面行为

### 只允许请求面 diff [STOP]

本 skill 只允许做请求面 diff。允许范围仅限 `test.py` 实际请求与抓包 / `ruyitrace/http_packet` 中的目标请求做 Header、Cookie、Body、Query、URL、Method、Content-Type、前置请求、重定向、preflight、会话状态和响应摘要差异对照，用于判断请求面是否一致。

除请求面 diff 外，其它层面的 diff 一律禁止，包括但不限于参数字节集 diff、签名字节 diff、密文字节 diff、算法输入输出 diff、普通样本 diff、bit/byte 翻转对照、批量样本差分、字段扰动差分、hash 前后差分、编码片段差分、轨迹 proof 差分、token 生成差分或任何用于反推签名 / 加密 / 编码 / 混淆算法的差分分析。

diff 结果只能用于确认请求面是否对齐，不得作为算法真值、环境真值、参数生成依据或继续下诊断探针 / 插桩 / Hook / tracer 的理由。

## 目标集合相关与语义完整 [MUST]

补环境只围绕当前已确认的目标集合展开。目标集合可以是一个或多个参数、token、签名片段、加密请求片段、验证码凭证、Worker 返回值或业务动作状态。

只允许补与目标集合的生成、校验、注入、请求组装或最终验证直接相关的环境对象、字段、方法、事件、Worker 消息和状态。与目标集合无关的浏览器对象、指纹面、DOM 内容、事件状态、接口或其它参数族，不得因为 trace 中存在或本地缺口提示就顺手补入。

目标链路内禁止壳子式补环境。凡是目标 JS 会继续读取、枚举、调用、比较或依赖的对象，都必须按证据补齐可观察语义：
- 外观：`typeof`、`instanceof`、constructor、prototype、descriptor、属性枚举结果、`Symbol.toStringTag`、native-like `toString`
- 内容：字段值、索引项、数组/类数组内容、集合长度、URL、cookie/storage 状态、子对象中的实际值
- 行为：方法入参、返回对象、getter/setter、副作用、异常类型与 message
- 身份关系：同一对象多次读取是否稳定、父子/owner/target/currentTarget/source/ports 等引用关系
- 时序状态：写入后再读取、事件 listener 顺序、timeout/microtask 顺序、Worker message 顺序和异步回调顺序

不允许一次性大批量补环境。必须按批次推进：先补目标链路触达的基础 BOM/DOM 对象，再补方法入参和返回对象，最后才按证据补 `canvas`、`canvas2d`、`webgl` 等指纹面。

批次推进以目标出值为准：基础 BOM/DOM 的“够用”标准是能推动目标链路继续接近目标产出边界，而不是浏览器语义完整。具体出值优先级遵循“目标出值优先门禁”；本节不重复定义完成顺序。

## Node 补环境方法 [MUST]

## 环境结构与检测语义落位门禁 [STOP]

AI 补环境时，必须将环境代码组织为顶层安装区、构造器区、原型区、window 区、指纹专项区、Document 区和其它专项检测区；其中指纹专项区固定在 window 区之后、Document 区之前。项目已有可运行环境代码时，只在不破坏其实际加载方式的前提下按同一语义分区最小增量补齐。不得为了“结构化”“复用”“自包含”写成通用 factory、class、闭包式环境构建器、module export 环境模块或多 runtime 拼装。

- 新建纯环境 JS 默认顶层创建 `window/document/navigator` 等宿主对象并供后续目标 JS 直接使用；不得强加 `module.exports`、`get_xxx`、`installEnvironment()`、`buildRuntimeEnvironment()` 或新的 require 链。项目已存在不同且已验证的加载方式时，保持其方式。
- `get_xxx(input)` 只属于目标参数逻辑的稳定入口；它不是把纯环境代码改造成业务模块的理由。
- 宿主对象、构造器、原型和检测分支必须落在对应语义区。新文件先建立这些语义区再补字段；不能因为当前缺口小就把 `navigator`、`screen`、`document`、canvas、iframe 或 WebGL 字段散写到目标 JS、业务 helper、请求 mock 或文件尾部。
- 先定位“检测操作在哪个区”，再补该区。禁止把检测结果当成单个字段值直接塞入其它区。

专项代码归属：

1. Document 区只放固定 DOM 状态、`document.head/body/documentElement`、`createElement`、`getElementById`、`querySelector(All)`、`getElementsByTagName`、`getElementsByClassName` 等创建和查询入口。
2. Node / DOM 树区只放通用 `appendChild/removeChild/insertBefore`、父子关系、`parentNode`、`children/childNodes` 等树状态。iframe 挂载和移除带来的 realm 可见性变化属于 iframe 区，但必须由这里的挂载操作触发，不得在目标业务代码中回填。
3. iframe 区只放 iframe realm 构造、`contentWindow/contentDocument`、`window/self/top/parent/frames` 身份关系和 iframe 挂载/移除生命周期；它必须与 Document 创建分支和 DOM 挂载操作相邻。`HTMLIFrameElement` 的构造器、继承链和 `Symbol.toStringTag` 仍在元素构造器 / 原型区。
4. 指纹专项区固定在 window 区之后、Document 区之前；其中 Canvas/WebGL 子区连续放置 `HTMLCanvasElement`、`CanvasRenderingContext2D`、`WebGLRenderingContext`、`WebGL2RenderingContext`、它们的原型方法、上下文状态、扩展、参数和 canvas 指纹行为。Document 区的 `createElement("canvas")` 只创建 canvas 实例、trace 已命中的实例状态并连接 `HTMLCanvasElement.prototype`；WebGL 只能由该 canvas 的 `getContext` 返回对象进入。
5. Worker、Audio、WebRTC、storage、performance 等各自建立独立专项区。除当前 trace 已证明的引用关系外，不得跨区读取、写入或伪造返回对象。

专项落位规则：

1. `document.createElement("iframe")`、`appendChild/insertBefore`、`contentWindow/contentDocument`、iframe realm、`top/parent/self/frames`、iframe `Function/Object` 等，必须放在 Document / HTMLIFrameElement 语义区。contentWindow 与主 window 的身份关系、共享对象或隔离对象、prototype 和 descriptor 必须由 trace 决定；不得另造一个通用 `makeIframe()` 或在业务流程里临时拼 iframe。
2. `document.createElement("canvas")` 只在 Document 创建元素分支返回带 `HTMLCanvasElement.prototype` 的实例及 trace 已命中的该实例状态；`getContext`、`toDataURL/toBlob`、2D context、WebGL/WebGL2 context、扩展和参数检测必须连续落在指纹专项区的 HTMLCanvasElement / CanvasRenderingContext2D / WebGLRenderingContext 原型子区。`getContext` 只能按当前方法实际接收的入参、当前 `this` canvas 实例状态和 trace 命中的返回/复用语义处理，不得固定参数名、返回全局单例或通用对象。不得把 canvas 指纹值散放在 navigator、window 或请求代码中。
3. Audio、OfflineAudioContext、Worker、SharedWorker、MessagePort、WebRTC、storage、performance 等只在各自构造器或专项语义区补；除非 trace 已证明关联，禁止通过目标业务回调、同步假消息或临时返回值跨区推进。
4. `typeof`、`in`、ownKeys、Object.keys、getOwnPropertyDescriptor(s)、prototype、constructor、instanceof、Symbol.toStringTag、native toString、getter/setter、异常文本、枚举顺序、同一对象多次读取和读写后状态，属于同一检测语义卡。补入任一字段前必须先确认该卡覆盖的可观察结果。

### Document DOM 创建、查询与节点一致性门禁 [STOP]

`Document.prototype.createElement` 是标签到 DOM 宿主类型、原型链和专项检测语义的分派点，不是“返回一个带 tagName 的通用对象”的便利入口。

- 当前目标 `ruyitrace`、目标 JS 或 `rtwatch` 已命中的每个标签，必须在 Document / DOM 元素创建区有可直接阅读的显式标签分支。只补已命中的标签；不要求预先罗列全部 HTML 标签。
- 每个已命中标签分支必须返回对应 `HTML*Element.prototype` 的实例，并在分支内就近补齐 trace 已读到的 `tagName`、`nodeName`、`style`、`children/childNodes`、`ownerDocument`、`parentNode`、属性 getter/setter 和该标签特有状态。是否需要字段、descriptor、异常和枚举外观由当前 trace 决定，不得批量散补。
- `createElement` 必须按当前文件风格挂到 `Document.prototype`，并在同一 Document 区完成 `fun_to_native` 和 descriptor 收口；不得把标签实现藏进业务闭包、目标 JS 或文件尾部。
- 每个已命中标签只有一个规范的创建分支、一个对应原型和一个可追踪的节点状态来源。`appendChild/removeChild/insertBefore`、`getElementById`、`querySelector(All)`、`getElementsByTagName` 等后续操作必须围绕该状态工作：当前状态和 trace 证明应查到该节点时，返回同一实例；trace 证明未命中时才返回 `null` 或空集合。禁止先创建标签、查询时无证据固定 `return null`、再在其它 helper 或业务路径重新创建同标签对象。
- `iframe` 分支必须在同一 Document / HTMLIFrameElement 语义区就近建立 `contentWindow`、`contentDocument` 和已命中的 realm 身份关系；`appendChild/removeChild/insertBefore` 对 iframe 可见性和状态转换的影响也必须在该区处理，不得在业务流程中临时创建 iframe 或回填 window。
- `canvas` 分支只负责创建带 `HTMLCanvasElement.prototype` 的 canvas 实例。`getContext`、2D/WebGL 返回对象及其检测语义仍分别放在对应原型区；不得在 `createElement` 分支内写入整套指纹返回值。
- `script` 分支只负责 `HTMLScriptElement` 的 DOM 身份和 trace 已命中的属性/状态。禁止在 `createElement("script")`、`appendChild` 或 `insertBefore` 中按业务 URL 映射本地资产路径、调用 `vm.runInThisContext`、预加载目标 SDK，或把资源加载成功和 `onload` 当作环境默认行为；脚本装载时序只能按独立、证据驱动的 Document 插入语义实现。
- 禁止以 `makeDomElement(tag)`、`makeElement(tag)`、标签无关的普通对象工厂、`{ style: {} }` 通用回退、正则解析 `innerHTML` 后递归创建通用元素，或“除少数标签外统一返回同一对象类型”替代已命中的标签分支。共享 helper 只能处理标签分支选定类型后的重复低层操作，不能决定标签类型、返回通用元素或重新创建已有节点。

查询方法必须与同一 Document 节点状态协作：

- `getElementById(id)`、`querySelector(selector)`、`querySelectorAll(selector)`、`getElementsByTagName(tagName)`、`getElementsByClassName(className)` 只能在 Document 区定义；必须按当前文件风格以 `rt_log` 记录实际入参，并在同一区完成 `fun_to_native` 和 descriptor 收口。
- 每个当前目标命中的 id、selector、tagName 或 className 必须有可读的精确分支。已由 trace 证明不存在的具体输入可以返回 `null` 或空集合；未知输入不得无证据统一 `return null`、统一 `return []`、创建通用元素后返回，或为继续运行改走其它 helper 重新造节点。
- Document 初始节点和 `createElement` 后经 DOM 操作挂载的动态节点必须分别有唯一、可追踪的状态来源。查询当前状态中存在的节点时，必须返回该节点的同一实例；不得在查询方法内临时构造一个同 id、同 selector 或同标签的替代对象。
- `getElementById` 与 `querySelector` 返回元素或 `null`；`getElementsByTagName` 返回符合当前 trace 的 `HTMLCollection`；`querySelectorAll` 返回符合当前 trace 的 `NodeList`。集合当前命中时至少补齐 trace 读取的 `length`、数字下标、`forEach`、迭代和节点身份，不能用裸数组或普通对象代替。
- `querySelectorAll(selector)`、`getElementsByTagName(tagName)` 等集合查询与单节点查询、固定 DOM 状态和动态树状态冲突时，先按当前 trace 的时序确定结果；不得为了兼容多个调用点分别伪造多份同名节点。
- 缺参、非法 selector、标签名大小写、集合顺序、异常文本和空结果外观均由 trace 决定；禁止复制其它 Document 方法的异常文本，或把 `createElement` 的入参异常套到查询方法。

命名与可读性：

- 公共浏览器对象、构造器、原型和成员必须保留标准 Web API 名称或当前目标 JS / Firefox trace 已证实的精确名称。
- 内部辅助对象使用项目既有、稳定且可搜索的前缀；同一对象的内部名、公开名和路径名必须固定。禁止生成随机缩写、乱码式成员、无来源别名或“看起来像缺属性”的伪名称。
- 每个非标准成员、非默认 descriptor、跨 realm 绑定和异常文本，必须在同一区就近以简短注释标明触发检测和 trace 证据位置。
- 一个宿主对象只能有一个正式实例。禁止先建空对象、在闭包中重建同名实例、再多次回挂到 window；禁止相同字段的重复赋值覆盖。当前模板已有对象时，继续在该对象所属区补。

环境层不得包含目标业务的网络请求、成功响应 fixture、自动按压、自动点击、主动派发业务事件、轮询业务成功条件或调用最终接口。目标 JS 的自然初始化如果需要事件，只能在 trace 已证实的注册点、派发条件和异步时序下由验证层触发；不得由环境层伪造“已经完成”的流程状态。

Node 补环境必须使用本 skill 的 `assets/rtproxy.js` 作为内联模板源文件。运行时不得通过 `require("./assets/rtproxy.js")`、绝对路径、软链接、硬链接或动态查找 skill 目录加载代理；必须把 `assets/rtproxy.js` 当前内容原样复制进 `code.js` / `runtime/*.code.js` 顶部，并在同一个文件中补宿主对象 `{}`。不得凭记忆重写、简化或另造 proxy 骨架。

`code.js` 的底座顺序必须采用：

```text
assets/rtproxy.js 底座：rt_log / proxylog.txt / rtwatch(get,set,has,ownKeys) / fun_to_native
→ 按固定语义分区进入构造器 / 原型链 / native 外观区
→ window realm / 关系区
→ 指纹专项区（Canvas / 2D / WebGL / Audio 等）
→ Document 固定 DOM / 创建 / 查询区
→ iframe realm / 挂载生命周期区
→ location / navigator / screen / storage / performance 区
→ Worker / Audio / WebRTC 等其它专项检测区
→ 只保留项目既有的共享 helper；不得把环境改造成新的 factory 或业务 runner
→ // 目标js
```

### 代理模板与宿主对象填充门禁 [STOP]

项目 `code.js` / `runtime/*.code.js` 必须内联包含本 skill `assets/rtproxy.js` 的代理底座和以下宿主对象模板形式。宿主对象模板必须和代理底座在同一个 JS 文件中，位于 `// 目标js` 之前；禁止把代理底座放在单独文件里再用 `require(...)` 引入：

```js
window = rtwatch(global, "window");
document = rtwatch({}, "document");
location = rtwatch({}, "location");
navigator = rtwatch({}, "navigator");
screen = rtwatch({}, "screen");
localStorage = rtwatch({}, "localStorage");
sessionStorage = rtwatch({}, "sessionStorage");
```

- `rtwatch({}, "name")` 是宿主对象的唯一初始对象字面量。正式补环境时，只能把当前目标 `ruyitrace` 证实的字段、方法、状态和返回对象入口直接填入这对大括号内部；这也是内联模板中唯一允许为补环境而修改的位置。
- 补环境后的代码必须保持“对象创建时完成填充”的形式，例如：
  ```js
  document = rtwatch({
      getElementById:function(aaa){
          rt_log('document.getElementById',aaa)
      },
  }, "document");
  ```
- 方法参数必须在方法体内用 `rt_log` 记录；方法名、参数名和缩进可以沿用项目现有风格，不要求改成其它函数写法。
- 文档和项目代码中禁止使用 `{ ... }`、`<真实值>`、`pageUrl`、`pageOrigin` 或其它占位写法来代替实际字段。文档只能说明“把 `ruyitrace` 真值直接填入大括号”，不能给出可被照抄的占位代码。
- 禁止先创建空对象，再用 `document.URL = ...`、`location.href = ...`、`navigator.userAgent = ...` 或同类语句在对象外部散补。字段和方法必须写入对象字面量；只有同一区紧邻的、由 trace 证明需要的 descriptor、原型或 `fun_to_native` 收口动作可以单独处理。
- 禁止重新创建同名宿主对象、重新赋值换壳、把真实字段放入 helper 区或独立的全局绑定区。
- 代理固定声明中唯一允许出现 `global` 的位置是 `window = rtwatch(global, "window")`；这只是把代理提供的底层全局对象交给 `window`，不是后续补环境的落位。
- 完成该固定声明后，后续补出的属性、方法、子对象和构造器必须直接写入 `window` 或对应宿主对象；禁止再写 `global.*`、`globalThis.*`，禁止重新创建或替换全局对象。
- 没有当前目标 `ruyitrace` 证据的字段、方法、原型、constructor、descriptor、`instanceof` 关系和 `toString` 外观不得凭经验补入。
- 原型链不是默认补环境内容。没有 `ruyitrace/descriptor` 或 `domtrace` 明确检测证据时，不创建或绑定任何宿主对象的 prototype，不补 constructor，不执行 `Object.setPrototypeOf`，不为了通过 `instanceof` 主动造原型链。

- `assets/rtproxy.js` canonical 源文件绝对不允许修改、加功能、加 trap、改日志逻辑或改文件名逻辑。内联到 `code.js` / `runtime/*.code.js` 后，代理核心区也绝对不允许修改；只允许修改固定宿主对象声明里的 `{}`。
- 项目宿主对象的补环境内容必须直接填入 `rtwatch({}, "name")` 的这对大括号内部；这是修改 `code.js` 中的宿主对象初始化区，不等于修改 canonical 代理源文件。
- `href`、`origin`、`URL` 等字段必须直接写入当前目标 `ruyitrace` 查到的真实字符串，不能使用自定义变量、提示文本或其它占位内容。
- 禁止在对象声明后再用 `location.href = ...`、`document.URL = ...` 这类方式散补；禁止重新创建第二个同名宿主对象或换壳。
- 如果代理核心能力或模板能力与目标需求冲突，记录为代理资产/模板缺口并暂停，不得自行重构代理；不得用 `require`、后补字段或二次 `rtwatch` 绕过对象字面量规则。

### rtproxy 内联模板门禁 [MUST]

- 进入 Node 补环境前，必须读取本 skill 的 `assets/rtproxy.js`，并把其当前全文原样复制到当前目标对应的 `code.js` / `runtime/*.code.js` 顶部，作为该 runtime 的内联底座。
- `code.js` / `runtime/*.code.js` 禁止通过 `require("./assets/rtproxy.js")`、`require("../assets/rtproxy.js")`、skill 目录绝对路径、项目相对路径、软链接、硬链接或运行时动态查找方式加载代理。
- 内联前可以记录 canonical `assets/rtproxy.js` 的 hash 或内容摘要，用于确认底座来源；内联补环境后不得要求整个 `code.js` / `runtime/*.code.js` 与 `assets/rtproxy.js` hash 一致。
- 交付验收时必须核对内联底座的代理核心未被修改，核对范围包括 `rt_log`、`rtwatch`、Proxy trap、`defaultFilterProps`、`existsobj`、`Function.prototype.toString` 保护、`fun_to_native` 和日志文件逻辑；固定宿主对象声明里的 `{}` 是允许变化区，不纳入“代理核心被修改”判定。
- 如果旧项目已经使用 `require("./assets/rtproxy.js")`，进入阶段 4 前必须改为内联底座；改造时只能把代理内容搬进 `code.js` / `runtime/*.code.js`，不得顺手改代理核心语义。

Node 补环境规则：
- `code.js` / `runtime/*.code.js` 必须在 `// 目标js` 之前建立固定宿主对象大区；`window`、`document`、`location`、`navigator`、`screen`、`history`、`localStorage/sessionStorage`、`performance` 等不得混写在同一段或同一个无分区的 `installBaseEnvironment()` 中。
- 每个大区必须有 1-3 行备注，写明“本区放什么 / 禁止放什么 / 证据来源”；空区也要保留区头和备注，避免后续补环境随手插错位置。
- 具体宿主对象实例和值必须落在对应大区：`location` 值只在 `location 区`，`screen` 值只在 `screen 区`，`document` 节点/方法只在 `document 区`，`window` 自身属性/方法只在 `window 区`；`history`、`performance` 和其它窗口能力归入 `window 区`。
- 代理固定声明完成后，不再设置独立的 `global` / `globalThis` 补环境区。`window` 上的属性、方法、子对象和全局构造器全部直接写在 `window 区`；`self/top/parent/frames` 等关系只有当前 trace 命中时，作为 `window` 的引用关系就近处理，不得把属性写回底层全局对象。
- helper、构造器辅助、`protect`、`makeStorage` 等只能放在共享 helper 区；不得在 helper 区创建或写死具体宿主对象实例值。标签无关的 `makeElement` / `makeDomElement` 类工厂不属于允许的共享 helper。
- `window`、`document`、`location`、`navigator`、`screen`、`history`、`localStorage`、`sessionStorage`、`performance` 等宿主对象必须按目标链路套用 `rtwatch` 观察。
- `window.chrome` 统一保持真实缺失：不能定义为自身属性、原型属性、空对象、空函数或值为 `undefined` 的占位字段；命中读取、`in`、descriptor 或枚举检测时，必须保持读取缺失、`in` 为 false、descriptor 缺失和枚举不存在，不得因旧模板、目标脚本 Chrome 分支或其它材料而补入。
- WebRTC 的全局构造器和对象归 `window` 语义处理，例如 `RTCPeerConnection`、`RTCSessionDescription`、`RTCIceCandidate`、`RTCDataChannel`、`MediaStream`；`navigator.mediaDevices`、`getUserMedia`、`enumerateDevices` 等设备访问入口归 `navigator`。两边都只在当前 `ruyitrace` 明确命中时补。
- 基础 DOM/BOM 必须沿用 `document = rtwatch({}, "document")` 这类模板；正式补环境时，真实字段、方法、getter、descriptor、prototype 和状态直接填入这对大括号内部，禁止在对象初始化后散补、重新赋值或换壳。
- 宿主对象的真实字段、方法和状态优先在对象字面量内一次性写入；`descriptor`、prototype、constructor 和 `fun_to_native` 只有在当前目标 trace 明确命中时，才在同一区紧邻收口。
- 方法调用入参必须显式用 `rt_log` 打印，例如 `document.createElement`、`document.querySelector`、`canvas.getContext`、`localStorage.getItem`。
- 方法返回对象默认返回真实实现对象；只有该返回对象属于基础 DOM/BOM 且被 `jscall` / `ruyitrace` 证明进入目标链路继续读取时，才允许在返回点显式 `rtwatch(returned, "path")`。
- `toString` 底座必须直接使用 `assets/rtproxy.js` 模板里的 `Function.prototype.toString` 保护和 `fun_to_native(fn)`；不得另写一套并行保护。`Function.prototype.toString` 的函数名、换行和缩进属于浏览器环境语义：当前任务以 Firefox `ruyitrace` 为真值时，必须使用 canonical Firefox 模板，不得沿用 V8/Chrome 的单行 native 字符串；命中具体 toString 检测时仍须回查当前 trace 的精确输出。
- 每个补出的浏览器宿主方法、构造器和 native-like 函数都必须做 `toString` 保护。方法在哪个大区定义，`fun_to_native(fn)` 就紧跟在同一个大区、同一个对象定义后面；不得在文件最后堆一个无分区的大名单，也不得把保护散落到目标 JS 后面。
- `rtwatch` / Proxy 日志只用于发现本地缺口，不是真值来源；每个准备补入的环境值、descriptor、prototype、异常外观或方法返回对象仍必须回到匹配当前目标的 `ruyitrace/` 查证。
- 目标 JS 必须放在内联 `rtproxy.js` 底座和宿主对象之后，沿用 `// 目标js` 分界；不能把补环境逻辑插进目标 JS 或 VMP 内部。

固定代理日志文件：
- Node 补环境阶段必须使用代理生成固定原始日志；单 JS/单 runtime 入口默认文件名为 `proxylog.txt`。
- 每次执行 `node code.js` 或 `node runtime/*.code.js` 时，启动阶段必须覆盖清空上一轮 `proxylog.txt`，本轮 `rtwatch` / Proxy trap / `rt_log` 按内联代理底座的文本格式追加写入。
- 不得默认创建时间戳日志、轮次目录或多份历史日志。只有同一任务存在多个 JS/runtime 入口，且每个入口都需要分别补环境和分别分析代理日志时，才允许为不同入口使用不同的固定 `.txt` 文件名；单入口一律继续使用 `proxylog.txt`。换名只能使用代理已有的配置、调用参数或外部运行配置，绝对不允许修改代理来增加换名功能；每个入口每次运行仍覆盖自己的固定日志。
- 多入口日志仍必须是普通 `.txt` 文件，不得改成 `.json`、`.jsonl` 或其它日志格式。
- `proxylog.txt` 是当前轮完整原始代理事件日志；写入前不得抽样、过滤、去重或静默丢弃 `rtwatch` / Proxy trap / `rt_log` 事件。日志写入后可以用独立分析层生成降噪视图，但不得修改、覆盖或替代原始日志。
- 日志格式以内联在当前 `code.js` / `runtime/*.code.js` 中的代理底座实际文本输出为准；不得为了追求 JSON / JSONL / `seq` 字段而擅自改写代理形态。
- 写文件失败必须在控制台报错，不得静默失败。
- `proxylog.txt` 只用于发现本地缺口和复盘本轮执行，不是真值来源；准备补入的环境值、descriptor、prototype、异常外观、方法返回对象和事件顺序仍必须回到匹配当前目标的 `ruyitrace/` 查证。

最小闭环：

```text
node code.js / runtime/*.code.js
→ 发现异常 / 参数错误 / 分支不一致
→ 看 rtwatch / rt_log 吐出的对象、属性、方法入参和本地缺口
→ 用 ruyitrace 或 jscall 确认真实表现
→ 只补当前已确认差异
→ 再跑 code.js / test.py
→ 继续下一轮
```

## 上下文管理 [MUST]

AI 不维护 `补环境进展清单.md`。如果项目中存在该文件，只能当人工摘要，不能当状态源、续跑依据或已补环境事实来源。

AI 的补环境状态只从以下材料判断：
1. `target.lock`：当前允许处理的目标集合，一行一个目标；多入口时可写 `目标 -> runtime/xxx.code.js`
2. `code.js` / `runtime/*.code.js`：已经实际补了什么
3. `proxylog.txt`：最新一轮本地缺口
4. 当前入口运行结果 / 报错
5. 匹配当前目标的 `ruyitrace/` 证据

阶段 4 以后不得靠清单续跑，不得回顾“上一轮到哪了”。清单与代码冲突时，以代码为准；清单缺失、过期或过短，不触发重新盘点全项目。

每轮开始：
1. 运行 `target.lock` 中当前目标对应的 `code.js` / `runtime/*.code.js`
2. 看本轮 `proxylog.txt` 和运行结果报什么缺
3. 若缺口命中 `references/environment-detection-signal-index.md`，先写检测语义卡，说明检测语义、trace 证据、涉及对象、跨对象一致性、状态 / 事件 / 异步时序和补完验证
4. 回匹配当前目标的 `ruyitrace/` 查真值、检测语义、状态或事件顺序
5. 只把 `target.lock` 中目标链路实际触达的缺口补进对应 `code.js` / `runtime/*.code.js`
6. 再跑当前入口

不要写清单，不要用清单盘点阶段，不要因清单缺失回顾历史。只有用户明确改变目标、参数、页面、账号、验证口径、执行层，或新 trace / 新抓包 / 新 jscall 替换旧证据时，才允许回退阶段 0-3。

## 默认任务目录

```text
任务目录/
├── code.js
├── runtime/
│   ├── xxx.code.js
│   └── yyy.code.js
├── test.py
├── target_info.md
├── 目标.txt
├── target.lock
├── 逆向任务分析计划.md
├── 反混淆js/                  # 可选，辅助理解目标 JS，不是真值来源
├── ruyitrace/
└── param_info.md
```

交付规则：
- `code.js` 只负责补环境、目标 JS 逻辑和稳定参数入口；单目标项目默认继续使用 `code.js`。
- `runtime/*.code.js` 只在多目标、多签名、多验证码或多加密 runtime 时使用；每个文件必须有稳定 `get_xxx(input)` 入口。
- AI 新建纯环境 JS 时必须采用顶层安装式环境结构，不得为了满足入口规则追加 `module.exports` 或将其拆成 factory / runtime 文件；项目已有已验证环境文件时保持其加载方式。只有实际产出目标参数的目标逻辑文件才需要稳定 `get_xxx(input)`。
- `assets/rtproxy.js` 只作为 skill 内的 canonical 模板源；项目 runtime 必须把该底座内联在 `code.js` / `runtime/*.code.js` 顶部，不得依赖项目副本、skill 目录、绝对路径或外部代理文件。
- `test.py` 负责真实请求、会话、Header、Cookie、代理和接口验证。
- `test.py` 必须以抓包或 `ruyitrace/http_packet` 中的完整请求面为基线，保留目标请求链相关的全部 Header、Cookie、Query、Body、前置请求、重定向和会话状态。
- `test.py` 的目标生成值和完成判定统一遵循“最高优先级反假完成门禁”；离线材料只能用于请求面基线、fixture 输入或失败 diff，最终结论必须明确 dry-run / real-run 状态。
- `逆向任务分析计划.md` 是阶段 0-3 的必需产物，用来记录最终目标接口、目标类型、需要逆向的参数、每个参数的生成方式、生成 JS、生成位置、依赖输入、验证方式和多参数 / 挑战链解决顺序。每个参数还必须有“目标参数生成收敛卡”，先确认自然出口、最小调用入口、必要初始化依赖和参数取得方式；未确认前不得把页面初始化、定时器、业务回调或请求 mock 写入阶段 4。若目标涉及请求链路或挑战链路，计划中必须按真实触发顺序写出完整请求接口顺序，包括前置请求、挑战 / 题面请求、提交校验请求、凭证注入请求和最终业务请求。阶段 3 等待用户确认时，必须以该文件为确认材料。
- `target.lock` 是阶段 4 以后的目标集合锁定文件，一行一个目标；多入口时可写 `目标 -> runtime/xxx.code.js`。补环境只能围绕 `target.lock` 中目标链路实际触达的缺口展开。
- `补环境进展清单.md` 不是 AI 状态源；如果旧项目中存在，只能当人工摘要，AI 不维护、不续写、不依赖它判断已补环境。
- 如果旧项目中存在 `test.js`，只把它当作参考材料，默认不要继续扩展它。

## 阅读顺序 [MUST]

启用本 skill 后，先完整阅读当前 `SKILL.md`。

按任务进度读取对应模块，不要一次性加载全部 reference：

1. 开始任务、盘点输入、本地现状、确认 `ruyitrace/`、读取目标说明、判定目标类型和定位参数/token 生成位置时，读取 `references/workflow-input-baseline.md`。如果任务目录存在 `反混淆js/`，同时读取目录索引和目标相关 JS，用于辅助定位入口、环境读取点和检测分支；不存在则忽略。
2. 需要确认工具边界或材料使用范围时，读取 `references/tool-boundaries.md` 和 `references/scope-rules.md`。
3. 准备读取 `ruyitrace/index.jsonl`、`http_packet`、`jscall`、`cookie`、`storage`、`domtrace`、`descriptor`、`event`、`eval`、`wasm`、`exception`、`profile` 或不确定 trace 字段含义时，读取 `references/jscall-tools.md`。
4. 目标链路出现 WebAssembly / `.wasm` / wasm base64 / wasm-bindgen / Emscripten / `WebAssembly.instantiate*` 时，读取 `references/wasm-handling-checklist.md`。
5. 出现安全产品同类特征时，读取 `references/products/index.md` 并命中对应产品；命中后只读取对应产品文档。
6. 目标类型为 `验证码`、`签名+验证码`，或 `完整业务链` 出现验证码 / challenge / 滑块 / 点选 / 九宫格 / 多宫格 / `vt` / `validate` / ticket / 业务中途验证码拦截时，读取 `references/workflow-captcha-chain.md`。
7. 目标类型为 `完整业务链` 且出现登录态业务动作、对象 ID、订单/草稿/发布对象状态、动态安全 token、ticket guard、行为一致性上报、protobuf、回执状态或主动发送/发布/评论/下单类动作时，读取 `references/workflow-stateful-business-flow.md`。
8. 目标类型为 `完整业务链` 且出现 WebSocket / WSS / `new WebSocket` / `onmessage` / `ws.send` / 二进制帧 / protobuf / 心跳 / ACK / 回执 / 推送同步 / 自动回复 / 重连时，读取 `references/workflow-websocket-business-flow.md`。
9. 阶段 0-3 结束时必须创建或更新 `逆向任务分析计划.md`。只有证据齐全、目标明确、请求链完整、每个目标参数的“目标参数生成收敛卡”已确认且不涉及验证码 / 业务高风险暂停点时，才允许根据计划结论写入 `target.lock` 并进入阶段 4；若存在证据冲突、目标不明、请求链不完整、参数出口或最小生成链不明、验证码 / 业务高风险、用户口径需要确认或阶段 4 准入阻塞，必须暂停等待用户确认。AI 不创建、不维护 `补环境进展清单.md`。
10. 进入 Node 补环境阶段时，读取 `references/workflow-ruyitrace-env-evidence.md` 和 `assets/rtproxy.js`，并按门禁把代理全文原样内联到当前目标对应的 `code.js` / `runtime/*.code.js` 顶部；runtime 禁止通过 `require` 引用代理文件。
11. `references/environment-hard-standards.md` 不是每轮补环境循环入口，只在首次正式进入阶段 4、准备结构性修改宿主大区 / 原型链 / native 外观、命中高风险环境语义，或交付验收前读取；每轮普通补环境优先按 `target.lock`、当前代码、当前入口运行结果、`proxylog.txt` 和必要的 `ruyitrace` 分区推进。若存在 `反混淆js/`，可在阶段 4-6 回查目标相关代码来解释缺口对应的检测语义，但不得把它当真值来源。阶段 4 首次修改 `code.js` / `runtime/*.code.js` 前，必须读取 `references/environment-detection-signal-index.md`，对目标集合相关 trace 做高风险检测信号扫描，并按“环境结构与检测语义落位门禁”先定位或建立对应语义区。命中 `document.all`、iframe/window realm、iframe/load 或 Worker 调度时序、主线程/iframe/Worker API 边界、Worker 存储泄漏、Worker/MessagePort、CSS 计算、DOM 结构变更、URL / `a` 标签解析、能力探测、`performance.memory`、Canvas/WebGL、plugins/mimeTypes、事件异步时序、鼠标交互状态、WebRTC / 权限 / 设备一致性或 WASM/动态载荷时，读取 `references/special-environment-detection-checklist.md`；命中堆栈 / 执行模型时必须同时读取 `references/environment-detection-checklist.md` 的“堆栈 / 执行模型”；涉及其它具体检测方式时读取 `references/environment-detection-checklist.md`；涉及原型链收口时读取 `references/prototype-chain-template.md`。
12. 需要确认 `code.js` / `runtime/*.code.js` 中 `window`、`document`、`location`、`screen`、`history`、`localStorage`、原型链模板、目标 JS 和 `get_xxx` 的位置时，读取 `references/environment-structure.md`。
13. 正式改造 `code.js` / `runtime/*.code.js`、本地验证、请求联调、升级诊断和交付时，读取 `references/workflow-codejs-verify-escalate.md`。
14. 需要参数说明文件、暂停边界或关键注意事项时，读取 `references/param-pause-notes.md`。

## 执行顺序 [MUST]

1. 阶段 0-3 写好 `逆向任务分析计划.md`，且计划结论为 `parameter_generation_ready=true`、`stage4_allowed=true` 后，按允许处理的目标集合写入 `target.lock`
2. 将 `assets/rtproxy.js` 全文原样内联到当前目标对应的 `code.js` / `runtime/*.code.js` 顶部，并确认 runtime 不通过 `require` 引用代理文件
3. 阶段 4.0：按 `references/environment-detection-signal-index.md` 扫描 `target.lock` 目标集合相关 trace；命中高风险信号时先写检测语义卡
4. 运行当前目标对应的 `code.js` / `runtime/*.code.js`
5. 读取本轮 `proxylog.txt` 和运行结果
6. 只处理 `target.lock` 中目标链路实际触达的缺口
7. 回 `ruyitrace` 查真值、检测语义、状态或事件顺序
8. 补进对应宿主对象区
9. 再跑当前入口
10. 出值达到格式、结构、长度可用标准后，跑 `test.py`
11. 验证失败 → 先对比请求面 → 证明确认为环境缺口后回到阶段 4.0，重新按 `environment-detection-signal-index.md` 扫描相关 trace，再回到第 4 步
## 对象字面量补环境硬规则 [MUST]

交付验收时遵循“Node 补环境规则”中的对象字面量创建、字段收口和不可换壳要求；本节不重复定义同一规则。
