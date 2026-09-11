# 阿里 Baxia / AWSC 231/234 bx-ua 与 140 fire_ua 参考文档

本文用于识别和处理阿里系登录态业务中的 Baxia / AWSC 安全头链路，重点是 `securityHeader` 产出的 `bx-ua`、`bx-umidtoken`，以及同一业务请求中配套的 AWSC 140 字段 `AsuraId`、`fire_ua`、`fire_umid`。`bx-ua` 常见前缀包括 `231!` 和 `234!`，二者都属于本文命中的 bx-ua 家族，不要因为前缀是 `234!` 就跳过本产品文档。

本文是产品专项经验参考，不替代当前目标实测。任何补入 `code.js` / `runtime/*.code.js` 的 DOM/BOM 值、storage 值、事件顺序、descriptor、prototype、`toString` 外观、Header、Cookie、请求体和行为回放，都必须来自当前目标的 `jscall`、`http_packet`、`storage/domtrace/event` 或已收敛的当前 trace 资产。

## 命中特征

出现以下特征时，优先按阿里 Baxia / AWSC bx-ua 链路分析：

- 业务请求 Header 中出现 `bx-ua`，值通常以 `231!` 或 `234!` 开头
- 业务请求 Header 中出现 `bx-umidtoken`
- 业务请求 body/metas 中出现 `AsuraId`、`fire_ua`、`fire_umid`
- `AsuraId` 或 `fire_ua` 值通常以 `140#` 开头
- 页面加载 `g.alicdn.com/code/npm/@alife/alsc-h5-sec/.../securityHeader.min.js`
- 页面、脚本或 jscall 中出现 `securityHeader.initSecurity`
- 页面、脚本或 jscall 中出现 `securityHeader.getSecurityHeaders`
- 初始化参数出现 `dependHeaders: ["bx-umidtoken", "bx-ua"]`
- 页面加载 `g.alicdn.com/sd/baxia/.../baxiaCommon.js` 或 `g.alicdn.com/sd/baxia-entry/baxiaCommon.js`
- 页面加载 `g.alicdn.com/AWSC/fireyejs/1.231.../fireyejs.js` 或 `g.alicdn.com/AWSC/fireyejs/1.234.../fireyejs.js`
- 页面加载 `g.alicdn.com/AWSC/WebUMID/.../um.js`
- 页面加载 `g.alicdn.com/AWSC/uab/1.140.../collina.js`
- 页面加载 `g.alicdn.com/AWSC/et/.../et_f.js`
- 页面或脚本出现 `AWSC.configFY`、`fyOBJ.getUA`、`fyOBJ.umidToken`
- 页面或脚本出现 `__napos_awsc_uab__`、`getUabModule`
- storage 中出现 `lswucn`、`_um_cn_umsvtn`、`_um_cn__umdata`、`_uab_collina`、`_umcost`、`tfstk__`
- 请求链出现 `ynuf.aliapp.org/service/um.json`、`nt2.ele.me/c/j`、`fourier.alibaba.com/ts`、`fourier.taobao.com/rp`
- 请求链出现 `gm.mmstat.com/a2f1q.bx...`
- 最终业务接口返回 `FAIL_SYS_USER_VALIDATE`、`x5 captcha`、`showCaptcha` 或同类用户验证拦截

如果同链路出现 `captcha-pro-open.aliyuncs.com`、`device.captcha-open.aliyuncs.com`、`x5secdata`、`_____tmd_____/punishTextFetch`、`__bx__`、`sufei-punish`，同时读取 `references/products/aliyun_captcha.md`。本文件负责 `bx-ua/bx-umidtoken` 与 `140#` 字段生成链，`aliyun_captcha.md` 负责验证码、WAF、x5sec 处罚链。

## 核心边界

该链路通常不是单独的验证码通过凭证，而是登录态业务请求前的安全 Header + body metas 组合：

```text
Header:
  bx-ua
  bx-umidtoken

Body metas:
  AsuraId
  fire_ua
  fire_umid
```

常见职责拆分：

- `231/234`：由 `securityHeader` / Baxia / fireyejs / 行为链产出 `bx-ua` 与 `bx-umidtoken`
- `140`：由 AWSC / WebUMID / uab-collina / fireyejs 产出 `AsuraId`、`fire_ua`、`fire_umid`
- `test.py`：统一把 231/234 bx-ua 写入 Header，把 140 写入业务请求 body/metas，再调用最终业务接口验证是否放行

