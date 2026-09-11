# 特殊环境检测专项清单

本文档用于处理不能按普通字段补环境的特殊检测。它不是浏览器 API 总目录，也不是自动补环境方案；只有当前目标链路的 `rtwatch` / `proxylog.txt` 观察和匹配当前目标的 `ruyitrace` 证据命中特殊检测时，才读取对应章节。

## 总原则

特殊检测统一按以下顺序处理：

```text
本地首轮运行
→ rtwatch / proxylog.txt 发现特殊缺口
→ ruyitrace 确认真实值、真实外观和检测语义
→ 判断属于哪个专项
→ 明确最小补环境范围
→ 按同一检测链补多个关联环境项
→ 重新运行并验证检测点、目标链路和参数可用性
```

每个专项分析至少写清：

```text
缺什么：
如何检测：
trace 依据：
补到哪里：
补完验证什么：
```

专项补环境必须满足：

- `rtwatch` / `proxylog.txt` 只负责发现本地缺口，不提供浏览器真值。
- `ruyitrace` 必须说明目标 JS 实际做了什么检测；不能只看到 API 名称就套用通用实现。
- 同一检测链可以一批补多个环境项，例如对象、返回对象、descriptor、原型、身份关系和异步时序。
- 未被当前目标检测到的语义不提前补；证据不足时记录缺口并暂停该专项。
- 不能用同步假回调、固定返回值、空对象、全局 Proxy 或 trace 中已有目标值伪装完成。
- 出现本地输出后，先检查参数格式、结构、长度和后续可用性；有输出不等于专项通过。

## 触发与暂停

### 触发条件

命中以下任一情况时，读取对应章节：

- `document.all`、HTML 集合特殊行为或 `typeof` / 布尔 / 宽松相等检测；
- `iframe`、`contentWindow`、`contentDocument`、`defaultView`、`parent`、`top`、`self` 或跨 realm 身份；
- iframe 创建、文档初始化、脚本加载、`DOMContentLoaded` / `load`、`postMessage` 或 Worker 消息的相对时序、完成速度或等待状态；
- `Worker`、`SharedWorker`、`MessageChannel`、`MessagePort`、`postMessage` 或消息事件；
- 主线程、iframe 和 Worker 的全局对象边界，或 Worker 对 `window`、`document`、`localStorage`、`sessionStorage` 等页面 API 的访问；
- `CSS.supports`、`getComputedStyle`、style 属性、媒体查询、布局尺寸或 CSS 计算结果；
- DOM 结构读取、节点插入/删除、`document.write`、页面清理或结构变化后的再次检测；
- 动态创建 `a` 标签、URL 规范化、`href` / `host` / `hostname` / `pathname` 与 `location` 对照；
- 浏览器能力探测、对象存在性、构造器/原型检查或 Promise 异步返回对象；
- `performance.memory`、堆统计读取或内存快照与 DOM/对象生命周期关联；
- `canvas`、Canvas 2D、`toDataURL`、`getImageData`、WebGL、扩展和渲染参数；
- `navigator.plugins`、`navigator.mimeTypes`、权限、媒体能力或其它集合/能力探测；
- 事件 listener、timer、microtask、MutationObserver、脚本加载或异步回调顺序；
- 鼠标移动、进入、离开、按下等交互事件及其状态累积；
- WebAssembly、动态载荷、Worker/WASM 入口或 JS 胶水层宿主能力。

### 暂停条件

- trace 只能证明 API 被调用，不能说明返回值、检测分支或时序；
- 需要猜测消息队列、跨 realm 身份、CSS 布局、渲染结果或特殊内部槽位；
- 本地能运行但参数长度、结构或请求边界明显异常；
- 继续推进需要 VMP/opcode 插装、全局 VM Proxy 或修改代理资产；
- 当前专项已经不再阻塞目标产出，却想继续扩展成完整浏览器。

## 1. document.all / HTMLAllCollection

### 触发条件

trace 命中 `document.all`，或目标 JS 对它进行属性读取、调用、枚举、比较、类型判断、索引访问或命名查找。

### 检测语义

重点确认目标 JS 实际命中了哪些语义：

- `typeof document.all`；
- `Boolean(document.all)` 或条件分支；
- `document.all == null`、与 `undefined` 的宽松比较；
- `document.all === undefined` 等严格比较；
- `document.all.length`；
- 数字索引、`item(index)`、`namedItem(name)`；
- 直接调用 `document.all(name)`；
- `Object.prototype.toString`、`Object.keys`、属性枚举或身份稳定性。

