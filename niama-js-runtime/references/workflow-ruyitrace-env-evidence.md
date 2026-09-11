## 工作流程：阶段 4-6

### 阶段 4：构造参数生成方法并开始 DOM/BOM Proxy 补环境

进入本阶段的前提是阶段 3 已经通过门禁。本阶段开始正式围绕目标参数构造本地生成方法，固定使用 `node_mode`，通过 `assets/rtproxy.js`、Proxy、`rtwatch` 和 `rt_log` 做本地缺口观察。具体补入值必须来自匹配当前目标的 `ruyitrace/` 真实值。

阶段 4-6 的优先级固定为：先让当前目标链路走到目标产出边界，再提升环境质量。目标产出边界可以是函数返回、目标参数、验证码凭证、Worker 返回值、`/reload` 请求面、XHR/fetch 请求边界或业务请求片段。不要在出值前追求完整浏览器。

阶段 4-6 的核心原则：补环境是基于匹配当前目标的 `ruyitrace/` 逆向目标 JS 可观察到的 API 语义，不是全量实现浏览器 API，也不是只把 trace 中的真值直接填回对象。必须先确认目标 JS 如何读取、调用、枚举、反射、比较、检查 native 外观、建立身份关系或依赖时序，再按实际命中的检测方式补对应的值、外观、内容、行为、状态、身份关系和时序语义。

阶段 4 前置硬条件，必须同时满足：
- 目标参数对应的目标 JS 已确定
- 完整入参已确定
- 生成方法已确定，明确是函数直出、请求边界产出、cookie/storage 预生成或动态 JS 产出
- 已确认目标参数是否涉及请求链条；如果涉及，请求链条、同一轮依赖、请求边界和 `code.js` / `test.py` 职责边界已明确
- 目标函数或请求组装热路径已有 `jscall` 定位证据
- 如果是动态 JS 产出，当前可验证版本已经固定到本地 `code.js`，并已确认能加载到稳定入口或稳定复现首个缺环境点
- 匹配当前目标的 `ruyitrace/` 已提供正式补环境所需 DOM/BOM 真值和行为证据
- `runtime_mode` 已确认为 `node_mode`
- 用户已确认允许进入阶段 4

任一条件不满足时，不得开始补环境，不得改造 `code.js`。

### 阶段 4.0：ruyitrace 检测证据链抽取

阶段 4 正式修改 `code.js` 前，必须先按 `references/environment-detection-signal-index.md` 扫描 `target.lock` 目标集合相关 trace，再从匹配当前目标的 `ruyitrace/` 还原目标 JS 对环境 API 的实际检测语义。重点不是只确认“读了哪个 API”，而是确认“目标 JS 如何检测这个 API”，再据此决定补值、方法、返回对象、descriptor、原型、外观、身份关系还是时序行为。

如果扫描命中高风险检测信号，必须先按 `environment-detection-signal-index.md` 写检测语义卡，说明检测语义、trace 证据、涉及对象、跨对象一致性、状态 / 事件 / 异步时序和补完验证；不能把该项降级成普通字段缺口。未命中高风险信号的普通环境项，使用下面五项最小分析记录即可。

每个准备补入的环境项，先用下面五项完成分析：

```text
缺什么：
如何检测：
trace 依据：
补到哪里：
补完验证什么：
```

五项的填写要求：

- `缺什么`：写清缺失或不一致的对象、属性、方法、返回对象、状态、关系或时序。
- `如何检测`：写清目标 JS 的检测动作和检测语义，例如直接读取、方法调用、`typeof`、`instanceof`、descriptor、原型链、ownKeys、`toString`、对象身份、getter/setter 或异步事件顺序。
- `trace 依据`：写出匹配当前目标的 `ruyitrace` 分区/文件/序号，必要时补充 `jscall` 的调用链和目标边界。
- `补到哪里`：写清具体对象、大区、方法、原型或绑定位置；如果需要联动返回对象或身份关系，也要一并说明。
- `补完验证什么`：写清重新运行后要确认的检测结果、分支、返回值、目标参数或请求边界。

例如：

```text
缺什么：document.createElement("canvas") 的返回对象
如何检测：目标 JS 调用 createElement("canvas")，随后读取 getContext 和 toDataURL
trace 依据：domtrace 对应 call/get 记录，jscall 对应调用链
补到哪里：document 区的 createElement 方法及其稳定返回对象
补完验证什么：方法入参、返回对象方法和后续指纹分支是否与 trace 一致
```

