## 工作流程：阶段 0-3（单一来源）

> 这是阶段 0-3 的唯一展开来源。`SKILL.md` 只应引用这里，不要把同一套分析流程再写一遍。阶段 0-3 的正式产物是 `逆向任务分析计划.md`，用于写清“要逆什么、在哪里生成、按什么顺序解决”，并判断是否允许进入阶段 4。

### 续跑恢复门禁
进入阶段 0 前，先判断当前轮是否为同一任务续跑：

1. 如果存在 `逆向任务分析计划.md`，先读取其中的最终目标接口、目标类型、逆向参数清单、参数生成方式、生成 JS、生成位置、参数依赖关系、解决顺序、阶段 4 准入结论和暂停原因。
2. 如果任务已经进入阶段 4，状态只从 `target.lock`、当前 `code.js` / `runtime/*.code.js`、当前入口运行结果、`proxylog.txt` 和必要的 `ruyitrace/` 分区判断；不读取 `补环境进展清单.md` 作为续跑依据。
3. 如果用户最新消息没有改变目标、runtime_mode、trace、请求链、账号/页面状态、触发动作或验证口径，沿用 `逆向任务分析计划.md` 中的已确认结论，不重新做阶段 0-3 完整盘点。
4. 如果 `逆向任务分析计划.md` 记录 `stage4_allowed=true` 且阶段 4 门禁仍满足，用户只是回复确认、追问状态或补充非冲突材料时，不得再次停在阶段 3 等待确认；进入阶段 4 后按 `target.lock` 和当前代码/日志继续。
5. 如果用户补充了新的 `目标.txt`、`param_info.md`、`target_info.md`、`ruyitrace/` 或抓包材料，只对新增材料做增量检查；只有新增材料与计划冲突时才回退到对应阶段。
6. 如果必须回退，记录 `resume_decision=rollback`、回退阶段和原因；否则记录 `resume_decision=continue`，并从计划中的 `当前阶段` / `下一步` 继续。
7. 续跑时禁止先读 `目标.txt` 再读 `逆向任务分析计划.md`；`目标.txt` 只在计划缺失、用户明确更新目标说明或计划与当前任务明显冲突时增量读取。
8. 不读取 `某台机器的固定客户端配置文件` 来确认命令前缀；AGENTS 规则已经生效，直接按当前会话要求使用 `rtk`。

续跑恢复不能绕过证据门槛：`逆向任务分析计划.md` 缺少目标 JS、完整入参、生成方法、请求链、匹配 `ruyitrace/` 真值或阶段 4 准入结论时，仍必须回到对应阶段补齐。

### 阶段 0：输入检查与证据盘点
1. 检查 `code.js` 是否存在
2. 检查 `runtime/` 是否存在；如果存在，盘点 `runtime/*.code.js`
3. 检查 `test.py` 是否存在
4. 检查是否已有 `逆向任务分析计划.md`；如果任务已经进入阶段 4，再检查 `target.lock`、当前代码入口和 `proxylog.txt`
5. 首次建档或因冲突回退时，检查可选目标说明文件，存在则读取；同一任务续跑时优先使用 `逆向任务分析计划.md`，不重复读取：
   - `target_info.md`
   - `param_info.md`
   - `目标.txt`
6. 首次建档或回退时，从 `目标.txt` 或用户当前指令中识别执行层；本 skill 只接受 `node_mode`：
   - `node/nodejs/Node补环境` 归一为 `node_mode`
   - 用户当前明确指定非 Node 执行层时，本 skill 不适用，必须停止使用本 skill 并切换到对应专用 skill
   - 未声明时按本 skill 固定为 `node_mode`，不得推断为其它执行层
7. 盘点：
   - `ruyitrace/` 是否存在，是否可能匹配当前目标
   - `ruyitrace/index.jsonl` 是否存在，是否可用于快速筛选 HTTP 包
   - `ruyitrace/` 分区是否存在：`jscall`、`cookie`、`storage`、`domtrace`、`descriptor`、`event`、`eval`、`wasm`、`exception`、`profile`
   - 当前目录中其他与目标相关的离线抓包、日志、脚本或历史归档
   - 目标名称、参数名、脚本名、Cookie、Header、URL、响应体或日志是否出现安全产品同类特征；出现同类特征时必须读取 `references/products/index.md` 并命中对应产品，再读取对应产品文档
