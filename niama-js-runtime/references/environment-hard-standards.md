## 补环境硬性标准

本文件是阶段 4-6 的硬约束和验收标准，不是每轮补环境循环的入口文档。普通迭代时优先读取 `target.lock`、当前 `code.js` / `runtime/*.code.js`、当前入口运行结果、本轮 `proxylog.txt` 和必要的 `ruyitrace` 分区；只有以下情况才读取本文件：

- 首次正式进入阶段 4，确认补环境前置门槛和代码结构红线；
- 准备结构性修改宿主大区、对象唯一壳、原型链、descriptor 或 native 外观；
- 命中高风险环境语义，例如 `document.all`、iframe/window 身份关系、iframe/load 或 Worker 调度时序、主线程/iframe/Worker API 边界、Worker 存储泄漏、Worker / MessagePort、CSS 计算、DOM 结构变更、URL / `a` 标签解析、能力探测、事件时序、鼠标交互状态、canvas/WebGL、WASM/VMP 边界、Node 特征泄漏或全局 Proxy 外壳；命中特殊检测时再读取 `references/special-environment-detection-checklist.md`。
- 收敛验收或交付前检查是否存在壳子式补环境、无 trace 依据补入、参数只出值但不可用等问题。

不要因为开始新一轮、补一个普通字段、读取一次 `proxylog.txt` 或上下文恢复，就默认重读本文件。

补环境的第一阶段目标是优先生成当前目标参数、验证码凭证、reload 请求面或业务动作所需材料，不是补出完整浏览器。目标参数是否能按当前输入实时产出是推进优先级最高的工程目标；凡是目标集合相关链路实际触达且阻塞出值或验证的检测点，才按 `jscall` 定位证据和 `ruyitrace/` 真值证据补到可观察语义一致。

阶段 4 第一次修改 `code.js` / `runtime/*.code.js` 前，必须按 `references/environment-detection-signal-index.md` 完成目标集合相关 trace 的高风险检测信号扫描。命中高风险信号时，不得降级为普通属性缺口处理；如果不能说明检测语义、trace 证据、涉及对象、跨对象一致性、状态 / 事件 / 异步时序和补完验证，只能记录缺口并暂停该项，不得补入交付版代码。

具体检测维度按 `references/environment-detection-checklist.md` 做最小验收。该清单只用于提醒检测面，不允许作为批量补环境清单、自动补环境工具或复制外部工具箱代码的依据。

目标链路出现 WebAssembly / `.wasm` / wasm-bindgen / Emscripten 时，按 `references/wasm-handling-checklist.md` 先归类加载方式、胶水层、imports/exports、memory/table、业务入口和版本材料；补环境优先落在 JS 胶水层和 importObject 需要的宿主能力上，不改 wasm 二进制，不在 wasm 内部下探针。

命中原型链、constructor、descriptor、`instanceof` 或相关比较时，必须按 `references/prototype-chain-template.md` 对当前命中的最小关系进行验收。只写 `document.__proto__ = HTMLDocument.prototype`、只补 `constructor`、只补 `Symbol.toStringTag` 或只让 `instanceof` 过关，都不算完成；未命中这些检测时，不创建默认原型链。

进入阶段 4、开始正式补环境前必须同时具备：
- 目标参数对应的目标 JS
- 完整入参
- 生成方法
- `jscall` 定位证据
- 匹配当前目标的 `ruyitrace/` 真实证据

缺任何一项都不得进入正式补环境流程或改造 `code.js`。这里的门槛用于确认任务具备正式补环境的基础材料，不要求在进入前先列出所有本地缺口。

阶段 4 开始后的首轮动作，是用 Node 的 `rtwatch` / Proxy / `rt_log` 运行目标 JS，观察本地实际触达的对象、属性、方法、返回对象和第一个阻塞点。首轮观察可以先于具体环境项的 `ruyitrace` 定位，但观察结果只用于发现缺口，不能直接作为补环境真值。

