# 瑞数/瑞树 RS6 参考文档

本文用于识别和处理瑞数/瑞树 RS6 类动态 JS 链路：动态挑战页、动态 cookie、XHR/fetch 请求后缀、业务接口放行验证。它是站点专项经验参考，不是固定套用方案；命中后仍必须以当前目标的 `ruyitrace/` 证据为准。

## 命中特征

出现以下特征时，优先按瑞数/瑞树 RS6 链路分析：

- 首次业务页返回 HTTP `412` 或跳到短挑战页，挑战页再加载伪装成站点一方资源的动态脚本。
- 动态脚本路径形如 `/jhKGIvczkKbR/<random>.0515a6f.js`，不同会话或不同轮次可能变化。
- HTML 中存在 `r='m'` 的 `meta` 或内联脚本，常见 `meta id="2vmka0flZgDo"`，`content` 会参与动态 JS 环境。
- Cookie 中出现同一随机前缀的 `O/P/enable` 组合，例如 `UA1L1zGonajvO`、`UA1L1zGonajvP`、`enable_UA1L1zGonajv`。
- 业务请求 URL 被自动追加动态 query 后缀，例如 `XJlCTRRM=<119 chars>`；该后缀通常出现在 `XMLHttpRequest.open` 或 fetch/open 边界，不是业务 JS 直接拼接。
- 业务 POST 成功响应才算验收，例如 JSON 中出现 `htmlView`、价格字段、列表 HTML 或业务数据；只生成 cookie/后缀不算完成。
- eval 目录中出现大体积混淆 JS、反调试 `debugger` 检测、native toString 检测，但外部补环境禁止进入 VMP/opcode/handler 插桩。

## 必读 Trace 分区

- `http_packet/index.jsonl`：确认 412、动态 JS、业务接口、业务响应和状态码。
- `http_packet/*.http_packet.json`：提取挑战页 HTML、动态脚本响应、Set-Cookie、Referer、Sec-Fetch、业务 body。
- `cookie/` 和 `storage/`：确认 JS 写入的 O/P/enable cookie 与服务端 cookie 的边界。
- `domtrace/`：定位 `meta` 读取、`document.currentScript`、`XMLHttpRequest.open` 后缀注入、DOM 构造器和缺口。
- `descriptor/`：确认 Firefox/Gecko 或其他浏览器原型、getter、缺失属性，不要凭 Chrome 经验硬补。
- `eval/`：只用于确认动态代码来源、执行顺序和外层入口；不要改 VM handler。
- `jscall/`：确认业务 JS 是否只是普通 XHR/fetch，后缀是否由安全 JS 外层包裹产生。

## 标准流程

1. 先读并更新 `补环境进展清单.md` 或 `补环境进展.md`，记录目标、类型、证据、失败点和验证命令。
2. 从真实 412 或业务页 HTML 中抽取所有 `r='m'` 片段，先移除 HTML 注释，避免本地错误执行 Firefox 不会执行的 IE 条件注释脚本。
3. 按页面顺序执行：前置 `r='m'` 内联脚本 -> 当前动态静态脚本 -> 后置 `r='m'` 内联脚本。
4. `document.currentScript.src` 必须来自当前会话动态脚本，不要硬编码 trace 旧路径。
5. 将 `meta id="2vmka0flZgDo"` 或 `r='m'` 的 `content` 映射进本地宿主，例如 `window.dolphinmeta`，并支持由 live 输入覆盖。
6. 挑战阶段只生成并回填 `P` cookie；不要提前触发业务 XHR 后缀边界。必要时加入 `skipXhrBoundary` 之类的外层开关。
7. 挑战 cookie 成功后，按真实链路先访问 `/index.html` 或站点首页建立服务端会话，再访问业务页，再生成最终请求后缀并 POST 业务接口。
8. 翻页或多次请求时保留同一真实会话 cookie，但每一页都重新进入本地 JS 生成新的动态后缀。

## Firefox/Gecko 优先规则

`ruyitrace` 常来自 Firefox/Gecko 时，不能用 Chrome 指纹兜底。按 trace 证据补齐最小差异：

