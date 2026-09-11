# F5 Shape / Shape Defense 参考文档

本文用于识别和处理 F5 Shape / Shape Defense 体系中的 API 级或页面级防护、动态 VMP/JS/WASM、Shape Cookie、`fetch` / `XMLHttpRequest` 包装、`Headers.set` 注入和最终业务接口放行链路。它是产品经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据、匹配当前目标的 `ruyitrace/` 真实证据和真实请求验证结果为准。

本文件包含 Southwest Airlines 任务会话 `019f2ca7-3512-7023-b8cf-a0d3b47097ef` 的经验记录。该会话目标是动态生成 Southwest F5 Shape headers 并拿到航班数据，最终收敛到 `runtime/shape_runner.code.js`、`code.js`、`test.py`、`fast_test.py` 和进展清单。

## 命中特征

出现以下特征时，可优先按 F5 Shape / Shape Defense 链路分析：

- 请求 Header 中出现一组六个同前缀字段，常见后缀为 `-a`、`-b`、`-c`、`-d`、`-f`、`-z`，例如 `EE30zvQLWf-a/b/c/d/f/z`、`x-jFuguZWB-a/b/c/d/f/z`。
- Cookie 中出现站点随机命名的 Shape 状态，例如 Southwest 样本中的 `sRpK8nqm_sc`、USPS 样本中的 `o59a9A4Gx`。Cookie 名不是通用固定值，必须按当前目标确认。
- 页面或脚本链出现 `Shape`、`F5`、`bm-verify`、`/_sec/cp_challenge/verify`、`ponos.zeronaught.com`、伪装第一方路径的动态资源或大体积混淆 JS。
- 业务请求本身看似普通，但在浏览器侧通过 `fetch` / `XMLHttpRequest` 包装自动注入 Shape headers，业务代码并不显式传这些字段。
- 脚本资源伪装成站点普通 JS，例如 Southwest 的 `/assets/app/scripts/swa-common.js`，或伪装第一方路径 `/resources/<hash>`、`/resources/<hash>/e_<id>_<version>.js`。
- trace 中能看到 `Request.get headers` 后紧跟多次 `Headers.set("prefix-f/b/c/d/z/a", ...)`，最终 `Window.fetch` 入参可能从 string/init 变成 `Request`。
- 去掉任意一个 Shape header 后业务接口返回风控错误，例如 Southwest 会话中去掉 `EE30zvQLWf-*` 返回 `403050700`。
- 运行链中出现 WASM、Blob URL、Worker、动态 script append、`Function.prototype.toString.call(fn)`、结构化克隆或错误栈检查等强反补环境特征。

不要只因为出现 `_abck`、`bm_sz`、`ak_bmsc` 就把目标误判成 Akamai BMP。F5 Shape 可以与其它 CDN / 站点 Cookie 同时出现，主线应以目标业务请求真正必要的 headers、cookie、challenge 和响应错误码为准。

## 典型防护模式

F5 Shape 至少有两类常见形态。

页面级挑战模式：

```text
访问受保护页面
→ 反代返回 302 或短 HTML
→ 跳转到 /_sec/cp_challenge/verify 或 bm-verify 挑战页
→ 挑战页响应头 Set-Cookie 下发初始 Shape Cookie
→ HTML 内嵌或动态加载 VMP/JS/WASM
→ JS 收集环境并包装请求
→ 后续页面或接口带 Cookie + Shape headers 才放行
```

API 级暗哨模式：

```text
页面正常加载，没有显式挑战页
→ 页面加载伪装第一方 JS，例如 swa-common.js 或 /resources/<hash>
→ JS 响应头或前置资源响应头 Set-Cookie 下发 Shape Cookie
→ VMP/JS/WASM 包装 window.fetch / XMLHttpRequest / Request / Headers
→ 业务代码发起正常 API 请求
→ wrapper 在请求边界写入 prefix-a/b/c/d/f/z
→ 业务接口校验 Cookie + Shape headers + 会话上下文
```