这五项是阶段 4.0 的最小分析记录，不要求为每个环境项填写一整套重型 evidence card。详细 trace 原始记录仍保留在 `ruyitrace/` 中，检测方式分类用于指导补法，不要求重复抄录全部字段。

证据链硬规则：
- 每个准备写入交付版 `code.js` / `runtime/*.code.js` 的环境项，必须有匹配当前目标的 `ruyitrace` 检测依据；只有本地日志或经验而没有 trace 依据时，只能作为候选缺口，不能直接写入交付版代码。
- 只有 `rtwatch` / `proxylog.txt` / 本地异常吐出缺口时，只能记录为 `candidate_gap`；必须回到 `ruyitrace/` 找到当前目标链路相关真值或外观证据后，才能写入交付版代码。
- `jscall` 只负责定位热路径、调用栈、目标边界和入参/出参关系；不得单独作为 DOM/BOM 真值、descriptor、prototype、toString 或事件顺序的依据。
- `domtrace` 优先用于确认直接属性读取、方法调用、`typeof`、`instanceof`、`Function.prototype.toString`、`Object.prototype.toString`、`Object.keys`、Canvas/WebGL/Audio、iframe/window、fetch/XHR 等实际触达。
- `descriptor` 优先用于确认 `Object.getOwnPropertyDescriptor`、`Reflect.getPrototypeOf`、`Object.getPrototypeOf`、`Object.getOwnPropertyNames`、ownKeys、descriptorKind、getter/setter、enumerable/configurable/writable、Symbol key 和 key 顺序。
- `event` 优先用于确认事件类型、listener 顺序、回调入参、`target/currentTarget/source/ports`、异步派发和状态写入。
- `cookie` / `storage` 优先用于确认同轮状态、读写顺序和目标链路依赖的 key/value。
- 如果 trace 没有覆盖某一反射面，只能把该反射面记录为 `evidence_gap`，不得用通用经验直接补成“看起来像浏览器”。

固定 `detect_class`：
- `direct_property_read`：直接读取字段或 getter。
- `method_call_semantics`：调用方法并依赖入参、返回对象、副作用或异常。
- `descriptor_check`：读取 descriptor、getter/setter、writable/enumerable/configurable/value 外观。
- `ownkeys_enumeration`：读取 own keys、`Object.keys`、属性名顺序、Symbol key、集合索引项。
- `prototype_chain_check`：读取 `[[Prototype]]`、`__proto__`、`constructor`、`instanceof` 或 `isPrototypeOf`。
- `native_tostring_check`：命中 `Function.prototype.toString`、函数自身 `toString` 或二阶 `toString`。
- `object_tostringtag_check`：命中 `Object.prototype.toString`、`Symbol.toStringTag` 或对象 class 外观。
- `getter_setter_check`：显式检查 getter/setter 函数外观、非法 this、只读写入或状态派生。
- `realm_identity_check`：iframe/window/document/defaultView/top/parent/self/source 等跨 realm 身份关系。
- `async_event_check`：事件、MutationObserver、timer、microtask、message 等时序和回调语义。
- `fingerprint_surface_check`：Canvas、WebGL、Audio、font、plugins、mimeTypes 等指纹面。
- `state_cookie_storage`：cookie/storage/localStorage/sessionStorage 同轮状态。
- `request_boundary`：目标参数、reload、fetch/XHR 或业务请求边界。
- `exception_semantics`：异常类型、message、stack、非法调用外观。

补法映射原则：
- `descriptor_check` 必须补正确 holder 上的完整 descriptor；不得靠全局 hook 或 Proxy 重 trap 兜底。
- `ownkeys_enumeration` 必须补真实 own 属性集合、枚举性、顺序、Symbol key 和索引项；不得批量填浏览器全量 key。
- `prototype_chain_check` 必须使用 `prototype-chain-template.md` 收口，只定义一次 constructor/prototype/继承关系；不得先临时换 `__proto__` 后续再换壳。
- `native_tostring_check` 必须使用 `assets/rtproxy.js` 的 `fun_to_native(fn)`，并紧跟函数定义所在大区；不得另写第二套 `Function.prototype.toString` 保护。
- `object_tostringtag_check` 必须把 `Symbol.toStringTag` 放到真实命中的对象或原型上，并补 descriptor 外观；不得只为字符串结果随手塞实例字段。
- `getter_setter_check` 必须补 getter/setter 的函数名、native 外观、descriptor 和状态语义；不得只返回固定值。
- `realm_identity_check` 必须补稳定身份关系和父子引用，例如 `iframe.contentDocument.defaultView === iframe.contentWindow`；不得返回每次新建对象。
- `async_event_check` 必须按 trace 证据补异步顺序、回调入参和状态写入；不得用同步假回调或猜测队列跑通。