`HTMLAllCollection` 具有浏览器遗留的特殊内部语义，不能按普通对象处理。命中时，普通对象、`undefined`、普通函数和普通 Proxy 都不能直接替代完整语义。

### 最小补法

- 只实现 trace 实际命中的检测面，不默认实现完整 HTML 集合。
- Node/V8 路线优先使用 undetectable 底座。项目需要时可按以下方式获取底座：

```js
const v8 = require("v8");
const vm = require("vm");

v8.setFlagsFromString("--allow-natives-syntax");
const undetectableBase = vm.runInThisContext("%GetUndetectable()");
v8.setFlagsFromString("--noallow-natives-syntax");
```

- `undetectableBase` 只作为 `document.all` 的特殊底座使用，不得作为普通对象、普通函数、全局 Proxy 或其它宿主对象的通用底座。
- 使用这条路线前，必须先在当前 Node/V8 版本中验证 `%GetUndetectable()` 是否可用；不可用时不能伪造成功，必须记录当前执行层无法完整覆盖的检测语义。
- 获取底座后，再按 trace 对 `length`、数字索引、命名项、`item()`、`namedItem()`、调用行为和稳定身份做最小补充；底座本身不能替代这些 HTML 集合语义。
- 按 trace 补集合长度、索引、命名项、`item()`、`namedItem()`、调用行为和稳定身份。
- `document.all` 的对象引用必须稳定；重复读取不能每次返回新对象。
- 如果只能覆盖部分特殊语义，明确记录已覆盖和未覆盖的检测点。

### 验证

- 本地 `typeof`、布尔转换、比较、索引和调用结果与 trace 命中的语义一致；
- 目标 JS 越过对应分支；
- 参数实时输出，格式和长度没有明显异常。

### 禁止

- `document.all = {}`；
- `document.all = undefined`；
- 用普通函数伪装全部行为；
- 只让 `typeof` 看起来正确，却不实现后续已命中的集合行为。

## 2. iframe / window / realm 身份

### 触发条件

trace 命中 iframe 创建、`contentWindow`、`contentDocument`、`defaultView`、`frameElement`、`parent`、`top`、`self`、`window` 或跨 realm 比较。

### 检测语义

确认目标 JS 是否检查：

- `iframe.contentWindow === iframe.contentWindow`；
- `iframe.contentDocument.defaultView === iframe.contentWindow`；
- `child.parent === parentWindow`；
- `child.top === topWindow`；
- `child.self === child`；
- `child.frameElement === iframe`；
- `document.defaultView`、`window.document` 的回指；
- `instanceof`、构造器、原型链或 `Object.prototype.toString`；
- iframe load、script 执行和 postMessage 时序；
- 同源/跨源访问失败或异常外观。

### 最小补法

- 明确区分 iframe 元素、frame window、frame document、top window 和 parent window。
- 为每个关系建立稳定引用，不要每次 getter 都新建对象。
- `contentWindow`、`contentDocument`、`defaultView`、`parent`、`top`、`self`、`window`、`frameElement` 只补 trace 命中的关系。
- 如果目标只检查身份关系，不要顺手实现完整 iframe DOM。
- 如果目标检查跨 realm 原型或 `instanceof`，按实际 realm 建立最小原型关系。
- iframe 的脚本加载、load 事件和 postMessage 必须按 trace 时序处理。

### 验证

- 重复读取关系保持稳定；
- 所有命中的 `===`、`instanceof`、constructor、tag 和异常分支与 trace 一致；
- iframe load 或消息顺序能推动目标链路继续执行。

### 禁止

- 所有 window 都指向同一个对象；
- 每次读取 `contentWindow` / `contentDocument` 都返回新对象；
- 用普通空对象代替 frame realm；
- 在 iframe 创建或 append 时提前执行目标脚本。

## 3. DOM 结构变更与页面清理

### 触发条件

trace 命中 DOM 节点、集合、页面结构或节点修改，并且修改前后结果可能参与目标参数或环境判断。

### 检测语义

确认目标 JS 是否执行：

