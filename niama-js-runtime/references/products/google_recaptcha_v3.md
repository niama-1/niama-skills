# Google reCAPTCHA v3 / invisible 参考文档

本文用于识别和处理 Google reCAPTCHA v3 / invisible 链路，重点覆盖 `grecaptcha.execute`、`api2/anchor`、`api2/reload`、`rresp`、`g-recaptcha-response`、`score/action` 和最终业务验证。它是产品经验参考，不替代当前目标实测；命中后仍必须以当前目标的 `jscall`、`http_packet`、`ruyitrace/` 和最终业务接口验证为准。

## 命中特征

出现以下特征时，优先按 Google reCAPTCHA v3 / invisible 链路分析：

- 页面加载 `https://www.google.com/recaptcha/api.js?render=<sitekey>` 或 `https://www.recaptcha.net/recaptcha/api.js?render=<sitekey>`
- 页面调用 `grecaptcha.execute(sitekey, {action})` 或 `grecaptcha.enterprise.execute(sitekey, {action})`
- 请求链出现 `/recaptcha/api2/anchor`、`/recaptcha/api2/reload`、`/recaptcha/enterprise/anchor`、`/recaptcha/enterprise/reload`
- reload 响应体前缀为 `)]}'`，数组中出现 `"rresp"`，其值被注入为 `g-recaptcha-response`
- 最终业务接口或验证接口提交字段名为 `g-recaptcha-response`、`recaptchaToken`、`recaptcha_response` 或同义 token 字段
- 最终验证返回或业务响应中出现 `success`、`score`、`action`、`challenge_ts`、`hostname`、`error-codes`
- 目标是“无感验证码”、“v3 评分”、“score >= 0.7”、“invisible reCAPTCHA” 或页面没有图片题面但仍需要 token

只出现 `recaptcha-token` 隐藏 input 不等于最终通过。`recaptcha-token` 通常是 anchor 页面内部状态或快照 token，不能当作最终 `g-recaptcha-response` 交付。

## 常见链路

标准 v3 / invisible 链路：

```text
业务页面加载 api.js?render=<sitekey>
-> 页面或业务 JS 调用 grecaptcha.ready / grecaptcha.execute(sitekey, {action})
-> reCAPTCHA runtime 加载 anchor 和 release 脚本
-> runtime / worker / iframe 生成 reload 请求体
-> POST https://www.google.com/recaptcha/api2/reload?k=<sitekey>
-> reload 响应返回 rresp
-> 页面把 rresp 作为 g-recaptcha-response 注入业务验证接口
-> 业务接口或 verify 口径检查 success / score / action / hostname
```

本地复现时，`code.js` / `runtime/*.code.js` 只负责执行当前目标版本的 reCAPTCHA runtime、补齐必要 DOM/BOM/worker/iframe/MessagePort 环境，并暴露 reload 请求面。`test.py` 负责真实 GET anchor、真实 POST reload、解析 fresh `rresp`、注入最终业务请求和验证口径。不要只看 `rresp` 是否存在。

在本 skill 的 Node 落地项目中，默认边界必须清楚：JS 生成参数和请求面，Python 发真实请求。除非用户明确要求并且项目文档另行记录，不要让 JS 直接发 `/recaptcha/api2/reload` 或最终业务接口。

reCAPTCHA 的第一阶段目标不是完整浏览器，而是让当前 `recaptcha__*.js` / worker / iframe 链路走到 `/recaptcha/api2/reload` 请求面。只要能稳定输出当前 reload URL、headers 和 body，就先交给 `test.py` 发真实 reload 和业务验证；不要继续补无关 DOM、指纹面或完整消息系统。

## 必须固定的目标信息

命中后先在 `param_info.md` 和进展清单记录：

```text
页面 URL
sitekey
action
recaptcha release 版本
api.js / anchor / recaptcha__*.js / webworker.js 当前资源
anchor URL 模板和 co/hl/v/size/anchor-ms/execute-ms
reload URL、method、Content-Type、POST body 长度和 hash
verify / 业务接口 URL、method、Header、Cookie、Body
最终成功口径：success / score / action / hostname / 业务放行字段
```