`231!` 和 `234!` 通常表示同一类 bx-ua 链路的不同版本或变体。分析时仍按 `securityHeader.initSecurity`、Baxia/fireyejs 脚本、storage、message/XHR 上报、行为链、最终 `getSecurityHeaders` 的顺序还原；交付入口可以保留历史命名 `get_231(input)`，但如果当前目标明确产出 `234!`，优先命名为 `get_234(input)` 或更中性的 `get_bxua(input)`，避免误导后续使用者。

成功口径必须看最终业务接口。只要最终业务仍返回用户验证、x5、验证码、风险拦截，就不能把本地 `getSecurityHeaders` 或 `getUA` 有输出当作成功。

## 231/234 总链路

231/234 链路以 `securityHeader` 初始化为核心，常见顺序如下：

```text
目标页入口
→ 加载 @alife/alsc-h5-sec/.../securityHeader.min.js
→ 加载 baxiaCommon.js
→ 加载 AWSC / fireyejs / et_f / WebUMID / uab-collina 相关脚本
→ securityHeader.initSecurity({ dependHeaders: ["bx-umidtoken", "bx-ua"] })
→ 准备 localStorage / cookie / performance / XHR / message / event 环境
→ 加载站点风险脚本，例如 appid_10000.js、pitaya.js、mozart.js
→ 回放 securityHeader 依赖的 window message
→ 回放登录前真实行为事件
→ 第一次 securityHeader.getSecurityHeaders(["bx-umidtoken", "bx-ua"])
→ 触发或回放首个登录请求边界及 UMID / nt2 上报链
→ 继续回放第二阶段登录行为和异步上报
→ 第二次 securityHeader.getSecurityHeaders(["bx-umidtoken", "bx-ua"])
→ 将第二次结果写入最终业务请求 Header
```

注意：不同站点的具体顺序可以有差异，但 `initSecurity`、storage 准备、异步上报、行为链和最终 `getSecurityHeaders` 的相对关系必须按当前 trace 对齐。

## 231/234 初始化重点

### 1. securityHeader 脚本

优先从当前请求链固定真实脚本版本：

```text
https://g.alicdn.com/code/npm/@alife/alsc-h5-sec/<version>/umd/securityHeader.min.js
```

本地入口不要凭记忆重写 `securityHeader`。应把当前轮 `http_packet` 中的脚本内容固定到本地，由 `code.js` / `runtime/*.code.js` 加载执行。

初始化常见形状：

```js
securityHeader.initSecurity({
  tips: true,
  dependHeaders: ["bx-umidtoken", "bx-ua"]
});
```

观察点：

- `initSecurity` 的调用时机和入参
- `dependHeaders` 是否只包含 `bx-umidtoken/bx-ua`，还是还有站点额外 Header
- 初始化后是否动态插入 `baxiaCommon.js`
- 初始化后是否监听 `message`、`mousemove`、`mousedown`、`input`、`submit`
- 初始化后是否触发 `ynuf`、`nt2`、`gm.mmstat`、`fourier` 等上报

### 2. Baxia / 231/234 脚本

常见脚本：

```text
g.alicdn.com/sd/baxia/<version>/baxiaCommon.js
g.alicdn.com/sd/baxia-entry/baxiaCommon.js
g.alicdn.com/AWSC/fireyejs/1.231.x/fireyejs.js
g.alicdn.com/AWSC/fireyejs/1.234.x/fireyejs.js
```

处理要点：

- `baxiaCommon.js` 版本可能有多轮，例如首屏版本与后续 entry 版本不同
- `fireyejs/1.231.x` 与 `fireyejs/1.234.x` 都是 bx-ua 行为证明链的强特征
- `bx-ua` 的长度与行为、storage、上报状态强相关
- 只加载脚本但不回放行为，常见结果是 `bx-ua` 明显偏短

### 3. storage / UMID 状态

231 链路常依赖这些状态：

```text
lswucn
_um_cn_umsvtn
_um_cn__umdata
_uab_collina
_umcost
tfstk__
eleme_device_id
browserDeviceId
__ETAG__CNA__ID__
```

