## code.js 推荐结构

本 skill 只支持 `node_mode`。正式补环境时，`code.js` / `runtime/*.code.js` 必须使用 `assets/rtproxy.js` 作为默认底座。目标 JS 只能放在 `// 目标js` 分界之后，补环境宿主对象、`rtwatch` 包装、方法入参日志和 `toString` 保护必须在目标 JS 之前完成。

`code.js` / `runtime/*.code.js` 必须遵守“目标集合相关、链路内语义完整”原则：
- 只补与当前目标集合的生成、校验、注入、请求组装或最终验证直接相关的环境
- 目标集合外不扩张；无关浏览器对象、无关指纹面、无关 DOM 内容、无关事件状态、无关接口或其它参数族不得写入交付版补环境
- 目标链路内不补空壳；顶层对象、属性子对象、方法返回对象、DOM 节点、集合对象、事件对象、Promise/回调对象、异常对象和 Worker 相关对象，都必须按证据补齐外观、内容、行为、状态、身份关系和时序语义
- native-like `toString`、constructor、prototype 和 descriptor 只是外观层，不足以说明对象补完

单目标项目继续默认使用 `code.js`。如果同一任务存在多个签名、多个验证码、多个加密链或多个 JS runtime，允许使用 `runtime/*.code.js` 拆分。每个 runtime 文件必须遵守“rtproxy 底座 → 宿主对象补环境 → `// 目标js` → 目标逻辑 → 稳定入口”的顺序。

推荐多 runtime 结构：

```text
任务目录/
├─ code.js                    # 单目标默认入口，或多目标聚合/兼容入口
├─ runtime/                   # 可选，多目标项目使用
│  ├─ captcha_xxx.code.js
│  ├─ sign_xxx.code.js
│  ├─ encrypt_xxx.code.js
│  └─ fingerprint_xxx.code.js
├─ test.py                    # 唯一真实请求编排层
├─ target.lock                # 阶段 4 以后锁定允许处理的目标集合
├─ param_info.md
└─ 补环境进展清单.md          # 可选人工摘要；AI 不维护、不作为状态源
```

推荐顺序：

```text
1. assets/rtproxy.js 底座：rt_log、proxylog.txt、rtwatch(get/set/has/ownKeys)、fun_to_native
2. 共享 helper / 构造器工厂，不放实例值
3. 按代理原样保留 `window`、`document`、`location`、`navigator`、`screen`、`localStorage`、`sessionStorage` 这组固定声明；`performance`、`history` 和其它 window 属性统一在 `window` 对象内部按证据补
4. 每个补环境方法的 `rt_log` 入参打印，并在同一大区紧跟 `fun_to_native` 保护
5. 只有当前 `ruyitrace` 明确命中时，才在对应对象紧邻位置收口 descriptor、prototype、constructor、toStringTag 或 native 外观
6. 在各宿主对象完成后，按目标链路补必要的 window 引用；代理固定声明完成后，所有后续属性、方法、子对象和构造器只直接补到 `window` 或所属宿主对象
7. 对象内容、状态、副作用、身份关系和事件/Worker 时序语义修正
8. canvas、2D/WebGL、audio 等只作为 `document` 创建或返回对象的子语义，在当前 trace 命中后补
9. // 目标js
10. 目标原始逻辑
11. 稳定导出入口 get_参数名(input)
12. Node CLI / module.exports / test.py 桥接入口
```

## 原型、descriptor 与 native 外观

这些内容不设固定大区，也不是默认补环境步骤。只有当前目标的 `ruyitrace/descriptor` 或 `domtrace` 明确命中相关检测时，才在对应宿主对象区的紧邻位置按 `references/prototype-chain-template.md` 处理。

硬约束：
- 没有原型或外观检测证据时，不创建构造器、prototype，不补 constructor，不执行 `Object.setPrototypeOf`。
- 命中后只处理当前对象和当前检测要求的最小 descriptor、prototype、constructor、`Symbol.toStringTag` 或 native-like 外观。
- 具体实例沿用代理提供的 `rtwatch({}, "name")` 对象模板，真实字段和方法仍然直接填入对象字面量内部，不在这里创建第二个实例或换壳。
- 构造器静态继承、prototype 继承、`prototype.constructor` 回指和实例原型关系，只有在当前 trace 同时证明需要时才联动处理。