`sitekey`、`action`、release 版本和 anchor URL 是目标配置，可以固定。`rresp`、`g-recaptcha-response`、reload body、`Idempotency-Key`、anchor 内部 token、`cb`、时间窗口和部分证明字段必须按当轮动态生成，不能复用历史值。

## ruyitrace / jscall 优先动作

命中后优先做：

```text
1. 在 http_packet/index 中定位 api.js、anchor、recaptcha release、webworker、reload 和最终 verify/业务请求
2. 记录同轮 reload POST body 长度、hash、response 前缀、rresp 长度、最终 score/action
3. 在 jscall 中搜索 grecaptcha.execute、XMLHttpRequest.open/send、postMessage、MessageChannel、Worker、iframe、anchor
4. 在 domtrace/descriptor 中确认当前 runtime 触达的 document/window/navigator/screen/location/storage/iframe 外观
5. 在 event/message/worker 证据里确认 MessagePort、worker 和 iframe 通信顺序，只对齐有因果作用的顺序，不逐点复制 trace 时间
6. 用 v8trace 只观察外部宿主对象、方法入参、返回值和请求边界，不进入 VMP/opcode/handler 内部插装
7. 用 test.py 做最终 verify 或业务接口验证，确认 token fresh、同轮可用、未被消费
```

旧版 jscall 可能只有调用链和异常，不一定输出 reload protobuf 明文字段。遇到这种情况，不要把“日志量少”误判成 trace 不足；先用 `http_packet`、body hash、response、最终 verify 结果建立边界，再从 runtime 外围和 DOM/BOM 差异推进。

## 本地落地建议

推荐结构：

```text
assets/
└─ rtproxy.js

runtime/
├─ recaptcha_api.js
├─ recaptcha__<hl>.js
└─ webworker.js

code.js 或 code1.js
├─ assets/rtproxy.js 代理主体直接内联或项目相对引用
├─ 共享 helper
├─ window/document/location/navigator/screen/history/storage/performance 固定大区
├─ constructor / prototype / native toString 收口区
├─ iframe / MessageChannel / MessagePort / Worker / postMessage
├─ XMLHttpRequest / fetch 请求边界，只捕获 reload 请求面
├─ 从 runtime/ 加载当前目标版本 api.js / recaptcha__*.js / webworker.js
└─ get_g_recaptcha_response(input) 或输出 reloadRequest

test.py
├─ GET 当前 anchor 页面
├─ 调用 node code.js，把当前 anchorUrl / anchorHtml 传给 JS
├─ 接收 JS 输出的 reloadRequest(url/headers/bodyBase64)
├─ Python POST reload 并解析 fresh rresp
├─ 向最终 verify / 业务接口注入 g-recaptcha-response / otpSessionId / recaptchaToken
├─ 验证 success=true、score 达标、action/hostname 匹配，或验证业务接口进入放行/OTP/下一状态
└─ 输出 code_result、verify_result、耗时和错误
```

`assets/` 只放通用代理底座，目标 JS 资源放入 `runtime/`。不要把 `recaptcha_api.js`、`recaptcha__*.js`、`webworker.js` 混放到 `assets/`，否则后续会把代理资源和目标 runtime 混淆。

reload 请求边界在本 skill 默认由 Python 真实发送。若某个旧项目选择 Node 发送 reload，必须在项目进展清单写清原因、Header/Cookie/解压处理和完成口径；不得把“JS 直接发请求”当成默认路线。

XHR 补环境要保持浏览器外观：原型只暴露常见方法，例如 `open`、`setRequestHeader`、`getResponseHeader`、`getAllResponseHeaders`、`overrideMimeType`、`send`、`abort`。不要把 `_sendRecaptchaReload` 之类内部 helper 暴露到 XHR prototype。

### reload 最小环境优先

reCAPTCHA v3 / invisible 的本地 Node 目标优先级：

