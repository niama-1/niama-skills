## jscall / ruyitrace 使用索引

本文用于替代浏览器侧实时调试依赖。默认不调用浏览器调试工具；优先从当前任务目录的 `ruyitrace/` 分区读取证据，还原目标参数、验证码 token、动态 JS、环境真值和请求链。

## 证据分工

```text
ruyitrace/index.jsonl
= HTTP 包索引：requestId、seq、pid、file、url、method、status、requestKind、contentType、hash、start/end/duration、cache/serviceWorker 状态。

ruyitrace/*.http_packet.json
= 历史请求链证据：URL、method、headers、cookies、query、body、response、status、服务端下发动态字段。

ruyitrace/jscall/*.jsonl
= JS 调用链证据：函数名、脚本来源、调用栈、入参、返回值、异常、时间戳、异步链路、请求边界附近调用。

ruyitrace/cookie/*.jsonl
= Cookie 读写证据：document.cookie 读取、写入尝试、raw cookie、attributes、thirdParty/fromHttp、rejectedReason、调用栈。

ruyitrace/storage/*.jsonl
= 状态读写证据：cookie、localStorage、sessionStorage、fp、token、cache、行为标记、请求前后状态变化。

ruyitrace/domtrace/
= DOM/BOM 证据：环境读取、方法调用、对象身份、指纹面真实值、部分原型/外观行为。

ruyitrace/descriptor/*.jsonl
= 反射面证据：Object.getOwnPropertyDescriptor、Object.getOwnPropertyNames、Reflect.ownKeys、prototype/constructor/toStringTag 相关检测。

ruyitrace/event/*.jsonl
= 事件与异步证据：addEventListener、dispatch、timeout、listener target、事件阶段、trusted/synthetic、采样策略、回调来源。

ruyitrace/eval/
= 动态 JS 证据：eval、new Function、inline/direct eval 等落盘源码；用于固定当前可验证动态 JS，并记录 hash / 来源请求 / 适用目标集合。

ruyitrace/wasm/
= WASM 外围证据：compile/instantiate metadata、imports/exports、sha256、dumped wasm 文件；只用于外部请求边界、公开 binding 定位和版本材料记录，不允许 VMP / opcode 插装。

ruyitrace/exception/trace_exception_process_<pid>
= 浏览器异常证据：无扩展名 JSONL，首行为 trace_init，后续记录 type=exception；用于确认浏览器真实异常、DOMException/Error 外观、异常文件/行列、stack、native_exception 和与本地 Node 异常差异。

ruyitrace/profile/
= 浏览器 profile 辅助资产：SQLite、缓存、扩展配置、Local State 等。只在 cookie/storage/cache/profile 证据缺口明确时定向读取，不全量当文本 trace 处理。
```

## 首轮读取顺序