写入顺序必须固定：
1. 先写 `rtproxy` 底座和共享 helper。
2. 再写各宿主对象区，把真实字段和方法直接填入对应 `rtwatch({}, "name")` 的大括号。
3. 如果 trace 命中特殊链路或原型/descriptor/native 外观，再在对应对象区紧邻收口。
4. 按目标链路补必要的 window 别名引用。
5. 最后才是 `// 目标js` 和稳定入口。

禁止写法：
- 先空壳，后面另起一段重建同一个对象。
- 先在对象区之外写真实值，再回头去所属对象区补语义。
- 把模板、实例、绑定、目标逻辑混进同一段。

## 宿主对象大区硬约束

`code.js` / `runtime/*.code.js` 在 `// 目标js` 之前必须采用固定大区。每个大区必须保留区头，并在区头下写 1-3 行备注，说明本区负责什么、禁止放什么、证据来源来自哪个 `ruyitrace/` 分区或 `jscall` 定位。空区也要保留备注，不得因为暂时没有补内容就删除。

补环境骨架顺序必须固定为：
1. `rtproxy` 底座
2. 共享 helper
3. 各宿主对象区
4. 按证据就近落位的特殊链路和收口动作
5. `// 目标js`
6. 稳定入口

骨架原则只有一条：代理对象壳只创建一次，不换壳。基础 DOM/BOM 对象采用 `document = rtwatch({}, "document")` 这类空模板时，正式补环境必须把真实字段、方法和状态直接填入这对大括号内部；descriptor、prototype 和 `fun_to_native` 等收口动作只能在同一区紧邻处理。

必选大区顺序：

```js
// ===== 00 rtproxy 底座 / 日志 / toString 保护 =====
// 放 rt_log、proxylog.txt 初始化、rtwatch、fun_to_native、native toString 保护。
// 不放具体宿主对象真值；日志只用于缺口观察，补入值仍以 ruyitrace 为准。

// ===== 01 共享 helper / 构造器工厂（不放实例值） =====
// 放 protect、makeElement、makeStorage、构造器/工厂函数等复用代码。
// 不创建 window/document/location/screen/history 等具体实例，不写死宿主对象真值。

// ===== 02 window 区 =====
// 放 window 自身属性、方法、事件、performance、history、定时器、fetch/XHR 以及 WebRTC 全局构造器/对象。
// WebRTC 只在 trace 命中时补，例如 RTCPeerConnection、RTCSessionDescription、RTCIceCandidate、RTCDataChannel、MediaStream。
// 后续补环境统一挂在 window 上；除代理固定的 window = rtwatch(global, "window") 外，不再使用 global 作为补环境对象。

// ===== 03 document 区 =====
// 放 document 对象、DOM 节点/集合、document 方法和 document 返回对象。
// canvas、2D/WebGL context、audio、CSS 计算相关返回对象，均在 document 创建或返回对象的位置按证据处理。
// 不放 location/screen/history 顶层值；这些对象完成后再按证据建立必要的 window 引用。

// ===== 04 location 区 =====
// 只放 location 的 URL 字段和目标链路实际命中的跳转方法。
// 不默认补 location 的 prototype、constructor、toString 或其它外观，不把 location 值散落到其它对象区。

// ===== 05 navigator 区 =====
// 放 navigator 字段、子对象和 navigator 方法返回对象；plugins、mimeTypes、mediaDevices 归这里。
// getUserMedia、enumerateDevices 等设备访问入口只在 trace 命中时补。
// 不提前批量补无关指纹面；目标链路未触达的 device/plugin/mimeType 不写入。

// ===== 06 screen 区 =====
// 只放 screen 尺寸、颜色深度、orientation 等 screen 语义。
// 不把 screen 值混进 window 区或 navigator 区；未命中时保留空模板。

// ===== 07 storage 区 =====
// 只放 localStorage/sessionStorage 及其目标链路实际命中的 storage 方法和状态。
// document.cookie 归 document 区；不把业务参数缓存、token 派生逻辑或无证据 storage 值混进来。

// ===== 按证据就近落位的 iframe / Worker / MessageChannel 链路 =====
// 不设固定编号或固定位置，按实际触发来源放在相关对象区的紧邻子段。
// window 创建的 Worker：放 window 区的 Worker 子段；Worker 内部 self、message、MessagePort：放该 Worker 子段。
// document 创建的 iframe：放 document 区的 iframe 子段；iframe 的 contentWindow、contentDocument 和独立 realm：放该 iframe 子段。
// MessageChannel 归入实际所属的 window、iframe 或 Worker 通信子段；当前目标未命中时不创建、不补写。

// ===== 目标 JS =====
// 目标js

// ===== 稳定入口 =====
// 放 get_xxx(input)、module.exports、CLI JSON 桥接。
// 不在入口里继续补宿主对象。
```