补环境迭代固定按以下顺序执行：

```text
rtwatch / proxylog.txt 观察本地缺口
→ 找到当前阻塞点
→ 回到匹配当前目标的 ruyitrace 查真实值、真实外观和检测语义
→ 判断该缺口是否属于目标参数链路
→ 按检测语义决定补值、方法、返回对象、descriptor、原型、外观、身份关系或时序
→ 写入 code.js / runtime
→ 重新运行验证
```

每个具体环境项在写入或固化到 `code.js` / `runtime/*.code.js` 前，必须由匹配当前目标、位于目标参数相关链路上的 `ruyitrace/` 提供真值、真实外观或检测语义证据。`rtwatch`、`proxylog.txt`、`jscall` 和本地异常只能用于发现缺口、定位调用链和补充判断，不能单独替代 `ruyitrace/` 真值与检测语义。

目标集合边界：
- 目标集合可以是一个或多个参数、token、签名片段、加密请求片段、验证码凭证、Worker 返回值或业务动作状态
- 环境项必须能证明与目标集合的生成、校验、注入、请求组装或最终验证直接相关
- 每个环境项必须标记归属：属于某个目标、多个目标共享，还是待确认
- 待确认环境项不得直接写入交付版 `code.js` / `runtime/*.code.js`
- 目标集合外不扩张；不得为了“更像浏览器”补无关对象、无关指纹面、无关 DOM 内容、无关事件状态、无关接口或其它参数族

宿主对象源码分区硬约束：
- `code.js` / `runtime/*.code.js` 必须在 `// 目标js` 前建立固定宿主对象大区，至少包含 `window 区`、`document 区`、`location 区`、`navigator 区`、`screen 区`、`storage 区`；`performance`、`history` 和其它全局能力统一归入 `window 区`，不再设置独立 `performance`、`history` 或全局绑定区。
- 每个大区必须有 1-3 行备注，写明本区放什么、禁止放什么、证据来源；没有备注的区不能继续写补环境。
- 原型链、`constructor` 回指、`Symbol.toStringTag`、native-like `toString` 必须在命中的所属宿主对象区紧邻收口，遵守“只定义一次，只填充不换壳”。
- 原型链收口只处理当前 trace 命中的关系；如果 trace 同时涉及构造器回指、父级 prototype、实例 `Object.getPrototypeOf(instance)`、`Symbol.toStringTag` 或 native-like `toString`，再联动处理对应关系。不得散落到 helper 区或独立全局绑定区。
- 同一个宿主对象只能有一个最终对象引用；允许在对象区使用 `document = rtwatch({}, "document")` 作为唯一壳，并把真实字段直接填入这对大括号，禁止后续重建、跨区覆盖或再次赋值换壳。
- 对象区只允许沿用代理模板创建的唯一对象壳；基础 DOM/BOM 的真实字段、方法和状态必须直接填入 `rtwatch({}, name)` 的这对大括号内部。descriptor、prototype 和 `fun_to_native` 等收口动作只能在同一区紧邻处理，不允许重新创建、重新赋值或换壳。
- `window`、`document`、`location`、`navigator`、`screen`、`storage` 必须保持所属大区，不能合并到“基础环境”“DOM/BOM”或 `installBaseEnvironment` 的连续赋值段里；`performance`、`history` 归入 `window 区`，不单独创建分区。
- `location` 只能在 `location 区` 定义和修正，`screen` 只能在 `screen 区` 定义和修正，`document` 节点/集合/方法只能在 `document 区` 定义和修正，`storage` 只能在 `storage 区` 定义和修正，`window` 自身字段/窗口方法/窗口事件以及 `performance`、`history` 只能在 `window 区` 定义和修正。
- 代理固定声明完成后，后续补环境不得再使用 `global` 或 `globalThis` 作为落位对象。所有窗口属性、方法、子对象和全局构造器必须直接写入 `window 区`；`self/top/parent/frames` 只有 trace 命中时才作为 `window` 的引用关系就近处理。
- helper、构造器工厂、复用函数和内部状态容器必须放共享 helper 区；共享 helper 区不得创建或写死具体宿主对象实例值。
- 跨区引用只能引用已定义对象，不能跨区定义真值；确需建立对象之间的引用关系时，必须拆清楚对象定义和引用动作，并在本轮检测语义分析或对应代码区头备注中说明跨区关系。
- 一轮可以补多个环境项，也可以跨多个宿主大区；前提是这些修改属于同一个阻塞点、同一条检测链、同一个方法返回对象链路，或同一个目标参数产出链路。禁止的是无关大批量补环境、全量浏览器枚举和顺手补无关对象。