```text
1. 固定当前 api.js / anchor / recaptcha__*.js / webworker.js 版本
2. 建立最小 window/document/location/navigator/screen/performance/storage
3. 建立 anchor iframe、Worker、MessageChannel / MessagePort 和 postMessage 的目标链路最小语义
4. 让 runtime 走到 XHR/fetch reload 请求边界
5. 输出 reloadRequest(url/headers/bodyBase64)
6. test.py 实发 reload，解析 fresh rresp，并注入最终业务接口
7. 只有 reload 或业务验证失败且证据指向环境语义时，再提升环境质量
```

禁止把目标改成“补完整浏览器”。以下内容不是第一阶段目标：

- 完整 DOM 树、完整 CSS/layout/font、完整 plugin/mimeType、完整 canvas/WebGL/audio 指纹面。
- 完整 iframe 浏览器和完整 Worker 消息系统。
- 批量补全所有浏览器枚举字段。
- 为了“更像浏览器”而推迟 reload 请求面输出。

### MessagePort / Worker / iframe 链路禁区

reCAPTCHA runtime 对 MessagePort、Worker、iframe `postMessage` 和异步时序敏感。旧项目中常见失败不是少字段，而是消息模型错误。

禁止：

- 手写猜测式消息队列或 `localDeliver` 逻辑来冒充浏览器消息派发。
- 同步调用另一端 `onmessage`，导致 Promise/microtask/timer 顺序偏移。
- 伪造 `MessageEvent.source`、`origin`、`ports` 或 MessagePort 双端身份。
- 让 Worker `self` 指向主 window。
- 把 iframe `contentWindow`、`contentDocument` 做成空对象或主 document 复用。

处理顺序：

```text
先从 jscall / event / domtrace / http_packet 确认实际 message 链路
-> 只补推动 reload 请求边界所需的最小 source/ports/异步派发
-> 每次改动后运行到 reloadRequest 输出
-> 输出已稳定后先进入 test.py 验证
```

证据不足时不要猜消息模型；记录缺口并暂停该项。

### 执行模型禁区

reCAPTCHA 项目中，执行模型错误优先级高于字段缺失。出现以下问题时必须回退结构，而不是继续补字段：

- 把 Proxy 当成全局 VM 外壳塞进目标上下文，污染 timer、Promise、module、require、vm context 或目标内部对象。
- 全局定时器解析异常、Promise/microtask 顺序异常。
- `currentScript` 附着时过早执行目标脚本。
- script append/load、iframe load、anchor runtime 初始化时机早于真实链路。
- anchor runtime 被跳过，或 fallback token 短路，导致没有真实 reload。

### code.js 分区硬要求

Google v3 项目尤其容易因为赶进度把环境补乱。进入正式落地时，`code.js` / `runtime/*.code.js` 必须按以下大区维护：

```text
1. rtproxy 区
   - 使用 assets/rtproxy.js 模板的 rt_log / rtwatch / fun_to_native / native toString。
   - 关闭日志只改 rt_loginfo=false。
   - 不允许为了提速替换成自造代理。

2. shared helper 区
   - 放 makeElement / makeCollection / addEventSurface / MessagePort helper 等工厂函数。
   - 不在 helper 区写死 window/document/location/navigator/screen 的实例值。

3. 构造器 / 原型链 / native toString 收口区
   - 集中定义 Node / Element / Document / DOMParser / XMLHttpRequest / Worker 等构造器外观。
   - constructor 回指、Symbol.toStringTag、必要 prototype 关系、fun_to_native 必须在这里或紧邻定义处完成。
   - 不要在文件末尾堆一个无分区 native 化大名单。

4. 宿主对象大区
   - location 值只在 location 区。
   - navigator 值只在 navigator 区。
   - screen 值只在 screen 区。
   - document 节点和 document 方法只在 document 区。
   - window 自身属性、globalThis/self/top/parent/frames 绑定只在 window/globalThis 区。

5. request-face / runtime bridge 区
   - 从 runtime/ 加载 api.js、recaptcha__*.js、webworker.js。
   - 搭建 main window、anchor iframe window、worker scope。
   - XHR/fetch 只捕获 reload 请求面，不真实发网。
```

若用户已有模板要求 `window = rtwatch(global, "window")`、`document = rtwatch({...}, "document")`、`location = rtwatch({...}, "location")` 等写法，应按模板填值，不要换成 `buildRuntimeWindow`、`MiniDocument`、`Document extends Node` 这类项目外风格，除非用户明确允许。

