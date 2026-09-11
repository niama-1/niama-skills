# 京东 JCAP 滑块参考文档

本文用于识别和处理京东 PC 登录图形验证码 / JCAP 滑块链路，重点是 `jcap.m.jd.com` 的 `fp`、`refresh/check`、滑块题面、交互证明 `ct/tk/cs`、服务端签发的 `vt`，以及 `vt` 注入后续 `passport.jd.com/uc/loginService` 的请求边界。

本文是产品专项经验参考，不替代当前目标实测。任何补入 `code.js` 的 DOM/BOM 值、环境外观、事件顺序、`ct/tk/cs` 入参、轨迹结构、Header、Cookie 和请求体，都必须来自当前目标的 `jscall`、`http_packet`、`storage/domtrace` 或已收敛的当前 trace 资产。

## 命中特征

出现以下特征时，优先按京东 JCAP 滑块链路分析：

- 请求链出现 `https://jcap.m.jd.com/cgi-bin/api/fp`、`/cgi-bin/api/refresh`、`/cgi-bin/api/check`
- 登录页或脚本出现 `requireCaptchaPc.js`、`jcap_*.js`、`window.jdCAP`、`jdCAP.captcha(info)`
- JCAP 脚本来自 `storage.360buyimg.com/jsresource/jcap/version/.../jcap_*.js`
- 登录链出现 `passport.jd.com/uc/graphic/sessionId/refresh`
- 登录提交体出现 `graphicCaptchaSessionId`、`graphicCaptchaJwtToken`、`graphicCaptchaVerifyToken`
- JCAP 请求体出现 `si`、`ct`、`tk`、`cs`、`se`、`version`、`lang`、`client`
- JCAP 响应出现 `st`、`fp`、`tp`、`img`、`vt`
- 滑块题面响应中 `tp=30`，`img` 中包含背景图和滑块小图，例如 `b1` / `b2`
- 最终校验失败出现 `code=16807`、`s_code=16130`、`code=16808`、`msg=验证失败` 或 `msg=验证未通过`
- 后续登录提交还同时出现 `h5st`、`_stk`、`aksParamsU`、`aksParamsB`

如果同一目标同时命中 `h5st/_stk/request_algo/tk03`，还必须读取 `references/products/jd.md`。`jd_jcap.md` 负责 JCAP 滑块和 `vt`；`jd.md` 负责京东业务签名、h5st、request_algo 和业务接口风控判断。

## 核心边界

JCAP 链路的目标不是直接登录成功，而是拿到当前会话可用的图形验证码通过 token：

```text
graphicCaptchaVerifyToken = vt
```

`vt` 的来源是 JCAP `/cgi-bin/api/check` 校验成功后的服务端响应，不是登录接口返回值，也不是 `h5st`、`aksParamsU`、`aksParamsB` 或密码加密过程的产物。

`vt` 通常具备以下绑定：

- 绑定 `graphicCaptchaSessionId`
- 绑定同轮 `graphicCaptchaJwtToken`
- 绑定同一浏览器/请求会话中的 Cookie
- 绑定当前 `st/fp` 或 JCAP 服务端状态
- 单次消费或短时效，浏览器现场先消费后，本地重放经常失败
- 与登录提交的时序强相关，拿到后应立即注入 `/uc/loginService`

## 总请求链

京东 PC 登录图形验证码常见全链路：

```text
登录页入口 passport.jd.com/new/login.aspx
→ 读取页面 hidden fields、cookie、eid/fp/uuid/_t、public key
→ GET passport.jd.com/uc/graphic/sessionId/refresh
→ 得到 graphicCaptchaSessionId / graphicCaptchaJwtToken / appId / status
→ 加载 jcap.m.jd.com/home/requireCaptchaPc.js
→ 加载 storage.360buyimg.com/jsresource/jcap/version/.../jcap_*.js
→ window.jdCAP.captcha(info) 初始化验证码工厂
→ factory(option) 创建验证码实例，option 带 sessionId/account/onSuccess/onFailure/onCancel/onLoad
→ POST jcap.m.jd.com/cgi-bin/api/fp
→ 得到 fp/st 或服务端状态
→ POST jcap.m.jd.com/cgi-bin/api/check 或 /refresh 获取滑块题面
→ 响应 tp=30/img，解析背景图和滑块小图
→ 生成滑块答案 A、touchList、records/fpt
→ POST jcap.m.jd.com/cgi-bin/api/check 提交答案证明
→ code=0 且响应带 vt
→ 将 vt 写入 graphicCaptchaVerifyToken
→ 构造 /uc/loginService plain body
→ ParamsSign 生成 h5st/_stk
→ summer-cryptico-h5 生成 aksParamsU/aksParamsB
→ POST passport.jd.com/uc/loginService
→ 根据业务响应判断验证码、签名、加密、账号态或安全验证状态
```