Southwest 会话属于 API 级暗哨模式。页面可以正常加载，关键保护点在航班查询 API，请求必须携带 `EE30zvQLWf-a/b/c/d/f/z`。`sRpK8nqm_sc` 来源是真实会话 GET `https://www.southwest.com/assets/app/scripts/swa-common.js` 的 HTTP `Set-Cookie`，不是本地 JS 通过 `document.cookie` setter 写出的值。

## 常见链路

F5 Shape 链路常见顺序如下：

```text
页面入口
→ 加载 Shape 主脚本或伪装第一方脚本
→ 加载 split chunks / 动态脚本 / WASM
→ 读取 document.currentScript、script nonce、document magic key、location、storage、navigator、screen、performance
→ 安装 fetch/XHR/Request/Headers wrapper
→ 可选请求 JWKS / config / telemetry / ponos endpoint
→ 业务请求进入 wrapper
→ wrapper 对 URL、method、headers、body、Request 对象做规则匹配
→ 读取 Request.headers
→ 连续 Headers.set 写入六个 Shape headers
→ 真实业务接口返回 JSON 或业务数据
```

Southwest 会话中最关键的真实证据是：

- Cookie 名：`sRpK8nqm_sc`。
- Shape header 前缀：`EE30zvQLWf`。
- 目标业务接口：`POST /api/air-booking/v1/air-booking/page/air/booking/shopping`。
- 伪装脚本：`/assets/app/scripts/swa-common.js`。
- 资源主包：`/resources/c4036b15ef548ff55d184615dd91bee22130011c85bd8`。
- split chunks：`e_65319_...js`、`e_65257_...js`、`e_64885_...js`、`e_65226_...js` 等。
- 指纹/校验回传：`ponos.zeronaught.com/2`。
- `swa-di.js` 负责业务侧 `interceptFetch/window.fetch`，`swa-common.js` / c403 链负责 Shape 外围包装和 header 注入。
- ruyitrace 证明真实 JWKS 和 shopping 请求都有 `Request.get headers` 后连续 `Headers.set("EE30zvQLWf-f/b/c/d/z/a", ...)` 的注入边界。

## 参数与状态分工

F5 Shape 场景中要先分清每个字段的职责。

`Shape Cookie`：

- 多数情况下来自服务端 HTTP `Set-Cookie`，不一定由 JS 写入。
- 需要用 `http_packet`、Chrome CDP `Network.responseReceivedExtraInfo`、ruyitrace `cookie` 分区或真实会话抓包确认。
- 如果在 `document.cookie` setter 上加断点没有触发，这是有价值的阴性证据，可能说明 Cookie 根本不是 JS 写的。
- 不要把 Cookie 当成 JS 算法目标硬逆。Cookie 的维护通常应放在 `test.py` 或真实请求会话层。

`Shape Headers`：

- 通常是一组六个同前缀字段，后缀为 `a/b/c/d/f/z`。
- 它们通常在请求边界由 wrapper 写入，不一定存在一个公开函数直接返回。
- 必须验证是否为当前业务接口必要条件。Southwest 会话中去掉任意 `EE30zvQLWf-*` 都会失败。
- 不要把 trace 中固定 header 值长期当成动态生成结果。只有从基础请求头中剔除 trace 固定值后，仍由原始 JS 链写入，才算动态生成。

`Telemetry / Ponos`：

- `ponos.zeronaught.com/2` 一类请求可能是 Shape 指纹/校验回传，不等于最终业务接口。
- 本地补环境可以用 trace packet 或模拟响应让 JS 链继续跑，但最终验收必须回到业务接口。

`业务状态`：

- `Idempotency-Key`、`X-API-Key`、`X-Channel-ID`、`Referer`、`Origin` 等字段可能是业务接口要求，不一定属于 Shape。
- 先做字段必要性实验：去掉 Shape headers、去掉 Cookie、去掉业务 headers、换 body，分别看错误码和响应体。

## ruyitrace 定位顺序

建议按以下顺序定位：