动态 JS 固定门禁属于正式补环境前置步骤，不属于阶段 7 请求联调：
- 如果目标参数由动态 JS 生成，必须先把该 JS 的当前可验证版本固定到本地 `code.js`
- 固定后只要求能加载到稳定入口或稳定复现首个缺环境点；目标参数通常要在 DOM/BOM Proxy 补环境收敛后才能稳定生成
- 不得在本地稳定生成前直接依赖 `test.py` 每轮动态拉取脚本来掩盖补环境或入口问题
- 补环境收敛到本地稳定生成目标参数后，再回到动态 JS 请求链做联动测试

目标集合相关与语义完整门禁：
- 补环境只围绕当前已确认的目标集合展开；目标集合可以包含多个参数、token、签名片段、加密请求片段、验证码凭证、Worker 返回值或业务动作状态
- 每个准备补入的环境项必须标记归属：属于某个目标、多个目标共享，还是待确认；待确认环境不得直接写入交付版 `code.js`
- 只补与目标集合生成、校验、注入、请求组装或最终验证直接相关的对象、字段、方法、事件、Worker 消息和状态
- 目标集合外不扩张；目标链路内不补空壳
- 对目标链路触达的对象，只按 `ruyitrace` 实际命中的检测语义补齐；命中外观、内容、行为、状态、身份关系或时序中的哪一项，就处理哪一项。未被当前链路检测到的维度只记录为待确认，不得提前扩张；不能只用 constructor、prototype、descriptor 或 native-like `toString` 等单一外观冒充已完成
- 如果目标 JS 继续深入读取、枚举、调用、比较或依赖子对象、返回对象、DOM 节点、集合对象、事件对象、Promise/回调对象、异常对象、Worker 消息对象，必须继续追踪并补其可观察语义，直到目标链路不再依赖

宿主大区落位门禁：
- 正式改 `code.js` / `runtime/*.code.js` 前，必须先给本轮环境项标记落位：`window 区`、`document 区`、`location 区`、`navigator 区`、`screen 区` 或 `storage 区`。`history`、`performance`、WebRTC 全局构造器、fetch/XHR/URL/Blob 等窗口能力归 `window 区`；`navigator.mediaDevices`、plugins、mimeTypes 等归 `navigator 区`。
- iframe / Worker / MessageChannel / canvas / WebGL / Audio 等按证据启用的独立链路，不作为固定全局大区预先创建；位置根据目标代码触发源就近放置，并在区头备注说明跨对象关系、事件顺序和验证点。
- 每个大区必须有区头备注，说明本区负责内容、禁止内容和证据来源；没有备注时先补备注，再写环境。
- 本轮环境项无法归类到某个大区时，不得写入代码；先回到 trace / jscall 证据确认对象归属。
- 一轮可以补多个环境项，也可以跨多个宿主大区；前提是这些修改属于同一个阻塞点、同一条检测链、同一个方法返回对象链路，或同一个目标参数产出链路。禁止的是无关大批量补环境、全量浏览器枚举和顺手补无关对象。
- 不得把 `window/document/location/navigator/screen/history/storage/performance` 连续堆进一个无分区的 `installBaseEnvironment()`；使用统一初始化函数时，函数内部也必须按固定大区备注拆段，或拆成区级初始化函数。

