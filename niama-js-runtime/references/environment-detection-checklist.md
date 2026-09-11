## 补环境检测点与补法映射

本清单只用于补环境建模和验收，不是自动补环境工具，也不是浏览器对象目录。它的核心用途是把“检测方式”映射到“应采用的补法”。

所有检测点必须先确认属于当前目标集合链路，再回到匹配当前目标的 `ruyitrace/`、`domtrace`、`descriptor`、`event` 或 `jscall` 证据补齐；不得因为清单里有某项就批量补全。阶段 4 产生的每个环境 patch 都必须能说明“缺什么、如何检测、trace 依据、补到哪里、补完验证什么”。

如果检测命中 `references/environment-detection-signal-index.md` 中的高风险信号类型，必须先按该文档写检测语义卡，再回到本清单选择具体补法。普通 descriptor、prototype、ownKeys、native `toString` 单独命中时按本清单处理；当它们绑定在高风险对象或跨对象一致性链路上时，必须作为该高风险检测链的一部分处理。

## 使用边界

- 只记录检测维度，不照搬外部工具箱代码。
- 只补目标链路已触达对象，不做全量浏览器枚举。
- 只补目标对象自身语义，不 patch 全局 `Object` / `Reflect`。
- Proxy 仍只允许 `rtwatch(get/set/has/ownKeys)` 轻量观察；方法入参用 `rt_log`。
- 若检测点会诱导大批量补环境，先记录缺口，拆成最小批次处理。

## 检测方式到补法

| 检测方式 | 主要证据 | 需要恢复的语义 | 允许的补法 | 常见错误 |
|---|---|---|---|---|
| 直接属性读取 | `domtrace` get / getter | 值、getter、状态派生、身份稳定性 | 在真实 holder 上补字段或 getter | 看到缺口就返回固定值 |
| 方法调用 | `domtrace` call / `jscall` | 入参、返回对象、副作用、异常 | 在目标对象上补命名方法，并显式记录入参 | 只补空方法或固定返回 |
| descriptor 检查 | `descriptor_lookup` | 属性归属、value/get/set、writable/enumerable/configurable | 在正确对象或原型上用 `defineProperty` | 只给实例赋值或全局 hook |
| 原型链检查 | `prototype_lookup`、`instanceof` | `__proto__`、`prototype`、`constructor`、继承方向 | 仅按 trace 命中的关系，在所属宿主对象区紧邻使用原型链模板收口 | 默认补完整原型链、后续换壳、constructor 断链 |
| ownKeys / Object.keys | `own_keys`、`Object.keys` | own 属性、Symbol key、顺序、可枚举性、索引项 | 恢复真实 key 集合和 descriptor | 批量填全量浏览器属性 |
| native toString | `Function.toString`、二阶 `toString` | 函数名、length、native 外观、非法 this | 使用 `fun_to_native`，紧跟函数定义 | 文件末尾统一保护或重写第二套 |
| Object.prototype.toString | `Object.prototype.toString` | 内部 class、`Symbol.toStringTag` 所在层级 | 在真实对象/原型补 `toStringTag` 和 descriptor | 只追求字符串结果 |
| getter/setter 检查 | `descriptor` getter/setter 字段 | getter 名称、native 外观、状态和非法调用 | 定义真实 getter/setter 并保护外观 | 用普通函数模拟 getter |
| realm 身份检查 | iframe/window/document 读取及比较 | contentWindow、defaultView、parent/top/self、稳定引用 | 建立 child realm 关系和缓存身份 | 每次返回新对象 |
| 异步事件检查 | `event`、`MutationObserver`、message | listener 顺序、回调参数、异步时序、状态写入 | 按证据实现最小事件链 | 同步假回调或猜队列 |
| 特殊环境语义 | `special-environment-detection-checklist.md` 对应专项 trace | `document.all`、CSS 计算、iframe/Worker 边界、性能、Canvas/WebGL 等特殊语义 | 命中后读取专项清单，按当前检测点补最小语义 | 把专项检测当普通字段批量补全 |

当同一目标同时命中多个检测方式时，必须按检测方式分别分析，不得用一个“对象已补”结论覆盖全部反射面。例如读取 `navigator.webdriver` 只证明 `direct_property_read`，不能自动证明 descriptor、prototype、ownKeys 或 native toString 已正确。

## detect_class 中文术语表

`detect_class` 是检测方式分类，不是产品分类，也不是对象分类。同一个对象可以同时命中多个 `detect_class`，每一类都要有独立证据和补法。