落位规则：
- `window`、`document`、`location`、`navigator`、`screen` 是一级大区，不能合并成一个“基础环境”段；`history` 和 `performance` 都属于 `window` 上的属性，不单独创建对象区。
- `location` 值只在 `location 区` 定义；`screen` 值只在 `screen 区` 定义；`document` 节点、集合和方法只在 `document 区` 定义；`window` 自身字段、窗口方法、`performance`、`history` 和窗口事件只在 `window 区` 定义。
- helper / 工厂函数只放共享 helper 区；如果 helper 内需要引用 `location`、`navigator`、`window`，只能引用已定义对象，不得在 helper 区创建或写死这些对象的真值。
- 跨区引用允许，跨区定义不允许。例如 iframe 的 `contentWindow.location` 可以引用已定义的 location，但 iframe 自己的 Window/Document/realm 必须在 document 区的 iframe 子段按证据处理。
- 代理固定声明完成后，后续补环境不得再把属性、方法或对象写到代理底层全局对象；window 上的后续属性、方法和对象统一直接挂在 `window` 上。
- 如果使用 `installBaseEnvironment(input)` 统一初始化，也必须在函数内部按同一套大区拆分，或拆成 `installLocation(input)`、`installDocument(input)` 等区级函数；不得把多个宿主对象连续堆在一个无备注的大函数中。
- 一轮可以补多个环境项，也可以跨多个宿主大区；前提是这些修改属于同一个阻塞点、同一条检测链、同一个方法返回对象链路，或同一个目标参数产出链路。跨区时仍要保持各对象真值落在所属大区，禁止把多个无关宿主对象堆进一个无备注的大函数。

## 多入口命名

入口命名必须可读、稳定、和参数语义绑定：
- `get_h5st(input)`
- `get_a_bogus(input)`
- `get_black_box(input)`
- `get_sensor_data(input)`
- `get_vt(input)`
- `get_ticket(input)`
- `get_encrypt_payload(input)`
- `get_ws_frame(input)`

多目标项目中，每个 `runtime/*.code.js` 必须只负责一个参数族、验证码链、加密链或指纹链。`test.py` 负责编排调用顺序和真实请求，不允许 runtime 文件之间隐式互调；确实依赖时必须在 `param_info.md` 或 `逆向任务分析计划.md` 记录依赖关系。

## rtproxy 放置位置

默认将 `assets/rtproxy.js` 作为随 skill 打包的只读代理资产。目标项目只允许复制并引用项目内副本：

1. 直接把 `rtproxy.js` 复制到项目，在 `code.js` 顶部引用项目内副本
2. 如果历史项目已经内联代理，必须先记录为代理资产差异；不得为了降噪继续改写、拆分或简化内联代码

不允许凭记忆手写简化版 proxy 骨架，也不允许为了降低日志噪声改变代理形态。复制后必须保留以下能力：
- `rt_loginfo` / `rt_log`
- `proxylog.txt` 固定代理事件日志；每次运行覆盖上一份，不默认创建多份历史日志
- `rtwatch(obj, name)` 只用于基础 BOM/DOM 宿主对象及其直接返回对象的轻量观察；默认只保留 `get`、`set`、`has` 这类基础面，方法入参必须由 `rt_log` 显式打印
- `fun_to_native(fn)`
- `Function.prototype.toString` 保护

`assets/rtproxy.js` 不允许做的事：
- 不得修改 Proxy trap、target/receiver、返回值包装、缓存、路径、事件顺序、日志 schema、序列化或异常处理来降低日志噪声
- 不创建 `window/document/location/navigator/screen/history/storage/performance` 等宿主对象
- top 代理模板底部的固定宿主对象声明必须原样保留；正式补环境只能写在声明之后的对应对象区，不得修改代理、回写 `{}` 或后面换壳
- 不递归包装返回值或普通子对象
- 不默认启用 `getOwnPropertyDescriptor/getPrototypeOf/defineProperty/setPrototypeOf/apply/construct` 等重 trap