处理规则：

- storage 值必须来自当前 trace 的 `storage` 分区、当前业务输入或当前会话返回
- `lswucn` 常参与 `bx-umidtoken`，有些链路会带 `@@timestamp` 类后缀；不要固定旧时间戳
- 如果有两次 `getSecurityHeaders`，storage 也可能需要按两次边界分别准备或覆盖
- `bx-umidtoken` 与 `lswucn`、UMID 请求、当前会话状态相关，不要把它当普通静态 token

### 4. message / XHR / 异步上报

231 链路常见异步请求：

```text
ynuf.aliapp.org/service/um.json
nt2.ele.me/c/j
fourier.alibaba.com/ts
fourier.taobao.com/rp
gm.mmstat.com/a2f1q.bx...
```

本地复现时要确认：

- `XMLHttpRequest.open/send/setRequestHeader/getAllResponseHeaders` 是否按 trace 外观补齐
- `readystatechange/load/loadend` 是否按真实顺序触发
- `service/um.json` 和 `nt2` 的响应体、响应头是否来自同一轮 trace
- `window.postMessage` / `message` 事件是否被 securityHeader 监听和消费
- `performance.getEntriesByType("resource")` 中是否能看到当前轮脚本与上报资源

只补一个空的 XHR 返回 `{}`，经常会导致 `bx-umidtoken` 或 `bx-ua` 不完整。

### 5. 登录前行为链

231 对行为链非常敏感。以登录页为例，trace 中通常需要覆盖：

```text
username: pointer/mouse/focus/key/input/textInput/keyup
password: blur/focus/mouse/textInput/input/keyup
checkbox: mousedown/mouseup/click/change
submit: pointerover/pointermove/mousedown/mouseup/click/submit
```

处理规则：

- 事件序列从 `ruyitrace/event` 提取，不手写固定“滑动几下/点击一下”
- 事件 target 要尽量还原真实 DOM 类型，例如 `HTMLInputElement`、`HTMLButtonElement`、`HTMLSpanElement`、`HTMLFormElement`
- `input.value`、`checked`、`selectionStart/selectionEnd` 要随事件推进
- `isTrusted`、`bubbles`、`cancelable`、`composed`、`timeStamp`、坐标、键盘字段要按 trace 补
- 如果 trace 有 `droppedSinceLast` 或采样字段，回放时要按目标链路实际需要展开，不要简单忽略

经验判断：`bx-ua` 只生成一小段，通常说明行为链、message、XHR 上报或 storage 有缺口。

## 140 总链路

140 链路通常给业务 body/metas 提供：

```text
AsuraId
fire_ua
fire_umid
```

常见脚本：

```text
g.alicdn.com/AWSC/AWSC/awsc.js
g.alicdn.com/??/AWSC/AWSC/awsc.js,/code/npm/@ali/napos-puzzle/.../index.js
g.alicdn.com/AWSC/WebUMID/.../um.js
g.alicdn.com/AWSC/uab/1.140.x/collina.js
g.alicdn.com/AWSC/fireyejs/1.231.x/fireyejs.js
g.alicdn.com/AWSC/fireyejs/1.234.x/fireyejs.js
g.alicdn.com/AWSC/et/.../et_f.js
```

常见初始化：

```js
AWSC.configFY(function (obj) {
  window.fyOBJ = obj;
}, { appName: "<current app name>" });

window.uabModule = await window.__napos_awsc_uab__.getUabModule();
```

常见取值：

```js
AsuraId = window.uabModule.getUA({ reqUrl });
fire_ua = window.fyOBJ.getUA({ reqUrl });
fire_umid = window.fyOBJ.umidToken || localStorage.getItem("_um_cn_umsvtn");
```

处理规则：

- `appName` 必须来自当前目标页面或调用栈，不跨站复用
- `reqUrl` 必须是最终业务接口 URL
- `fire_umid` 常来自 `fyOBJ.umidToken`、`_um_cn_umsvtn` 或当前 UMID 请求链
- `AsuraId/fire_ua` 前缀、长度和行为证明强相关，不能只检查有无字符串
- 140 和 231/234 可以并行生成，但最终验证必须使用同一业务请求、同一 Cookie/storage/UA 上下文