8. `code.js` / `runtime/*.code.js` / `test.py` 可以不存在或为空；只记录状态，不因此阻塞
9. 如果本地文件为空，但已有目标 URL、触发步骤、页面入口、抓包或其他目标线索，继续进入 ruyitrace/jscall 证据分析
10. 只有在 `code.js` / `runtime/*.code.js` / `test.py` 为空且当前材料也无法确认目标页面、触发动作或目标参数时，才让用户补充目标 URL、触发步骤和目标参数
11. 如果证据已有，先建立最小任务上下文，不机械重新采集
12. 首次建立最小任务上下文后，必须立即创建或更新 `逆向任务分析计划.md` 的“当前阶段”“已读证据/引用”“运行模式”和“下一步”；后续中途对话以该计划为续跑入口，不再重复读取目标说明文件

目标说明文件只作为用户目标声明和线索。若用户声明与 `jscall`、`http_packet` 或真实响应冲突，以真实证据为准，并在 `逆向任务分析计划.md` 记录冲突。`runtime_mode` 在本 skill 中固定为 `node_mode`，不改变 trace 真值来源。

#### 目标类型判定

阶段 0-3 必须判定任务目标类型，不能默认都是签名参数：

```text
签名         = 只恢复签名、加密、指纹参数
验证码       = 只过验证码 / challenge，并拿通过凭证
签名+验证码  = 验证码凭证 + 签名 / 加密参数
完整业务链   = 从前置挑战、验证码、签名、加密，或登录态状态型业务动作 / WebSocket 长连接协议一路跑到最终业务接口
多产品签名   = 一个任务中存在多个安全产品、多个签名参数、多个验证码或多个 JS runtime 入口，需要分别定位和验证
证据不足     = 暂时不能判定目标类型，继续盘点 trace / 请求链
```

验证码触发点需要进一步标记：

```text
登录验证码      = 登录前或登录中验证码
业务中途验证码  = 登录后翻页、搜索、下单、详情、领券等业务中途验证码
```

`完整业务链` 需要进一步标记子类型：

```text
完整验证码链
= 完整链路中明确包含验证码 / challenge / vt / validate / 通过凭证

登录态业务链
= 登录态下的状态型业务动作，依赖账号态、目标对象、业务对象状态、动态 token、风控 header、行为上报和最终业务接口

长连接协议业务链
= 带 SDK / protobuf / WebSocket / WSS / 长连接 / 会话创建 / ACK / 回执状态的业务协议链路

主动动作业务链
= 发送、私信、评论、发布、下单等主动动作，重点是行为一致性、设备/票据材料、目标对象和服务端状态
```

判定依据：
- `签名` 常见特征：`sign`、`h5st`、`a_bogus`、`black_box`、`sensor_data`、`x-api-eid-token`、摘要字段、加密 body、加密 header
- `验证码` 常见特征：`captcha`、`verify`、`check`、`challenge`、`slider`、`grid`、`cell`、`tile`、`matrix`、`ticket`、`validate`、`vt`、`tp`、`img`、验证码失败、滑块失败、点选失败、九宫格失败
- `签名+验证码` 常见特征：先拿验证码 token，再把 token 注入带签名 / 加密的业务请求，例如 JCAP `vt` + `h5st/_stk` + `aksParamsU/B`
- `完整业务链` 常见特征：用户要求跑完整登录、翻页、搜索、下单、私信、评论、发布或其它最终业务链路
- `多产品签名` 常见特征：同一任务同时命中多个安全产品或多个签名族，例如一个业务请求同时依赖 `_px3`、`akamai` cookie、`h5st`、`x-sign`、加密 body 或多个 runtime 入口
- `登录态业务链` 常见特征：已有 Cookie / 登录态，目标依赖自己账号 ID、目标对象 ID、会话 / 订单 / 草稿 / 发布对象状态、动态安全 token、风控 header、行为上报或最终服务端状态
- `长连接协议业务链` 常见特征：链路出现 protobuf、SDK command、WebSocket / WSS、`new WebSocket`、`onmessage`、`ws.send`、长连接、心跳、ACK、回执、二进制包、cursor / sequence / read_index / mid 等协议状态
- `主动动作业务链` 常见特征：目标是发送、私信、评论、发布、下单、领券等主动动作，成功口径不能只看 HTTP 200，必须验证服务端状态、回执、业务 ID 或实际到达

#### VMP / 动态载荷版本风险盘点

阶段 0-3 不要求 AI 必然识别出“多版本字节流”的语义；只能要求盘点目标集合相关链路中的版本材料、动态执行材料和疑似不透明运行时载荷。AI 可以基于代码形态判断 `疑似 VMP` / `确认 VMP`，但不能用单 trace 排除多版本风险。