注意：不同版本脚本里，滑块题面可能由 `/refresh` 返回，也可能由一次 `/check` 返回 `tp=30/img`。必须以当前 `http_packet` 或实时抓包确认题面实际落点，不要硬套端点顺序。

## JCAP 初始化

页面入口通常先拿图形验证码上下文：

```text
GraphicCaptchaHelper.getContext()
→ { account, status, appId, sessionId, jwtToken }
```

随后登录分支创建验证码：

```text
GraphicCaptchaHelper.create({
  sessionId,
  account,
  onSuccess,
  onFailure,
  onCancel,
  onLoad
})
```

底层 JCAP 初始化常见形状：

```js
window.jdCAP.captcha({
  appType: 3,
  tdat_version: 99992,
  host: "jcap.m.jd.com",
  tdat_ctx: "...",
  cs: 1
})
```

`tdat_ctx`、`cs`、`appType`、`tdat_version` 必须来自当前页面和脚本证据。不要把旧样本配置写成固定值。

## sessionId 刷新

常见请求：

```text
GET https://passport.jd.com/uc/graphic/sessionId/refresh?... 
```

常见响应字段：

```text
code
msg
appId
status
sessionId
jwtToken
```

本地联调时，`test.py` 应负责请求 fresh session，并把返回值注入 `code.js`：

```text
graphicCaptchaSessionId = sessionId
graphicCaptchaJwtToken = jwtToken
```

如果使用旧 `sessionId/jwtToken/vt`，常见结果是 JCAP 自身返回失败，或登录接口返回“图形验证码参数校验失败，请刷新重试”。

## /api/fp

常见请求：

```text
POST https://jcap.m.jd.com/cgi-bin/api/fp
Content-Type: application/x-www-form-urlencoded;charset=UTF-8
Origin: https://passport.jd.com
Referer: https://passport.jd.com/
```

常见 body：

```text
si=<graphicCaptchaSessionId>
ct=<client proof>
version=3
lang=<lang>
client=<platform/client>
```

字段说明：

- `si`：当前 `graphicCaptchaSessionId`
- `ct`：客户端环境/光标/设备信息证明，通常由 JCAP 当前脚本的公开 binding 或同类封装函数生成
- `version`：当前脚本协议版本，常见为 `3`
- `lang`：语言环境，按当前页面和脚本取值
- `client`：平台或客户端标识，按当前脚本取值

常见响应：

```text
code=0
fp=<server fp>
st=<server state>
tp=<optional type>
```

`st` 是后续生成 `tk` 或请求下一阶段时的重要状态，不应跨会话复用。

## /api/refresh

部分 JCAP 版本使用 `/refresh` 获取题面。

常见请求：

```text
POST https://jcap.m.jd.com/cgi-bin/api/refresh
```

常见 body：

```text
si=<graphicCaptchaSessionId>
version=3
se=<refresh proof>
lang=<lang>
client=<platform/client>
type=<captcha type>
```

字段说明：

- `se`：刷新题面证明，常见由当前脚本用 `sessionId` 和上一阶段 `st` 生成
- `type`：题型或请求类型，必须来自当前脚本分支

常见响应：

```text
code=0
tp=30
img=<json/base64 payload>
st=<new state>
```

`tp=30` 常见为滑块拼图。`img` 通常能解析出背景大图和滑块小图，字段名可能是 `b1/b2` 或当前版本的等价字段。

## /api/check

`/check` 既可能用于拿题面，也可能用于提交答案。必须按响应区分阶段。

### check_challenge

在某些 PC 登录链中，`/fp` 后第一次 `/check` 会返回滑块题面：

```text
POST https://jcap.m.jd.com/cgi-bin/api/check
```

body 仍然是 `si/lang/tk/ct/cs/version/client` 形状，但此时 `tk/cs` 可能只是足以进入题面分支的当前状态证明。

常见响应：

```text
code=0
tp=30
img=<slider image payload>
st=<challenge state>
```

此阶段没有 `vt`，不能把 `code=0` 误判为验证码最终通过。

### check_answer

滑块答案提交仍走 `/check`：

```text
si=<graphicCaptchaSessionId>
lang=<lang>
tk=<answer proof>
ct=<cursor/device proof>
cs=<collection proof>
version=3
client=<platform/client>
```

字段说明：