环境项完成标准不是“目标对象存在”，也不是“本地日志出现过该字段”。当 `ruyitrace/` 显示某个返回对象进入目标链路后，必须继续追踪该对象后续被读取或调用的属性、方法、descriptor、原型链、异常外观、父子节点关系、别名读取点和请求边界影响，并检查 `code.js` / `runtime/*.code.js` 中是否有对应实现，且语义与 trace 一致。`rt_log`、结构化导出或请求边界捕获都只是覆盖验证和排错材料；最终验收看补环境代码是否实现了 trace 中的下游读取语义。

禁止壳子式补环境：
- 不得只补 constructor、prototype、descriptor、`Symbol.toStringTag`、native-like `toString` 等外观后就视为完成
- 速度优化不能变成只补外观；只补外观、空对象、空方法、假返回对象来追求跑通，一律视为未完成
- 但上述检查不能被扩大成“先补完整浏览器”；出值前只处理当前阻塞目标产出边界的最小对象集合，出值后再按失败证据提升环境质量
- 对目标链路触达的对象，只检查 `ruyitrace` 实际命中的检测语义；命中什么就补什么。未被当前链路检测到的外观、内容、行为、状态、身份关系或时序维度，只记录为待确认，不要求提前补齐。
- 内容包括目标 JS 实际读取的字段值、索引项、数组/类数组内容、集合长度、URL、cookie/storage 状态和子对象中的实际值
- 行为包括方法入参、返回对象、getter/setter、副作用、异常类型、异常 message 和触发条件
- 身份关系包括多次读取是否返回同一对象、父子/owner/target/currentTarget/source/ports 等引用关系
- 时序语义包括写入后再读取、事件 listener 顺序、timeout/microtask 顺序、Worker message 顺序和异步回调顺序
- 顶层对象、属性子对象、方法返回对象、DOM 节点、集合对象、事件对象、Promise/回调入参对象、异常对象、Worker / SharedWorker / MessageEvent / MessagePort / Worker 内部 `self` 都适用该标准

VMP / 动态载荷覆盖标准：
- AI 可以通过单 trace 和代码形态判断 `suspected_vmp` / `confirmed_vmp`，但不能通过单 trace 排除多版本字节流或动态载荷风险
- 目标集合相关链路经过 VMP、VM-like interpreter、动态 opcode/payload、server 下发不透明 blob、base64/hex/ArrayBuffer/字节数组、eval/new Function、Worker/WASM 内执行载荷时，必须记录版本材料并标记 `version_risk`
- 单 trace 已通过只代表当前版本可用；存在多版本风险候选时，不得把环境质量标记为跨版本稳定
- 单 trace 未通过且当前 trace 无法解释失败原因时，不得继续盲补无证据环境，必须标记 `single_trace_failed_need_more_evidence`
- 只有多 trace 对照证明目标链路读取面、入口入参、事件/Worker 链、storage/cookie 状态、目标输出和最终请求验证一致，才可标记 `multi_trace_stable`