1. 先确认 `ruyitrace/` 是否匹配当前目标页面、账号状态、触发动作、目标 URL 和目标参数。
2. 优先读 `index.jsonl`，用 `url/method/status/requestKind/contentType/file/seq` 快速筛目标请求和脚本资源。
3. 从根目录 `*.http_packet.json` 读取目标包详情，记录 URL、method、query/body/header/cookie、响应状态和响应体关键字段。
4. 用目标参数名、目标 URL、functionId、header 名、cookie 名、body 字段在 `jscall/*.jsonl` 中搜索。
5. 用 `cookie/*.jsonl` 和 `storage/*.jsonl` 确认 cookie、fp、token、cache、localStorage、sessionStorage 的读写时机和同轮关系。
6. 如果目标 JS 是动态产出，读取 `eval/` 中对应落盘 JS；先固定当前可验证版本，再进入正式补环境，并记录 eval/new Function hash、来源请求和适用目标集合。
7. 用 `event/*.jsonl` 确认触发动作、事件顺序、listener、timeout 和验证码 / 行为链回调。
8. 用 `descriptor/*.jsonl` 确认 descriptor、ownKeys、prototype、constructor、toStringTag 等反射面。
9. 用 `domtrace/` 确认目标链路实际读取的 DOM/BOM 环境值、方法调用、指纹面和对象外观。
10. 如果目标命中 WASM 或公开 binding，读取 `wasm/*.jsonl` 元数据和 dumped wasm 文件名；记录 sha256 / dumped wasm 文件 hash，只在外围确认 imports/exports/binding，不进入 VMP / opcode 插装。
11. 如果需要对照浏览器异常，读取 `exception/trace_exception_process_<pid>`；优先按 PID、URL/脚本、时间、`origin_call_id`、`jscall_parent_call_id` 或异常 message 定向过滤，不全量打开大文件。
12. 只有 cookie/storage/cache/profile 证据缺口明确时，定向读取 `profile/`；不要把 SQLite 或二进制 profile 文件当文本日志打开。
13. 盘点版本材料：目标 JS URL/hash、eval/new Function hash、Worker 脚本 URL/hash、WASM hash、server payload/blob/hash、ArrayBuffer/base64/hex/byte array hash、cookie/storage/init seed、目标集合和适用请求。
14. 将证据收敛成 `code.js` / `runtime/*.code.js` 的稳定入口和 `test.py` 的真实请求参数。

## 分区优先级

```text
请求链定位：index.jsonl -> http_packet -> jscall
参数/调用定位：jscall -> eval -> http_packet
状态绑定：cookie -> storage -> http_packet Set-Cookie/headers
环境真值：domtrace -> descriptor -> event
行为/验证码：event -> jscall callback -> http_packet challenge/check
WASM 外围：wasm metadata -> jscall公开调用 -> http_packet
异常对照：exception -> jscall error/exception -> 本地 Node 异常
浏览器持久态缺口：profile 定向读取
```

## jscall 重点字段

不同项目的 jsonl 字段可能不完全一致，读取时优先找这些语义：

- `schema_version` / `schemaVersion`：字段结构版本。
- `seq` / `pid` / `process_type`：进程序列和跨分区对齐键。
- `op` / `phase`：调用 enter/leave、get/set、异常阶段。
- `call_id` / `parent_call_id` / `depth`：调用树和父子关系。
- `function` / `name` / `callee`：函数名或方法名。
- `callee_name` / `callee_url` / `caller_url` / `script` / `url` / `source`：脚本来源、动态 JS 来源或 sourceURL。
- `stack` / `callStack`：调用栈，用来判断热路径和请求组装边界。
- `args` / `arguments`：入参，重点看 query、body、headers、cookie、storage 值、时间戳、随机数。
- `return` / `result`：返回值，重点看签名、fp、token、加密串、请求配置对象。
- `error` / `exception`：异常和缺环境点。
- `time` / `ts` / `timestamp`：调用顺序和请求前后边界。
- `async` / `promise` / `task`：异步链路、Promise、定时器、事件回调。

## 搜索关键词

先用任务目标字段，再用通用字段：

```text
目标参数名
目标请求 URL 或 path
functionId / appid / client / loginType
目标 header / cookie / body 字段
sign token h5st stk fp fingerprint eid x-api-eid-token
encrypt decrypt hash md5 sha aes rsa
XMLHttpRequest fetch send open request response
localStorage sessionStorage cookie
navigator screen document window canvas webgl performance
```

如果目标命中安全产品特征，先读 `references/products/index.md`，再只读对应产品文档。

## cookie 对照规则

遇到 cookie、token、eid、session、风控状态时必须查 `cookie/`：

- `cookieSetAttempts`：确认 JS 写入、raw 字符串、attributes、domain/path/expires/sameSite/secure。
- `cookieReads`：确认请求前 JS 读到了哪些 cookie，jar 顺序和同轮状态。
- `rejectedReason` / `validationError`：确认浏览器是否拒绝写入，避免本地照搬无效 cookie。
- `fromHttp` / `thirdParty`：区分 JS 写入、HTTP Set-Cookie、第三方上下文。
- `stack`：定位哪个脚本读写 cookie。