- `document.documentElement`、`head`、`body`、`script`、`meta` 等节点读取；
- `createElement`、`appendChild`、`removeChild`、`remove`、`insertBefore` 等节点操作；
- `getElementsByTagName`、`querySelector`、`querySelectorAll`、`children`、`childNodes`；
- 读取节点属性、`innerHTML`、`outerHTML`、`textContent`、`style` 或 `parentNode`；
- 读取 meta 内容后删除节点；
- 删除 head 下的 script 或其它节点后再次读取页面结构；
- `document.write`、自动创建 body 或文档结构变化后的二次检测；
- 节点、集合和父子关系是否保持稳定。

### 最小补法

- 先按 trace 建立当前检测需要的最小文档树，不实现完整 DOM。
- 节点创建、插入、删除和查询必须维护目标链路实际读取的父子关系、顺序和集合内容。
- 如果目标只检查节点存在性或某个属性，只补该检测面；如果修改后再次读取，就补对应状态变化。
- `document.write` 只实现当前链路需要的文档变化和执行时机。
- 返回的节点和集合保持稳定身份；同一查询是否返回同一对象由 trace 决定。

### 验证与禁止

- 验证修改前后节点、集合、属性和父子关系是否推动目标分支；
- 验证删除、插入和 `document.write` 的顺序；
- 禁止用固定节点数量、空集合或静态 HTML 结果代替动态结构；
- 禁止在节点创建或插入时提前执行目标脚本。

## 4. URL / a 标签解析与 location 对照

### 触发条件

trace 命中动态创建 `a` 标签、设置 `href`、读取 URL 拆分字段，或将这些字段与 `location` 对比。

### 检测语义

确认目标 JS 是否读取：

- `a.href` 的绝对化和规范化结果；
- `protocol`、`host`、`hostname`、`port`、`pathname`、`search`、`hash`；
- 相对 URL、协议相对 URL、编码字符、默认端口和路径末尾斜杠；
- `location.href`、`origin`、`host`、`hostname`、`pathname` 等字段；
- `a` 标签解析结果和 `location` 字段之间的相等、差异或分支关系；
- URL 修改后再次读取是否保持规范化结果。

### 最小补法

- 使用当前目标输入和 trace 对应的页面 URL 作为解析基准。
- 让 `a.href`、`location` 和 URL 拆分字段按照同一规范化规则派生，不分别硬编码互相矛盾的值。
- 只补目标实际读取的字段和相对 URL 解析关系。
- 如果需要动态创建 `a` 标签，将它作为 DOM 结构链的一部分放入 document 区，并保持属性读取语义。

### 验证与禁止

- 验证相对 URL、绝对 URL、默认端口、编码和路径规范化；
- 验证 `a` 标签字段与 `location` 对照结果；
- 验证 URL 字段进入目标参数后的格式和长度；
- 禁止只设置 `href` 原字符串而不实现规范化字段；
- 禁止分别写死 `a` 标签和 `location` 的互相矛盾结果。

## 5. 浏览器能力探测与异步返回对象

### 触发条件

trace 命中 API 是否存在、构造器是否存在、对象类型/原型检查、能力方法调用或 Promise 异步返回对象。

### 检测语义

区分以下情况：

- `typeof`、属性存在性、`in`、`hasOwnProperty`；
- 构造器、`instanceof`、prototype、`constructor` 或 `toString`；
- 能力方法调用是否成功、抛出什么异常或返回什么类型；
- Promise 是否异步完成、回调/then 顺序和返回对象字段；
- 返回对象的属性、状态、枚举和身份稳定性；
- 能力结果是否参与分支、环境参数或请求参数。

### 最小补法

- 先按 trace 确认目标检测的是“不存在”、 “存在但不可调用”、 “调用成功”还是“返回对象语义”。
- 只补当前链路命中的能力和返回对象，不批量暴露 Node 或浏览器 API。
- 异步能力必须按 trace 恢复 Promise、回调顺序、返回对象状态和字段读取。
- 如果目标检查对象类型或原型，按专项原型规则建立最小关系。
- 如果某能力在当前 Node 执行层无法可靠模拟，记录覆盖边界并暂停，不用固定结果伪造。

### 验证与禁止

- 验证存在性、调用结果、异常、Promise 时序、返回对象字段和目标分支；
- 验证结果由当前输入实时产生；
- 禁止把所有能力方法都返回 `true`；
- 禁止把异步返回对象替换成同步普通对象；
- 禁止为了通过 `instanceof` 只补一个空 prototype。

## 6. performance.memory / 动态堆统计

### 触发条件