- `tk`：答案证明，常见入参形状为 `[sessionId, st, encodeURI(A), JSON.stringify({ touchList })]`
- `ct`：设备/光标证明，常见入参来自 `sessionId + devInfo/cursorInfo`
- `cs`：采集证明，常见入参形状为 `[sessionId, JSON.stringify({ rec, fpt })]`
- `st`：来自 `/fp` 或题面响应的当前服务端状态
- `A`：滑块答案对象，不只是坐标，通常包含 `ht/wt/bw/sw/mw/list/ii` 和当前版本噪声键
- `touchList`：用户交互轨迹列表，必须和 `A.list`、滑块 offset、时间节奏同轮一致
- `rec`：运行时采集记录，常见来自 JCAP 脚本内部 records
- `fpt`：文件路径或脚本路径集合，常见包含当前 `jcap_*.js` URL

`A.list` 与 `touchList` 的点数量、耗时、抖动和编码后长度在部分 JCAP 版本中会影响 `tk/ct/cs` 的长度级别，具体以当前脚本和浏览器样本为准。offset 正确但 check_answer 仍失败时，应对比浏览器样本和本地样本的 `A` 长度、`touchList` 长度、`encodeURI(A)` 长度、`JSON.stringify({ touchList })` 长度以及最终 `tk/ct/cs` 长度，不要只看坐标是否正确。

成功响应：

```text
code=0
msg=""
vt=<graphicCaptchaVerifyToken>
```

失败响应常见：

```text
code=16807
s_code=16130
msg="验证失败，请重新验证"
```

或：

```text
code=16808
msg="验证未通过"
```

失败时优先判断滑块 offset、`A/touchList`、`ct/tk/cs` 输入、`st` 是否同轮、`sessionId/jwtToken/cookie` 是否 fresh，不要先怀疑登录加密。

## 滑块题面与答案

`tp=30` 常见为滑块拼图：

```text
img.b1 = 背景大图
img.b2 = 滑块小图
```

本地可以把图片保存到 `img/` 便于人工核对或算法识别。识别出来的 offset 只是原始答案的一部分，还必须转换为 JCAP 当前脚本需要的交互结构：

```text
slider offset
→ A.ht / A.wt / A.bw / A.sw / A.mw
→ A.list 轨迹点
→ A.ii 和版本噪声键
→ touchList
→ tk
```

不要只把 `x` 坐标塞进请求体。服务端通常校验当前脚本生成的 `tk/ct/cs` 证明和交互形状；轨迹长度、时间节奏是否参与校验，要看当前版本脚本和浏览器样本。轨迹过短、过长、过于线性、采样间隔异常，或本地编码后的证明长度和浏览器样本明显不一致，都应作为 `/api/check` 失败的重点排查项。

## 登录提交联动

拿到 `vt` 后，登录 plain body 至少要确认：

```text
graphicCaptchaSessionId=<same sessionId>
graphicCaptchaJwtToken=<same jwtToken>
graphicCaptchaVerifyToken=<fresh vt>
loginname=<account>
nloginpwd=<encrypted password>
h5st=<ParamsSign result>
_stk=<ParamsSign result, login chain often "loginname">
```

随后再经 `summer-cryptico-h5` 加密：

```text
url query  -> aksParamsU
form body  -> aksParamsB
```

最终请求：

```text
POST https://passport.jd.com/uc/loginService?...&r=<random>&version=2015
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
Origin: https://passport.jd.com
Referer: https://passport.jd.com/new/login.aspx
```

如果登录接口返回“图形验证码参数校验失败，请刷新重试”，优先检查：

- `vt` 是否已被浏览器或上一轮请求消费
- `vt` 是否过期
- `vt/sessionId/jwtToken/cookie` 是否同轮
- JCAP 请求和登录请求是否复用了同一个 HTTP session / cookie jar
- `graphicCaptchaVerifyToken` 是否确实进入 plain body 后再被加密成 `aksParamsB`
- 登录 body 中 `h5st/_stk` 是否由当前链路生成，而不是旧样本

如果登录接口越过验证码校验，返回账号密码错误、`newSafeVerify=true`、`resultCode=1100` 或安全验证 URL，通常说明 JCAP、签名和加密请求边界已经进入业务层，后续问题属于账号态或业务安全验证。

## 动态字段清单

以下字段默认都应按当前会话动态维护：

```text
graphicCaptchaSessionId
graphicCaptchaJwtToken
graphicCaptchaVerifyToken / vt
si
st
fp
ct
tk
cs
se
A
touchList
rec
fpt
img
tp
Idempotency-Key
Cookie
h5st
_stk
aksParamsU
aksParamsB
```

暂时使用固定样本时，必须在进展清单中标记为“固定样本，仅用于对照”。固定旧 `vt`、旧 `st`、旧 `tk/ct/cs` 或旧图片答案不能视为最终实现。

