## 高风险环境检测信号索引

本文件用于阶段 4.0：正式补环境前，对目标集合相关 trace 做高风险检测信号扫描。它的目的不是提供完整补法，也不是浏览器 API 清单，而是避免 AI 把复杂检测误判成普通字段缺口。

扫描只限当前目标集合相关链路，不做全量 trace 大盘点。优先看：
- 目标参数生成函数附近的 `jscall`
- 进入目标参数前后的 `domtrace`、`descriptor`、`event`、`exception`、`profile`
- 目标 JS 中参与分支判断的环境读取、方法调用、异常捕获和事件回调
- 本轮 `proxylog.txt` / `rt_log` 实际触达的对象、方法入参和返回对象
- 影响目标请求边界的 cookie、storage、Worker、iframe、WASM 或动态载荷

命中本文件任一信号时，禁止直接按普通字段补环境。必须先写“检测语义卡”，说明检测语义、trace 证据、涉及对象、跨对象关系、状态/事件/时序和补完验证；无法说明时，只能记录缺口并暂停该项。

## 检测语义卡

```text
检测类型：
代码 / trace 信号：
目标代码位置：
ruyitrace / jscall 证据：
检测语义：
涉及对象：
读取 / 调用 / 事件顺序：
分支条件：
跨对象一致性：
状态 / 事件 / 异步时序：
影响的目标参数或请求边界：
下一步补法：
补到哪个对象区：
补完验证什么：
是否需要暂停：
```

如果只能写出“缺某个对象 / 缺某个字段”，不能写出“如何检测”和“检测结果影响哪里”，则不得补入交付版 `code.js` / `runtime/*.code.js`。

## 高风险信号类型

### 1. 堆栈 / 执行模型检测

信号：
- 递归计数、最大调用栈、`RangeError: Maximum call stack size exceeded`
- `try/catch` 捕获递归异常后读取计数
- `Error.stack`、stack 行列号、stack 深度、`sourceURL`
- `eval`、`new Function` 的 stack 外观
- `Function.caller`、`arguments.callee`
- `Promise`、`async/await`、timer 的异步 stack
- Node 特征泄漏：`process`、`Buffer`、`global`、`module`、`require`、Node 路径或内部栈帧

判断：
- 这类问题通常属于执行层、runner 参数、异常外观或 Node 特征泄漏，不是 DOM/BOM 字段缺口。
- 例如递归计数检测最大栈深度时，不得通过补 `window` 字段解决；应判断是否需要固定 runner 参数、记录执行模型差异或暂停。

### 2. CSS 计算检测

信号：
- `style.sheet` 在插入 DOM 前后状态变化
- `CSSStyleSheet.cssRules`
- `CSS.supports`、`matchMedia`
- `getComputedStyle`
- CSS 变量 `var()`、`calc()`、继承、类名叠加、伪类 / 伪元素
- `order`、`width`、`display`、`color`、`transform`、字体、媒体查询、布局尺寸

判断：
- 不只补 `getComputedStyle` 存在性；必须还原目标实际读取的计算语义。
- 命中 CSS 变量、`calc` 或样式插入 DOM 后读取时，必须确认元素、样式表、类名、继承和计算结果的关系。

### 3. `document.all` 特殊语义检测

信号：
- `document.all`
- `typeof document.all`
- `document.all == null`
- `Boolean(document.all)`
- `document.all.item`、`namedItem`、索引、调用行为

判断：
- `document.all` 不是普通对象、普通函数、普通 Proxy 或 `{}`。
- 命中时读取专项清单，优先考虑 V8 undetectable 底座；无法覆盖时记录具体未覆盖检测点。

### 4. iframe / realm 身份检测

信号：
- `document.createElement("iframe")`
- `iframe.contentWindow`、`contentDocument`
- `document.defaultView`
- `window.parent`、`top`、`self`、`frames`
- `frameElement`
- 跨 realm `instanceof`、构造器、`Object.prototype.toString`
- iframe load、script 执行和 `postMessage` 时序

判断：
- 必须区分 iframe 元素、frame window、frame document、top window 和 parent window。
- 重点检查 SameObject 和回指关系，例如 `contentDocument.defaultView` 与 `contentWindow`。

### 5. Worker / MessageChannel 通信检测

信号：
- `new Worker`、`new SharedWorker`
- `postMessage`、`onmessage`、`addEventListener("message")`
- `MessageEvent.data`、`origin`、`source`、`ports`
- `MessageChannel`、`MessagePort`
- structured clone、transferable、ArrayBuffer detach
- `importScripts`

判断：
- 不得同步假回调跑通。
- 必须按 trace 确认主线程发送、Worker 返回、事件派发、source/ports 和异步顺序。
- Worker 内部不能默认暴露主线程 `window`、`document`、`localStorage`、`sessionStorage`。

### 6. WebRTC / 权限 / 设备一致性检测

