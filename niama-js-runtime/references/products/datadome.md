# DataDome 参考文档

本文用于识别和处理 DataDome 保护链路，包括无感 interstitial、captcha iframe、滑块 / audio challenge、`datadome` Cookie 更新和最终业务页面放行。

本文是产品专项参考，不替代当前目标实测。任何补入 `code.js` / `runtime/*.code.js` 的环境值、事件顺序、轨迹、Header、Cookie、TLS/HTTP 边界和请求参数，都必须来自当前目标的 `http_packet`、`jscall`、`event`、`cookie/storage`、`domtrace/descriptor` 或实时抓包证据。

## 命中特征

出现以下特征时，优先按 DataDome 链路分析：

- Cookie 中出现 `datadome`
- 响应头出现 `x-datadome`、`x-datadome-cid`、`x-dd-b`
- 保护页 HTML 出现 `var dd={...}` 或 `var ddm={...}`
- 响应体出现 `You have been blocked`、`Please enable JS`
- 请求链出现 `ct.captcha-delivery.com/c.js`、`ct.captcha-delivery.com/i.js`
- 请求链出现 `geo.captcha-delivery.com/interstitial/`
- 请求链出现 `geo.captcha-delivery.com/captcha/` 或 `geo.captcha-delivery.com/captcha/check`
- 请求链出现 `dd.prod.captcha-delivery.com/image/...`、`dd.prod.captcha-delivery.com/audio/...`、`static.captcha-delivery.com/captcha/assets/pixel.png`
- 页面通过后加载 `js.datadome.co/tags.js`
- interstitial 请求体或 query 中出现 `payload`、`plv3`、`ps`
- captcha 校验请求中出现 `ddCaptchaChallenge`、`ddCaptchaEncodedPayload`、`ddCaptchaResponse`、`ddCaptchaEnv`、`ddCaptchaAudioChallenge`、`plv3`
- interstitial 响应出现 `view:"redirect"`、`view:"captcha"`、`ir` 原因码
- captcha/check 成功响应返回 `{"cookie":"datadome=..."}`

## 先分链路

DataDome 不是单一签名参数。阶段 0-3 必须先判断当前轮是无感 interstitial，还是 captcha / slider fallback。

常见分支：

```text
interstitial 无感链
= 入口 403 / challenge 上下文
→ 加载 i.js 或 interstitial 页面
→ 目标 JS 生成 payload / plv3 / ps
→ POST /interstitial/
→ 成功时返回 view:"redirect" + datadome cookie
→ 带 cookie 回到原页面验证

captcha 滑块链
= 入口 403 / challenge 上下文
→ 加载 c.js
→ GET /captcha/ iframe
→ iframe 内 JS 初始化 ddm、题面、行为采集
→ 用户或求解器给出滑块答案 / audio 答案
→ JS 生成 ddCaptchaEncodedPayload 或 ddCaptchaResponse、plv3
→ GET /captcha/check
→ 成功时返回 datadome cookie
→ 带 cookie 回到原页面验证
```

如果 interstitial 固定样本已字节级对齐，但 live 仍返回 `view:"captcha"`，不能继续默认是 interstitial body 写错。应记录为服务端当前轮切到了 captcha fallback，转而复现 `/captcha/` 与 `/captcha/check` 链路。

## interstitial 链

常见入口：

```text
GET 目标页面
→ 403 / 短 HTML
→ var dd = { rt, cid, hsh, t, s, e, host, cookie, ... }
→ GET https://ct.captcha-delivery.com/i.js
→ GET https://geo.captcha-delivery.com/interstitial/?...
→ POST https://geo.captcha-delivery.com/interstitial/
```

常见上下文字段：

```text
initialCid = dd.cid 或响应头 x-datadome-cid
hash       = dd.hsh
cid        = dd.cookie 或当前 datadome cookie
t          = dd.t
s          = dd.s
e          = dd.e
referer    = 原业务页面
```

常见 POST 字段：

```text
payload
plv3
ps
```

成功口径通常是：

```json
{"view":"redirect","url":"https://目标页/","cookie":"datadome=..."}
```

失败或升级口径常见为：

```json
{"view":"captcha", "url":"...", "ir":[...]}
```

`view:"redirect"` 只是保护链口径成功，最终还必须带返回的 `datadome` Cookie 请求原页面或原业务接口，确认不再返回 DataDome challenge。

## captcha / slider 链

常见入口：

```text
GET 目标页面
→ 403 / 短 HTML
→ var dd = { rt:"c", cid, hsh, t, s, e, host, cookie, ... }
→ GET https://ct.captcha-delivery.com/c.js
→ GET https://geo.captcha-delivery.com/captcha/?initialCid=...&hash=...&cid=...&t=...&referer=...&s=...&e=...&dm=cd
→ iframe HTML 内生成 var ddm = {...}
→ 滑块 / audio 行为完成后调用 window.captchaCallback()
→ GET https://geo.captcha-delivery.com/captcha/check?...
→ 响应返回 datadome cookie
→ 带 cookie 回到原页面验证
```