批次硬约束：
- 不允许一次性大批量补环境，也不允许把浏览器全量枚举结果一次性照搬进 `code.js`。
- 为提高速度，每轮只处理当前异常、当前分支、当前检测链或当前请求边界直接阻塞的最小对象集合；同一阻塞点关联的字段、方法、返回对象、descriptor、prototype、native 外观、身份关系或状态可以作为一批处理。
- 出值不等于补环境合格。当前目标值、reload 请求面或目标请求片段能实时输出后，必须先检查参数是否可用、格式是否正确、结构是否合理、长度与 `ruyitrace` / 抓包参考样本是否差距过大，以及是否已经越过当前检测链。
- 只有本地实时输出达到可用标准后，才进入请求边界或 `test.py` 验证；如果只是“有输出但长度、格式或结构明显异常”，继续按检测语义和差异证据补环境或定位生成链问题。不得继续补无关浏览器对象来追求“更像浏览器”。
- 每轮只补一批由本地缺口观察和 `ruyitrace/` 共同证明的明确缺口：Node 补环境看 `rtwatch` / Proxy / `rt_log`
- 当有新的环境需要补时，必须先在目标链路相关的 `ruyitrace/` 中找到真值、descriptor、prototype、异常外观、事件顺序或行为证据；找不到时记录缺口并暂停补该项，不得凭猜测、旧项目或单独 jscall 现象补入
- 常见推进可以先从目标链路触达的基础 BOM/DOM 对象和基础属性开始，再处理方法入参、返回对象、descriptor、prototype、constructor、native `toString` 外观，最后按证据处理 `canvas`、`canvas2d`、`webgl`、audio、font、plugin、mimeType 等指纹面。
- 上述只是常见推进建议，不是固定批次或强制顺序；实际顺序必须由 `ruyitrace` 还原出的检测语义决定。目标一开始就检测 descriptor、native 外观、iframe 身份、Worker 或 canvas 时，可以直接按对应检测链处理。
- 指纹面仍不得提前批量补；必须由当前目标链路的本地观察和 `ruyitrace` 共同证明触达，并且属于当前阻塞点或目标产出链路。
- 如果一轮修改跨越基础 BOM/DOM、canvas/WebGL 或其它指纹面，只要属于同一检测链或同一目标产出链路可以一起处理；不得把无关对象拼成大补丁。

必须关注：
- 宿主对象外观与身份：`toString` / native code 外观、二阶 `toString` 检测、constructor、原型链、descriptor、属性归属、自身属性 / 原型属性、`instanceof`、是否允许 `new`
- 宿主对象内容与状态：目标 JS 读取到的字段值、数组/类数组项、集合长度、storage/cookie 同轮状态、URL/location 内容、`navigator` / `screen` / `performance` 子对象中的具体值
- 宿主对象行为与副作用：方法入参、返回对象、getter/setter、写入后再读取、异常触发条件、返回对象继续深入读取的语义
- 子对象和返回对象：`navigator.connection`、`navigator.userAgentData`、`performance.memory`、`document.createElement(...)`、`querySelector(...)`、`canvas.getContext(...)`、`permissions.query(...)` 等不得只返回空对象
- `toString` 二阶检测：目标函数或宿主方法要检查 `target.toString()`、`Function.prototype.toString.call(target)`、`target.toString.toString()`，以及必要时的 `Function.prototype.toString.toString()`
- 反射与检测接口：目标 JS 若直接调用 `Object.getOwnPropertyDescriptor`、`Object.getPrototypeOf`、`Reflect.ownKeys`、`typeof`、`in`、`hasOwnProperty`、`Object.prototype.toString.call(x)` 等，只能按证据补目标对象本身的 descriptor、prototype 和枚举结果；不得 patch 全局 `Object` / `Reflect`，不得靠 Proxy 重 trap 兜底
- 异常与堆栈外观：`Error` / `TypeError` 的 `name`、`message`、`stack` 格式、调用栈层级、非法调用报错、是否泄漏 Node 路径或 Node 内部栈帧
- Node 特征泄漏：目标逻辑不应直接探测到不该存在的 `process`、`Buffer`、`global`、`module`、`require` 等 Node 特征
- 事件链路：目标参数相关事件必须按证据处理事件类型、顺序、时间戳、坐标/按键/触点字段、`target/currentTarget`、listener 回调、回调内状态写入和最终进入目标集合的位置；不得只构造 `{ type: 'click' }` 这类空壳事件
- Worker 与调度通信：按证据处理 `Promise`、`queueMicrotask`、`MutationObserver`、`setTimeout` / `setInterval`、事件触发顺序、`postMessage`、`Worker` / `SharedWorker`、`MessageChannel` / `MessagePort`、`MessageEvent.data/origin/source/ports`、structured clone、transferable 对象和异步回调顺序