trace 命中 `performance.memory`、`jsHeapSizeLimit`、`totalJSHeapSize`、`usedJSHeapSize`，或目标参数会读取这些值并参与环境判断、指纹拼接或签名输入。

### 检测语义

确认目标 JS 是否：

- 直接读取 `performance.memory`；
- 连续读取三个字段并要求它们属于同一时间快照；
- 多次读取并比较数值变化；
- 在 DOM 创建、插入、删除、样式计算或其它对象分配前后读取；
- 检查属性归属、descriptor、`Symbol.toStringTag` 或对象身份；
- 将数值编码、取整、拼接或 hash 后进入目标参数。

`performance.memory` 是非标准、浏览器相关的兼容属性，不能把某一组浏览器样本固定写入 Node。Node/V8 的 `getHeapStatistics()` 可以提供当前执行进程的堆统计，但它与浏览器页面的内存统计并不完全等价；应把它作为当前 Node 执行层的动态来源，而不是声称还原了浏览器真实内存。

### 推荐补法

使用当前项目可用的 V8 统计接口，按短时间窗口缓存同一份快照，避免连续读取三个字段时彼此不一致：

```js
const v8 = require("v8");

let memorySnapshot = null;
let memorySnapshotTime = 0;

function getMemorySnapshot() {
  const now = Date.now();
  if (memorySnapshot === null || now - memorySnapshotTime >= 100) {
    const heap = v8.getHeapStatistics();
    memorySnapshot = {
      jsHeapSizeLimit: heap.heap_size_limit,
      totalJSHeapSize: heap.total_heap_size,
      usedJSHeapSize: heap.used_heap_size,
    };
    memorySnapshotTime = now;
  }
  return memorySnapshot;
}

const memory = {};
Object.defineProperties(memory, {
  jsHeapSizeLimit: {
    enumerable: true,
    configurable: true,
    get() {
      return getMemorySnapshot().jsHeapSizeLimit;
    },
  },
  totalJSHeapSize: {
    enumerable: true,
    configurable: true,
    get() {
      return getMemorySnapshot().totalJSHeapSize;
    },
  },
  usedJSHeapSize: {
    enumerable: true,
    configurable: true,
    get() {
      return getMemorySnapshot().usedJSHeapSize;
    },
  },
  [Symbol.toStringTag]: {
    value: "MemoryInfo",
    writable: false,
    enumerable: false,
    configurable: true,
  },
});
```

接入正式项目时，`memory` 必须放在 `performance` 区，`performance.memory` 使用稳定引用；不能每次读取都创建新对象。若项目已有统一的 V8 封装，可以用该封装替换示例中的 `v8`，但必须保持动态统计和快照一致性。

### 重要边界

- `jsHeapSizeLimit` 通常相对稳定；`totalJSHeapSize` 和 `usedJSHeapSize` 应来自当前运行时，不得固定成浏览器样本。
- DOM 增删改可能通过真实对象分配、缓存和垃圾回收影响统计，但不保证每次操作立即变化；不要手动给 DOM 操作绑定固定的内存增量。
- 100ms 只是同轮读取的一致性窗口，不是浏览器标准时间，也不是用来制造变化的随机机制。
- 如果目标检查的是数值变化，必须让变化来自当前 Node 执行产生的真实分配和回收；不能用随机数或人为递增。
- 如果 Node/V8 统计与目标链路明显不匹配，记录为执行层差异，不能把固定值写入代码冒充浏览器内存。

### 验证与禁止

- 验证连续读取三个字段时来自同一快照；
- 验证跨越快照窗口后可以重新读取当前堆统计；
- 验证 DOM/对象操作后的数值由真实运行状态产生，不能要求每次都单调变化；
- 验证 `performance.memory` 对象、字段 descriptor 和 `Symbol.toStringTag` 符合目标检测语义；
- 禁止固定值、随机值、旧 trace 数值和按 DOM 操作手工加减内存；
- 禁止将 `performance.memory` 的 Node 数值宣称为浏览器完全一致的内存真值。

## 7. Worker / SharedWorker / MessageChannel

### 触发条件

trace 命中 `Worker`、`SharedWorker`、`MessageChannel`、`MessagePort`、`postMessage`、`onmessage`、`addEventListener("message")` 或消息事件对象。

### 检测语义

至少确认：