1. 用 `index.jsonl` 和 `http_packet` 找目标业务接口、前置脚本、前置配置、Shape Cookie 下发响应和 telemetry 请求。
2. 在 `http_packet` 中搜索 header 前缀，例如 `EE30zvQLWf`，确认所有带 Shape headers 的请求节点。
3. 在 `jscall` 中围绕业务 `fetch` / XHR 边界找 `interceptFetch`、`window.fetch`、`Headers.set`、`Request` 构造和 wrapper 返回。
4. 在 `domtrace` 中搜索 `Request.get headers`、`Headers.set`、`HTMLAnchorElement`、`document.createElement("a")`、`location`、`currentScript`、`script.src`、`script.nonce` 等关键环境读取。
5. 在 `cookie` / `storage` 分区确认 Cookie 是 JS 写入、HTTP 下发还是 profile 预存。
6. 在 `descriptor` 中确认高风险反射面，例如 native 函数 `toString`、prototype、constructor、ownKeys、descriptor kind。
7. 在 `wasm` 分区只确认 WASM 外围：模块数量、hash、imports/exports、绑定关系。不要进入 WASM/VMP/opcode 内部插桩。
8. 回到本地 runner，只补当前请求链真实触达且有因果作用的 DOM/BOM、Request、Headers、Worker、URL、storage 和事件边界。
9. 在 `test.py` 做真实请求验证，验收口径必须是业务接口返回正常业务数据。

## 补环境优先级

F5 Shape 的补环境不要追求一次性补全浏览器。优先级建议如下：

- `Function.prototype.toString` 保护：必须覆盖实例调用和 `Function.prototype.toString.call(fn)`，不要只改 `fn.toString`。
- Node 痕迹隐藏：避免 `process`、`require`、`Buffer`、`console._stdout`、`node:internal` 栈帧等直接暴露。
- `window` / `document` / `location` / `history` / `navigator` / `screen` / `performance` 的基础外观。
- `document.currentScript`、script `src`、`nonce`、`getAttribute`、`hasAttribute`、动态 script append 和 onload。
- `document` / `window` 上 Shape 使用的随机 magic key，例如 `document["  $$__..."]`、`window["  $$__..."]`。
- `Blob`、`URL.createObjectURL`、`Worker`、`postMessage`、`MessageEvent`、`addEventListener`、`dispatchEvent`。
- `fetch`、`XMLHttpRequest`、`Request`、`Headers` 的构造、getter、clone、set/append/get/forEach 和 native 外观。
- `HTMLAnchorElement` URL 解析：`document.createElement("a")` 必须返回正确原型，并支持 `href/protocol/host/hostname/port/pathname/search/hash/origin/toString`。
- `URL`、`URLSearchParams`、`TextEncoder`、`crypto.getRandomValues`、`performance.now`、timer、idle/animation callbacks。
- 只有 trace 证明进入目标链路时，再补 canvas、WebGL、Audio、font、plugin、mimeType 等高成本指纹面。

## Southwest 会话关键坑点

这些坑来自会话 `019f2ca7-3512-7023-b8cf-a0d3b47097ef`，后续遇到 F5 Shape 时应优先检查。

坑 1：拿到业务数据不等于动态生成成功。

早期 `code.js` 从成功 trace 包复制了固定 `EE30zvQLWf-*`，`test.py` 能返回 HTTP 200 和航班数据，但这只是 replay 成功，不是动态生成成功。真正的验收必须从基础请求头里剔除 trace 固定 Shape headers，再证明原始 Shape JS 链在本地最终 Request 上重新写入六个 headers。

坑 2：不要把 Shape Cookie 当成客户端算法。

Southwest 的 `sRpK8nqm_sc` 来自 `swa-common.js` 响应头 `Set-Cookie`。会话中曾尝试从 `document.cookie` 写入链找 cookie，后来通过 HTTP 层证据确认 cookie 不是 JS setter 写入。正确分工是 `test.py` 用真实会话 GET `swa-common.js` 预热 Cookie，`code.js` / `runtime` 负责动态 Shape headers。

坑 3：Cookie 必要性会随请求窗口变化。

会话早期测试过无 Cookie 仍可返回 200，后续窗口中跳过 `sRpK8nqm_sc` 返回 403。不要把单次样本写死为永久结论。每轮交付前都要重新验证当前窗口的 Cookie 和 Shape headers 必要性。

坑 4：不要误判为 Akamai 主线。

