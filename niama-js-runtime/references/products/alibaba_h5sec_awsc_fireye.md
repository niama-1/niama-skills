# 阿里系 H5Sec / AWSC / Fireye 140/231/234 / x5sec 参考文档

本文用于识别和处理阿里系业务页中的 H5Sec `securityHeader`、AWSC、Fireye/Baxia 231/234、UAB 140、WebUMID 和 x5sec 处罚链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据、请求证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

本文只覆盖“业务请求前置风控 headers/metas/cookie + x5sec punish”的链路，不等同于阿里云验证码 v2 滑块、1036/WAF、noCaptcha 题面校验或站点业务加密。阿里产品很多，命中时必须先拆清楚当前请求依赖的是哪一类。

## 命中特征

出现以下特征时，可优先按 H5Sec / AWSC / Fireye 140/231/234 链路分析：

- 页面加载 `g.alicdn.com/code/npm/@alife/alsc-h5-sec/.../securityHeader.min.js`
- 页面加载 `g.alicdn.com/AWSC/AWSC/awsc.js`
- 页面加载 `g.alicdn.com/AWSC/fireyejs/1.231.x/...`、`1.234.x/...` 或同类 `fireyejs.js`
- 页面加载 `g.alicdn.com/AWSC/uab/.../collina.js`
- 页面加载 `g.alicdn.com/AWSC/et/.../et_f.js`
- 页面加载 `g.alicdn.com/AWSC/WebUMID/.../um.js`
- 页面加载 `g.alicdn.com/sd/baxia/.../baxiaCommon.js`
- JS 或 trace 中出现 `securityHeader.getSecurityHeaders`、`securityHeader.initSecurity`、`AWSC.configFYEx`、`AWSC.configFY`、`AWSCInner.register`
- 请求头出现 `bx-ua`，值以 `231!` 或 `234!` 开头
- 请求头出现 `bx-umidtoken`，常见长度约 68，值以 `T2gA` 开头
- 请求体或业务 metas 中出现 `AsuraId`、`fire_ua`，值以 `140#` 开头
- 请求体或业务 metas 中出现 `fire_umid`，常见长度约 68，值以 `T2gA` 开头
- Cookie 中出现 `tfstk`、`cna`
- storage 中出现 `tfstk__` 或同类 H5Sec 状态
- 响应头或响应体出现 `bxpunish: 1`、`x5secdata`、`_____tmd_____/punish`、`__bx__`
- 业务请求本身不是验证码 verify 接口，但缺少或错误携带上述风控材料时返回 `FAIL_SYS_USER_VALIDATE`、处罚 URL 或挤爆类错误

不要只因为出现 `AWSC` 就直接判成滑块验证码。若没有 `captcha-pro-open.aliyuncs.com`、`device.captcha-open.aliyuncs.com`、`StaticPath`、`Result`、题面图片或 verify 接口，当前更可能是 H5Sec/AWSC headers/metas 风控链。

## 与其它阿里链路的区分

```text
阿里云验证码 v2
= captcha-pro-open.aliyuncs.com / device.captcha-open.aliyuncs.com / requestInfo / StaticPath / FeiLin / Result / verify

noCaptcha / nc.js
= cf.aliyun.com/nocaptcha / nc.js / 滑块或无感 challenge / nc token

H5Sec / AWSC / Fireye 140/231/234
= securityHeader / AWSC.configFYEx / AWSC.configFY / bx-ua=231!/234! / AsuraId=140# / fire_ua=140# / bx-umidtoken / fire_umid

Baxia / x5sec punish
= baxiaCommon.js / x5secdata / bxpunish / _____tmd_____/punish / __bx__

1036 / WAF
= refer__1036 / ssxmod_itna / ssxmod_itna2 / acw_tc / WAF HTML / aliyun_waf_*

业务加密
= 站点自己的 req/res/AES/签名参数，只负责业务载荷，不代表验证码或 AWSC 已通过
```

同一页面可能同时加载多个阿里安全组件。最终以目标业务请求实际携带和服务端实际校验的字段为准。

## 常见链路

H5Sec / AWSC 140/231/234 登录或业务请求常见链路：