- Worker 脚本 URL、脚本 hash 和初始化入参；
- 主线程发送消息的顺序和消息内容；
- Worker 返回消息的顺序和返回内容；
- `MessageEvent.data`、`origin`、`source`、`ports`；
- `MessagePort.start()`、`close()`、`postMessage()` 和 listener 注册顺序；
- structured clone、transferable 和 ArrayBuffer 所有权变化；
- timer、Promise、microtask、事件任务之间的相对顺序；
- 是否存在心跳、ACK、重试、超时或重连；
- 消息返回值如何进入目标参数或请求边界。

### 最小补法

- 先恢复当前目标实际使用的 Worker/Port 拓扑，再补消息行为。
- 只实现目标链路命中的消息类型、入参、返回值、source/ports 和异步顺序。
- `MessageEvent` 的引用关系和字段形态按 trace 复现。
- Worker 内部的 `self` 只补目标脚本实际读取的宿主能力。
- 需要 structured clone 或 transferable 时，验证数据是否被复制或转移，而不是直接复用同一引用。
- 消息链只服务于目标值、reload 请求面或请求边界。

### 验证

- 消息数量、方向、顺序和关键字段与 trace 一致；
- listener 回调收到的 `data/source/ports` 形态可用；
- Worker 返回值进入目标参数或请求组装；
- 没有用固定旧消息或同步假回调产出结果。

### 禁止

- 猜测式消息队列；
- `localDeliver`、同步直接调用回调；
- 伪造 `source` / `ports`；
- 把 Worker 内部所有 API 一次性补全；
- 把 trace 中旧的 Worker 返回值直接写成本地结果。

## 8. CSS 能力与计算结果

### 触发条件

trace 命中 CSS 能力探测、样式读取、计算样式、媒体查询、布局尺寸或 CSS 解析结果。

### 检测语义

区分以下检测：

- `CSS.supports(property, value)`；
- `CSS.supports(conditionText)`；
- `style.setProperty`、直接设置 style 属性、读取 `style.cssText`；
- `getComputedStyle(element)`；
- 读取 `display`、`position`、`width`、`height`、`transform`、`font`、颜色等计算结果；
- `matchMedia(query).matches`、`media` 和 change 事件；
- `offsetWidth`、`offsetHeight`、`clientWidth`、`clientHeight`、`getBoundingClientRect()`；
- 伪元素、继承、默认样式、CSS 自定义属性和变量；
- CSS 属性是否被解析、规范化、序列化或丢弃。

### 最小补法

- 先明确目标是在检测“是否支持”，还是读取“计算后的结果”。
- `CSS.supports` 只补 trace 命中的属性/值和返回布尔语义，不实现完整 CSS 解析器。
- `getComputedStyle` 只补目标读取的属性和依赖的最小计算关系；返回对象的读取方式、长度、枚举和稳定性按 trace 处理。
- 布局尺寸只在目标链路确实读取时补；需要时建立元素尺寸、父子关系和样式影响的最小模型。
- `matchMedia` 只补命中的查询、`matches` 和事件时序。
- CSS 自定义属性、继承和变量只在 trace 证明会影响目标结果时补。

### 验证

- `CSS.supports` 的真假和异常行为与 trace 一致；
- 计算样式、媒体查询或尺寸读取能推动目标分支；
- 返回对象属性读取、枚举和身份稳定；
- 参数实时输出没有因 CSS 分支缺失产生明显格式或长度异常。

### 禁止

- 用固定 `true` 通过所有 `CSS.supports`；
- 用空对象代替 `getComputedStyle`；
- 返回与元素、父节点和样式状态无关的固定尺寸；
- 为一个 CSS 检测实现完整浏览器布局引擎。

## 9. Canvas 2D / Canvas 指纹

### 触发条件

trace 命中 `canvas`、`getContext("2d")`、绘制方法、文字测量、像素读取、`toDataURL` 或 `toBlob`。

### 检测语义

确认目标实际使用：

- canvas 宽高、属性读取和上下文类型；
- `fillText`、`strokeText`、路径、渐变、变换、合成和裁剪；
- 字体、字号、baseline、抗锯齿相关输入；
- `measureText()` 返回对象和宽度；
- `getImageData()` 的像素内容；
- `toDataURL()` / `toBlob()` 的格式、参数和输出；
- 绘制调用顺序、状态栈和上下文状态。

### 最小补法