## 允许的观察点

优先观察这些边界：

```text
GraphicCaptchaHelper.getContext 返回值
GraphicCaptchaHelper.create 入参
login2024.js onSuccess(payload) 入参
window.jdCAP.captcha(info) 入参
factory(option) 入参
XHR/fetch 请求 URL、body、headers、response
getCTData / getTKData / getCSData 等公开导出函数的入参和返回值
```

严格禁止把补环境推进到 VMP / VM 解释器 / opcode handler / 字节码分发层内部。对 WASM、混淆执行器或同类内部实现，不要改写执行语义、不要插 opcode 级探针、不要把内部 tracer 写进 `code.js`。需要定位时，回到公开 API、请求边界、DOM/BOM 读取点和当前 trace 证据。

## 本地落地建议

建议 `code.js` 暴露稳定入口：

```js
get_jcap_local_request(input)
build_login_request(input)
get_login_request(input)
```

建议 `test.py` 负责：

- 请求 `passport.jd.com/uc/graphic/sessionId/refresh` 获取 fresh `sessionId/jwtToken`
- 调用 `node code.js` 生成当前 JCAP 请求体
- 真实发送 `/api/fp`
- 发送题面阶段 `/api/check` 或 `/api/refresh`
- 保存并识别 `tp=30/img`
- 将 offset 转换为 `A/touchList/records`
- 再调用 `node code.js` 生成答案阶段 `tk/ct/cs`
- 真实发送 `/api/check` 获取 `vt`
- 在同一进程、同一会话中立即构造登录请求
- 调用 `node code.js` 生成 `h5st/_stk` 与 `aksParamsU/B`
- 发送 `/uc/loginService` 并打印 HTTP 状态、响应体、关键响应 header

## 推荐验证顺序

```text
1. 只跑 session refresh，确认拿到 sessionId/jwtToken。
2. 本地驱动 jdCAP，确认能捕获 /api/fp 请求体。
3. 真实发送 /api/fp，确认 HTTP 200 且响应 code=0、拿到 st/fp。
4. 发送题面阶段请求，确认拿到 tp=30/img。
5. 保存 b1/b2，确认滑块题面可识别。
6. 用 offset 构造 A/touchList，再生成 tk/ct/cs。
7. 发送 check_answer，确认 code=0 且 vt 非空。
8. 同会话立即注入 vt 构造 /uc/loginService。
9. 判断登录响应是否越过“图形验证码参数校验失败”。
10. 若进入账号密码错误或安全验证，记录为 JCAP 链路通过。
```

## 常见错误

- 把 `/api/fp` 返回的 `fp/st` 当成最终验证码 token。
- 把 `check_challenge` 的 `code=0` 当成最终通过，忽略没有 `vt`。
- 固定旧 `vt`、旧 `st`、旧 `tk/ct/cs` 长期重放。
- 浏览器现场先消费了 `vt`，再拿同一个 `vt` 本地登录。
- 只提交滑块 `x` 坐标，不生成当前脚本需要的 `A/touchList/tk/cs`。
- `A.list`、`touchList`、`ct` 的轨迹点数量、编码后长度、时间节奏和同轮状态不一致。
- offset 正确但 `tk/ct/cs` 长度级别与浏览器样本不一致，仍按签名错误排查。
- JCAP 用一个 session，登录提交用另一个 cookie jar。
- 登录 plain body 有 `vt`，但加密后的 `aksParamsB` 实际没有包含它。
- 忘记同时生成 `h5st/_stk`，误把验证码失败和签名失败混为一谈。
- 看到登录接口返回 `newSafeVerify=true` 仍继续补滑块链路；这通常已经不是 JCAP 未通过。

## 交付记录要求

命中京东 JCAP 链路时，进展清单或阶段输出必须记录：

- 命中特征和读取的产品文档：`references/products/jd_jcap.md`
- 如果联动登录签名，同时记录已读 `references/products/jd.md`
- 当前脚本 URL：`requireCaptchaPc.js`、`jcap_*.js`
- `sessionId/jwtToken` 来源和刷新方式
- JCAP 请求链实际顺序：`fp -> refresh/check_challenge -> check_answer`
- `/api/fp` body 字段和响应 `st/fp`
- 题面响应端点、`tp`、`img` 字段结构、图片保存路径
- `A/touchList/rec/fpt` 的来源
- `tk/ct/cs` 生成入口、入参形状、长度级别
- 最终 `/api/check` 的 HTTP 状态、业务 `code`、是否签发 `vt`
- `vt` 注入 `/uc/loginService` 的方式和是否同会话发送
- 登录接口 HTTP 状态、业务响应、是否越过图形验证码校验