### Google v3 请求面输出格式

JS 输出推荐为 reload 请求面，而不是 token：

```json
{
  "ok": true,
  "stage": "reload_request",
  "reloadRequest": {
    "url": "https://recaptcha.net/recaptcha/api2/reload?k=<sitekey>",
    "headers": {
      "Content-Type": "application/x-protobuffer",
      "Origin": "<page origin>",
      "Referer": "<anchor/page referer>"
    },
    "bodyBase64": "<current protobuf body base64>"
  }
}
```

Python 接收后：

```text
base64 decode bodyBase64
移除 Host / Content-Length / Connection / TE
session.post(reloadRequest.url, headers=headers, data=body)
解析 )]}' 前缀后的 JSON
提取 ["rresp", "<fresh token>"]
```

这样能强制保持边界：JS 负责生成请求面，Python 负责真实请求和业务验证。

## 本案难点与解决

本案目标为 `https://antcpt.com/score_detector/`，`sitekey=6LcR_okUAAAAAPYrPe-HK_0RULO1aZM15ENyM-Mf`，`action=homepage`，最终 `verify.php` 要求 `success=true` 且 `score>=0.7`。

关键难点：

- 旧 jscall 日志体量不小，但不输出 reload protobuf 的实际入参/返回值；不能直接从 jscall 还原明文字段。
- 历史 `rresp` 和 anchor hidden `recaptcha-token` 都不可复用；必须生成同轮 fresh token。
- reload body 与通过样本不必逐字节完全一致，本地 body 比 pass trace 短约 250-300 bytes 仍可被 Google 接受。
- relative URL `/recaptcha/api2/reload?k=...` 在 Node XHR 中必须解析为 `https://www.google.com/recaptcha/api2/reload?k=...`。
- Node `fetch` / undici 在本地 timer/performance shim 下不稳定，改用 Node `https` + `zlib` 后稳定。
- `RT_SKIP_ANCHOR_RECAPTCHA_LOAD=1` 会导致 `reCAPTCHA null`；anchor runtime 不能跳过。
- `RT_CROSS_ORIGIN_FRAME_GUARD=1` 会缩短 reload body，不是通过路线。
- `RT_ANCHOR_DOCUMENT_CONTEXT=1` 加 anchor token fallback 会短路为“看似 token ok”，但没有 reload 请求，不是通过路线。
- `RT_READY_STATE_LOADING=1` 会导致 `execute-timeout`；本案使用 `RT_READY_STATE_INTERACTIVE=1`。
- 盲目补长 `field16` 或强行对齐 trace body 长度不是必要路线；最终口径以 live reload + verify 成功为准。

本案解决路径：

```text
固定当前 api.js / recaptcha__en.js / anchor.html / webworker.js
-> 补基础 DOM/BOM、iframe、MessagePort、Worker、timer、storage 外观
-> 实现 XHR reload request boundary
-> relative reload URL 解析为 Google absolute URL
-> 用 Node https + zlib 发送 live reload 并解压响应
-> 从 live 响应提取 rresp
-> test.py 注入 verify.php
-> verify 返回 success=true、score=0.9、action=homepage
```

硬编码核查口径：

```text
搜索 code.js / runtime 中是否内置 0cAF... 或固定 rresp
连续运行 node code.js --json 或 --compact
比较 token 前后缀、reload body hash、reload response hash
要求 token/body/response 每轮不同，且 traceShaMatch=false 时仍可 status=200
```

本案两次正式运行的 token、reload body hash 和 response hash 均不同，说明不是 trace 常量回放。

## 案例流程：Weverse credential 登录 SIGNIN

本案目标为 Weverse Account credential 登录页，页面为 `https://account.weverse.io/en/login/credential`，验证码接口使用 `https://recaptcha.net/recaptcha/api2/`。目标 token 在登录提交链中生成，并作为业务请求 body 的 `otpSessionId` 注入 `POST /web/api/v4/auth/token/by-credentials`。

