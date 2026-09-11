## 参数说明文件

当任务目标是恢复具体参数、验证码 token、请求加密片段或全流程时，建议交付 `param_info.md`。如果用户已提供 `target_info.md` 或 `目标.txt`，仍建议在交付时用 `param_info.md` 固化最终事实。

`param_info.md` 建议包含：
- 目标类型：`签名`、`验证码`、`签名+验证码`、`完整业务链`、`多产品签名`
- `完整业务链子类型`：`完整验证码链`、`登录态业务链`、`长连接协议业务链`、`主动动作业务链` 或 `证据不足`
- `runtime_mode=node_mode`，以及 Node 执行层调用方式
- 目标参数 / token / 凭证名
- WebSocket / 长连接链路：握手 URL、前置 token / 签名、auth/register/init 包、心跳、ACK、业务消息、发送/回执、重连策略
- 目标触发点：登录、翻页、搜索、下单、详情或其它业务动作
- `code.js` 或 `runtime/*.code.js` 文件名
- 稳定入口方法名
- 调用示例
- 外部入参
- 内部依赖
- 输出字段
- 注入到哪个请求、哪个 Header / Cookie / Query / Body / Storage
- 浏览器侧样本
- 本地样本
- 最小热路径
- 相关脚本 URL
- 请求链：前置请求、目标请求、题面 / challenge 请求、提交校验请求、后续验证请求
- 验证码任务的通过凭证来源、有效期、是否单次消费、最终业务验证口径
- 多 runtime 项目的目标矩阵：目标、类型、JS 文件、入口、请求边界、状态
- VMP / 动态载荷覆盖：`runtime_shape`、`version_risk`、`multi_trace_trigger`、版本材料矩阵和覆盖结论
- 版本材料：目标 JS URL/hash、eval/new Function hash、Worker 脚本 URL/hash、WASM hash、server payload/blob/hash、ArrayBuffer/base64/hex/byte array hash、cookie/storage/init seed、目标集合和适用请求
- trace 覆盖等级：`single_trace_current_version_passed`、`multi_trace_stable`、`multi_trace_divergent` 或 `insufficient_trace_coverage`
- 关键环境依赖
- 已套 `rtwatch` 的对象
- 已用 `rt_log` 记录入参的方法
- `proxylog.txt` 路径、当前轮覆盖生成状态和是否有写入错误
- 使用 `fun_to_native` / 自写 native `toString` 保护的函数
- ruyitrace/jscall 浏览器侧基准证据来源
- ruyitrace 目标参数相关证据来源
- ruyitrace 分区证据来源：`index/http_packet`、`jscall`、`cookie`、`storage`、`domtrace`、`descriptor`、`event`、`eval`、`wasm`、`exception`、`profile` 中实际使用了哪些
- 如果使用 `eval/`，记录动态 JS 文件、来源请求、hash 或版本
- 如果使用 `wasm/`，记录 WASM 元数据、imports/exports、sha256 和公开 binding；不得记录任何 VMP / opcode 插装结果
- 如果使用 `exception/`，记录 `trace_exception_process_<pid>` 文件、异常 message、file/line/column、stack 和本地异常对照结论
- 如果使用 `profile/`，记录具体文件、读取原因和解析方式

## 暂停边界

以下情况必须暂停并等待用户：
1. 当前材料无法确认目标页面、触发动作、目标参数或目标请求，且无法从 jscall 继续确认
2. 目标需要登录、验证码、短信、人工操作
3. 已进入 ruyitrace 补齐阶段，但当前目录没有可用 ruyitrace/jscall trace
4. 目标页面无法采集匹配的 ruyitrace/jscall，且需要人工确认代理或账号
5. 本地请求失败明显与 IP、账号、风控状态、会话态有关
6. 即将大改 `code.js`，但浏览器侧定位还没完成
7. 关键环境值、descriptor、prototype、native `toString` 外观没有证据，只能猜
8. 当前推进路线看起来必须依赖在 VMP / VM 解释器 / opcode handler / 字节码分发层内下探针、插装、插日志、Hook、改 handler、改字节码或改执行语义；必须暂停并说明阻塞点，不允许执行或绕过
9. 目标参数对应的目标 JS、完整入参或生成方法尚未确定
10. 缺少匹配当前目标的 `ruyitrace/` 真实证据，或进入阶段 4 后准备补入的具体环境项没有目标参数相关链路上的 `ruyitrace/` 真值 / 真实外观证据支撑
11. 已出现安全产品同类特征，但尚未命中 `references/products/index.md` 中的产品或记录为未知安全产品特征
12. 计划一次性大批量补环境，或准备在基础 BOM/DOM 未稳定前批量补 `canvas`、`webgl`、audio、font、plugin、mimeType 等指纹面
13. 验证码任务尚未确认题面接口、提交校验接口、通过凭证字段、凭证注入位置或最终业务验证口径
14. 多签名 / 多验证码任务尚未明确是否使用单 `code.js` 还是 `runtime/*.code.js`，以及每个入口的职责边界
15. 用户或项目材料明确要求非 Node 执行层；本 skill 不适用，必须停止使用本 skill 并切换到对应专用 skill
16. 需要读取 `profile/`，但尚未明确具体文件、目标字段或解析方式；不得全量文本读取 profile
17. 当前路线看起来需要进入 WASM / VMP / opcode / handler 内部插装或改写语义才能继续；必须回到外围公开 API、请求边界和 trace 分区证据
18. 单 trace 未通过，且当前 trace 无法解释失败原因或证据不足；必须标记 `single_trace_failed_need_more_evidence`，等待更多 trace 或证据，不得继续盲补环境
19. 单 trace 已通过，但目标链路存在 VMP / VM-like runtime / 动态执行载荷 / 不透明 payload / Worker/WASM 执行载荷等多版本风险候选，且用户要求跨版本稳定结论；必须标记 `single_trace_passed_quality_check`，等待多 trace 对照
20. 当前路线需要做请求面以外的 diff，例如参数字节集 diff、签名字节 diff、密文字节 diff、算法输入输出 diff、字段扰动差分、bit/byte 翻转对照或批量样本差分；必须暂停并回到请求面、trace 证据和 DOM/BOM 环境证据