## ruyitrace / jscall 观察点

优先按以下顺序定位：

- `http/index.jsonl`：确认 `securityHeader.min.js`、`baxiaCommon.js`、`AWSC`、`fireyejs`、`WebUMID`、`collina`、`ynuf`、`nt2`、最终业务接口
- `jscall`：定位 `initSecurity`、`getSecurityHeaders`、`AWSC.configFY`、`getUabModule`、`getUA` 调用序号和调用栈
- `storage`：确认 `lswucn`、`_um_cn_umsvtn`、`_um_cn__umdata`、`_uab_collina`、`tfstk__` 等状态读写
- `event`：确认登录前输入、勾选、提交的真实事件序列
- `domtrace`：确认真实 DOM 类型、`createElement`、`querySelector`、`getBoundingClientRect`、表单控件外观
- `descriptor`：确认 `navigator.webdriver`、构造器、prototype、`toStringTag` 和 native 外观
- `cookie`：确认 `cna`、`tfstk` 等与当前请求绑定的 Cookie 状态

样本中常见的关键序号形态：

```text
initSecurity: 早期初始化
AWSC.configFY: AWSC 140 初始化
getUabModule: uab/collina 模块初始化
第一次 getSecurityHeaders: 首次登录边界前
第二次 getSecurityHeaders: 登录行为和上报推进后
```

不要只看一次 `getSecurityHeaders`。如果 trace 证明存在两次取值，通常第二次才是最终业务请求应使用的 Header。

## 本地交付建议

推荐拆分：

```text
code.js
  get_140(input) -> { AsuraId, fire_ua, fire_umid }

code1.js 或 runtime/ali_bxua.code.js
  get_231(input) -> { bx_ua, bx_umidtoken }
  如果当前目标产出 234!，可命名为 get_234(input) 或 get_bxua(input)

test.py
  并发或顺序调用 get_140/get_231、get_234 或 get_bxua
  把 140 写入 body.metas
  把 231/234 bx-ua 写入 Header
  发送最终业务请求
  以业务响应判断是否放行
```

验证建议：

- 先检查前缀：`AsuraId/fire_ua` 是否为 `140#`，`bx-ua` 是否为 `231!` 或 `234!`
- 再检查长度量级：真实 trace 中 140 和 231/234 通常是千级长度，UMID/token 常为几十字节级
- 再检查最终业务响应：不能出现 `FAIL_SYS_USER_VALIDATE`、x5、验证码或安全校验失败
- 如果使用测试账号，业务返回“账号不存在”一类普通业务错误，反而可作为风控链路已过的辅助口径

## 常见坑

- 把 `bx-ua` 当成普通签名参数，只调用 `getSecurityHeaders`，不回放事件和异步上报
- 只补 231，不补 140，最终业务接口仍因 metas 不完整被拦截
- 只补 140，不补 231，最终请求缺 Header 或 Header 过短
- 固定旧 `lswucn`、`_um_cn_umsvtn`、`bx-umidtoken` 或旧 Cookie
- `securityHeader.initSecurity` 入参和真实页面不一致
- 忽略 `message` 事件，导致 securityHeader 初始化状态不完整
- 忽略 `ynuf/nt2/fourier/mmstat` 请求和响应，导致 UMID / 行为状态不完整
- 事件 target 都用普通对象，缺少真实 `HTMLInputElement`、`HTMLButtonElement`、`HTMLFormElement` 外观
- `performance` 资源列表为空或脚本顺序不对，导致分支与浏览器现场不同
- 本地断言前缀通过就宣布成功，没有跑最终业务接口
- 遇到 x5 / captcha 后误判为账号问题；这类响应通常表示安全链仍未对齐

## 硬边界

- 不要在 VMP、opcode handler、VM 解释器内部插桩或改写执行语义
- 除非用户当前明确要求，否则不要使用浏览器/页面自动化程序接管页面、模拟用户行为、生成参数或补齐证据；也不要把自动化现场直接吐出的 `bx-ua`、`AsuraId` 等旧值当作本地实现
- 不要跨账号、跨 Cookie、跨 UA、跨页面复用旧 140/231 字段
- 不要在产品文档中沉淀真实 Cookie、真实 Header 值、真实 token 或账号凭证
