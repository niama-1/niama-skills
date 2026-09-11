## 工具定位

### jscall

`jscall` 是浏览器侧主分析工具，用来定位：
- 真实请求链和请求发起点
- 目标 JS 来源
- 加密参数生成位置
- 函数入参、返回值、闭包变量和 `this`
- XHR/fetch、Cookie、Storage、Header、Body 变化
- 调用栈、入参、返回值、异常、脚本来源和请求边界

`jscall` 负责离线定位和链路还原；不作为默认环境真值来源。补环境值默认回到匹配目标的 `ruyitrace/` 中确认。

### ruyitrace

`ruyitrace/` 是默认环境真值与行为证据层，用来保存：
- `index.jsonl` HTTP 包索引和根目录 `*.http_packet.json`
- `jscall/` 关键调用链、脚本来源、入参、返回值、异常、请求边界
- `cookie/` document.cookie 读写、attributes、rejectedReason、调用栈
- `storage/` localStorage/sessionStorage、fp、token、cache 读写
- `domtrace/` DOM/BOM 真实值、方法调用、指纹采集点
- `descriptor/` descriptor、ownKeys、prototype、constructor、toStringTag 等反射面
- `event/` 事件顺序、listener、timeout、dispatch、验证码 / 行为链回调
- `eval/` 动态 JS、eval/new Function/challenge 脚本落盘源码
- `wasm/` WASM compile/instantiate 外围元数据、imports/exports、dumped wasm 文件
- `exception/` 浏览器异常、DOMException/Error 外观、message、file/line/column、stack
- `profile/` 浏览器 profile 辅助资产

使用 `ruyitrace/` 前必须判断是否匹配当前目标请求、账号状态、页面状态和触发步骤。只提取目标链路实际相关证据，不全量搬运。

`exception/` 文件通常无扩展名但内容是 JSONL，按 PID、message、脚本、时间窗口或 `jscall_parent_call_id` 定向过滤，不全量打开大文件。`profile/` 中可能包含 SQLite、WAL、缓存和二进制文件，只能按明确缺口定向读取，不能当文本 trace 全量打开。`wasm/` 只允许用于外围 imports/exports/binding 和资源版本确认，不允许对 WASM / VMP / opcode / handler 做插装或语义改写。

### rtproxy.js

`assets/rtproxy.js` 是本 skill 随包携带的 Node 补环境 rtproxy 源文件，也是默认补环境观察资产。使用时必须读取或复制这个源文件，不允许凭记忆重写简化版。它包含：
- `rt_loginfo` / `rt_log`：可开关日志
- `proxylog.txt`：单 JS/单 runtime 入口的固定代理事件日志，每次 Node 启动覆盖上一份；多个入口只有在代理已有机制支持时才允许使用不同固定 `.txt` 文件名
- `rtwatch(obj, name)`：DOM/BOM Proxy 观察器
- `fun_to_native(fn)`：把函数 `toString()` 标记成 native 外观
- `Function.prototype.toString` 保护：通过内部 `Symbol('ToString')` 保存 native-like 字符串，并保护 `Function.prototype.toString` 自身外观