本案不是打开 `https://account.weverse.io/` 根页面时触发；触发点在 credential 登录提交链。必须以匹配当前目标的 `ruyitrace/index.jsonl`、业务 chunk 和 HTTP 包为准，不得只根据本地脚本能 `grecaptcha.execute` 就写成站点触发。

### Weverse 落地目录模板

本案落地时目录应保持：

```text
googlev3/
├─ assets/
│  └─ rtproxy.js
├─ runtime/
│  ├─ recaptcha_api.js
│  ├─ recaptcha__en.js
│  └─ webworker.js
├─ code1.js
├─ test.py
├─ param_info.md
├─ 补环境进展清单.md
├─ ruyitrace/
└─ recapcha流程分析/
```

规则：
- `assets/rtproxy.js` 只放代理模板。
- `runtime/` 放当前目标 JS 资源。
- `code1.js` 不从 skill 目录引用代理，不用 jsdom，不用浏览器自动化。
- `code1.js` 不发真实网络请求，只输出 reloadRequest。
- `test.py` 发真实 anchor / reload / Weverse 业务请求。

若目标语言或 release 变成 `recaptcha__zh_cn.js`，必须按当前抓包资源更新 `runtime/`，不要沿用旧文件名。

关键证据：

```text
页面 chunk:
000020_GET_200_account_weverse_io_next_static_chunks_pages_login_credential-66e9c4705975264e_js_*.http_packet.json

reCAPTCHA 请求链:
000121 GET  https://recaptcha.net/recaptcha/api.js?render=6LdHW1kpAAAAAMQ4itbdu1urGNh9v86jzGdLBMrM
000123 GET  https://recaptcha.net/recaptcha/api2/anchor?...&size=invisible&anchor-ms=20000&execute-ms=30000
000125 GET  https://recaptcha.net/recaptcha/api2/webworker.js?hl=en&v=A7KpaEASfhDcK0nXxgQEyyYv
000127 POST https://recaptcha.net/recaptcha/api2/reload?k=6LdHW1kpAAAAAMQ4itbdu1urGNh9v86jzGdLBMrM

业务消费请求:
000128 POST https://accountapi.weverse.io/web/api/v4/auth/token/by-credentials
```

业务 chunk 中的触发结构：

```text
w()
-> 如果 window.grecaptcha 不存在，创建 script
-> script.src = https://recaptcha.net/recaptcha/api.js?render=<sitekey>
-> document.body.appendChild(script)

b(action)
-> 等待 window.grecaptcha.ready
-> window.grecaptcha.execute(<sitekey>, { action })
-> 返回 token

登录提交链
-> generateOtpSession("SIGNIN")
-> postTokenByCredentials({ email, password, otpSessionId })
```

`jscall` 中可见页面 chunk 调用 `window.grecaptcha.ready`，来源为：

```text
https://account.weverse.io/_next/static/chunks/pages/login/credential-66e9c4705975264e.js
callee_name: .../window.grecaptcha.ready
```

`reload` 请求体中可见 `SIGNIN` 与 sitekey，同轮 `reload` 响应返回 `rresp`；后续登录请求将该 `rresp` 注入为 `otpSessionId`。记录时只写字段和长度 / hash，不输出账号、密码、token 或响应令牌。

### 请求顺序与参数流

本案请求顺序必须按同一轮链路记录，不能只摘 `otpSessionId`：