关键检测点优先级：
- `document.all`、`iframe`/`window` 关系、`Worker`/`SharedWorker`/`MessageChannel` 通信、CSS 计算、Canvas/WebGL 和事件异步时序属于高优先级检测点，`ruyitrace/domtrace` 命中时必须读取 `references/special-environment-detection-checklist.md`，再按专项处理
- 命中后先写专项 checklist，再补最小语义，不得把它们当普通字段顺手补入
- `MessagePort`、`Worker`、iframe `postMessage` 只能按证据建立最小通信链；禁止手写猜测式消息队列、`localDeliver`、同步假回调、伪 `source` 或伪 `ports`
- 消息链只以目标产出边界为目标：能推动当前 runtime 走到目标值、reload 请求面或请求边界即可；不得先实现完整浏览器消息系统
- `document.all` 优先走 undetectable 特殊路径，优先使用 V8 native/Node 侧 undetectable 底座；Node 层不要求完美浏览器实现，但必须按目标实际检测点尽量还原并记录覆盖范围
- `document.all` 不能默认补成 `{}`、`undefined` 或普通函数；`iframe` 不能默认补成空对象；`Worker` 通信不能默认补成同步假回调
- 原因：`document.all` 依赖 `[[IsHTMLDDA]]` 特殊语义，例如 `typeof document.all === "undefined"`、`Boolean(document.all) === false`、`document.all == null`，普通 JS 无法完整模拟
- Node/V8 路线：可用 `v8.setFlagsFromString("--allow-natives-syntax")` 后通过 `vm.runInThisContext("%GetUndetectable()")` 获取 undetectable 底座，再关闭 natives syntax；该对象只作为 `document.all` 底座
- `length`、索引、调用、`item()`、`namedItem()`、id/name 映射按当前 document 状态和 trace 证据逐项补；如果当前 Node/V8 不支持 undetectable，必须标记为非完整兼容层并说明已覆盖/未覆盖的检测点
- 涉及 iframe/window 链路时，必须区分 top window、parent window、frame window、frame document、iframe element，并按 `ruyitrace/domtrace` 真值补 `contentWindow`、`contentDocument`、`frameElement`、`parent`、`top`、`self`、`window` 的身份关系和 SameObject 行为
- 命中这些点时，直接回到当前目标匹配的 `ruyitrace/domtrace/jscall` 证据，确认真实检测语义后再决定是否进入正式补环境
- 该知识库不得作为环境真实值来源；真实值、descriptor、异常外观、事件顺序和请求边界仍必须来自当前目标匹配证据

异常对照判定：
- 如果浏览器中也出现相同异常、相同位置或相同分支结果，优先视为目标逻辑的正常浏览器行为，不要把它当成缺环境盲目修
- 如果本地异常在浏览器中没有出现，或异常类型、位置、分支结果不一致，优先按缺失环境、descriptor、prototype、getter 或宿主对象差异排查
- 只有确认浏览器与本地异常不一致时，才把该异常升级为需要补环境的问题

