## WASM 归类与处理清单

本清单用于目标链路出现 WebAssembly / `.wasm` / wasm base64 / wasm-bindgen / Emscripten / `WebAssembly.instantiate*` 时的归类和交付约束。它不是 wasm 反编译流程，也不是自动补环境工具。

## 硬边界

- 不优先改 wasm 二进制，不改 wasm 指令，不在 wasm 内部下探针。
- 不把 wasm 当普通 DOM/BOM 环境项混进 `window/document/navigator` 大区。
- 不复制外部 wasm 课件或工具箱代码，只提炼加载方式、胶水层类型、import/export 证据和交付边界。
- 不用绝对路径写死 `.wasm` 文件；交付版 wasm 路径必须相对项目目录或通过输入配置传入。
- 不把 `console.log` 的散输出作为稳定接口；最终入口必须返回结构化 JSON。

## 识别信号

命中以下任一特征时进入 wasm 归类：
- `WebAssembly.instantiate`、`WebAssembly.instantiateStreaming`、`WebAssembly.compile`、`new WebAssembly.Module`、`new WebAssembly.Instance`
- `.wasm` 请求、`application/wasm`、base64/ArrayBuffer/Uint8Array wasm 字节
- `WebAssembly.Memory`、`WebAssembly.Table`、`instance.exports`、`module imports/exports`
- wasm-bindgen 特征：`wbg`、`__wbindgen_*`、JS heap、`TextEncoder` / `TextDecoder`、memory 字符串桥
- Emscripten 特征：`Module`、`HEAPU8`、`ccall`、`cwrap`、`_malloc`、`_free`

## 加载方式分类

先确认 wasm 来源和加载方式：
- `buffer_instantiate`：本地或网络字节进入 `WebAssembly.instantiate(buffer, imports)`
- `streaming_instantiate`：`Response` 进入 `WebAssembly.instantiateStreaming(response, imports)`
- `module_instance`：先 `new WebAssembly.Module(bytes)`，再 `new WebAssembly.Instance(module, imports)`
- `embedded_base64`：wasm 字节以内嵌 base64 / 字符串 / 数组形式存在
- `network_fetch`：通过 `fetch` / XHR / loader 拉取 wasm，再转 `ArrayBuffer`

交付版要记录 wasm 文件名、hash、来源 URL 或内嵌来源、加载方式和是否存在多版本风险。

## 胶水层分类

先处理 JS 胶水层，不优先反编译 wasm：
- `raw_exports`：JS 直接调用 `instance.exports.xxx`
- `wasm_bindgen`：JS 胶水层维护 heap、string encode/decode、`wbg` imports，并包装业务函数
- `emscripten`：JS 胶水层维护 `Module`、HEAP、malloc/free、ccall/cwrap
- `custom_loader`：混淆 JS 手写 imports、memory、table、字符串桥或 Promise loader

交付版应保留必要胶水层，收敛入口到项目自己的 `get_xxx(input)`，不要让业务调用散落在 wasm loader 尾部。

## importObject 处理

WASM 补环境优先补 importObject 和 JS 胶水层需要的宿主能力：
- `env` / `wbg` / 自定义模块名必须按 `WebAssembly.Module.imports(module)` 或 trace 证据列出。
- import 函数要明确职责：取 window/self/globalThis、读 document/location、执行 Date/timezone、字符串转换、抛异常、调用 JS 函数等。
- 命中 DOM/BOM import 时，仍回到对应宿主大区补对象语义，不在 wasm 区新建第二套 window/document/location。
- import 函数入参和返回值必须用 `rt_log` 或稳定结构日志记录，不用重 Proxy 兜底。
- `eval/new Function`、`Date/getTime/timezone`、`TextEncoder/TextDecoder`、`URL/Response/fetch` 只按 wasm 链路实际触达补。

## exports / memory / table

确认 wasm 对外可用面：
- 记录 `WebAssembly.Module.exports(module)`，区分 `function`、`memory`、`table`、`global`。
- 字符串参数和返回值经 wasm memory 桥接时，确认编码、指针、长度、释放函数和异常路径。
- `memory.buffer` 变更后要重建 typed array view，不能缓存失效 view。
- 只把目标链路调用到的 export 包装成稳定入口；无关 exports 不展开。

## 业务边界

WASM 链路最终必须落到目标集合：
- 识别 wasm 产出的参数、header、token、签名片段或加密 payload。
- 记录业务入口入参，例如 method、url、deviceId、client、body、timestamp、cookie/storage 状态。
- `test.py` 负责真实请求验证；`code.js/runtime/*.code.js` 只负责 wasm 加载、必要补环境、目标 JS/wasm 胶水层和稳定参数入口。
- 多个 wasm 或多版本 wasm 时，拆 runtime 或记录版本风险，不把多条链混在一个大函数里。

## 证据与验收

必须保留：
- wasm 文件或内嵌字节的 hash
- loader JS hash
- imports / exports 列表
- 目标 export / wrapper 函数名
- 目标入口入参和结构化输出
- `ruyitrace/wasm`、`eval`、`jscall`、请求边界或本地运行证据
- `test.py` 请求面验证结果

验收只看目标链路是否稳定产出目标集合并通过真实请求验证，不要求还原无关 wasm exports 或反编译算法。