通用路径：
1. 将目标 JS 中与参数生成直接相关的最小逻辑整理进 `code.js`
2. 为目标参数建立稳定入口：`get_参数名(input)`，例如 `get_xxx(input)`
3. 如果参数在请求边界产出，先构造 `build_target_request(input)`，再从 URL/Header/Body/Cookie 中提取目标参数
4. 执行阶段 4.0：先按 `environment-detection-signal-index.md` 扫描当前目标集合相关 trace；命中高风险信号时先写检测语义卡，未命中时从 `ruyitrace/` 还原目标 JS 对环境 API 的检测语义，并按“缺什么、如何检测、trace 依据、补到哪里、补完验证什么”形成最小分析记录
5. 根据检测语义决定补值、方法、返回对象、descriptor、prototype、native 外观、身份关系、状态或异步时序；`detect_class` 只作为内部补法分类
6. 读取随 skill 打包的源文件 `assets/rtproxy.js`，并原样复制到当前任务目录的 `assets/rtproxy.js`；源文件和项目副本绝对只读，不得加功能、改 trap、改日志逻辑或改文件名逻辑，不得用简化版替代，不得让 runtime 跨目录引用 skill 内的代理文件
7. 按项目本地 `assets/rtproxy.js` 的固定格式顺序和固定宿主对象声明组织 `code.js` 底座，并确认单 JS/单 runtime 默认使用代理生成的 `proxylog.txt`，每次 Node 启动覆盖上一份；只有多个 JS/runtime 入口需要分别补环境和分别分析日志时，才允许通过代理已有配置、调用参数或外部运行配置为不同入口选择不同 `.txt` 文件名；目标 JS 放在 `// 目标js` 分界之后
8. 只对明确宿主对象做最小 `rtwatch` 观察，不把 Proxy 套成全局 VM 外壳
9. 根据检测语义、trace 依据和本地日志继续代理 `document`、`location`、`navigator`、`screen`、`localStorage`、`sessionStorage` 等目标链路触达对象；`history`、`performance` 等窗口能力落在 `window 区`，每个对象和返回对象都必须落到对应大区
10. 每补一批后立即尝试推进到目标产出边界；一旦能输出目标参数、验证码凭证、reload 请求面或目标请求片段，先进入请求边界 / `test.py` 验证
11. 验证失败且证据指向环境语义时，再按本地缺口日志和 trace 中还原出的检测语义补方法入参、返回对象、descriptor、prototype、constructor、native `toString` 外观、对象内容、状态、副作用和身份关系
12. 只有本地缺口日志和 `ruyitrace` 检测语义分析都证明目标链路触达，且当前目标验证需要时，才进入 `canvas`、`canvas2d`、`webgl` 等指纹面
13. 每定义一个补环境方法，立即在同一大区紧跟 `fun_to_native(fn)` 做 native-like `toString` 保护；不得拖到文件末尾统一保护
14. 每补一批环境，立即用固定输入运行 `node code.js` / `node runtime/*.code.js`，或由 `test.py` 调用验证目标参数
15. 不写 `补环境进展清单.md`。本轮状态以 `target.lock`、当前代码、当前入口运行结果、`proxylog.txt` 和匹配当前目标的 `ruyitrace/` 为准；`evidence_id`、`detect_class`、`patch_strategy`、验证结果、代理资产校验和版本材料保留在本轮回复、代码验证输出或 `proxylog.txt` 中。

### rtproxy 强制规则

`assets/rtproxy.js` 是随 skill 打包的绝对只读 rtproxy 源文件和默认 Proxy 骨架。进入项目时必须原样复制到当前任务目录的 `assets/rtproxy.js`，之后只使用项目副本；不得修改源文件或项目副本，不得在 `code.js` / `runtime/*.code.js` 中直接 `require` / `import` skill 目录里的代理文件，也不得用旧示例结构图或手写简化版替代。

代理源文件和项目副本的行为、形态和日志语义必须保持不变。禁止为了任何理由修改 trap 集合、target/receiver、返回值包装、缓存、路径、事件顺序、日志 schema、序列化、异常处理或日志文件名逻辑；需要降噪时只能在控制台展示或独立日志分析层过滤。

项目副本要求：
- 任务目录必须有 `assets/rtproxy.js`；没有就从 skill 的 `assets/rtproxy.js` 复制。
- runtime 只能用相对路径引用项目内副本，例如 `require("./assets/rtproxy.js")` 或 `require("../assets/rtproxy.js")`。
- 禁止引用 `C:\nxtool\nxtoolskill\...`、`%CODEX_HOME%`、skill 安装目录、软链接、硬链接或运行时搜索出来的代理路径。
- 如果项目已有 `assets/rtproxy.js` 且和 skill 源文件不同，先记录为代理资产差异并暂停；任何情况下都不得修改。即使需要多个入口日志，也不得通过修改代理实现换名。
- 代理源文件、项目副本 hash、差异原因和每个 runtime 的实际引用路径必须在进入补环境前完成校验；这些属于代理资产校验，不写入 `补环境进展清单.md`。

