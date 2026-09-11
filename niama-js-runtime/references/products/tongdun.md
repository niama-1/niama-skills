# 同盾 / TrustDecision 参考文档

本文用于识别和处理同盾、TrustDecision、TrustDeviceJs 指纹链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

## 命中特征

出现以下特征时，可优先按同盾链路分析：

- 页面加载 `static.trustdecision.com/tdfp/.../fm.js`
- 页面加载 `static.tongdun.net/v3/fm.js`
- JS 头部、注释或脚本内容出现 `TrustDeviceJs`、`TrustDecision`、`Tongdun`、`tdfp`
- 请求链出现 `cn-fp.apitd.net/web/v2`、`apitd.net`
- 目标字段名出现 `black_box`、`blackBox`、`BlackBox`、`blackbox`、`currentBlackBox`、`tddf`
- 业务 Header、Body 或 axios 配置中出现 `Anti-Headers.black_box`、`BlackBox`、`blackbox`、`blackBox`
- 初始化配置出现 `window._fmOpt`、`partner`、`appName`、`success`、`error`
- SDK 构造 `Blob`、`URL.createObjectURL`、`Worker`，并通过 Worker 分支参与指纹生成
- TD 请求 body 常见 `application/x-www-form-urlencoded`，字段为 `data=<payload>`
- 同页可能同时出现网易易盾、验证码、客服或统计 SDK；先以业务字段和请求链确认目标产品，不要被同页噪声带偏

## 常见链路

同盾典型链路是：

```text
请求页面或业务入口
-> 页面加载 TrustDecision fm.js
-> SDK 读取 BOM/DOM、storage、Worker、canvas 等环境
-> SDK POST data 到 cn-fp.apitd.net/web/v2
-> TD 响应 result / requestId，页面回调或 storage 获得 black_box
-> 业务请求从 sessionStorage / 内存状态取 black_box
-> 业务请求把 black_box 写入 Anti-Headers 或业务参数
-> 服务端按 black_box 放行业务接口
```

不要默认 `black_box` 一定是 Cookie。部分站点把它放在自定义 Header 的 JSON 字段里，例如 `Anti-Headers.black_box`；也可能要求 Header `BlackBox` / `blackbox` 和 JSON body `blackBox` 同时携带。业务字段大小写必须按当前 trace 和业务 bundle 保留。

注意时序问题：业务首个请求可能早于 TD `success` 回调或 storage 写入，导致 trace 里 `blackBox` 为空并返回 `QUICK_VERIFY_FAIL`。本地验证时要等 TD 回调完成，再组装业务请求；不要用首个失败包里的空值判断算法失败。

## 参数产出方式

同盾场景里的稳定入口通常围绕 `black_box` 收敛：

- `get_black_box(input)`
- `getBlackBox(input)`
- 当前 TD SDK 发出的 `data` payload
- 由 TD payload 和页面命中的元信息包装出的 `tddf...` 长值
- 页面回调返回的短 `black_box`
- `sessionStorage.currentBlackBox`、`sessionStorage.blackBox` 或同类 storage key
- 业务请求最终写入 `Anti-Headers.black_box`、Header `BlackBox` / `blackbox`、body `blackBox` 的值

短回调值只能当候选或诊断值，不能直接视为业务可用。九元航空机票查询案例中，业务接口需要的是长 `tddf<metadata>.<payload>`，其中 payload 来自 TD SDK 对 `cn-fp.apitd.net/web/v2` 发出的真实 `data`，元信息来自业务 trace 命中的 TD 版本、partner、编码等状态；短回调值不能让业务查询稳定返回数据。

如果业务请求从 `sessionStorage.currentBlackBox` 读取，不要只复现 SDK callback。必须确认 storage 写入时机、业务 axios/header 注入时机，以及最终请求上的 `Anti-Headers` JSON。

吉祥航空机票查询案例中，页面使用 `static.tongdun.net/v3/fm.js`，`window._fmOpt` 里的 `partner=jxhk`、`appName=jxhk_web` 来自业务 bundle；浏览器 trace 的 `/api/flightFares/queryFlightSimple` 先携带空 `blackBox` 返回 `QUICK_VERIFY_FAIL`，TD `/web/v2?partner=jxhk` 成功后才有可用回调值。本地验证通过时，同一个值同时放入 Header `blackbox` 和 JSON body `blackBox`，业务返回 `SUCCESS/status=200` 且航班数据非空。

## 常见环境面

同盾常见会触达这些环境面：

```text
window / document / location / navigator / screen / history
localStorage / sessionStorage
performance.now / timing / entries
Date / Math.random / crypto
canvas 2d / toDataURL / getImageData / measureText
OffscreenCanvas / Image / speechSynthesis
RTCPeerConnection / indexedDB / caches / CacheStorage
TextEncoder / TextDecoder / chrome runtime/app/csi
Blob / URL.createObjectURL / URL.revokeObjectURL
Worker / onmessage / onmessageerror / postMessage / terminate
addEventListener / removeEventListener / dispatchEvent
XMLHttpRequest / fetch / sendBeacon
```

这些值、行为、descriptor、prototype、`toString`、异常栈和事件顺序不能猜。命中新目标时，必须从当前 `jscall` 定位证据和匹配 `ruyitrace/` 的目标参数相关证据中取真实值。