信号：
- `navigator.mediaDevices`
- `getUserMedia`、`enumerateDevices`
- `navigator.permissions.query`
- `RTCPeerConnection`
- `createOffer`、`createAnswer`、`setLocalDescription`
- `onicecandidate`
- `RTCSessionDescription`、`RTCIceCandidate`
- `connectionState`、`iceGatheringState`、`iceConnectionState`

判断：
- WebRTC 不能只补全局构造器存在性。
- 需要检查权限状态、设备列表、label 暴露、Promise 成功/失败、SDP/candidate、ICE 状态和事件顺序之间是否一致。
- 若目标链路涉及网络出口或 IP 暴露，WebRTC 结果不得与请求代理策略明显矛盾；真实请求仍由 `test.py` 验证。

### 7. 事件 / 异步时序 / 用户交互状态检测

信号：
- `addEventListener`、`removeEventListener`、`dispatchEvent`
- `MouseEvent`、`PointerEvent`、`TouchEvent`、`KeyboardEvent`
- `isTrusted`、`timeStamp`、坐标、按键、触点
- `focus`、`blur`、`visibilitychange`
- `mousemove`、`scroll`、`wheel`
- `MutationObserver`
- timer、microtask、Promise、脚本 load 顺序

判断：
- 不得只构造 `{ type: "click" }` 这类空壳事件。
- 必须按 trace 处理 listener 顺序、事件对象字段、`target/currentTarget`、状态写入和目标参数进入位置。

### 8. `performance.memory` / timing 动态检测

信号：
- `performance.now`、`timeOrigin`
- `performance.timing`
- `performance.getEntriesByType`
- `PerformanceResourceTiming`
- `performance.memory`
- `Date.now` 与 `performance.now` 对照
- DOM / 对象生命周期后读取内存或 timing

判断：
- `performance.memory` 不能补固定值或随机值；需要动态来源和短时间快照一致性。
- timing 相关字段不能与事件、script load、Worker message 或请求边界时序明显矛盾。

### 9. Canvas / WebGL / Audio 指纹检测

信号：
- `canvas.getContext("2d")`
- `measureText`、`getImageData`、绘制序列
- `toDataURL`、`toBlob`
- `getContext("webgl")`、`webgl2`
- `getParameter`、`getSupportedExtensions`、`getExtension`
- `WEBGL_debug_renderer_info`
- `AudioContext`、`OfflineAudioContext`、`startRendering`

判断：
- 这类检测看渲染、字体、GPU、DPR、音频状态和硬件画像一致性。
- 没有 trace 触达证据时不得提前批量补指纹面；命中后按专项清单处理最小链路。

### 10. Storage / Cookie / Origin 隔离与状态检测

信号：
- `document.cookie`
- `localStorage`、`sessionStorage`
- `Storage.length`、`key()`、直接属性写入
- `navigator.storage.estimate`、`persist`、`persisted`
- `indexedDB`
- iframe origin、同源 / 跨源 storage 共享或隔离
- 写入后再次读取

判断：
- 重点是同轮状态、origin 边界、cookie/storage 与目标参数或请求边界的关系。
- 不得把业务 token 派生逻辑硬编码进 storage。

### 11. DOM 结构 / script 加载 / URL 解析检测

信号：
- `appendChild`、`removeChild`、`insertBefore`
- `document.body`、`documentElement`
- `querySelector`、`getElementsByTagName`
- style 插入 DOM 后状态变化
- `document.currentScript`
- script append/load、`DOMContentLoaded`、`load`
- `document.write`、`readyState`
- `a.href`、`URL`、`location` 对照和 URL 规范化

判断：
- 重点是 DOM 状态变化、脚本执行时机和 URL 解析一致。
- 不得在创建 script、iframe 或 DOM 节点时提前执行目标脚本。

### 12. WASM / 动态载荷 / VMP 边界检测

信号：
- `WebAssembly.instantiate`、`instantiateStreaming`
- wasm binary、base64、ArrayBuffer、字节数组
- `eval`、`new Function`
- Worker 中加载动态 JS
- VM-like dispatcher、opcode、bytecode、server payload blob

判断：
- 只在外围还原宿主能力、入口、版本材料和请求边界。
- 不得进入 VMP / opcode / wasm 二进制内部补环境、插探针或改执行语义。

## 常规反射检测的边界

`descriptor`、prototype、ownKeys、native `toString`、`Symbol.toStringTag` 是常规反射检测，不单独列为高风险主类。单独命中时按 `environment-detection-checklist.md` 和 `prototype-chain-template.md` 处理。

但当反射检测绑定在本文件的高风险对象或跨对象一致性链路上时，必须升级为该高风险检测链的一部分处理，例如：
- `iframe.contentWindow` 的 descriptor 或跨 realm `instanceof`
- `Worker.prototype.postMessage.toString`
- `CSSStyleDeclaration` 的 ownKeys
- `RTCPeerConnection.prototype` 的 native 外观
- `document.all` 的 `typeof`、`toStringTag` 或 descriptor

此时不得只补外观后标记完成，必须回到对应检测语义卡验证关联关系。