cookie 分区比 `storage/` 更适合判断 document.cookie 的读写顺序；HTTP Set-Cookie 仍回到 `http_packet` 对照。

## 定位参数生成链

按这个顺序判断目标参数在哪里产生：

1. 请求组装边界：`fetch`、`XMLHttpRequest.open/send`、统一 request 方法、axios/fetch wrapper。
2. 参数返回边界：某函数直接返回目标参数或包含目标参数的对象。
3. 状态预生成：目标参数提前写入 cookie/storage/cache，后续请求直接读取。
4. 二阶段链路：先请求算法、token、配置、动态 JS，再用响应值生成最终请求参数。
5. 环境指纹链路：读取 DOM/BOM 指纹面后生成 fp、token、eid、签名上下文。

每一条结论必须能落到具体证据：哪个 jsonl 文件、哪一条记录、哪个字段、请求前还是请求后。

## storage 对照规则

遇到 fp、token、cookie、eid、session、cache 等字段时必须查 storage：

- 是否由服务端响应写入。
- 是否由 JS 计算后写入。
- 是否请求前已存在，还是请求中途更新。
- 是否和 cookie 中同名字段、header 中字段、body/query 中字段一致。
- 是否需要在 `test.py` 中动态维护，不能写死。

如果 storage 值每次变化，先判断它是否参与签名、是否有缓存周期、是否和账号/cookie/设备指纹绑定。

## eval 对照规则

当目标 JS 来源为 eval、new Function、challenge 下发脚本、动态拼接脚本时：

- 先在 `jscall` 中确认 eval/new Function 的调用栈、入参和 sourceURL。
- 再在 `eval/` 中找到对应落盘 JS，固定当前可验证版本。
- 动态 JS 固定后只允许作为目标 JS 原逻辑使用，不允许把 eval hook 或浏览器侧观察框架写进最终 `code.js`。
- 如果动态 JS 每轮变化，记录版本、hash、来源请求和刷新条件。
- 单 trace 下不能根据当前 eval hash 推断跨版本稳定；存在动态载荷风险时，标记 `version_risk=candidate`，按需要进入 `single_trace_passed_quality_check` 或 `single_trace_failed_need_more_evidence`。

## event 对照规则

验证码、行为风控、延迟初始化和异步链路必须看 `event/`：

- `eventListenerAdds`：确认监听的事件类型、target、capture/passive/once、回调来源脚本。
- timeout / interval / promise / listener 回调：确认请求前后顺序和触发条件。
- `isTrusted`、synthetic、phase、bubbles、defaultPrevented：用于判断行为事件是否需要真实用户态或可模拟。
- 对滑块、点选、九宫格/多宫格、输入、滚动、点击链，必须把 event 证据和 jscall 回调、http_packet 校验请求对齐。

event 分区用于行为顺序和触发条件，不单独替代 DOM/BOM 真值。

## domtrace 对照规则

只有目标链路实际读取的环境项才补入 `code.js`。优先确认：

- `navigator`、`screen`、`location`、`history`、`performance`。
- `document` 查询、创建、事件、cookie、visibility、referrer。
- `canvas`、`canvas2d`、`webgl`、audio、font、plugin、mimeType。
- descriptor、prototype、constructor、`Object.prototype.toString`、`Function.prototype.toString`。
- getter/setter 行为、异常外观、枚举顺序、属性存在性。

没有 `domtrace` 或本地缺口观察证据时，不要凭旧项目经验批量补环境；Node 补环境看 `rtwatch` / Proxy / `rt_log`。

## descriptor 对照规则

当目标链路使用反射检测时，优先查 `descriptor/`：

- `descriptor_lookup`：确认属性是否存在、descriptorKind、hasValue/hasGet/hasSet、writable/enumerable/configurable。
- `own_keys` / `getOwnPropertyNames` / `Reflect.ownKeys`：确认 key 顺序、数量、是否含 symbol、是否截断。
- `target.class` / `targetInput` / `prop`：确认检测对象是实例、prototype 还是 constructor。
- `stack`：确认哪个脚本触发反射检测。