Worker 是同盾链路里的高频坑。若 trace 证明 SDK 构造了 `Blob` 和 object URL，就要按浏览器外观补出 `Blob`、`URL.createObjectURL/revokeObjectURL`、`Worker` 实例、`onmessage/onmessageerror`、`postMessage/terminate`、事件监听和派发行为。不要在 TD 混淆逻辑或 VM/opcode 层插装。

## ruyitrace/jscall 优先动作

命中同盾后，优先做：

```text
1. 在 `jscall`、脚本缓存和 `http_packet` 中搜索 fm.js、TrustDeviceJs、TrustDecision、Tongdun、tdfp、_fmOpt、partner、appName、black_box、blackBox、BlackBox、blackbox、currentBlackBox、Anti-Headers、cn-fp.apitd.net、static.tongdun.net
2. 用 `jscall` 调用栈和 `http_packet` 确认 TD POST、业务请求、调用栈和请求顺序
3. 从 `ruyitrace/index.jsonl` 定位并打开根目录 `*.http_packet.json`，抽取 TD POST 的 URL、Header、Content-Type、data body、响应 result/requestId
4. 从 `ruyitrace/index.jsonl` 定位并打开根目录 `*.http_packet.json`，抽取业务请求里 black_box / blackBox 的最终落点，例如 Anti-Headers JSON、Header、Body
5. 从 `ruyitrace/storage` 确认 currentBlackBox、blackBox 或同类 key 的读写时机
6. 从 `ruyitrace/domtrace` 确认 Blob、objectURL、Worker、canvas、storage 等真实触达点
7. 用 `rtwatch` / `rt_log` 只观察外部宿主对象、方法入参和请求边界
8. 本地 `code.js` 生成 black_box 后，由 `test.py` 组装真实业务请求并验证业务返回
```

如果同页还有网易易盾、验证码、客服或统计请求，先看目标业务接口实际依赖哪个字段。没有流入业务请求的安全 SDK 不应成为当前补环境主线。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ rtproxy.js 底座与 native toString 保护
├─ 当前目标触达的 BOM/DOM/storage/performance 环境
├─ Blob / URL / Worker 外观和事件行为
├─ XMLHttpRequest/fetch 边界，用于捕获 TD data POST
├─ 当前目标版本的 fm.js 或稳定入口
└─ get_black_box(input) 或 getBlackBox(input)

test.py
├─ 读取当前业务 trace 的 URL、Header、Cookie 和业务参数
├─ 调用 node code.js 获取 black_box
├─ 只替换 Anti-Headers.black_box、Header BlackBox/blackbox、body blackBox 或目标字段
├─ 保留航线、日期、channel、业务 Header 和会话状态
└─ 请求业务接口并验证 status/msg/data，而不是只看 HTTP 200
```

九元航空案例的验证口径：

```text
TD POST = POST https://cn-fp.apitd.net/web/v2?partner=9air&appKey=...
TD body = data=<payload>
业务接口 = GET /shop/api/shopping/b2c/searchflight
业务落点 = Anti-Headers.black_box
通过标准 = HTTP 200 且业务 status=200、msg=message.result.ok、航班数据非空
```

吉祥航空案例的验证口径：

```text
TD JS = https://static.tongdun.net/v3/fm.js?t=...
TD POST = POST https://cn-fp.apitd.net/web/v2?partner=jxhk
业务接口 = POST /api/flightFares/queryFlightSimple
失败特征 = Header/body blackBox 为空时返回 QUICK_VERIFY_FAIL
业务落点 = Header blackbox + JSON body blackBox
通过标准 = HTTP 200 且业务 code=SUCCESS、status=200、航班数据非空
```

## 常见坑

- 把同页网易易盾流量误认为目标产品
- 只拿 callback 短 `black_box`，忽略业务实际需要的长 `tddf...` 值
- 忽略 `sessionStorage.currentBlackBox` 的写入和业务读取时机
- 忽略 TD 回调时序，复用首个空 `blackBox` 失败请求
- 只复现 `fm.js` 入口，不捕获真实 `cn-fp.apitd.net/web/v2` 的 `data` 请求边界
- 业务请求重建时覆盖航线、日期、channel、Referer、Cookie、原有 `Anti-Headers` 结构或 Header/body 的字段大小写
- 只把值放入 Header 或只放入 Body，漏掉当前业务要求的双落点
- Worker 分支缺失，导致 payload 长度、字段或分支不稳定
- OffscreenCanvas、Image、speechSynthesis、RTC、IndexedDB 或 CacheStorage 分支缺失，导致 SDK 超时或回调不触发
- 在 TD 混淆代码、VMP、opcode handler 或解释器层插装
- 只看 `node code.js` 能输出值，不跑 `test.py` 验证业务数据

## 验证重点

最终验证不只看 `black_box` 是否存在，还要看：

- TD SDK 是否来自当前页面、当前版本
- TD POST 的 URL、Method、Header、Content-Type、Body 编码是否与浏览器一致
- `data` payload 是否来自当前本地运行链，而不是旧 trace 硬编码
- `black_box` 是否写到业务实际读取的位置
- 业务请求上的 `Anti-Headers`、Header 或 Body 是否只替换目标字段并保留原业务上下文
- Header/body 字段名大小写、双落点和注入时机是否与当前业务一致
- 业务响应是否返回正常业务数据，而不是只返回 HTTP 200 或空数据
- 多轮更换会话、航线、日期或 SDK 版本后，能否定位是业务参数变化还是 TD 环境差异

## 使用边界

本文只指导优先观察点和常见问题，不提供可直接套用的固定环境值、固定指纹或固定算法。

补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。