必须使用或保留的能力：
- `rt_loginfo` / `rt_log`：作为可开关的补环境日志
- `proxylog.txt`：作为单 JS/单 runtime 入口当前轮完整代理事件日志；多入口独立补环境时才允许使用不同固定 `.txt` 文件名
- `rtwatch(obj, name)`：作为 DOM/BOM Proxy 观察器
- `fun_to_native(fn)` / `Function.prototype.toString` 保护：作为 native 外观保护工具

格式必须按 `rtproxy.js` 来：

```text
rt_loginfo / rt_log
proxylog.txt 固定覆盖初始化（单入口默认；多入口仅在代理已有机制支持时使用不同固定 `.txt` 文件名）
defaultFilterProps / existsobj
rtwatch(obj, name)
Function.prototype.toString 保护 / fun_to_native
window = rtwatch(global,'window')
补 window/document/location/navigator/screen/storage 等宿主对象；history/performance 归 window 区
// 目标js
目标 JS 原始逻辑
稳定导出入口 get_参数名(input)
```

上面的“补宿主对象”必须展开为固定大区结构；不得用一段无备注代码代替 `window 区`、`document 区`、`location 区`、`navigator 区`、`screen 区` 和 `storage 区`。`history`、`performance` 不设置独立大区，统一归 `window 区`。

不得把补环境代码插进 `// 目标js` 后面的目标逻辑内部；目标 JS、VMP 或混淆逻辑应保持语义不被探针污染。

执行模型禁区：
- 不得把 Proxy 作为全局 VM 外壳塞进目标执行上下文；只能观察明确宿主对象。
- 不得让 Proxy 污染 Node 全局定时器、Promise、module、require、vm context 或目标 JS 内部对象。
- 不得在 `currentScript` 附着、script 创建、iframe 构造或 DOM append 阶段提前执行目标脚本；脚本执行时机必须按证据最小复现。
- 出现全局定时器解析异常、脚本过早执行、currentScript 状态错误或 VM context 污染时，必须回退执行模型，而不是继续补字段。

`proxylog.txt` 硬规则：
- 每次执行单个 `node code.js` 或单个 `node runtime/*.code.js` 时覆盖该入口自己的固定日志
- 单入口默认使用 `proxylog.txt`；只有多个 JS/runtime 入口分别补环境时，才允许使用不同固定 `.txt` 文件名
- 换名只能使用代理已有配置、调用参数或外部运行配置，禁止修改 `assets/rtproxy.js` 增加换名功能
- 不默认创建时间戳日志、轮次目录或多份历史日志
- 每一次 `rtwatch` / Proxy trap / `rt_log` 事件都必须写入，不得在写入前抽样、过滤、去重或静默丢弃；写入后可以用独立分析脚本生成降噪视图，但不得修改原始日志
- 写文件失败必须输出控制台错误
- 该文件只用于本地缺口观察；任何准备补入的环境值仍必须回到匹配当前目标的 `ruyitrace/` 查证

证据使用边界：
- `ruyitrace/`、`http_packet`、`jscall`、抓包响应体中的目标参数、token、签名、`captchaBody`、通过凭证和成功响应只能作为定位和基线证据。
- 不得把 trace 中已经生成好的目标值写入 runtime 或 `test.py` 后声称本地已生成。
- runtime 执行时不得读取 trace 目录、HTTP 包、旧响应文件或请求基线文件来产出目标值；如果这样做，只能标记为离线回放或 fixture 验证。
- 阶段 4-6 的通过标准是项目本地 Node 入口按显式输入实时生成目标值；阶段 7-8 的通过标准是 `test.py` 使用这些生成值发出请求并得到当前运行结果。

### 方法入参与 native toString

方法入参必须显式用 `rt_log` 打印，例如：

```js
document.querySelector = function querySelector(selector) {
  rt_log("document.querySelector", selector);
  // ...
};

fun_to_native(document.querySelector);
```