descriptor 分区是补 `Object.getOwnPropertyDescriptor`、`ownKeys`、prototype、constructor、`toStringTag` 时的优先证据，不再只依赖 domtrace 混合日志。

## wasm 对照规则

遇到 WebAssembly、WASM binding、二进制 challenge 或验证码 proof 时读取 `wasm/`：

- `trace_wasm_*.jsonl`：确认 compile/instantiate、api、phase、sourceKind、sha256、imports/exports、moduleId、instanceId。
- `wasm_*.wasm`：作为当前版本资产或 hash 对照，只有需要复现公开 binding 时才使用。
- `importsSample` / `exportsSample`：优先定位公开导出函数、外部 binding 和输入输出边界。
- 如果 WASM、二进制 challenge、ArrayBuffer、base64/hex blob 或 opcode-like 数据参与目标集合，记录为版本材料；无法确认是否为 VMP 字节流时，按多版本风险候选处理。

禁止：
- 不在 wasm 字节码、VM / VMP、opcode、handler、解释器分发层插桩。
- 不用改写 wasm 执行语义的结果作为参数真值。
- 不把 wasm tracer、opcode hook 或 handler hook 写进 `code.js`。

允许：
- 在 wasm 外围确认公开 API 入参、返回值、导出函数名和请求边界。
- 将 wasm 文件作为目标 JS 依赖资产加载，但补环境仍围绕外部 DOM/BOM、方法入参和请求边界。

## exception 对照规则

新版 RuyiTrace 会把浏览器侧异常落到：

```text
ruyitrace/exception/trace_exception_process_<pid>
```

这些文件通常无扩展名，但内容是 JSONL：
- 第一行 `type=trace_init`，包含 `pid`、`process_type`、`log=exception`、`schema_version`。
- 后续行 `type=exception`，常见字段包括 `phase`、`origin_call_id`、`jscall_parent_call_id`、`jscall_depth`、`value_type`、`object_class`、`is_error_object`、`error_type`、`native_exception_name`、`native_exception_message`、`file_name`、`line`、`column`、`stack`。

读取原则：
- 先按目标页面 PID 或 `index.jsonl` / HTTP 包中的 pid 缩小文件。
- 大文件不得全量读取；用目标 URL、脚本名、message、`origin_call_id`、`jscall_parent_call_id`、时间窗口或 `native_exception_name` 过滤。
- 浏览器有相同异常且本地也相同，优先视为浏览器真实行为，不盲目修。
- 浏览器没有异常但本地有异常，优先按缺环境、descriptor、prototype、getter、异常类型或宿主对象差异排查。
- 浏览器异常与本地异常不同，优先排查分支进入条件、DOMException/Error 外观、stack、时序和 native `toString` 外观。

`exception/` 只能作为异常真值和差异归类证据；环境值仍回到 `domtrace/descriptor/event/cookie/storage` 确认。

## profile 对照规则

`profile/` 是浏览器 profile 辅助资产，不是默认 trace 主线：

- 只在 cookie/storage/cache/profile 证据缺口明确时读取。
- SQLite、WAL、缓存和二进制文件必须用对应解析器或定向工具读取，不能 `cat` / `Get-Content` 全量当文本打开。
- 读取前先确认文件类型和目标字段，例如 cookie DB、local storage、IndexedDB、cache、extension config。
- profile 证据只能补充持久态来源，不能替代 `jscall` 请求链定位或 `domtrace/descriptor/event` 环境真值。

## http_packet 对照规则

历史包用于确定真实请求边界：