`proxylog.txt` 规则：
- 默认写入当前工作目录的 `proxylog.txt`；只有多个 JS/runtime 入口分别补环境和分析日志时，且代理已有机制支持，才允许使用不同固定 `.txt` 文件名
- 启动时覆盖清空上一份，本轮按 `assets/rtproxy.js` 的文本格式追加写入
- 写入前不得抽样、过滤、去重或静默丢弃 `rtwatch` / Proxy trap / `rt_log` 事件；写入后允许用独立分析层生成降噪视图
- 序列化失败、循环引用、函数、Symbol、getter/setter、DOM-like 对象等必须写入占位和结构信息，不能跳过整条日志
- 该文件只用于当前轮缺口观察，不替代 `ruyitrace/` 真值证据

## Node 宿主对象包装与落位

宿主对象必须沿用代理模板的 `rtwatch({}, name)` 结构，并在对应宿主对象区内按目标链路分批填充。环境真值必须直接写入这对大括号内部，不能先定义任何自定义占位变量，也不能在对象初始化后用 `location.href = ...`、`document.URL = ...` 这类方式散补。

```js
document = rtwatch({
    getElementById:function(aaa){
        rt_log('document.getElementById',aaa)
    },
}, "document");

fun_to_native(document.getElementById);

// location 区：如果 trace 命中 href、origin 等字段，直接填入 rtwatch({}, "location") 的大括号内部。
location = rtwatch({}, "location");

// 按目标链路补必要的 window 别名引用，不新建宿主对象
window.document = document;
```

不得把上面这些补环境内容集中堆在一个无分区的 `installBaseEnvironment()` 中。对象方法、descriptor/prototype 修正、返回对象和入参日志都要落在对应大区；必要的 window 别名引用只能在各宿主对象完成后按目标链路补入。项目代码中必须直接填入当前 `ruyitrace` 的真实值，不能保留提示文字、变量名或自行猜测值。

方法返回对象不默认继续包装。只有满足“基础 DOM/BOM 直接返回对象 + 目标链路继续读取 + ruyitrace/jscall 有证据”三个条件，才在返回点显式包装，例如：
- `document.createElement(...)`
- `document.querySelector(...)`
- `document.getElementsByTagName(...)`
- `navigator.connection`
- `navigator.userAgentData`
- `performance.memory`
- `canvas.getContext('2d')`
- `canvas.getContext('webgl')`
- `permissions.query(...)`
- `Worker` / `MessageChannel` 返回对象

## 事件与 Worker 结构

事件和 Worker 相关对象只能按目标链路证据补：
- listener 注册顺序、触发顺序、回调入参和返回副作用必须来自匹配当前目标的 `ruyitrace/`
- 事件对象必须按证据补 `type`、`target`、`currentTarget`、`timeStamp`、坐标、按键、触点、`isTrusted` 外观、`preventDefault` / `stopPropagation` 行为
- `postMessage`、`MessageEvent.data`、`origin`、`source`、`ports`、transferable 对象和 structured clone 必须按 trace 证据收敛
- 异步时序必须按 `event/`、`jscall` 调用栈和请求边界确认，不得只靠本地能跑通

专项重点：
- `document.all`、`iframe` / `window` 关系、`Worker` / `SharedWorker` / `MessageChannel` 通信是高优先级检测点，`ruyitrace/domtrace` 命中时先处理它们
- `iframe.contentWindow`、`iframe.contentDocument`、`frameElement`、`window.parent`、`window.top`、`window.self` 等不是说明项，必须分清 top window、parent window、frame window、frame document、iframe element 的对象身份和引用关系；涉及目标链路时按 `ruyitrace/domtrace` 真值补齐并交付
- `document.all` 优先走 V8/native undetectable 特殊路径，Node 层不要求完美浏览器实现，但不能直接补成普通对象、`Proxy`、getter、`valueOf` 或 `Symbol.toPrimitive` 兼容层；实现后不得再套普通 `rtwatch`
- `Worker` 不能只做同步假回调；`iframe` 不能只返回一个空壳 window
- 命中这些点时，直接回到当前目标匹配的 `ruyitrace/domtrace/jscall` 证据，确认真实检测语义后再决定是否进入正式补环境

`document.all` 最小底座路线：