captcha iframe 常见下发字段：

```text
ddm.cid
ddm.hash
ddm.ua
ddm.s
ddm.userEnv
ddm.noPuzzle
ddCaptchaChallenge
ddCaptchaEnv
ddCaptchaAudioChallenge
captchaChallengePath
captchaAudioChallengePath
```

注意 `ddm.cid` 是 captcha iframe 下发的当前校验 cid，可能不同于首页 403 里的 `dd.cookie`。不要把 `initialCid`、首页 `datadome`、iframe `ddm.cid` 和最终通过后的 `datadome` Cookie 混成一个字段。

`/captcha/check` 常见 query：

```text
cid
icid
ccid
userEnv
dm
ddCaptchaChallenge
ddCaptchaEncodedPayload 或 ddCaptchaResponse
plv3
ddCaptchaEnv
ddCaptchaAudioChallenge
hash
ua
referer
parent_url
x-forwarded-for
s
ir
```

成功响应常见为：

```json
{"cookie":"datadome=...; Max-Age=31536000; Domain=...; Path=/; Secure; SameSite=None"}
```

captcha/check 成功仍是中间口径。最终成功口径是带该 Cookie 请求原页面或原业务接口，返回正常业务内容。

## 动态字段来源

captcha/check 中下列字段通常由服务端在 captcha iframe HTML 中直接下发或由前置响应传递：

```text
icid
hash
s
dm
referer
parent_url
ddm.cid
ddm.userEnv
ddCaptchaChallenge
ddCaptchaEnv
ddCaptchaAudioChallenge
```

下列字段是客户端动态产物，不能从历史 trace 硬编码到 live 会话：

```text
ddCaptchaEncodedPayload
ddCaptchaResponse
plv3
```

在 datedemo 的滑块样本中，captcha iframe 第三段 inline script 直接包含 DataDome captcha runtime。提交逻辑表现为：

```text
window.captchaCallback()
→ 拼接 /captcha/check query
→ 如果 window.captchaResponse 存在，提交 ddCaptchaResponse
→ 否则如果 window.captchaEncodedPayload 存在，提交 ddCaptchaEncodedPayload
→ 如果 window.plv3 存在，提交 plv3
```

同一份样本中，`window.captchaEncodedPayload` 在 `sendPayload` 中由当前轮 `ddm.cid`、行为采集结果、答案状态和环境状态生成；`window.plv3` 来自 iframe 内的检测逻辑结果。结论只能写到“这两个字段是当前轮动态 JS 产物”，不能写成固定值、固定长度或服务器静态下发。

## 行为与题面

DataDome slider 题面常包含：

```text
captchaChallengeSeed
captchaChallengePath
captchaAudioChallenge
captchaAudioChallengePath
width / height / sliderL / sliderR / offset
```

滑块链路通常会采集：

```text
mousedown / touchstart
mousemove / pointermove / touchmove
mouseup / touchend
slider 起点
slider 终点或 block left
移动轨迹
耗时
document.hasFocus()
事件 isTrusted 状态
```

如果 trace 显示行为轨迹参与 `ddCaptchaEncodedPayload`，只识别滑块 offset 不等于通过。必须把答案、轨迹、耗时和当前轮环境证明一起交给目标 JS 生成校验字段。

不要凭经验随意补点、平滑轨迹或压缩采样。轨迹长度、节奏、起终点和事件类型应以当前 trace 的 `event` / `jscall` / 请求长度级别为准。

## Header 与传输边界

DataDome 对请求边界敏感。必须以真实抓包为准，不要只看代码里声明的 Header。

常见首页 document GET：

```text
Host
User-Agent
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language
Accept-Encoding
Connection
Upgrade-Insecure-Requests: 1
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site
Sec-Fetch-User: ?1
Priority
```

常见 captcha iframe GET：

```text
Host
User-Agent
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language
Accept-Encoding
Referer: 原页面
Upgrade-Insecure-Requests: 1
Sec-Fetch-Dest: iframe
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: cross-site
Priority
```

常见 captcha/check XHR GET：

```text
Host
User-Agent
Accept: */*
Accept-Language
Accept-Encoding
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
Referer: 完整 captcha iframe URL
Cookie
Sec-Fetch-Dest: empty
Sec-Fetch-Mode: cors
Sec-Fetch-Site: same-origin
Priority
```

不要把 document navigation 的 `Upgrade-Insecure-Requests`、`Sec-Fetch-User` 等头错误带到 XHR 边界。反过来，也不要因为本地代码没写某个头就认为真实请求没带；某些客户端或代理会自动注入、去重或改写 Header，必须抓包确认。