暂停时只做：
- 整理缺失项
- 明确下一步需要用户提供什么
- 保留当前证据结论

不得：
- 猜测关键环境值
- 跳过定位直接硬补
- 在目标 JS、入参、生成方法、Proxy 证据和 `ruyitrace/` 真值未齐时提前补环境
- 当新的环境项缺少目标链路相关 `ruyitrace/` 真值时，凭旧项目、猜测、单独 jscall 现象或浏览器表面枚举结果补入
- 用浏览器跑出来的参数替代本地实现
- 无证据扩大 Proxy 范围
- 用单 trace 通过结论声明 VMP / 动态载荷跨版本稳定
- 在单 trace 失败且证据不足时继续盲补环境
- 通过 VMP 插装、下探针、opcode hook、VM tracer 或解释器 proxy 继续推进
- 做请求面以外的 diff，或用参数 / 签名 / 密文 / 算法输入输出差分结果反推算法
- 一次性大批量补环境，或跳过基础 BOM/DOM 直接堆 canvas/WebGL 指纹面

## 关键注意事项

- `jscall` 是浏览器侧 trace 证据，不是最终交付物
- `ruyitrace/` 中记录的分区证据是本版默认环境真值来源：请求链看 `index/http_packet`，调用链看 `jscall`，状态看 `cookie/storage`，环境看 `domtrace/descriptor/event`，动态 JS 看 `eval`，WASM 外围看 `wasm`，浏览器异常看 `exception`
- `profile/` 只作为持久态辅助资产，必须定向读取，不全量当日志处理
- `assets/rtproxy.js` 是随 skill 打包的 Node 补环境 rtproxy 源文件；`node_mode` 使用时必须读取或复制它，允许使用其 `rt_log`、`rtwatch`、`fun_to_native`、`Function.prototype.toString` 保护
- `proxylog.txt` 是当前轮固定代理事件日志，每次 Node 运行覆盖上一份，不默认创建多份历史日志；它只用于本地缺口观察，不替代 `ruyitrace/` 真值
- 默认以本 skill 的 `environment-structure.md` 作为补环境结构依据；Node 补环境使用 `assets/rtproxy.js`
- Node 补环境底座必须采用 `rtproxy.js` 的格式顺序，目标 JS 仍放在 `// 目标js` 之后
- 每个补环境方法必须做 `toString` 保护
- 不允许在 VMP 上进行插装补环境，不允许下探针
- 具体指纹值、调用链和事件顺序必须按证据确认
- 不默认全量补环境
- 不允许一次性大批量补环境；必须先补基础 BOM/DOM 对象，再补方法入参与返回对象，最后才按证据补 canvas、WebGL 等指纹面
- Node 补环境必须沿用代理已有的 `window = rtwatch(global, 'window')` 等固定宿主对象声明；补环境只能写在声明之后，最终只按目标链路实际吐出的缺口补环境
- 不默认深度反混淆 VMP
- VMP 形态可以单 trace 判断为 `suspected_vmp` / `confirmed_vmp`，但 VMP 多版本字节流或动态载荷风险不能靠单 trace 排除
- 多 trace 对照有两类用途：单 trace 通过后的环境质量复核，以及单 trace 未通过且证据不足时的失败定性和补证据
- 单 trace 通过只能写 `single_trace_current_version_passed`；存在多版本风险但未做对照时，必须写 `insufficient_trace_coverage`，不能写跨版本稳定
- 多 trace 对照只允许围绕请求链、版本材料、目标入口入参、DOM/BOM 读取点、事件/Worker 消息链、storage/cookie 状态和最终请求 diff 做外围比较，不得进入 VMP / opcode / handler 内部插装
- 默认单目标使用 `code.js`；多签名、多验证码、多加密链或多个 JS runtime 时，允许拆分到 `runtime/*.code.js`
- 拆分多个运行文件时，必须维护目标矩阵，并让 `test.py` 统一编排调用顺序
- 最终以 `test.py` 稳定跑通、目标参数稳定复现、验证码通过凭证有效或最终业务接口放行为准