```text
打开业务页面
-> 页面加载 securityHeader / AWSC / fireyejs / uab / et_f / WebUMID / Baxia
-> securityHeader.initSecurity 初始化 dependHeaders
-> AWSC.configFYEx 初始化 231 Fireye 对象
-> AWSC.configFY 初始化 140 UAB / Fireye 对象
-> 浏览器环境和行为日志进入 Fireye/UAB 采集器
-> WebUMID 生成或刷新 T2gA... token
-> et_f / Fourier 链写入或刷新 tfstk
-> 业务代码组装 metas：AsuraId / fire_ua / fire_umid
-> securityHeader.getSecurityHeaders 生成 bx-ua / bx-umidtoken
-> Baxia 或 securityHeader 包装 XHR/fetch 并注入 headers
-> 业务请求携带 headers + metas + cookie 发送
-> 服务端返回正常业务错误或业务数据
```

### 231 / 234 版本边界

- `231!` 与 `234!` 是同一 bx-ua 家族的版本/变体线索；目标为 `234!` 时仍按 `initSecurity -> storage/message/XHR/UMID/行为状态 -> getSecurityHeaders -> 最终请求` 还原，不另建重复产品路线。
- 当前目标若出现两次 `securityHeader.getSecurityHeaders`，必须按真实调用顺序保存两次调用前后的 message、XHR、UMID、storage 和行为状态；只有请求边界实际消费的那次结果可用于业务请求，不能默认取第一次或最长值。
- 稳定入口优先使用中性 `get_bxua(input)`；只有项目契约明确区分版本时才使用 `get_231/get_234`，并记录脚本 URL/hash 和适用请求。

如果任一环节不稳定，常见表现不是验证码弹出，而是业务接口直接进入 x5sec punish：

```text
业务请求
-> 服务端返回 FAIL_SYS_USER_VALIDATE
-> 响应头 bxpunish=1 或 Set-Cookie: x5secdata=...
-> 响应体包含 _____tmd_____/punish?x5secdata=...__bx__...
```

## 参数产出方式

不要把这类链路收敛成一个“过验证码 token”。通常需要同时产出并带上多类材料：

- `bx-ua`: 请求头，Fireye/Baxia 231/234 输出，前缀 `231!` 或 `234!`
- `bx-umidtoken`: 请求头，WebUMID / Fireye 输出，常见前缀 `T2gA`
- `AsuraId`: 请求体 metas，UAB 140 输出，前缀 `140#`
- `fire_ua`: 请求体 metas，140 链路输出，前缀 `140#`
- `fire_umid`: 请求体 metas，常见前缀 `T2gA`
- `tfstk`: Cookie，通常由 `et_f` / Fourier / document.cookie 写入
- `cna`: Cookie，阿里系常见设备标识，部分业务请求必须同带
- `X-Eleme-RequestID` 或站点自定义 request id: 通常是业务代码生成，不属于 AWSC token，但可能要对齐格式
- `x-shard`、`Origin`、`Referer`、`Accept`、`Content-Type`: 业务请求边界字段，不要在重建请求时漏掉

这些材料要来自同一轮运行或同一可用会话。历史 token、旧 cookie、旧 `tfstk` 或旧 `x5secdata` 回放常会被服务端判为 punish。

## 常见环境面

H5Sec / AWSC / Fireye 140/231/234 常见触达这些环境面：

```text
window / self / document / location / navigator / screen
navigator.userAgent / appVersion / language / languages / platform / oscpu
navigator.plugins / mimeTypes / hardwareConcurrency / deviceMemory / webdriver
document.cookie / localStorage / sessionStorage
performance.now / timing / getEntriesByType("resource")
document.createElement / appendChild / script.src / image.src
EventTarget / addEventListener / dispatchEvent
MouseEvent / KeyboardEvent / FocusEvent / input/change/click/mousemove/mousedown/mouseup
HTMLMediaElement.canPlayType / Audio / video
canvas 2d / WebGL getParameter / getSupportedExtensions / getShaderPrecisionFormat
Function.prototype.toString / native-like constructor 外观
Object.getOwnPropertyDescriptor / ownKeys / prototype / Symbol.toStringTag
XMLHttpRequest / fetch / sendBeacon / Headers / Request / Response
setTimeout / setInterval / requestAnimationFrame
```

这些值、descriptor、prototype、native 外观和事件形态不能靠旧项目硬套。命中新目标时，必须先由本地异常、产物长度、请求 diff、v8trace 事实或服务端响应形成候选，再从匹配当前目标的 `ruyitrace/` 复取真实值。