必须记录：

```text
运行形态:
  普通 JS / 疑似 VMP / 确认 VMP / WASM 运行时 / Worker 运行时 / 未知

版本风险:
  未知 / 候选风险 / 多 trace 确认稳定 / 多 trace 确认分歧

多 trace 触发状态:
  无 / 单 trace 质量检查通过 / 单 trace 质量检查失败需补证据

版本材料:
  target_js_url/hash
  eval/new Function hash
  Worker script url/hash
  WASM hash
  server payload/blob/hash
  ArrayBuffer/base64/hex/byte array hash
  cookie/storage/init seed
  target集合
  适用请求
```

凡目标集合相关链路经过 VMP、VM-like interpreter、动态 opcode/payload、server 下发不透明 blob、base64/hex/ArrayBuffer/字节数组、eval/new Function、Worker/WASM 内执行载荷，或参与目标生成的动态响应材料，默认把 `版本风险` 标记为 `候选风险`。无法确认某个 blob 是否就是 VMP 字节流时，记录为版本材料，不得用单 trace 结论外推。

单 trace 下最多只能标记 `版本风险=未知` 或 `版本风险=候选风险`。只有多 trace 对照后，才能标记 `多 trace 确认稳定` 或 `多 trace 确认分歧`。

阶段 0-3 必须创建或更新 `逆向任务分析计划.md`。该文件是阶段 3 结论材料；需要暂停时作为人工确认材料。聊天回复只需要摘要、准入结论和必要确认点，不能用大段回复替代该文件。

`逆向任务分析计划.md` 必须围绕“跑通接口需要解决哪些逆向参数、参数怎么生成、在哪个 JS 生成、先解决哪个”组织：

```text
# 逆向任务分析计划

## 当前阶段
- current_stage: stage_0_3_analysis
- runtime_mode: node_mode
- stage4_allowed:
- pause_required:
- pause_reason:
- resume_decision:
- 下一步:

## 最终目标接口
- URL:
- Method:
- 成功口径:
- 失败口径:
- 请求面基线:

## 完整请求接口顺序
请求链路、挑战链路、验证码链路、完整业务链和多产品签名任务必须填写本节；单函数直出且不依赖请求链时写“不涉及请求链”。

| 顺序 | 接口角色 | URL / Method | 关键 Query / Header / Body / Cookie | 产出 / 写入 | 依赖上一节点 | 证据来源 |
|---|---|---|---|---|---|---|
| 1 | 前置请求 / challenge 初始化 / 题面请求 / 提交校验 / 凭证注入 / 最终业务请求 |  |  |  |  |  |

## 目标类型
- 类型: 签名 / 验证码 / 签名+验证码 / 完整业务链 / 多产品签名 / 证据不足
- 完整业务链子类型:
- 判定依据:

## 需要解决的逆向参数
| 参数 | 用途 | 生成方式 | 生成 JS | 生成位置 | 依赖输入 | 验证方式 | 状态 |
|---|---|---|---|---|---|---|---|

## 参数依赖关系
- 参数 / token / cookie / storage / challenge 之间的先后依赖:

## 解决顺序
1. 先解决:
   - 原因:
   - 预计产出:
   - 验证方式:

2. 再解决:
   - 原因:
   - 预计产出:
   - 验证方式:

## 证据索引
- 目标说明文件:
- ruyitrace:
- http_packet:
- jscall:
- 产品文档:
- 关键缺口:

## 阶段 4 准入结论
- 是否允许进入阶段 4:
- 阻塞原因:
- 是否需要暂停:
- 暂停原因:
- target.lock 计划:
```

本阶段禁止正式改造 `code.js`。

### 阶段 1：本地现状盘点

读取 `test.py`：
- 如果存在且非空，确认当前已写入的目标接口、目标参数和调用 `code.js` 的方式
- 如果不存在或为空，只记录为空；不要据此判断请求链缺失

读取 `code.js`：
- 如果存在且非空，找到当前入口函数、疑似生成加密参数的位置和已存在的环境补丁
- 如果不存在或为空，只记录为空；不要强行假设已有入口函数
- 只有在 `code.js` 可运行时，才记录当前本地失败症状
- 不在本阶段定性为环境问题、参数错误或请求链错误

读取 `runtime/*.code.js`：
- 如果存在，逐个记录文件名、稳定入口、负责的参数族 / 验证码链 / 加密链
- 如果不存在，只记录未启用多 runtime 结构
- 多文件项目必须建立目标矩阵，不允许多个 JS 文件职责混乱