- 先按调用序列恢复目标实际绘制操作和状态，不先做通用 Canvas。
- 只实现被读取的返回值、像素区域或编码输出。
- 同一 canvas 的上下文和状态保持稳定。
- 需要像素或编码一致时，明确 Node 图形后端、字体和编码差异；无法一致时暂停，不用固定旧值冒充。

### 验证

- 绘制调用、参数和状态顺序与 trace 一致；
- `measureText`、像素或 `toDataURL` 输出结构和长度合理；
- 输出确实由当前输入实时生成，而不是复用旧截图、旧 data URL 或旧响应。

### 禁止

- 只返回固定 data URL；
- 只实现 `getContext` 空对象；
- 用旧 trace 的 canvas 指纹直接写入本地；
- 在基础链路未确认触达前批量补 Canvas。

## 10. WebGL / GPU 能力

### 触发条件

trace 命中 WebGL 上下文、扩展、参数查询、着色器、纹理、帧缓冲或像素读取。

### 检测语义

区分：

- `getContext("webgl")` / `webgl2`；
- `getParameter()` 的具体枚举；
- `getSupportedExtensions()`、`getExtension()`；
- shader 编译、program/link 状态；
- buffer、texture、framebuffer、viewport 和 clear；
- `readPixels()`；
- `WEBGL_debug_renderer_info` 等扩展；
- WebGL 对象的类型、身份、native 外观和异常。

### 最小补法

- 只补当前目标查询的参数、扩展或渲染调用。
- 如果只是能力探测，优先补返回类型、布尔值和枚举集合。
- 如果读取 GPU/渲染结果，必须根据当前运行环境重新生成，不能填旧设备值。
- WebGL 上下文、资源对象和扩展对象保持目标需要的身份稳定。

### 验证

- 上下文类型、能力列表、关键参数和调用顺序合理；
- 目标参数长度、结构和后续分支不再明显异常；
- 本地输出不是从 trace 或旧响应复制。

### 禁止

- 默认返回完整 GPU 能力列表；
- 固定伪造显卡厂商、渲染器或扩展；
- 只让 `getContext` 不报错，却不补后续已命中的查询；
- 在没有 trace 触达证据时提前补 WebGL。

## 11. plugins / mimeTypes / 能力集合

### 触发条件

trace 命中 `navigator.plugins`、`navigator.mimeTypes`、索引、命名属性、迭代、长度或对象身份。

### 最小补法

- 只补目标读取的集合长度、索引项、命名项、类型和迭代行为。
- 保持 plugins、mimeTypes、plugin、mimeType 之间的引用关系。
- 按 trace 处理 `item()`、`namedItem()`、`length`、`Object.keys` 和 `instanceof`。

### 验证与禁止

- 验证集合读取、枚举、身份和目标分支；
- 禁止返回空集合后声称浏览器环境完整；
- 禁止批量复制固定设备插件列表。

## 12. 事件、定时器与异步时序

### 触发条件

trace 命中 `addEventListener`、事件派发、`setTimeout`、`setInterval`、Promise、microtask、MutationObserver、脚本 load 或异步回调。

### 检测语义

确认：

- listener 注册和触发顺序；
- `target`、`currentTarget`、事件字段和回调入参；
- timer、Promise、microtask、message、MutationObserver 的相对顺序；
- 状态在回调前后的写入和读取；
- 回调是否只触发一次、是否可取消、是否受异常影响；
- 异步结果如何进入目标参数。

### 最小补法

- 按 trace 复现当前链路需要的最小任务顺序和状态变化。
- 只建立目标链路实际使用的事件类型、listener 和回调。
- 保持事件对象和回调对象的引用关系。
- 执行时机错误时，优先调整执行模型，不继续堆字段。

### 验证与禁止

- 验证顺序、次数、入参和状态变化；
- 禁止同步假回调代替异步链；
- 禁止猜测任务队列；
- 禁止为通过一次运行而提前执行目标脚本。

## 13. 鼠标事件与交互状态累积

### 触发条件

trace 命中鼠标移动、进入、离开、按下、抬起、点击或坐标/按钮/修饰键字段，并且事件状态参与目标参数或业务分支。

### 检测语义

确认目标 JS 是否读取或累积：