native `toString` 保护规则：
- `rtproxy.js` 已提供 `Function.prototype.toString` 保护和 `fun_to_native(fn)`，直接使用该模板底座，不另写第二套保护
- 对补出的每一个方法、宿主方法、构造器和 native-like 函数，必须调用 `fun_to_native(fn)` 做 native 外观保护
- 方法在哪个大区定义，`fun_to_native(fn)` 就紧跟在同一区；禁止文件末尾大名单、禁止写到 `// 目标js` 后面、禁止跨区保护其它宿主对象的方法
- 补环境方法应尽量写成命名函数，例如 `createElement: function createElement(ele) { ... }`
- 高风险函数必须同时考虑 `target.toString()`、`Function.prototype.toString.call(target)`、`target.toString.toString()` 和 `Function.prototype.toString.toString()`
- `Function.prototype.toString` 自身的 `name` 和 native 外观也要保持合理
- 不要给普通业务函数乱加 native 外观；只对浏览器宿主方法、构造器或目标检测会命中的 native-like 函数使用

### VMP 禁区

- 不允许在 VMP / VM 解释器 / opcode handler / 字节码分发层进行插装补环境
- 不允许向 VMP 内部下探针、插日志、包 Proxy、改 handler、改字节码或改解释器执行语义
- 不允许把 VM tracer、解释器 proxy、opcode hook、probe 或 instrumentation 写入本地 `code.js`
- 如果目标参数来自 VMP，只能在 VMP 外围确认最小入参、最终返回值、环境读取点和请求边界；补环境仍落在 DOM/BOM 宿主对象、方法、事件和 Worker 消息的可观察语义上
- 如果当前推进路线看起来必须依赖 VMP 插装、下探针或改写执行语义，必须暂停；不得为了继续推进而放宽禁令

补环境策略是“吐什么补什么”：
- “吐什么补什么”只适用于当前目标集合相关链路；目标集合外的缺口即使出现在日志中，也只能记录为候选，不得顺手补入
- 目标链路内的对象不能只补外观；必须补目标 JS 实际读取的字段值、索引项、数组/类数组内容、集合长度、方法返回对象、getter/setter 副作用、异常外观、对象身份稳定性和跨对象引用关系
- 顶层对象的子对象和方法返回对象继续适用同一规则，例如 `navigator.connection`、`navigator.userAgentData`、`performance.memory`、`document.createElement(...)`、`querySelector(...)`、`canvas.getContext(...)`、`permissions.query(...)`
- 事件参与目标参数链路时，必须从 `ruyitrace/event` 和对应 `jscall` 中确认事件类型、顺序、时间戳、坐标/按键/触点字段、`target/currentTarget`、listener 回调、回调内状态写入和最终进入目标集合的位置
- Worker / SharedWorker / MessageChannel / MessagePort 参与目标参数链路时，必须定位 Worker 脚本来源、脚本 hash、初始化入参、主线程消息、Worker 返回消息、`MessageEvent.data/origin/source/ports`、structured clone / transferable 语义、异步顺序和最终进入目标集合的位置
- `rtwatch` 只记录目标链路实际触达的 `get/set/has/ownKeys` 基础观察面，方法入参用显式 `rt_log`；descriptor、prototype 和详细反射语义只能按目标 JS 真实检测点与 `ruyitrace/descriptor` 证据补目标对象语义，不靠 Proxy 重 trap 兜底
- 日志提示“存在于 window/document/navigator 但没有补”的字段，只能作为候选缺口；是否补入必须再看 `ruyitrace/` 是否有真实值或真实外观证据
- 当有新的环境需要补时，必须依赖目标参数相关链路上的 `ruyitrace/` 真值或真实外观证据；优先从 `domtrace/`、`descriptor/`、`event/`、`cookie/`、`storage/` 中取证
- 只有 `rtwatch` 吐出缺口、只有 jscall 单条调用现象、或只有旧项目经验，都不能直接固化到 `code.js`
- `rt_loginfo` 调试阶段可以打开，收敛和交付时默认关闭
- 不允许一次性大批量补环境；每轮只补一个清晰批次，先基础 BOM/DOM，再方法与返回对象，再 canvas/WebGL 等指纹面
- `canvas`、`canvas2d`、`webgl`、audio、font、plugin、mimeType 等指纹面不得提前批量补；必须等基础 BOM/DOM 已验证稳定，并且目标链路日志与 `ruyitrace/` 都证明触达