- `direct_property_read`：直接读字段或 getter。例：`navigator.webdriver`、`screen.width`、`document.cookie`。这类证据只能证明“读了这个值”，不能自动证明 descriptor、原型链或枚举外观。
- `method_call_semantics`：调用方法并依赖入参、返回值、副作用或异常。例：`document.createElement("canvas")`、`localStorage.getItem("x")`。补法要恢复方法行为，不是只写空函数。
- `descriptor_check`：检查属性描述符。例：目标代码对某个宿主对象或其原型执行 `Object.getOwnPropertyDescriptor(holder, key)`。补法要先用 trace 确认真实 holder 是实例还是原型，再在该 holder 上写全 `value/get/set/writable/enumerable/configurable`。
- `ownkeys_enumeration`：枚举 own key、字符串 key、Symbol key 或 key 顺序。例：`Object.keys(obj)`、`Object.getOwnPropertyNames(obj)`、`Reflect.ownKeys(obj)`。补法要恢复真实 key 集合和可枚举性。
- `prototype_chain_check`：检查原型链、构造器、继承关系或 `instanceof`。例：`Object.getPrototypeOf(obj)`、`obj.constructor`、`obj instanceof Navigator`。补法只按当前 trace 命中的关系，在所属宿主对象区紧邻使用原型链模板收口。
- `native_tostring_check`：检查函数源码外观。例：`Function.prototype.toString.call(document.createElement)`。补法是 `fun_to_native(fn)` 和函数名/length/native 外观保护。
- `object_tostringtag_check`：检查对象 class/tag 外观。例：`Object.prototype.toString.call(navigator)`、`Symbol.toStringTag`。补法要把 tag 放到正确对象或原型，并保持 descriptor。
- `getter_setter_check`：专项检查 getter/setter 函数自身和非法调用语义。例：取 descriptor 后继续看 `desc.get.name`、`desc.get.toString()` 或 `desc.get.call({})`。补法要恢复 getter/setter 外观和 this 语义。
- `realm_identity_check`：检查跨 window/iframe/realm 身份关系。例：`iframe.contentWindow`、`iframe.contentDocument.defaultView`、`top/parent/self/window`。补法要保证稳定引用和父子关系。
- `async_event_check`：检查异步事件、观察器、message、timer 或 listener 顺序。例：`MutationObserver.observe`、`postMessage`、`addEventListener`。补法要按 trace 恢复异步时序和回调入参。
- `fingerprint_surface_check`：检查指纹面。例：Canvas、WebGL、Audio、fonts、plugins、mimeTypes。只有目标链路命中且验证需要时才补，禁止提前批量浏览器化。
- `state_cookie_storage`：检查同轮状态容器。例：cookie、localStorage、sessionStorage 的读写顺序和值。补法要恢复状态语义，不能把业务 token 硬编码成环境。
- `request_boundary`：目标参数或 token 最终进入请求边界。例：fetch/XHR/reload/body/header/cookie。它主要用于判断补环境是否已经服务到目标产出，不直接代表某个 DOM/BOM 对象要补。
- `exception_semantics`：检查异常类型、message、stack 或非法调用外观。例：非法 this、缺参、只读属性写入。补法只针对目标链路命中的异常语义，不全局替换 Error/DOMException。

## Object / Reflect 检测

重点判断属性到底在实例自身还是原型上，以及 descriptor 是否符合真实浏览器表现：
- 自身属性、原型属性、可枚举属性、不可枚举属性要分清。
- `Object.keys`、属性名枚举、Symbol 属性枚举、descriptor、getter/setter、`hasOwnProperty`、`in`、`isPrototypeOf` 都可能成为检测点。
- 命中这类检测时，补目标对象的真实属性归属、descriptor、prototype 和枚举结果；不得通过全局 hook 或 Proxy 重 trap 兜底。
- `defineProperty` 默认值和普通赋值默认值不同，补 descriptor 时必须显式写清 `configurable/enumerable/writable/get/set/value`。
- 如果 `descriptor` 分区只记录了查找动作、没有记录目标属性的真实 descriptor，标记为 `evidence_gap`，不得凭浏览器常识填写全部 flags。
- 如果只记录 `Object.keys` 而没有 `own_keys` 或完整 key 文件，先区分“可枚举字符串键证据”和“完整 own property/Symbol 键证据”，不能混为一谈。

## 原型链与构造器