```text
1. GET /en/login/credential
   作用: credential 登录页入口
   输出: Next.js 页面与登录 chunk

2. GET /_next/static/chunks/pages/login/credential-*.js
   作用: 登录页业务逻辑
   关键逻辑: w() 插入 recaptcha api.js；b(action) 调用 grecaptcha.execute；提交链调用 generateOtpSession("SIGNIN")

3. GET https://recaptcha.net/recaptcha/api.js?render=<sitekey>
   触发来源: credential chunk 中 document.createElement("script")
   参数: render=<sitekey>

4. GET https://www.gstatic.cn/recaptcha/releases/<release>/recaptcha__en.js
   触发来源: api.js loader
   参数: release=<当前版本>

5. GET https://recaptcha.net/recaptcha/api2/anchor
   触发来源: grecaptcha.execute / runtime
   关键 query:
     k=<sitekey>
     co=<base64 origin，account.weverse.io>
     hl=en
     v=<release>
     size=invisible
     anchor-ms=20000
     execute-ms=30000
     cb=<动态值>

6. GET https://recaptcha.net/recaptcha/api2/webworker.js
   触发来源: anchor / runtime Worker 链
   关键 query:
     hl=en
     v=<release>

7. POST https://recaptcha.net/recaptcha/api2/reload?k=<sitekey>
   触发来源: Worker / runtime XHR
   请求体关键材料:
     sitekey
     action=SIGNIN
     anchor / runtime / worker 生成的动态证明字段
   响应:
     ["rresp", <fresh token>]

8. POST https://accountapi.weverse.io/web/api/v4/auth/token/by-credentials
   触发来源: credential 登录提交
   body 字段:
     email=<用户输入，不记录值>
     password=<用户输入，不记录值>
     otpSessionId=<第 7 步 rresp>
   headers 要保留:
     Origin / Referer / User-Agent / Accept-Language / Content-Type
     x-acc-app-version / x-acc-app-secret / x-acc-service-id / x-acc-language
     x-acc-trace-id / x-clog-user-device-id
   响应口径:
     进入 OTP 分支或其它业务层响应，不能是 captcha/token 错误

9. POST https://accountapi.weverse.io/web/api/v2/auth/otp
   触发来源: by-credentials 返回需要 OTP 后
   body 字段:
     otpSessionId=<同轮 fresh token>
   响应口径:
     HTTP 200，返回 expiresIn 等 OTP 状态字段

10. POST https://accountapi.weverse.io/web/api/v3/auth/token/by-credentials-with-otp
    触发来源: 用户输入 OTP 后完成登录
    body 字段:
      email=<同一登录输入，不记录值>
      password=<同一登录输入，不记录值>
      otpSessionId=<同轮 fresh token>
      otpCode=<用户输入，不记录值>
    响应口径:
      进入登录成功或明确业务错误；只记录字段存在和状态摘要，不输出 accessToken / refreshToken
```

`test.py` 编排时必须保证第 7 步 `rresp` 与第 8-10 步 `otpSessionId` 同轮、同会话、未过期、未被消费。若第 8 步请求失败，先做请求面 diff：URL、method、headers、body、preflight、session、trace id 和设备 id 是否与抓包一致；未对齐前不得定性为补环境或 reCAPTCHA runtime 错误。

### Weverse 请求头真值对齐

Weverse 业务接口失败时，优先检查业务请求头，不要回头盲补 Google 环境。当前案例中 `Incorrect API usage.\nheaders` 的根因是 Weverse 业务头不一致，而不是 rresp 不可用。

请求头基线必须从 `ruyitrace/*.http_packet.json` 的 requestHeaders 提取。常见关键项：

```text
User-Agent
Accept: */*
Accept-Language
Referer: https://account.weverse.io/
Content-Type: application/json
Origin: https://account.weverse.io
X-ACC-TRACE-ID: UUID 形态
X-ACC-APP-VERSION: 当前抓包版本，例如 4.6.5
X-ACC-APP-SECRET: 当前抓包值
X-ACC-SERVICE-ID: weverse
X-ACC-LANGUAGE: en
X-CLOG-USER-DEVICE-ID: UUID 形态
X-ACC-DEVICE-ID: UUID 形态
Cookie: wa_device_management_id / we2_device_id / we2_service_lang / consent
Idempotency-Key
Priority
Sec-Fetch-Dest / Sec-Fetch-Mode / Sec-Fetch-Site
```

不要把 `Content-Length`、`Host`、`Connection`、`TE` 写死到 Python headers；这些由 HTTP 客户端或传输层处理。JSON body 推荐使用紧凑编码，避免无意义空格造成请求面差异。

判断口径：
- 如果 by-credentials 返回 `Incorrect API usage.\nheaders`，优先做 Weverse Header/Cookie/Body diff。
- 如果 by-credentials 返回 `Email OTP verification is required`，说明 fresh rresp 已进入业务层。
- 如果 `/web/api/v2/auth/otp` 返回 200 和 `expiresIn`，说明 OTP 触发链路已通。
- with-otp 需要当前邮箱 OTP，不能用旧 OTP 或 trace 里的响应冒充。