补环境顺序：
- 不采用固定的全局修复顺序；先根据 `ruyitrace` 还原出的检测语义确定当前补法。
- 如果先命中直接属性读取，就先补被读取的值或 getter；如果先命中方法调用，就先补方法入参、返回对象和副作用；如果先命中 descriptor、原型链、`toString`、身份关系或事件时序，就先处理对应语义。
- 同一检测链需要联动多个语义时，可以在同一批中一起补，例如方法、返回对象、descriptor、prototype 和 native 外观。
- 每次补完后重新运行目标 JS，确认当前检测点是否通过、目标链路是否继续推进，以及参数是否达到可用标准；没有命中的语义维度只保留为待确认，不得为了“完整”提前扩张。

`node_mode` 的 `rtwatch` 硬性要求：
- `rtwatch` 只用于基础 BOM/DOM 宿主对象及其直接返回对象的轻量观察，默认只代理已确认命中的基础对象，不扩散到无关对象族
- `window`、`document`、`location`、`navigator`、`screen`、`history`、`localStorage`、`sessionStorage`、`performance` 等基础宿主对象可以套 `rtwatch`，但不得把 Proxy 变成全局反射层
- 任何方法入参必须用 `rt_log` 显式打印，Proxy 不承担方法入参日志职责
- `rtwatch` 默认且交付版只保留 `get`、`set`、`has`、`ownKeys` 这类基础观察面；不得在 `assets/rtproxy.js` 或交付版 `code.js` 中沉淀 `getOwnPropertyDescriptor`、`getPrototypeOf`、`defineProperty`、`setPrototypeOf`、`apply`、`construct` 等重反射 trap
- `rtwatch` 不得递归包装返回值、普通子对象、业务对象或目标 JS 内部对象；方法返回对象只有在属于基础 DOM/BOM 且有目标链路证据时，才允许在返回点显式包装
- 宿主对象必须沿用代理模板的创建形式，例如 `window = rtwatch(global, "window")`、`document = rtwatch({}, "document")`、`location = rtwatch({}, "location")`、`navigator = rtwatch({}, "navigator")`、`screen = rtwatch({}, "screen")`、`localStorage = rtwatch({}, "localStorage")`、`sessionStorage = rtwatch({}, "sessionStorage")`。正式补环境时，把真实字段和方法直接写进对应对象的这对大括号；不得修改代理文件、重新创建宿主对象或换壳。
- `assets/rtproxy.js` 及其项目副本是只读代理资产；不得为了降低日志噪声修改 Proxy trap、target/receiver、返回值包装、缓存、路径、事件顺序、日志 schema、序列化或异常处理
- `rt_loginfo` 调试阶段可以打开，收敛和交付时可以关闭控制台回显；这不能改变代理行为或原始事件
- 每次单 JS/单 runtime 运行必须覆盖生成当前入口的固定 `.txt` 日志，默认是 `proxylog.txt`，并完整记录 `rtwatch` 的 `get/set/has/ownKeys` 与显式 `rt_log` 事件；写入前不得抽样、过滤、去重或静默丢弃
- 日志写入后允许用独立脚本生成过滤、聚合或去重后的分析视图；分析视图不得回写、覆盖或替代原始 `proxylog.txt`
- 默认 `proxylog.txt`，以及多个入口经已有配置区分出的其它固定 `.txt` 日志，格式都以项目本地 `assets/rtproxy.js` 的实际文本输出为准；不得为了改文件名、追求 JSON / JSONL / `seq` 字段或降噪而擅自改写代理形态
- `proxylog.txt` 只用于缺口观察和复盘，不得替代 `ruyitrace/` 真值证据