- HTTP 客户端优先使用 Firefox impersonation，UA 与 trace 保持一致；如用 `curl_cffi`，选可用 Firefox profile。
- 不要默认补 `window.chrome`、`webkitRequestFileSystem`、`webkitPersistentStorage`、`navigator.connection`、`navigator.deviceMemory`，除非 descriptor/trace 明确存在。
- `window.ActiveXObject` 在瑞数/瑞树链路中可能是特征点：本地需要显式存在该属性，但取值仍为 `undefined`。
- `document.all` 应按 Firefox 真实行为做 callable/HTMLAllCollection 风格，而不是简单缺失或普通对象。
- `navigator` 建议按 `Navigator.prototype` getter 模型补齐；PDF `mimeTypes/plugins`、`pdfViewerEnabled`、`doNotTrack`、`oscpu` 等必须以 descriptor 为准。
- 常见外层缺口包括 `BarProp`、`window.locationbar/menubar/personalbar/scrollbars/statusbar/toolbar`、窗口尺寸、`matchMedia`、`createEvent`、`scrollingElement`。
- 若 trace 命中 IndexedDB，最小实现可先覆盖观测链路：`IDBFactory.open("EkcP", 1)`、`IDBOpenDBRequest`、success 回调、`IDBDatabase.transaction`、`objectStore.get/put`、`close`。
- 若 trace 命中 `window.external`、`navigator.locks`，按 Firefox 外层对象补齐 native toString 和 prototype 形态。

## 会话难点记录

来源会话：`019f316f-bdbc-7762-8b13-42ac1ecfcda7`。

- 初始按普通离线补环境能生成 cookie，但 live `/index.html` 返回 `400`，说明离线后缀成功不等于真实会话放行。
- 一度按 Chrome 思路补宿主是错误方向；用户指出 `ruyitrace` 是 Firefox，后续改成 Firefox/Gecko 证据优先。
- 动态 JS 与 HTML `meta` 相关，`window.dolphinmeta` 为空会导致 live P cookie 不稳定；必须从当前挑战页 `meta content` 注入。
- 本地 HTML 解析若执行 IE 条件注释里的脚本，会偏离 Firefox；需要先剥离 HTML 注释再执行 `r='m'` 脚本。
- `document.currentScript.src` 硬编码 trace 旧脚本会导致 live 动态脚本错位；必须从当前页面脚本 URL 推导。
- 挑战阶段如果提前触发业务 XHR wrapper，会污染 P cookie 或让流程错位；412 bootstrap 应只取 cookie。
- `HTMLAnchorElement.href/pathname` 缺失会让 XHR open wrapper 已安装但不追加后缀。
- `HTMLMetaElement`、`HTMLAnchorElement`、`Node/Element/HTMLElement` 原型链和 `Symbol.toStringTag` 不像真实 DOM 时，动态 JS 会走异常分支。
- `document.all`、PDF mime/plugin、Navigator getter、BarProp、matchMedia、IndexedDB、window.external、navigator.locks 都是本次从 Firefox trace 证据逐项补齐的外层差异。
- `window.ActiveXObject = undefined` 必须显式补：属性缺失与属性存在但值为 `undefined` 在该链路里不是同一件事。
- Windows 子进程读取 Node JSON 时曾遇到 GBK/UTF-8 解码问题；测试脚本应固定 `encoding="utf-8"`。
- 不能把成功标准停在 `UA1L1zGonajvP` 或 `XJlCTRRM` 生成；必须用真实业务 POST 验证 HTTP `200` 和业务数据。

## 验收标准

- `node -c code.js` 通过。
- `python -m py_compile test.py` 通过。
- 离线 `python test.py` 生成目标 cookie 和固定长度业务后缀。
- live `python test.py --live` 完整链路返回 HTTP `200`，响应体含业务字段。
- 翻页验证使用同一真实会话，循环 `currentPage`，每页重新生成后缀，确认多页返回不同业务数据。

## 禁止路线

- 不进入 VMP/opcode/handler 内部插桩。
- 不因探针检查 Chrome/WebKit 属性就盲目补 Chrome 指纹。
- 不将 trace 旧 cookie、旧动态 JS 路径、旧 meta content 写死到 live 流程。
- 不只看本地 `ok=true`；必须最终验证真实业务接口。