## ruyitrace/jscall 优先动作

命中 H5Sec / AWSC / Fireye 140/231 后，优先做：

```text
1. 搜索 securityHeader.getSecurityHeaders、securityHeader.initSecurity、AWSC.configFYEx、AWSC.configFY、AWSCInner.register
2. 搜索 bx-ua、bx-umidtoken、AsuraId、fire_ua、fire_umid、tfstk、cna、tfstk__
3. 搜索 x5secdata、bxpunish、_____tmd_____/punish、__bx__、FAIL_SYS_USER_VALIDATE
4. 用 domtrace/jscall 确认业务 XHR/fetch 的 open、setRequestHeader、send 和 response
5. 用 cookie/storage 分区确认登录或业务请求前后的 cna、tfstk、localStorage 状态
6. 用 domtrace/descriptor 确认关键环境真值，尤其是 UA、screen、media、plugins、WebGL、performance entries
7. 用本地 runtime 跑出 token shape，再和 trace 中 bx-ua/body 长度级别对照
8. 用 test.py 真实发送，最终以业务接口是否离开 punish 并返回正常业务响应为准
```

如果 `bx-ua`、`AsuraId`、`fire_ua` 都存在但明显比 trace 短，优先检查事件/行为采集窗口、performance entries、WebGL/media 分支和初始化等待，而不是先怀疑业务 body 结构。

如果本地标准 HTTP 客户端发送同一套参数仍返回 punish，要检查 TLS/HTTP 传输指纹。H5Sec/AWSC 通过不只看 JS 字段，也可能要求请求传输层接近浏览器。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
runtime/awsc_env.code.js
├─ v8trace 事实吐出 / native toString 保护
├─ 当前 trace 证明触达的 BOM/DOM/storage/performance 环境
├─ Firefox 或 Chrome 轮廓：JS UA、语言、screen、plugins、mimeTypes
├─ media / canvas / WebGL 等指纹面
├─ EventTarget 和最小行为 warmup
├─ securityHeader / AWSC / fireyejs / uab / et / WebUMID 资产
└─ get_awsc_tokens(input) 输出 140/231/umid/cookie

code.js
├─ 业务请求构造
├─ token 文件 / env / inline token 优先级
├─ 缺完整 token 时调用 runtime/awsc_env.code.js 动态生成
└─ buildLoginRequest 或 buildBusinessRequest 输出真实请求材料

test.py
├─ 默认 dry-run，显式 --send 才发包
├─ 使用 curl_cffi 或等价浏览器 TLS impersonation
├─ 保留 trace 证据中的 Header、Cookie、body 结构和业务参数
└─ 验证 riskBlock、punish、业务错误码和业务数据
```

不要把旧 trace 中的完整 `231!`、`140#`、`tfstk` 当长期稳定值写死。它们只能作为形状、长度级别、前缀和排错参照。

## melody.shop.ele.me 案例要点

本案例来自 `https://melody.shop.ele.me/login` 登录链路，目标接口是：

```text
POST https://app-api.shop.ele.me/xtop/xtop.napos.keeper.login.loginByUsername/2.0
```

trace 中正常浏览器请求的关键形态：

```text
Header bx-ua        = 231!...，trace 截断长度约 2508
Header bx-umidtoken = T2gA...，长度约 68
Body metas.AsuraId = 140#...
Body metas.fire_ua = 140#...
Body metas.fire_umid = T2gA...
Cookie             = tfstk=...; cna=...
Body length        = 3785 左右
业务响应           = 用户名密码错误 / showCaptcha=false / loginFailType=USERNAME_NOT_EXIST
```

本次任务中遇到的主要难点和解决方式：