- `clientX`、`clientY`、`pageX`、`pageY`、`screenX`、`screenY`；
- `button`、`buttons`、`which`、`detail`、`movementX`、`movementY`；
- `altKey`、`ctrlKey`、`shiftKey`、`metaKey`；
- `target`、`currentTarget`、`relatedTarget`；
- `mouseenter`、`mouseleave`、`mouseover`、`mouseout`、`mousemove`、`mousedown`、`mouseup`、`click` 的顺序；
- 移动距离、停留时间、事件计数、轨迹数组、最后一次坐标和状态清理；
- 事件状态如何进入 cookie、token、签名输入或请求参数。

### 最小补法

- 按 trace 的实际事件类型、顺序、字段和时间关系建立最小事件链。
- 只记录目标链路实际使用的坐标、按钮、修饰键和轨迹状态。
- 状态累积必须由当前事件输入实时生成，不能直接填旧轨迹或固定计数。
- 事件对象、target/currentTarget 和回调状态保持 trace 要求的身份关系。
- 事件触发时机不一致时，先修正调度和事件顺序，不继续批量补字段。

### 验证与禁止

- 验证事件顺序、次数、字段、轨迹状态和最终参数变化；
- 验证相同输入能够稳定产生合理的状态和参数长度；
- 禁止用固定鼠标轨迹、固定坐标或固定事件计数冒充交互状态；
- 禁止同步触发所有事件或跳过中间事件；
- 禁止在没有 trace 证明时自行设计鼠标轨迹算法。

## 14. WASM / 动态载荷 / JS 胶水层

### 触发条件

trace 或目标 JS 命中 `.wasm`、`WebAssembly.instantiate`、`instantiateStreaming`、wasm-bindgen、Emscripten、ArrayBuffer/字节数组载荷、eval、`new Function` 或 Worker/WASM 动态执行。

### 检测语义

确认：

- wasm/载荷来源、hash 和版本材料；
- JS 胶水层如何获取 imports、memory、table、exports；
- 动态载荷何时下载、解码、执行和缓存；
- 环境 API 在胶水层还是载荷外围被读取；
- 最终返回值如何进入目标参数或请求边界；
- 是否存在多版本或多 trace 分歧。

### 最小补法

- 优先补 JS 胶水层和 `importObject` 需要的宿主能力。
- 只补外围环境、入口入参、返回值和请求边界，不改 wasm 二进制，不在 VM/opcode 层插装。
- 记录版本风险；单 trace 通过只代表当前版本可用。
- 载荷或脚本版本变化导致读取面变化时，拆分 runtime 或暂停重新取证。

### 验证与禁止

- 验证本地动态载荷由当前输入实时加载/执行；
- 验证入口、返回值、参数长度和请求边界；
- 禁止把旧 payload、旧 wasm 返回值或旧成功响应写成本地结果；
- 禁止 VMP 插装、opcode hook、解释器 Proxy 或改写执行语义。

## 15. 执行速度与任务调度时序

### 触发条件

trace 命中 iframe 创建到文档可用、脚本加载、`DOMContentLoaded`、`load`、Worker 启动、`postMessage` / `onmessage` 或其它异步任务的相对时序，并且本地执行明显快于浏览器，或目标 JS 依赖某个任务完成后再继续执行。

### 检测语义

确认目标 JS 实际检测的是哪一种语义：

- iframe 创建后，`contentWindow` / `contentDocument` 何时可读；
- 子 Window、Document 和必要脚本何时完成初始化；
- `script` append、脚本执行、文档状态变化、`DOMContentLoaded` 和 `load` 的先后关系；
- 主线程继续执行前，是否必须等待 iframe `load`、Worker 启动或某个消息返回；
- `postMessage`、Worker `onmessage`、Promise、microtask、timer 和其它任务之间的相对顺序；
- 是否读取完成状态、事件计数、时间差或把异步结果写入目标参数；
- 多次运行的调度是否要求稳定，还是只要求满足一个最小先后关系。

### 最小补法

- 按 trace 建立最小任务边界：
  `iframe 创建 → Window/Document 初始化 → 必要脚本初始化 → 文档状态变化 → load/message 任务 → 主线程继续`。
- iframe `load`、Worker `message` 和脚本加载不得在创建或 `postMessage` 调用栈内同步完成。
- 只实现当前目标链路要求的任务顺序、状态变化和回调触发，不为了模拟浏览器而给所有任务增加延迟。
- 确实需要时间差时，使用有界、可复现、由任务边界决定的调度；不得每次使用无规则随机 `sleep`。
- 本地速度更快本身不是补环境依据；必须有 `ruyitrace` 的事件顺序、状态读取或时间语义支持。