只有当前 trace 命中原型、constructor、`instanceof` 或相关比较时，才处理原型关系。收口位置放在命中的所属宿主对象区内、对应对象定义之后；不设置独立原型链大区，也不默认要求完整 DOM 原型链：
- 实例 `__proto__` 指向对应构造器的 `prototype`。
- 构造器的 `prototype.constructor` 回指构造器。
- 构造器之间的静态继承和 prototype 继承要分清。
- `document` 这类对象只补当前 trace 证实需要的原型关系；如果 trace 同时证明了 `HTMLDocument -> Document -> Node -> EventTarget` 的多个层级，再按实际命中范围保持方向正确。
- 不允许先临时 `__proto__`，后面又换壳重建同一对象。
- 只有命中 `prototype_lookup`、`instanceof`、`constructor` 或相关比较证据时，才把原型链列为本轮 patch；仅有普通属性读取时，原型链只能记录为待确认。

## native 外观

目标链路触达的浏览器宿主方法和构造器要按 native-like 外观处理：
- 函数名、`length`、`prototype` 是否存在要按证据补。
- 宿主方法、getter、setter 默认按严格模式语义处理，非法 this 调用要能抛出合理异常。
- `fn.toString()`、`Function.prototype.toString.call(fn)`、二阶 `toString` 都要检查。
- 对象的 `Symbol.toStringTag` 要放在正确对象或原型上，不能只为让字符串好看就随手塞到实例。
- `Function.prototype.toString` 的命中要和 `Object.prototype.toString` 分开记录；前者是函数源码外观，后者是对象 class/tag 外观，二者不能用同一个补丁解决。

## getter / setter

命中 getter/setter 检测时：
- getter/setter 函数名按 `get xxx` / `set xxx` 这类浏览器外观处理。
- getter/setter 自身也要做 native-like `toString`，且不应暴露普通函数 `prototype`。
- getter/setter 不能只返回固定值；若依赖当前对象状态，要从对应实例状态读。
- 非法 this 调用、缺少参数、只读属性写入等异常外观按 trace 证据补。

## 特殊检测点

以下点命中时必须专项处理，不得当普通字段补：
- `document.all`：优先 V8 undetectable 底座；不套普通 `rtwatch`，不补成 `{}`、普通函数或普通 Proxy。
- `iframe/window`：分清 top window、parent window、frame window、frame document、iframe element；`contentWindow/contentDocument/frameElement/parent/top/self/window` 身份关系按 `domtrace` 证据补。
- `Worker/MessageChannel`：分清 `postMessage`、`MessageEvent.data/origin/source/ports`、transferable、异步回调顺序；不得同步假回调跑通。
- `navigator.plugins/mimeTypes`：只有目标链路命中时再补，注意集合、索引、命名项、迭代和身份稳定性。

## Storage

`localStorage/sessionStorage` 命中时按状态容器处理：
- `getItem/setItem/removeItem/key/clear/length` 要有同轮状态语义。
- key/value 以字符串语义存取；缺参数、非法 this 调用、返回 `null` 等行为按证据补。
- 具体 storage 值只能来自 cookie/storage/trace 或目标输入，不把业务 token 派生逻辑写进 storage 区。
- 如需用 Proxy 处理直接属性写入，也必须局限在 storage 区，并确认不会扩成全局代理。

## Error / DOMException / Node 特征

异常检测不能靠全局重 hook 兜底：
- 先确认浏览器是否也会在同位置抛同类异常；一致时不要盲补。
- 不一致时补对应方法的异常类型、message、调用条件和必要的 stack 外观。
- 目标逻辑不应看到不该存在的 Node 特征，例如 `process`、`Buffer`、`global`、`module`、`require`、Node 路径和 Node 内部栈帧。
- Error/DOMException 只按目标链路需要做最小建模，不全量替换 Node 内置 Error 族。

## 出值可用性验证

环境补丁已经让目标 JS 继续执行，或已经产生某个参数，不等于补环境合格。每轮必须继续确认：

- 参数、验证码凭证、请求参数或请求边界能够根据当前输入实时生成，不是固定旧值、trace 回放值或硬编码结果。
- 输出格式、字段结构、编码方式和依赖关系符合当前目标链路。
- 输出长度与匹配当前目标的 `ruyitrace` / 抓包参考样本相比不能明显异常；长度只能作为辅助判断，不能替代内容、结构和请求验证。
- 目标 JS 已越过当前检测点，并且下游参数生成或请求组装没有因环境缺口走错误分支。
- 如果只是“有输出”，但格式、结构或长度明显异常，继续按检测语义和差异证据定位，不得把本轮标记为补完。