执行模型硬性要求：
- Proxy 只能套明确宿主对象或有证据的返回对象，不得作为全局 VM 外壳包裹目标上下文、Node global、定时器、Promise、module、require 或目标 JS 内部对象
- `setTimeout`、`setInterval`、Promise/microtask、script append/load、`document.currentScript`、iframe load 和 Worker message 的触发时机必须按目标证据最小复现；不得因为本地缺口而提前执行目标脚本
- 不得用无规律随机等待代替浏览器任务边界；iframe 创建、Window/Document 初始化、脚本执行、文档状态变化、`load`、Worker 启动和 message 必须按 trace 证明的相对顺序异步调度；确需时间差时只能使用有界、可复现的调度
- 主线程、iframe 和 Worker 必须保持真实的全局对象边界。Worker 默认不暴露 `window`、`document`、`localStorage`、`sessionStorage`；若 Worker 能访问页面 Web Storage，先标记为环境边界错误，并排查错误 shim、主线程对象泄漏和 Node 特征泄漏
- 主线程和 Worker 可以共享业务算法与输入输出约定，但不得因此共享主线程宿主对象、页面存储或 Node 全局对象；iframe 需要按 trace 建立独立 Window/Document/realm 身份
- 如果本地失败来自执行模型错误，例如全局定时器解析异常、目标脚本过早执行、`currentScript` 状态错误或 VM context 被 Proxy 污染，必须回退执行模型，不得继续补字段掩盖问题

`toString` 硬性要求：
- `Function.prototype.toString` 保护和 `fun_to_native(fn)` 底座只使用 `assets/rtproxy.js` 模板提供的实现；不得在项目代码里另写第二套 toString 保护。
- 每个补出来的方法都必须做 `toString` 保护，包括 `document.createElement`、`querySelector`、`appendChild`、`canvas.getContext`、`localStorage.getItem`、`setItem`、事件方法、storage 方法、crypto 方法等
- 方法在哪个大区定义，`fun_to_native(fn)` 就紧跟在该大区、该对象定义后面；例如 document 方法的保护留在 document 区，location 方法的保护留在 location 区，storage 方法的保护留在 storage 区
- 禁止在文件最后集中堆 `fun_to_native(...)` 大名单；禁止把 `fun_to_native(...)` 写到 `// 目标js` 之后；禁止跨区保护别的宿主对象方法
- 方法尽量使用命名函数，保证 native-like 字符串名称合理，例如 `function createElement(ele) { ... }`
- 必须检查 `fn.toString()`、`Function.prototype.toString.call(fn)`、`fn.toString.toString()` 和 `Function.prototype.toString.toString()`

VMP 禁区：
- 不允许在 VMP / VM 解释器 / opcode handler / 字节码分发层做补环境
- 不允许向 VMP 内部下探针、插日志、包 Proxy、改 handler、改字节码或改解释器执行语义
- 如果目标逻辑是 VMP，只能在 VMP 外围定位入参、返回值、环境读取、请求边界和 DOM/BOM 宿主对象，不把探针沉淀进本地 `code.js`
- 如果当前推进路线看起来必须依赖 VMP 插装、下探针或改写执行语义，必须暂停并说明缺失证据，不允许执行或绕过禁令
## `{}` 内填充硬约束

补环境时，基础 DOM/BOM 只能沿用代理模板创建的唯一对象壳。`rtwatch({}, name)` 是未填充模板；正式补环境时，必须把当前 `ruyitrace` 证实的真实字段、方法和状态直接填入这对大括号内部。如果当前轮没有证据可填，就保留空对象字面量和区头备注，不要修改代理或创建第二个对象。

禁止写法：
```js
document = rtwatch({}, "document");
document.URL = "禁止：这里不能在初始化后再赋值";
document.getElementById = function(aaa) {
    rt_log('document.getElementById', aaa);
};
```

推荐写法：
```js
document = rtwatch({
    getElementById:function(aaa){
        rt_log('document.getElementById',aaa)
    },
}, "document");
```

如果 `ruyitrace` 证实还需要 URL 字段，直接把当前 trace 查到的真实字符串写入同一个对象字面量内部。文档和项目代码中不得保留提示文本、自定义占位变量或伪造 URL。

同一对象的 `Object.defineProperty`、`Object.setPrototypeOf`、`fun_to_native` 可以在同一区紧邻收口；不得在所属对象区之外散补真实值，也不得把真实值写入 helper 区或目标 JS 后面。