站点可能同时存在其它 CDN / Cookie / 安全字段。Southwest 任务真正导致 `403050700` 的是 `EE30zvQLWf-*` 缺失，不是 Akamai cookie。产品索引未收录 F5 Shape 时应记录未知安全产品特征并新增文档，不要硬套 Akamai 文档。

坑 5：VMP/opcode 内部不是补环境入口。

F5 Shape 常见 40 万字符级混淆 VMP、动态字节码和 WASM。会话最终成功没有进入 VMP/opcode handler 插桩，而是通过外层 DOM/BOM、Worker、Request、Headers、URL 和 fetch/XHR 边界补环境触发原始 wrapper。产品文档和项目实现都应禁止把 VMP tracer、opcode hook、handler patch 写进最终 `code.js`。

坑 6：`HTMLAnchorElement` 是本次关键突破。

本地 runner 在补 Anchor 前只读到 `Request.url/method`，`headerOps=[]`，最终不会写 `EE30zvQLWf-*`。ruyitrace 证明真实链路在写 header 前会用 Anchor URL 解析 JWKS 和 shopping URL：设置 `href` 后读取 `pathname/host/protocol/search/hash/port/hostname`。补齐 `HTMLAnchorElement` 后，本地开始读取 `Request.headers`，`headerOpsCount=12`，最终 fetch inputType 为 `Request`，六个 Shape headers 动态出现。

坑 7：`Request` 对象边界比 string/init 更关键。

真实注入点常常不是普通 `fetch(url, init)`，而是 wrapper 构造或接收 `Request` 对象后读 `request.headers` 再写入。补环境时必须支持 `Request.url/method/headers/body/signal/bodyUsed/clone`，并确保 `Headers` 的大小写、迭代、set/append/get/forEach 行为能被 wrapper 正常使用。

坑 8：`Headers.set` 顺序可作为证据，不要作为唯一算法。

Southwest ruyitrace 中常见写入顺序是 `f/b/c/d/z/a`。这个顺序有助于确认命中了真实注入链，但不要把顺序当成可手写的算法替代。最终仍应由原始 Shape 外围链写入当前请求 headers。

坑 9：Worker 异步错误不一定阻断验收。

本地 runner 后续仍可能出现 `Cannot read properties of undefined (reading 'L')` 一类 Worker 异步错误。会话中确认该错误发生在 Shape headers 已写入、shopping fetch 已完成之后，不阻断当前业务请求。不要因为后置异步错误误判动态生成失败；也不要因为当前业务成功就忽略它，后续若保护脚本改变触发顺序，需要重新评估。

坑 10：trace 时间字段不能直接当真实等待。

F5 Shape 链路有异步加载、Worker、XHR、load/DOMContentLoaded、requestIdleCallback。trace 中的长间隔可能是观测扰动。会话中默认等待 `shapeWaitMs=1200`、`afterPreflightWaitMs=300` 能稳定，但压到 `0/0` 仍能生成 headers。等待时间应通过真实本地验证收敛，不要盲目复制 trace 的 dt。

坑 11：冷启动性能和服务化性能是两回事。

冷启动完整链路需要 Node 启动、加载并执行 Shape/swa-common/swa-di/chunks、预热 `sRpK8nqm_sc`、真实 POST，实测约 6s+。2 秒 SLA 不能靠每次冷启动实现；会话最终采用长驻 Node JSONL 生成器、后台动态请求池、复用 Cookie 会话和 `curl_cffi` POST，预热后前台请求约 1.51s-1.88s。

坑 12：标准 HTTP 客户端可能不是最快或最稳定。

会话中 `requests` / `httpx` POST 偶发超过 2s，`curl_cffi` 的 POST 样本稳定在 2s 内。真实交付时应区分算法正确性和传输层性能，不要把网络/TLS/HTTP2 抖动误判为 Shape 参数错误。

## 动态生成验收标准

F5 Shape 任务建议使用以下验收标准：