使用规则：
- `node_mode` 正式补环境前必须确认 `assets/rtproxy.js` 源文件存在
- `node_mode` 需要把 proxy 骨架放入目标项目时，必须从 `assets/rtproxy.js` 原样复制完整源文件，并保持函数名、`toString` 保护、固定宿主对象声明和 `window = rtwatch(global,'window')` 分界；不得只复制片段
- 每次运行单个 `node code.js` 或单个 `node runtime/*.code.js` 必须覆盖写入当前入口的固定日志；单入口默认是 `proxylog.txt`，多个入口只有在代理已有机制支持时才允许使用不同固定 `.txt` 文件名；不得默认创建时间戳日志、轮次目录或多份历史日志
- `proxylog.txt` 必须记录每一次 `rtwatch` / Proxy trap / `rt_log` 事件，不得抽样、过滤、去重或静默丢弃；格式以项目本地 `assets/rtproxy.js` 的实际文本输出为准
- 默认始终使用项目当前工作目录下的 `proxylog.txt`。只有多个 JS/runtime 入口确实需要分别补环境和分析日志，且代理已有机制支持时，才允许指定不同固定 `.txt` 文件名；不得修改代理增加换名功能，同一入口每次运行仍覆盖上一份
- `node_mode` 可以先用 `window = rtwatch(global, 'window')` 作为总入口观察
- `node_mode` 中 `document`、`location`、`navigator`、`screen`、`history`、`localStorage`、`sessionStorage`、`performance` 等对象必须按目标链路继续套 `rtwatch`
- `node_mode` 中对象属性返回对象时，也必须继续套 `rtwatch`，例如 `navigator.connection`、`document.head`、`document.body`、`canvas.getContext('2d')`
- 不允许一次性大批量补环境；必须先补基础 BOM/DOM，再补方法入参与返回对象，最后才按证据补 `canvas`、`webgl` 等指纹面
- 方法入参必须在函数体内用 `rt_log` 打印，例如 `rt_log('document.createElement', ele)`
- `node_mode` 对补出的每一个方法、native-like 宿主方法、构造器和高风险函数，必须使用 `fun_to_native(fn)` 或等价方式保护 native 外观
- `rt_loginfo` 调试阶段可打开；收敛和交付时关闭高噪声日志

格式要求：
- `node_mode` 的 `code.js` 补环境底座必须沿用 `assets/rtproxy.js` 的组织格式
- 顺序固定为：`rt_loginfo/rt_log` → `proxylog.txt` 初始化 → `defaultFilterProps/existsobj` → `rtwatch` → `Function.prototype.toString` 保护 / `fun_to_native` → `window = rtwatch(global,'window')` → 宿主对象补环境 → `// 目标js`
- 目标 JS 只能放在 `// 目标js` 之后，不能把补环境逻辑插入目标 JS 或 VMP 内部
- `proxylog.txt` 只用于发现本地缺口和复盘当前轮执行，不是真值来源；环境真实值仍必须回到匹配当前目标的 `ruyitrace/` 查证

### 请求链证据


`http_packet` 可用于确认：
- URL、Method、Query、Body
- Headers、Cookie、Set-Cookie
- 前置请求、预热请求、重定向、preflight
- 会话态变化
- 浏览器请求与本地请求的差异

请求面 diff 只允许基于 `test.py` 实际请求与抓包 / `ruyitrace/http_packet` 目标请求做字段对照。不得使用任何工具做参数字节集 diff、签名字节 diff、密文字节 diff、算法输入输出 diff、批量样本差分、字段扰动差分、bit/byte 翻转对照或任何用于反推签名 / 加密 / 编码 / 混淆算法的差分分析。

### code.js / test.py

`code.js`：
- 放补环境实现、目标 JS 逻辑和稳定参数入口
- 必须沉淀 Node 下 `rtwatch` 风格 DOM/BOM 补环境结构
- 不保留与目标链路无关的大量 Hook、VM tracer、解释器 proxy 或全局调试框架
- 不允许在 VMP 上进行插装补环境，不允许下探针，不允许把 VMP probe / tracer / handler hook 写入本地
- 每个补出的函数方法必须做 native `toString` 保护
- 每轮只补一批明确缺口；基础 BOM/DOM 未稳定前，不得批量补 canvas/WebGL/audio/font/plugin/mimeType 等指纹面
- 只有在目标 JS、完整入参、生成方法、`jscall` 定位证据和匹配 `ruyitrace/` 真值都已确认后，才允许进入正式补环境改造；Node 下的 Proxy / `rtwatch` / `rt_log` 是进入后的首轮观察动作，不是进入前置条件

`test.py`：
- 负责真实请求、会话、Header、Cookie、代理和接口验证
- 通过 Node 子进程、固定 CLI 输出或等价 Node 桥接方式调用 `code.js`
- 参数正确但请求失败时，先排查请求链、会话态、IP/代理和风控状态，不盲目继续补 DOM/BOM