### 验证与禁止

- 验证 iframe 创建、脚本执行、文档状态、`load`、Worker 消息和主线程继续执行的先后关系；
- 验证目标 JS 不会在异步结果准备前读取未初始化对象，也不会因回调过早而走错误分支；
- 验证同一输入下调度结果稳定，参数格式、结构、长度和后续请求边界可用；
- 禁止用完全随机等待掩盖错误的执行模型；
- 禁止 iframe 创建后同步触发 `load`，或 `postMessage` 后同步调用 `onmessage`；
- 禁止为了让耗时看起来像浏览器而阻塞无关任务或拖慢整个 Node 运行时。

## 16. 主线程、iframe、Worker 环境边界与存储隔离

### 触发条件

trace 命中主线程与 iframe / Worker 之间的全局对象比较、API 存在性检查、`self` / `window` / `document` 读取、页面存储访问，或目标 JS 根据线程身份选择不同分支。

### 检测语义

必须区分以下三类执行环境：

- 主线程 Window：拥有页面 `window`、`document`、页面 `location` 和页面 Web Storage；
- iframe Window：拥有独立的 Window / Document / realm，并按实际同源关系处理 `parent`、`top`、`self`、`frameElement` 和页面存储；
- WorkerGlobalScope：拥有 Worker 内部的 `self` 和 Worker 专属 API，不应默认暴露页面 `window`、`document`、`localStorage` 或 `sessionStorage`。

重点确认目标 JS 实际检测：

- `typeof window`、`typeof document`、`typeof self`、`globalThis` 和线程间身份关系；
- Worker 是否读取或判断 `localStorage` / `sessionStorage`，以及读取结果是“没有该 API”还是其它异常；
- 主线程与 Worker 是否使用相同业务算法，但读取不同的宿主对象和 API；
- iframe 与主线程是否共享或隔离 `document`、`location`、cookie、storage 和对象原型；
- Worker 消息返回对象是否跨线程复制、转移或保持目标要求的字段和身份；
- 线程边界差异是否进入指纹、签名、验证码凭证或请求参数。

### 最小补法

- 主线程、iframe 和 Worker 分别建立自己的全局对象边界；不要把主线程 `window` 直接复制给 Worker。
- Worker 默认只提供 trace 命中的 `self`、消息 API、定时器和其它 Worker 专属能力；没有证据时不提供 `window`、`document`、页面 Web Storage。
- iframe 只在 trace 证明需要时建立独立 Window / Document / realm，并维护 `parent`、`top`、`self`、`frameElement`、`contentWindow` 和 `contentDocument` 的稳定身份关系。
- 主线程和 Worker 的业务算法、输入输出可以一致，但全局对象、API 暴露面、存储权限和对象原型必须按真实线程区分。
- 如果 Worker 能直接访问页面 `localStorage` 或 `sessionStorage`，先标记为环境边界错误；再根据 trace 检查是错误 shim、主线程对象泄漏还是 Node 特征泄漏，不能直接把它当作浏览器行为。
- 存储只补目标链路实际读取、写入和后续再次读取的最小语义，并保持同一线程内的状态一致。

### 验证与禁止

- 验证 Worker 中不应存在的 `window`、`document`、`localStorage`、`sessionStorage` 是否按目标环境表现为缺失或正确异常；
- 验证主线程、iframe、Worker 的 `self` / `window` / `document` 身份和 `instanceof` / 原型关系；
- 验证存储写入、读取、清理和跨线程消息的边界符合 trace；
- 验证相同业务输入在主线程和 Worker 中不会因错误共享宿主对象而产生异常参数；
- 禁止把主线程 `window`、`document`、storage 或 Node 全局对象直接挂到 Worker；
- 禁止因为 Worker 可以访问页面存储就直接补这种能力；必须先确认目标 trace 确实要求它；
- 禁止用“主线程和子线程逻辑一样”作为理由抹平两者的宿主 API 边界。

## 专项完成标准

专项不是“API 不报错”，而是：

```text
当前特殊检测已按 trace 语义实现
+ 当前检测链已越过
+ 目标参数由本地实时生成
+ 参数格式、结构和长度达到可用标准
+ 没有用旧值、固定值或假回调完成
```

如果特殊检测仍然无法解释，写清：

```text
专项名称：
当前检测点：
已确认语义：
缺失证据：
本地现象：
下一步需要的 trace 或材料：
```