- 目标 URL、method、query/body 字段是否和本地请求一致。
- headers/cookies 是否有服务端下发字段、浏览器自动字段或账号态字段。
- `t`、时间戳、随机数、fp、token、h5st、sign 等是否动态。
- 响应状态、业务 code、风控 code、空 body、重定向、set-cookie 是否变化。
- 是否有前置请求，例如 request_algo、动态 JS、配置接口、验证码、指纹上传。
- 是否下发动态执行载荷或不透明 payload，例如 challenge JS、Worker 脚本、WASM、二进制 body、base64/hex blob、ArrayBuffer、opcode-like 数据、init seed；这些材料必须记录 hash、来源请求、目标集合和适用请求。

`http_packet` 是请求面基线证据；实时验证由 `test.py` 完成。

如果存在 `index.jsonl`，先用它筛选目标包，再打开对应 `file`。不要在几百上千个 `*.http_packet.json` 中盲读全量包。

## 与 test.py 的配合

`jscall` 负责解释参数怎么生成，`http_packet` 负责确认浏览器请求面基线，`test.py` 负责发起当前真实请求验证：

- 用 `jscall` 找参数生成链和依赖。
- 用 `index.jsonl` / `http_packet` 找请求 URL、Method、Header、Cookie、Body、Query、响应体、Set-Cookie、前置请求和会话态。
- 用 `cookie/storage/event/descriptor/eval/wasm` 补齐状态、行为、反射、动态脚本和 WASM 外围证据。
- 用 `test.py` 发起最终请求，并把实际请求面与 `http_packet` 基线做字段对照。
- 不把临时 trace 或 Hook 当交付物。

`test.py` 中的 diff 只允许用于请求面差异对照，包括 URL、Method、Query、Body、Header、Cookie、前置请求、重定向、preflight、会话状态和响应摘要。不得使用参数字节集 diff、签名字节 diff、密文字节 diff、算法输入输出 diff、普通样本 diff、字段扰动差分、bit/byte 翻转对照或批量样本差分来反推签名、加密、编码或混淆算法。

## 禁止事项

- 除非用户在当前任务中明确要求，否则不使用浏览器/页面自动化程序接管页面、模拟用户行为、生成参数或补齐证据；即使用户明确要求使用，也不能把自动化跑出的参数、状态或事件轨迹当作本地最终实现。
- 不在 VMP / opcode handler / VM 解释器内部插桩或补环境。
- 不做请求面以外的 diff；禁止参数字节集、签名、密文、算法输入输出、字段扰动、bit/byte 翻转、批量样本或普通样本层面的差分逆向。
- 不把 jscall 记录当成万能真值；环境真实值仍要回到匹配目标的 `ruyitrace/domtrace`，并结合本地 `rtwatch` / Proxy / `rt_log` 缺口观察对照。
- 不因为某条历史 trace 能过，就把时间戳、fp、token、cookie、算法响应写死。
- 不因为单 trace 已通过，就声明 VMP / 动态载荷跨版本稳定；单 trace 只能证明当前版本，跨版本稳定必须靠多 trace 对照。
- 不在没有证据的情况下批量补 canvas、webgl、audio、font、plugin、mimeType。

## 最小交付判断

完成时应能说明：

- 目标请求由哪条 `http_packet` 对齐。
- 目标参数由哪组 `jscall` 记录定位。
- 依赖的 fp、token、cookie、storage 来自哪里，哪些需要动态生成或刷新，证据来自 `cookie/`、`storage/` 或 HTTP Set-Cookie 的哪条记录。
- 依赖的 DOM/BOM 环境项有哪些，证据来自哪组 `domtrace`、`descriptor`、`event` 或 `rt_log`。
- 动态 JS 是否来自 `eval/`，WASM 是否来自 `wasm/`，profile 是否只做了定向辅助读取。
- VMP / 动态载荷覆盖状态是什么：`single_trace_current_version_passed`、`multi_trace_stable`、`multi_trace_divergent` 或 `insufficient_trace_coverage`。
- 是否读取过 `exception/`，浏览器异常与本地 Node 异常是否一致。
- `code.js` 提供哪个稳定入口，`test.py` 如何调用并完成真实请求验证。