阶段 1 不单独生成长输出；本地现状只写入 `逆向任务分析计划.md` 的最终目标接口、需要解决的逆向参数、生成 JS / 入口、证据索引和关键缺口。不存在或为空的文件只在影响计划判断时记录，不逐项输出空字段。

### 阶段 2：确认 ruyitrace 证据与任务上下文

本阶段不默认重新采集。目标是确认当前任务是否已经具备后续补环境所需的 `ruyitrace/` 真值证据。

默认流程：
1. 盘点 `ruyitrace/` 文件、时间、目标域名、页面 URL、触发动作和目标参数线索
2. 判断 `ruyitrace/` 是否与当前目标请求、账号状态、页面状态和触发步骤匹配
3. 从匹配的 `ruyitrace/` 中提取：
   - HTTP 请求索引：`index.jsonl` 中的目标 URL、method、status、requestKind、contentType 和对应 packet 文件
   - HTTP 包详情：根目录 `*.http_packet.json` 中的 header、cookie、query、body、response、set-cookie
   - 请求面基线：目标请求和关键前置请求的完整 headers、cookie、query、body、method、URL、redirect、preflight、HTTP 版本 / HTTP2 伪头映射；不要只记录动态签名字段
   - JS 调用链：`jscall/` 中的函数、脚本来源、调用栈、入参、返回值、异常和请求边界
   - Cookie 状态：`cookie/` 中的 document.cookie 读写、attributes、rejectedReason、调用栈
   - Storage 状态：`storage/` 中的 localStorage/sessionStorage 读写、fp、token、cache
   - DOM/BOM 真实值：`domtrace/` 中的 `window`、`document`、`location`、`navigator`、`screen`、`history`、`performance`、canvas/webgl 等
   - 反射面：`descriptor/` 中的 descriptor、ownKeys、prototype、constructor、toStringTag 证据
   - 事件顺序：`event/` 中的 listener、timeout、dispatch、trusted/synthetic、验证码或行为链回调
   - 动态 JS：`eval/` 中落盘的 eval/new Function/challenge JS
   - WASM 外围：`wasm/` 中的 compile/instantiate、imports/exports、sha256、dumped wasm
   - 版本材料：目标 JS URL/hash、eval/new Function hash、Worker 脚本 URL/hash、WASM hash、server payload/blob/hash、ArrayBuffer/base64/hex/byte array hash、cookie/storage/init seed、目标集合和适用请求
   - 浏览器异常：`exception/trace_exception_process_<pid>` 中的 Error/DOMException/native_exception、message、file/line/column、stack 和 `jscall_parent_call_id`
   - Profile 辅助资产：`profile/` 只在持久态证据缺口明确时定向读取，不全量文本读取
4. 如果 `ruyitrace/` 缺失或明显不匹配，记录缺口；正式补环境前必须补齐匹配当前目标的 `ruyitrace/`、`jscall` 和 `http_packet` 证据

阶段 2 不单独生成长输出；`ruyitrace/`、`http_packet`、`jscall` 和专项分区的结论只写入 `逆向任务分析计划.md` 的证据索引、参数生成方式、参数依赖关系、解决顺序和关键缺口。缺少匹配当前目标的 `ruyitrace/`、`jscall` 或 `http_packet` 时，必须在计划的阶段 4 准入结论中标记为阻塞。

### 阶段 3：定位目标产出位置与请求链

本阶段使用 `jscall` 定位目标 JS 来源、签名 / 加密参数生成位置、验证码 / challenge token 产出位置、jscall 调用栈、入参、返回值和请求边界证据；使用 `ruyitrace/index.jsonl` 和根目录 `*.http_packet.json` 确认真实请求链、请求/响应字段、动态字段和会话态变化。阶段结束时应已经明确目标是在函数返回、请求组装边界、cookie/storage 预生成、验证码校验响应、业务拦截响应还是动态 JS 中产出。

优先在 jscall 脚本来源、调用记录、入参/返回值、异常、调用栈和 `http_packet` 请求/响应中搜索目标参数名、目标请求 URL/Header/Cookie/Body 字段；通用关键词补充：`sign, token, encrypt, decrypt, hash, md5, sha, aes, rsa, cookie, sensor, fp, fingerprint, captcha, challenge, verify, check, slider, grid, cell, tile, matrix, ticket, validate, vt, tp, img, canvas, webgl, navigator, screen, localStorage, sessionStorage, XMLHttpRequest, fetch`。