```js
const v8 = require("v8");
const vm = require("vm");

v8.setFlagsFromString("--allow-natives-syntax");
const documentAll = vm.runInThisContext("%GetUndetectable()");
v8.setFlagsFromString("--no-allow-natives-syntax");
```

该对象只解决 `[[IsHTMLDDA]]` / undetectable 底座问题；`length`、索引、调用、`item()`、`namedItem()` 按目标实际检测点、当前 document 状态和 trace 证据尽量还原，并记录已覆盖/未覆盖范围。

## 方法入参日志

每个目标链路内的方法必须显式打印入参，不能只依赖属性 `get` 日志；方法定义后必须在同一大区紧跟 `fun_to_native`：

```js
// document 区
document = rtwatch({
  createElement: function createElement(ele) {
    rt_log("document.createElement", ele);
    // ...
  },
}, "document");

fun_to_native(document.createElement);
```

入参日志用于定位缺口，不是真值来源。准备写入的环境值、descriptor、prototype、异常外观、方法返回对象和事件时序仍必须回到匹配当前目标的 `ruyitrace/` 查证。

## native toString 保护

`Function.prototype.toString` 保护和 `fun_to_native(fn)` 底座直接使用 `assets/rtproxy.js` 模板。每个补出的浏览器宿主方法、构造器和 native-like 函数都必须做 `toString` 保护；方法在哪个大区定义，`fun_to_native(fn)` 就紧跟在同一个大区、同一个对象定义后面。

禁止：
- 文件末尾统一堆一个无分区的 `fun_to_native(...)` 大名单
- 在 `// 目标js` 之后补 `toString` 保护
- 在 document 区保护 location/navigator/storage 等其它大区的方法

允许：
- 构造器和原型链方法在其所属宿主对象区、对应原型链定义之后紧邻收口保护
- getter/setter 函数在定义 descriptor 的同一区紧跟保护

必须覆盖：
- `fn.toString()`
- `Function.prototype.toString.call(fn)`
- `fn.toString.toString()`
- `Function.prototype.toString.toString()`

方法尽量使用命名函数，保证 native-like 字符串名称合理。

## VMP 禁区

目标 JS、VMP 或混淆逻辑应保持语义不被探针污染：
- 不得把补环境代码插进 `// 目标js` 后面的目标逻辑内部
- 不得在 VMP / VM 解释器 / opcode handler / 字节码分发层做补环境
- 不得向 VMP 内部下探针、插日志、加 Proxy、改 handler、改 opcode、改字节码或改解释器执行语义
- 如果推进路线必须依赖 VMP 插装才能继续，停止该路线，回到外围 `jscall`、`ruyitrace/`、`rtwatch` 和 `rt_log` 证据

## 稳定入口

交付版必须提供稳定入口：

```js
function get_xxx(input) {
  // normalize input
  // call target function
  // return structured result
}

module.exports = { get_xxx };

if (require.main === module) {
  const input = JSON.parse(process.argv[2] || "{}");
  process.stdout.write(JSON.stringify(get_xxx(input)));
}
```

入口规则：
- 入参结构必须记录到 `param_info.md`
- 输出必须是结构化 JSON，不依赖交互式控制台
- `test.py` 必须调用稳定入口并负责真实请求验证
- 交付前可以关闭控制台高噪声回显，保留可按开关启用的排错日志；不得修改代理形态或原始日志事件来降噪
## 对象字面量填充硬规则

基础 DOM/BOM 宿主对象必须在对应大区内用对象字面量一次性创建并包进 `rtwatch`：

```js
document = rtwatch({
    getElementById:function(aaa){
        rt_log('document.getElementById',aaa)
    },
}, "document");
```

规则：
- `rtwatch({}, "document")` 是未填充的对象字面量模板；正式补环境时必须把真实字段、方法和状态直接填进这对大括号内部。也不允许修改 `assets/rtproxy.js`。
- 同一个宿主对象只允许一次最终赋值；后续只能在同一区紧邻位置对同一个对象做 `Object.defineProperty`、`Object.setPrototypeOf`、`fun_to_native` 等收口动作，不能跨区换壳。
- window 别名引用只做已有对象指向，例如 `window.document = document`；不在别名引用位置新建对象或补真实字段。
- 代理模板里的 `document = rtwatch({}, "document")` 是空模板，正式补环境时直接把真实字段和方法填入这对大括号；如果代理能力无法满足目标需求，记录代理资产/固定骨架缺口并暂停。