- 基础请求头中不包含 trace 固定 Shape headers。
- 本地 runner 执行原始 Shape 外围链后，最终 Request 包含完整 `prefix-a/b/c/d/f/z`。
- 证据中能看到 `dynamicShape.enabled=true`、`fetchInputType=Request`、`Request.get headers` 或等价边界、`Headers.set` 操作数量大于 0。
- 去掉任意一个 Shape header 会触发风控错误，保留完整动态 headers 能返回业务数据。
- Cookie 由真实会话预热或当前请求链维护，不回放过期 trace Cookie。
- 最终验收是业务接口返回正常业务 JSON，例如 `success=true`、`searchResults.airProducts` 存在，而不是 telemetry 或 challenge 接口成功。
- 连续请求至少验证 5 次，记录状态码、Cookie 是否存在、动态 headers 是否启用、业务数量和耗时。
- 如果有性能 SLA，必须区分冷启动耗时、预热耗时、动态生成耗时和业务 POST 耗时。

## 交付建议

推荐交付结构：

```text
code.js
= 构造基础业务请求，删除 trace 固定 Shape headers，调用 runtime 动态生成 headers，导出 build_xxx_request(input)

runtime/shape_runner.code.js
= 固定当前 Shape JS 资源和外层 DOM/BOM/Worker/fetch/XHR/Request/Headers 补环境，只负责动态 Shape headers

test.py
= 真实会话、Cookie 预热、调用 code.js、发送业务请求、输出业务摘要

fast_test.py 或服务化入口
= 可选性能路径，长驻 Shape runtime，维护动态请求池和会话 Cookie

param_info.md
= 记录目标接口、请求体、Shape Cookie、Shape headers、稳定入口、当前边界和验收结果

补环境进展清单.md
= 记录已证实、已证伪、当前不成立路线和下一步
```

不推荐交付：

- 固定 replay trace 中的 `prefix-a/b/c/d/f/z`。
- 固定 replay 旧 Cookie。
- 把 VMP/opcode tracer 或调试 hook 写进最终交付。
- 使用浏览器自动化实时跑参数当作本地 `code.js` 实现。
- 只验证 challenge / telemetry 成功，不验证最终业务接口。

## 排错清单

遇到 F5 Shape 请求失败时，优先按以下顺序排查：

- 当前请求是否真的携带完整六个 Shape headers。
- Shape headers 是否由本地原始 JS 链动态写入，而不是 trace 固定值。
- 当前会话是否有最新 Shape Cookie，Cookie 是否来自正确域名和路径。
- 目标 URL 是否使用真实浏览器同形态的 absolute URL / relative path，规则匹配是否走到 `Request.headers`。
- `document.createElement("a")` 和 `HTMLAnchorElement` URL 解析是否完整。
- `Request` / `Headers` 行为是否支持 wrapper 的构造、读取、迭代和写入。
- `document.currentScript`、script `src`、nonce、magic key 和动态 script onload 是否对齐当前链路。
- `fetch` / XHR wrapper 是否真的安装，`window.fetch !== nativeFetch` 或等价证据是否成立。
- Worker / Blob / MessageEvent 是否能让外围链跑到请求边界。
- `ponos` / JWKS / config 等前置响应是否按当前 trace 或真实请求返回了足够内容。
- 错误是否发生在最终业务 fetch 之前；如果发生在之后，先判断是否影响当前验收。
- 当前错误码是 Shape 缺失、Cookie 缺失、业务参数错误、TLS/传输问题还是限流问题。

## Southwest 会话结果摘要

本次会话最终状态：

- `runtime/shape_runner.code.js` 动态生成 `EE30zvQLWf-a/b/c/d/f/z` 成功。
- `code.js` 默认路径删除 trace 固定 Shape headers，并调用 runner 动态生成。
- `test.py` 真实 GET `swa-common.js` 预热 `sRpK8nqm_sc` 后，POST shopping 返回 HTTP 200。
- 连续 5 次冷请求验证 5/5 成功，均返回 `success=true`、`airProductCount=2`。
- 预热后 2 秒路径使用 `runtime/shape_stdio.js`、`fast_test.py`、后台动态请求池和 `curl_cffi`，5/5 前台 total 均小于 2s。
- 关键修复是 `HTMLAnchorElement` URL 解析，而不是 VMP 内部插桩。