请求链定位必须建立完整请求面基线：目标请求和关键前置请求的 headers、cookie、query、body、method、URL、redirect、preflight 和会话状态都属于验证材料。不得把 `Accept`、`Accept-Language`、`User-Agent`、`Origin`、`Referer`、`Sec-Fetch-*`、`Sec-CH-UA-*`、`Content-Type`、`Authorization`、`X-*` 等看似基础的 headers 当作可省略项。只有 HTTP 客户端必须自动重算或无法直接设置的字段才允许不手写到 `test.py`，并必须记录省略原因、客户端等价行为和是否影响签名 / 风控。

如果目标名称或特征命中已知安全产品，例如 Akamai、Kasada、Reese84 / Imperva / Incapsula、DY `a_bogus` 等，必须先读取 `references/products/index.md`，并命中对应产品文档。产品文档只用于识别常见链路、优先观察点和常见坑，不替代当前目标的 `jscall` 定位证据和匹配 `ruyitrace/` 真值。

安全产品强制命中规则：
- 出现同类产品名、参数名、脚本名、Cookie、Header、URL、响应体或日志特征时，必须命中 `references/products/index.md` 中的产品
- 命中后必须读取对应产品文档，并在阶段输出中写明命中的产品和已读取文档
- 已有同类特征但无法映射到现有产品文档时，必须记录为“未知安全产品特征”，不能当成普通站点跳过产品识别
- 未完成产品命中识别，不得进入正式补环境阶段

定位目标：
- 真实目标请求是谁发起的
- 目标参数最终出现在哪里：URL、Query、Header、Body、Cookie、Storage、函数返回值
- 验证码 token / 通过凭证最终从哪个校验响应产生，注入到哪个后续请求
- 如果是业务中途验证码，原业务请求、拦截响应、验证码校验接口和回放业务请求必须成链
- 目标 JS 来源是什么：静态 JS、动态 JS、challenge 返回、eval/new Function、worker/iframe
- 目标函数或请求组装逻辑的大致位置
- 最小入参是什么
- 前置 cookie/storage 是否由 JS 生成
- 是否有前置 challenge 请求
- 参数是否依赖事件、时间、随机数、页面状态

### 请求链条判定

阶段 3 必须先判断目标参数是否涉及请求链条，不得默认目标参数只是某个 JS 函数直出。

需要判定：
- 目标参数是否依赖前置请求返回值、Cookie、Storage、Header、动态 JS、页面状态或服务端下发配置
- 目标参数是否只在 `fetch` / `XMLHttpRequest` / `sendBeacon` / 表单提交 / URL 拼接 / Header 设置 / Cookie 写入等请求边界出现
- 目标参数是否需要同一轮请求链中的 JS、Cookie、Header、Storage、响应体或 token 才能生成
- 目标参数生成后是否还需要进入后续业务请求才能验证有效性

如果目标参数涉及请求链条，阶段 3 必须先整理最小请求链条，再允许进入阶段 4。不能在请求链条未确认时直接开始补环境。

阶段 3 结束时必须把定位结论写入 `逆向任务分析计划.md`，重点写清楚最终目标接口、完整请求接口顺序、需要逆向的参数、每个参数的生成方式、生成 JS、生成位置、依赖输入、验证方式和多参数 / 挑战链解决顺序。不要另行输出大段字段清单。

```text
阶段 3 必须在计划中给出:
- 目标类型
- 最终目标接口与成功 / 失败口径
- 完整请求接口顺序
- 需要解决的逆向参数清单
- 每个参数的生成方式和生成 JS
- 每个参数的生成位置或请求边界
- 每个参数的依赖输入
- 每个参数的验证方式
- 多参数 / 挑战链 / 多产品签名的解决顺序
- 阶段 4 是否准入以及阻塞原因
```

请求链路或挑战链路的计划要求：
- 必须按真实触发顺序列出每个接口；不得只写“先过验证码 / 再请求业务”这类泛描述。
- 每个接口节点必须写明接口角色、URL / Method、关键 Query / Header / Body / Cookie、该节点产出或写入了什么、依赖哪个上一节点，以及证据来源。
- 如果某个接口只在 `ruyitrace/index.jsonl` 中有索引，还没打开对应 `*.http_packet.json` 确认请求面，必须标记为 `请求面未确认`，不得写成已确认。
- 如果挑战链缺少初始化、题面、提交校验、凭证注入或最终业务请求中的任一节点，阶段 4 准入结论必须标记为阻塞。