如果请求在 JS 执行前就出现 HTTP/2 reset、TLS 指纹不匹配、连接层 400 或代理注入 Header，修复位置在 `test.py` 的传输层、TLS/ALPN、HTTP 版本、Header 管理和连接复用，不在 `code.js` 的 DOM/BOM 补环境。

## ruyitrace / jscall 观察点

命中 DataDome 后，优先按这个顺序确认：

1. `index.jsonl` / `http_packet`：确认首页 403、`c.js/i.js`、`/interstitial/` 或 `/captcha/`、`/captcha/check`、最终原页面 200。
2. `http_packet`：提取 `var dd`、`var ddm`、请求 Header、query/body、Set-Cookie、响应 JSON、`ir` 原因码。
3. `jscall`：搜索 `/captcha/check`、`captchaCallback`、`captchaEncodedPayload`、`captchaResponse`、`plv3`、`sendPayload`、`XMLHttpRequest.open/send`。
4. `event`：确认 slider/audio 的事件顺序、事件类型、是否 trusted、起点/终点和触发 submit 的时机。
5. `cookie`：确认 `datadome`、GA 或其它 Cookie 在各节点的发送、读取和 Set-Cookie 写入；特别区分首页 `datadome`、iframe `ddm.cid`、通过后的 `datadome`。
6. `storage`：确认 `localStorage/sessionStorage` 是否参与模式切换、audio 状态、缓存或风控状态。
7. `domtrace/descriptor`：只补目标集合相关链路实际读取的 DOM/BOM、canvas、Image、navigator、screen、performance、descriptor 和 native 外观；链路内对象还必须补实际字段、返回对象、状态、副作用、身份关系和事件/异步语义。
8. `exception`：确认浏览器真实异常与本地异常是否一致，避免把浏览器本来就发生的异常当成缺环境。
9. `profile`：只在 cookie/storage/cache 证据缺口明确时定向读取，不全量当文本日志。

## 本地落地建议

推荐职责拆分：

```text
test.py
├─ 建立真实 HTTP/TLS 会话
├─ 请求原页面并解析 var dd / 响应头 / Set-Cookie
├─ 根据 rt/view 判断走 interstitial 还是 captcha fallback
├─ 维护 Header、Cookie、Referer、同轮 cid/hash/s/e/userEnv
├─ 下载 captcha iframe / 题面资源
├─ 调用 code.js 或 runtime/*.code.js 生成动态校验字段
├─ 发送 /interstitial/ 或 /captcha/check
└─ 带返回的 datadome Cookie 请求原页面或原业务接口验证

code.js 或 runtime/datadome_*.code.js
├─ 固定当前目标版本的 DataDome JS 或最小入口
├─ 补齐当前 trace 证据命中的 DOM/BOM
├─ 生成 interstitial payload/plv3/ps 或 captcha payload/plv3
└─ 输出结构化 JSON 给 test.py
```

多入口项目建议拆分：

```text
runtime/datadome_interstitial.code.js
runtime/datadome_captcha.code.js
```

每个 runtime 只负责一个参数族。不要让 interstitial 入口假装能产出 slider captcha 的 `ddCaptchaEncodedPayload`。

## 常见坑

- 固定 trace 中的 `datadome` Cookie、`ddCaptchaEncodedPayload`、`plv3`、`payload` 到 live 会话。
- 把 interstitial 固定样本字节级对齐，误认为 live 必须返回 `view:"redirect"`。
- live 已返回 `view:"captcha"` 仍继续盲补 interstitial DOM/BOM，不转向 captcha fallback。
- 混淆 `initialCid`、首页 `dd.cookie`、captcha iframe `ddm.cid` 和最终通过后的 `datadome` Cookie。
- 只看验证码校验接口 200，不验证原页面或业务接口是否放行。
- 只解滑块 offset，不生成当前目标 JS 要求的行为证明。
- 忽略 `Referer` 必须是完整 captcha iframe URL。
- 把 document navigation Header 错带到 XHR，或忽略客户端自动注入的真实 Header。
- 把 TLS/HTTP/连接复用问题误判为 JS 补环境问题。
- 没有当前 trace 证据就批量补 canvas、WebGL、audio、font、plugin。
- 把 Google/GTM/GA 链路当成主因；除非当前 trace 或 live diff 明确证明其参与 DataDome 状态，否则它只能作为页面背景请求或 Cookie 背景材料记录。
- 除非用户当前明确要求，否则使用浏览器/页面自动化程序接管页面、模拟用户行为、生成参数或补齐证据；也不得用自动化跑出的参数替代本地 `code.js` / `runtime` 实现。
- 在 VMP / VM / opcode handler 内下探针或改写执行语义。遇到必须依赖 VMP 插装才能继续的路线，应暂停并回到外围请求边界、DOM/BOM 和事件证据。