### Weverse 文档/流程文件最低要求

项目内 `recapcha流程分析/全流程.txt` 或同类流程文档必须写清：

```text
1. 点击登录 -> grecaptcha.execute(SIGNIN)
2. api.js -> recaptcha__en.js -> anchor -> webworker.js -> reload
3. anchorUrl 和 recaptcha.anchor.Main.init 的作用
4. Worker / importScripts / MessageChannel 的作用
5. code1.js 只捕获 reload 请求面
6. test.py Python 实发 reload 并解析 fresh rresp
7. rresp 作为 otpSessionId 注入 by-credentials / otp / with-otp
8. 当前实测结果：reload 200，业务进入 OTP，otp 200
9. 明确 trace 里的 rresp/token/业务成功响应不能复用
10. 当前文件分区：assets 只放 rtproxy，runtime 放目标 JS
```

流程文档不要堆完整旧 token 或完整旧 rresp。需要说明时只记录字段名、长度、hash、响应状态和用途。

按本 skill 归类：

```text
runtime_mode: node_mode
目标类型: full_flow
full_flow_subtype: full_flow_captcha_chain
验证码触发点: captcha_login
触发动作: credential 登录提交
目标集合: SIGNIN reCAPTCHA token / otpSessionId
runtime_shape: worker_runtime
version_risk: candidate
code.js / runtime 负责: 本地运行当前 reCAPTCHA release，生成 fresh token
test.py 负责: 保留完整请求面，注入 otpSessionId，并验证登录 / OTP 链路响应
```

本案补环境重点：

```text
api.js loader
anchor iframe
webworker.js / Worker VM
MessageChannel / MessagePort / postMessage
XMLHttpRequest 或等价 reload 请求边界
document.createElement / appendChild 触发 iframe/script 加载
location / navigator / screen / performance 等基础 BOM
```

完成门禁：

```text
node code.js 当前实时生成 fresh token
api.js -> anchor -> webworker -> reload 链路真实发生
reload response 当前返回 rresp
test.py 将当前 rresp 作为 otpSessionId 注入登录请求
登录接口进入 OTP 或其它业务层响应，而不是 captcha/token 错误
敏感值不输出、不落盘
```

## 常见坑

- 把浏览器侧 token、历史 `rresp`、anchor hidden `recaptcha-token` 当最终交付。
- 只看 reload `status=200`，不验证最终 `score/action/hostname`。
- 用浏览器自动化直接跑 token 替代本地 `code.js` 实现。
- 因为 body 长度与通过 trace 不完全一致就盲补字段；Google 已接受并返回可验证 `rresp` 时，长度差异不是阻塞。
- 跳过 anchor runtime 或用 fallback token 短路，导致没有真实 reload。
- 把 trace 时间戳、长卡顿或密集日志 `dt` 写进本地 timer/等待节奏。
- 在 reCAPTCHA 混淆/VMP/opcode/handler 内部插装推进；补环境只围绕外部 DOM/BOM、MessagePort/Worker/iframe 和请求边界。
- 把 `fetch` 异常误判成算法错误；先确认是否被本地 shim 污染。
- 不记录硬编码核查，导致后续无法证明 token 是动态生成。
- 要求冷启动 1-2 秒出 fresh token；本案 token-only 冷启动约 4.5-6.8 秒，完整 verify 样本约 10.9 秒，瓶颈主要是 Google reload 与 verify 网络。

## 验证口径

至少同时满足：

```text
node code.js --json 或 --compact 返回 ok=true、stage=token
reload_network.status=200，responsePreview 含 rresp
连续两次运行 token、reload body hash、response hash 不同
test.py 注入最终 verify / 业务接口
最终返回 success=true，score 达标，action 与目标 action 一致，hostname 与目标站一致
进展清单记录通过样本、失败路线、硬编码核查和当前下一步
```

如果目标要求业务放行，不要只用 Google verify 口径；必须回到原业务接口，确认不再返回验证码拦截或风控失败。