先判断目标参数产出方式，不要默认参数一定由某个函数直接返回：
- 函数直出：某个 JS 函数直接返回目标参数，优先整理为 `code.js` 稳定入口
- 请求边界产出：参数在 `fetch` / `XMLHttpRequest` / `setRequestHeader` / URL / Body / Cookie 组装过程中出现，先观察请求边界，再决定落到 `code.js` 还是 `test.py`
- 动态 JS 产出：如果目标参数由动态 JS 生成，阶段 3 必须标记为动态 JS 产出；进入阶段 4 正式补环境前，必须先把该 JS 的当前可验证版本固定到本地 `code.js`，确认能加载到稳定入口或稳定复现首个缺环境点；补环境收敛到本地稳定生成目标参数后，再回到动态 JS 请求链做联动测试
- trace 捕获型：暂时找不到稳定入口时，可用 jscall 的调用记录、入参、返回值、异常和调用栈还原最终值与热路径，但不得把观察框架写进本地 `code.js`
- 验证码校验型：目标值由提交校验接口返回，例如 `vt/ticket/validate`；必须把初始化、题面、答案证明、校验、凭证注入和最终业务验证分清，不能只复现一个 JS 函数返回
- 业务中途验证码型：原业务请求被 challenge 拦截后，需要通过验证码校验接口拿凭证，再把凭证注入原业务请求；最终成功口径必须是原业务接口返回正常业务数据

阶段 3 不是固定人工暂停门禁。AI 更新 `逆向任务分析计划.md` 后，先按以下内容判断是否满足阶段 4 准入：
- 目标类型是否已确认：`签名`、`验证码`、`签名+验证码`、`完整业务链`、`多产品签名` 或 `证据不足`
- 需要逆向的参数是否已列清，并且每个参数的生成 JS、生成位置、生成方式已经确认
- 如果涉及请求链路或挑战链路，`逆向任务分析计划.md` 是否已经按真实触发顺序写出完整请求接口顺序
- 入参和请求面是否完整，包含必要的 query/body/header/cookie/storage/时间/随机数/页面状态，以及目标请求和关键前置请求的完整 headers/cookie/query/body/method/URL/redirect/preflight/会话状态
- 匹配当前目标的 `ruyitrace/`、`jscall`、`http_packet` 证据是否满足阶段 4 准入
- 是否允许开始构造 `get_参数名(input)` 并进入阶段 4 补环境

证据齐全、目标明确、请求链完整且不涉及验证码 / 业务高风险暂停点时，允许在计划中写明 `stage4_allowed=true`，生成 `target.lock` 后进入阶段 4。

以下情况必须暂停等待用户确认，不得进入阶段 4，不得开始改造 `code.js` 或套 Proxy 补环境：
- 证据冲突，或用户口径与 `ruyitrace` / `jscall` / `http_packet` 不一致
- 目标类型、目标接口、目标参数、生成 JS、生成位置或生成方式不明确
- 请求链路、挑战链路、验证码链路或完整业务链缺节点、顺序不明或请求面未确认
- 验证码通过口径、业务放行口径、账号 / 页面状态 / 登录态 / 代理状态存在高风险不确定性
- 阶段 4 前置门槛缺失，或动态 JS 当前版本尚未固定到本地入口

硬性禁止提前补环境：
- 未确定目标参数对应的目标 JS，不得补环境
- 未判定目标类型，不得补环境
- 未确定完整入参，不得补环境
- 未确定完整请求面基线，不得进入 `test.py` 验收；本地请求面未与抓包目标请求面 diff 前，不得把请求失败归因到 JS 补环境
- 未确定生成方法，不得补环境
- 验证码任务未确认题面 / 校验 / token 注入 / 最终业务验证口径，不得补环境
- 未确认目标参数是否涉及请求链条，不得补环境
- 目标参数涉及请求链条但最小请求链条、同一轮依赖、请求边界或 `code.js` / `test.py` 职责边界尚未明确，不得补环境
- 动态 JS 产出但尚未固定当前可验证 JS 到本地 `code.js`，或尚未确认能加载到稳定入口 / 稳定复现首个缺环境点，不得补环境
- 未拿到匹配当前目标的 `ruyitrace/` 真实证据，不得补环境
- 进入阶段 4 后，未通过本地缺口观察日志和 `ruyitrace` / `jscall` 对照确认的具体环境项，不得补入或固化；Node 补环境看 `rtwatch` / Proxy / `rt_log`
- 只有浏览器跑出了目标参数，但没有本地生成方法和证据链，不得补环境