- 误判方向：一开始围绕“滑块/验证码是否触发”排查，但 trace 证明目标登录请求正常返回业务错误，未触发验证码题面。解决方式是回到 `loginByUsername` 请求链，以 140/231/x5sec 为主线。
- trace 选择：多次补采中有误采和未点击提交的 trace。解决方式是只使用命中 `https://melody.shop.ele.me/login` 且存在 `loginByUsername` XHR 的主 trace。
- Fireye 231 崩溃：本地出现 `fy_231 ... B[pe] is not a function`，trace 反查对应到 `HTMLMediaElement.canPlayType`。解决方式是补 `HTMLMediaElement`、`HTMLAudioElement`、`HTMLVideoElement`、`Audio` 和 Firefox 真实 `canPlayType` 返回值。
- token 过短：本地最初 `bx-ua` 约 1500、body 约 2000，trace 中 `bx-ua` 约 2508、body 约 3785。解决方式是补行为 warmup，在取 headers/metas 前持续触发 mouse/key/focus/input 等事件，8 秒左右后 token 长度贴近 trace。
- cookie 缺口：本地初期只有 `tfstk`，trace 请求实际携带 `tfstk` 和 `cna`。解决方式是注入 trace 证明存在的 `cna`，并按请求头合并顺序输出 `tfstk; cna`。
- 浏览器轮廓不一致：本地请求最初是 Firefox 140、`zh-CN`、1920x1080，trace 是 Firefox 151、`en-US`、1536x864。解决方式是同时对齐 JS 环境和最终请求 Header。
- 传输层问题：同样的 140/231/cookie 用 Python `urllib.request` 发送仍返回 `FAIL_SYS_USER_VALIDATE` / `x5secdata`，换 `curl_cffi:firefox147` 后返回正常业务错误。解决方式是把发送层视为验证口径的一部分，不把 JS 参数正确误判成全链路通过。

最终通过的本地验证形态：

```text
tokenSource = runtime/awsc_env.code.js
bx-ua       = 231!...，长度约 2470
AsuraId     = 140#...，长度约 1750
fire_ua     = 140#...，长度约 1750
bodyLength  = 3800+，贴近 trace
transport   = curl_cffi:firefox147
riskBlock   = false
response    = 用户名密码错误 / showCaptcha=false / loginFailType=USERNAME_NOT_EXIST
```

这个案例说明：H5Sec/AWSC 不是“通过后返回一个 cookie 或 token 再登录”。它更像是本地同轮生成 headers、metas 和 cookie，然后直接带在登录请求上。成功标志是业务接口不再进入 x5sec punish，而是返回正常业务边界。

## 常见坑

- 把 `231!`、`140#` 链路误认为阿里云 v2 滑块验证码
- 没有验证码题面时仍继续找滑块，忽略登录接口已经有正常业务错误响应
- 复用历史 token 文件或旧 trace 的 `tfstk`，导致 `FAIL_SYS_USER_VALIDATE`
- 只生成 `bx-ua`，漏掉 `AsuraId/fire_ua/fire_umid`
- 只补 140 metas，漏掉 `bx-ua/bx-umidtoken`
- 只补 JS token，漏掉 `tfstk/cna` cookie
- 只看 token 前缀正确，不看长度级别、body 长度和服务端响应
- 只改 HTTP Header UA，漏掉 JS 环境里的 `navigator.userAgent/appVersion/language/screen`
- 只补 canvas/WebGL，漏掉 media `canPlayType`、plugins、performance resource 或事件采集窗口
- 只用 Node/Python 标准 HTTP 客户端发送，忽略 TLS/HTTP 指纹导致的 punish
- 只看 HTTP 200，不检查 `bxpunish`、`x5secdata`、`FAIL_SYS_USER_VALIDATE` 和业务字段
- 把 `用户名密码错误` 误判为失败；随机账号密码场景下这是通过风控后的正常业务响应

## 验证口径

H5Sec / AWSC 140/231 链路至少同时满足：

```text
动态生成 bx-ua，前缀 231!，长度级别接近 trace
动态生成 bx-umidtoken，前缀 T2gA 或 trace 证明的同类形态
动态生成 AsuraId / fire_ua，前缀以当前 trace 为准，本案例为 140#
动态生成 fire_umid，前缀和长度级别接近 trace
Cookie 中带当前会话需要的 tfstk / cna
请求 body 结构、metas、params、extraInfo 与 trace 对齐
最终发送层使用与浏览器相容的 TLS/HTTP 指纹
业务接口不返回 bxpunish / x5secdata / punish URL
业务接口返回正常业务 JSON、正常错误码或目标数据
```

注意：`140#` 是本案例 trace 中的前缀，个别阿里链路前缀或字段名可能不同，必须以当前目标实测为准。

## 使用边界

本文只指导优先观察点和常见问题，不提供可直接套用的固定环境值、固定 token 或固定 cookie。

补入 `code.js` 或 `runtime/*.code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据、当前运行差异和匹配当前目标的 `ruyitrace/` 真实值。