Proxy 使用边界：
- Proxy 必须可读、可开关、可按日志收敛；不得默认代理基础原型、目标业务函数或 VM 解释器
- 不得改造 Proxy handler 或增加重型 trap；如果现有代理已经提供某些反射面，只能原样使用。缺少反射能力时记录代理资产缺口并暂停，不得自行补进代理
- Proxy 返回的值、descriptor、原型链、`toStringTag`、constructor、异常外观必须以目标链路相关 `ruyitrace/` 真值证据为准
- 如果 Proxy 导致参数或请求结果偏离，先根据日志缩小到触发差异的对象和属性，不盲目扩大补环境范围

### 阶段 5：首轮本地验证与差异定性

默认验证：

```text
node code.js
node runtime/*.code.js
python test.py
```

真实请求统一由 `test.py` 发起：

```text
python test.py
```

如果 `test.py` 真实请求依赖登录态、代理、Cookie 或时间窗口，先允许只跑 Node 和固定输入参数样本；真实请求联调放到阶段 7。

异常对照判定：
- 如果浏览器中也出现相同异常、相同位置或相同分支结果，优先视为目标逻辑的正常浏览器行为，不要把它当成缺环境盲目修
- 如果本地异常在浏览器中没有出现，或异常类型、位置、分支结果不一致，优先按缺失环境、descriptor、prototype、getter 或宿主对象差异排查
- 只有确认浏览器与本地异常不一致时，才把该异常升级为需要补环境的问题
- 浏览器异常优先从 `exception/trace_exception_process_<pid>` 对照；没有对应异常时再回到 `jscall` 的 error/exception 字段补充定位

本阶段输出：

```text
目标入口函数:
runtime_mode: node_mode
runtime_shape:
version_risk:
multi_trace_trigger:
version_material:
固定输入样本:
本地运行结果:
浏览器同触发步骤异常/分支结果:
exception 证据位置:
本地与浏览器异常是否一致:
是否能稳定生成目标参数:
Node rtwatch 吐出的缺口:
Node rt_log 打印的方法入参:
proxylog.txt 路径:
proxylog.txt 是否为当前轮覆盖生成:
native toString 保护的函数:
是否存在未保护 toString 的补环境方法:
是否存在 VMP 探针/插装残留:
检测证据链:
检测语义分析:
缺什么:
如何检测:
trace 依据:
补到哪里:
补完验证什么:
descriptor/prototype/ownKeys/toString/Symbol 证据:
detect_class:
patch_strategy:
validation_probe:
首个异常或差异:
差异归类:
下一批需要补的 DOM/BOM 对象:
对应 ruyitrace 证据位置:
```

失败分类：
- 运行时异常：对象缺失、descriptor 错误、原型链错误、非法调用外观不一致
- 参数不一致：环境值、入参、时间戳、随机数、编码、事件顺序差异
- 请求组装不一致：URL、Header、Cookie、Body、前置状态缺失
- 会话态问题：登录态、账号、代理、IP、风控状态或时间窗口问题

每轮只修一批差异。不要同步或维护 `补环境进展清单.md`；下一轮从 `target.lock`、当前代码、当前入口运行结果、`proxylog.txt` 和 `ruyitrace/` 重新判断状态。

### 阶段 6：多 trace 对照触发场景

多 trace 对照不是只在失败时才使用。阶段 4-6 必须区分以下两类触发场景：

```text
single_trace_passed_quality_check
= 单 trace 已经跑通，但目标链路存在 VMP / VM-like runtime / 动态执行载荷 / 不透明 payload / Worker/WASM 执行载荷等多版本风险候选，需要额外 trace 复核环境读取面和版本材料。

single_trace_failed_need_more_evidence
= 单 trace 未通过，且当前 trace 无法解释失败原因或证据不足，不能继续盲补环境，需要补齐或更新 trace 证据。
```

需要多 trace 对照时，记录：
- 每份 trace 的目标 JS hash、eval hash、Worker hash、WASM hash、payload/blob hash
- 目标集合、入口入参、事件/Worker 链、storage/cookie 状态、环境读取面、目标输出和最终请求验证结果
- 每份 trace 的反射检测面：descriptor、prototype、ownKeys、Symbol keys、native `toString`、`Object.prototype.toString`、`instanceof`、iframe realm 身份关系是否一致
- 每份 trace 的五项检测语义分析是否稳定复用；若同一产品不同站点的检测方式稳定但真值不同，记录为产品稳定检测面 + 站点差异真值
- 读取面是否稳定，是否需要拆 runtime 或分版本入口

没有多 trace 证据时，最多声明当前版本通过，不得声明跨版本稳定。
