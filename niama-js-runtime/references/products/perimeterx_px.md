# PerimeterX / HUMAN Security PX 参考文档

本文用于识别和处理 PerimeterX / HUMAN Security PX 链路，重点覆盖 `_px3`、`_pxvid`、`pxcts`、collector、bundle、PX captcha、`collector-notouch`、`bundle-press`、`blocked-page-press`、`xhr-press`，以及 Walmart 相关站点的 PX3 高信任补环境流程。

它是经验参考，不是固定套用方案。命中同类目标后，仍必须以当前目标的 `jscall` 定位证据、匹配当前目标的 `ruyitrace/` 真实证据、当前 SDK 文件、当前抓包和最终业务验证为准。

## 命中特征

出现以下特征时，可优先按 PX 链路分析：

- Cookie、响应体、脚本或日志中出现 `_px3`、`_pxvid`、`pxcts`、`_pxAppId`、`pxvid`
- 响应体或 captcha context 中出现 `jsClientSrc`、`collector`、`uuid`、`vid`、`did`、`hostUrl`、`blockScript`、`altBlockScript`、`firstPartyEnabled`
- 请求链出现 `px-cloud.net`、`collector-*.px-cloud.net/api/v2/collector`、`/api/v2/collector`、`/assets/js/bundle`、`/ns`、`/d/p`
- 页面出现 PX captcha、captcha iframe、HUMAN Security / PerimeterX SDK 或与 PX block 相关的短 HTML / JSON context
- collector 或 bundle POST 响应中出现 `do`、`ob`，OB 解码后能看到 `_px3/_pxvid/pxcts` 或 server-state 命令形态
- 日志、脚本或项目目标中出现 `collector-notouch`、`bundle-press`、`blocked-page-press`、`xhr-press`
- Walmart 相关链路出现 `PXu6b0qd2S`、`PXZiTus4E5`、`www.walmart.com`、`advertising.walmart.com`、`identity.walmart.com`

注意：`_px3` 签发不等于业务通过。必须把三层结果分开记录：

```text
_px3 issuance
= collector 或 bundle 返回 set-cookie 命令

PX acceptance
= 同一 _px3 打回触发 PX 的原始请求后不再返回 PX block

business acceptance
= 真实业务链继续推进，而不是只拿到 cookie
```

PX 不暴露公开数值评分。不要把 `_px3` 签发称为“高评分”；客户侧可验证的信任代理只能是原始失败请求 exact retry 后推进到预期业务状态。

## 先判门再解 PX

任何失败响应先分类，确认是 PX 后才进入 `_px3` 工作。

| Gate | 证据 | 下一步 |
| --- | --- | --- |
| PX | HTML/JSON 含 `_pxAppId`、PX captcha、`jsClientSrc`、collector、`uuid`、`vid`、`did`、`blockScript`、`altBlockScript` | 归因 source host，选择对应 profile，solve 后 exact retry |
| Akamai | 响应或 Cookie 出现 `_abck`、`bm_sv`、`ak_bmsc`、Akamai/Bot Manager 标记 | 记录为非 PX 门，同时读取 `akamai.md`，不要改 PX 字段 |
| GraphQL / 业务错误 | JSON 有 `data/errors/extensions.code`、`data.<operation>.errors[].code`、正常 operation 结构或 `x-gql-status`，无 PX 标记；例如 Walmart identity `SignInV2` 返回 `data.signInV2.errors.code=SOMETHING_WENT_WRONG` | 不改 PX 字段；先对齐请求体、变量、同轮 session/header/cookie、前置页面状态或记录业务拒绝 |
| 下游风控 | 例如 INKIRU、phone velocity、physical risk 等结构化风控码 | 记录为非 PX 算法问题 |

如果一个 response 同时是结构化 JSON 但嵌套了 captcha / PX context，把它归为 `xhr-press`，保留 `appId`、`jsClientSrc`、`firstPartyEnabled`、`uuid`、`vid`、`did`、`hostUrl`、`blockScript`、`altBlockScript`。

HTTP `200` JSON 不是自动通过。必须继续判断业务 operation 是否推进到预期步骤：

- 账号预检类接口只有出现可进入下一步的结构，例如 `data.getLoginOptions.loginOptions`、`loginPreference` 和无业务错误，才能记录为“到密码步骤”
- 密码提交类接口只有出现有效 `authCode`、有效 `multiFactorInfo` / `twoFALoginOptions` / challenge 对象、跳转状态或浏览器同等下一页证据，才能记录为“到 OTP / 邮箱验证码”
- 仅因为响应字段名包含 `canUseEmailOTP`、`supportedOtpChannels`、`otpConsentInfo`、`twoFALoginOptions`，但对象为空或同时有业务错误码，不能判定已经进入 OTP
- `SOMETHING_WENT_WRONG`、`INVALID_*`、`ACCOUNT_*` 等 operation 内业务错误码属于业务层或请求状态缺失；只要没有 PX context，就不要回头改 `_px3`、payload、OB 或 collector 生成
- 同一请求同时带 `akamai-cache-status`、`x-edgeconnect-*` 等边缘响应头但返回正常 GraphQL JSON 时，按业务层处理；只有 `456/403`、短 HTML、challenge 页面或 Akamai cookie 状态失败时，才单独开 Akamai 分支

## Walmart Profile 分流

Walmart 相关目标必须先识别 source host，不能混用常量、模板、cookie scope 或 command map。

| 线 | 典型 host | profile | 当前判断 | 处理原则 |
| --- | --- | --- | --- | --- |
| 老 Walmart 主站 | `www.walmart.com` | `PXu6b0qd2S` | PX 层宽档参考，业务主门可能是 Akamai | 只把它当方法论和字段参考；业务不过时先查 `_abck / bm_sv / ak_bmsc` |
| Walmart Advertising | `advertising.walmart.com` | `PXZiTus4E5` | 可作为独立广告入口 profile | 从广告 sign-in 入口走真实链路，不能直接从 auth-request 开始 |
| Walmart Identity | `identity.walmart.com` | 常见烟测为 `PXu6b0qd2S` | 资源发现不等于业务验证 | 只有真实 identity login / GraphQL 链路发出 PX block 后才能升级为 business-verified |

历史参考值只能用于判断差异，不能直接作为生产配置：

| 项 | 老 Walmart 主站历史参考 |
| --- | --- |
| AppID | `PXu6b0qd2S` |
| Collector | `collector-pxu6b0qd2s.px-cloud.net/api/v2/collector` |
| Cookie | `_px3`, TTL 常见 `330` |
| TAG / FT | 抓包中曾见 `eW5CaD8AUB99Zg==` / `396`，必须以当前抓包为准 |
| OB XOR | 抓包中曾见 `ml(TAG)%128 = 41`，必须当前验证 |
| 特点 | 2 POST、无 EV3、无 counter、通常不取 `/ns` |

老 Walmart 的重要教训是跨事件一致性。同一 session 内页面加载时间戳和 uuid 类字段要跨 EV1/EV2 保持 CONSTANT，performance、计数器和当前时间类字段要 MONOTONIC。宽档可能放行不真实的 wire，但高信任目标不能依赖宽档容忍。

Advertising 线必须使用双站 profile 矩阵：

| profile host | 状态 | 关键要求 |
| --- | --- | --- |
| `advertising.walmart.com` | 可作为广告入口 profile | 记录 app id、captcha/main hash、collector、command map、cookie scope、验收链 |
| `identity.walmart.com` | 默认为 resource-discovered，除非真实链路证明 | 真实 identity block 出现后重新提 app id、资源、collector、command map、cookie scope |

Advertising 入口验收链必须是：

```text
advertising.walmart.com/signin?adtechClientId=...&rd=...
-> /signin/auth/?type=walmart&select_platform=true&rd=...&adtechClientId=...
-> advertising-domain server Location redirects
-> /signin/walmart/auth-request only when returned by /signin/auth/
-> generated identity.walmart.com/account/login?...redirect_uri=https://advertising.walmart.com/signin/walmart/verifyToken...&tp=ads
```

不要把手工直连 `/signin/walmart/auth-request` 当作广告入口验收。

## 输入与产出

最低输入：

- 6+ 批同 SDK hash 的 cold-visit 真实浏览器样本
- 每批包含完整 collector 或 bundle POST 请求、响应、SDK hash、UA、client hints、Cookie 初始状态、source host
- 当前业务失败请求和失败响应，包含 method、URL 形状、headers 形状、cookie scope、referer / origin
- 当前 captcha/main JS 文件或 URL、collector host、AppID、TAG、FT、BI
- 代理/IP/TLS/UA 策略描述，至少能区分 Node TLS、curl_cffi / Chrome impersonation 和真浏览器

最低产出：

- profile 矩阵：host、app id、captcha/main hash、collector、command map、cookie scope、状态
- field 分类：EV1/EV2/EV3 的 STATIC / DYNAMIC / CONDITIONAL
- `state.* -> EV key` 映射：用 6+ 批 value-match 得出
- HMAC/MD5 公式表：每个动态字段的 input 经过 6+ 批验证
- 环境种子：UA、client hints、screen、timezone、Intl、plugins、mimeTypes、canvas/WebGL/audio、storage/cookie、performance
- issued-value ledger：每个 `_px3`、`_pxvid`、`pxcts`、server-state 命令的来源和验收结果
- 验收报告：签发、PX acceptance、business acceptance 分开记录

不要在文档、日志模板、进展清单或交付物里保存 live `_px3`、原始 payload、原始 ob、代理账号、账号密码、OTP、OAuth `state`、`code_challenge` 或一次性业务 URL。只保存哈希、命令形状、profile、来源 host、触发请求形状、重试结果和验收结论。

## 分档判断

先按抓包事实判档，不要按站点名猜。

| 维度 | 宽松 Collector | 收紧 Collector | 严档+ / 高信任 | Bundle / Press |
| --- | --- | --- | --- | --- |
| POST 链 | 2 个，seq 0/1 | 可能 3 个，含 EV3 cookie 回传 | 2 或 3 个，但跨事件强校验 | 2-4 个 bundle 或 XHR press |
| 模板来源 | cold Chrome 样本 | cold Chrome + 多批 diff | 真 Chrome CDP 优先，多指纹轮换 | captcha iframe 真行为基线 |
| HMAC | 结构像即可 | 每个 input 逐项实测 | 每个 input + state 来源强校验 | 还要处理 PoW/WASM/行为 |
| counter | 可无 | 子字段相关性 | 合法模式空间，不产真实未出现组合 | 轨迹和 action counter 受检 |
| `/ns` | 可无或 null/0 | 与样本一致 | 同一 Chrome-like TLS session | 常与 bundle telemetry 联动 |
| 传输 | Node/curl 可能够 | Chrome impersonation 更稳 | 持久 Chrome TLS + 干净住宅 IP | 真浏览器或同等 iframe/XHR 环境 |
| 验收 | `_px3` + 简单 endpoint | exact PX-gated endpoint | 4-way trust 矩阵 + exact retry | 原始业务动作继续推进 |

宽松策略只用于快速证明算法链可行。高信任交付必须走收紧策略：逐字段、跨事件、传输、行为、业务链全部验收。

## 常见链路

`collector-notouch` 常见链路：

```text
请求受保护页面或入口
-> 获取 PX app id、collector、SDK / captcha main 脚本、初始 Cookie / storage
-> SDK 生成 EV1 / EV2，必要时生成 EV3 cookie confirmation
-> POST /api/v2/collector
-> 服务端通过 do / ob 下发 state 或 set-cookie 命令
-> 写入 _px3 / _pxvid / pxcts / server-state
-> 带当前 Cookie exact retry 原始 PX-gated 请求
```

`bundle-press` / `blocked-page-press` / `xhr-press` 常见链路：

```text
业务请求返回 PX block 或嵌套 captcha context
-> 加载 blockScript / altBlockScript / captcha.js / bundle
-> SDK 创建真实 challenge target/listeners、iframe 或 XHR press 上下文
-> 采集 pointer/mouse、PoW/WASM、large payload、/d/p 或 bundle telemetry
-> 发送 2-4 个 bundle 或 XHR press 请求
-> 服务端签发 _px3 / _pxvid / pxcts 或推进 server-state
-> 等待必要 post-solve delay 后 exact retry 原始业务动作
```

如果 no-touch preflight 返回 `did`，后续 press / XHR solve 要带上。

## Payload、OB 与 SDK 定位

payload 链必须等价于 PX：

```text
serialize(events) -> XOR(50) -> UTF-8 base64 -> padding/interleave -> payload
```

禁止用 `JSON.stringify` 替代 PX serialize。禁止用 Latin-1 base64 替代 UTF-8 base64。解析 POST body 时不要把 base64 里的 `+` 转成空格。

OB 解码：

```text
base64 -> binary/latin1 -> XOR(ml(TAG)%128) -> split("~~~~") -> split("|") -> handler args
```

handler 用参数形状识别，不用 wire 字节或函数名：

- 1 个 13 位毫秒时间戳：`state.no`
- 1 个 64 hex：`state.qa`
- UUID：`state.pxsid` / `state.vid` / `state.cts`
- 4+ args 且第一或第二段像 `_px3/_pxvid/pxcts`：cookie set 命令
- 12-30 位小写字母数字：`state.appId` 候选
- `sid/cls/sts/drc` 等 clear 命令先记录为 server-state，不直接当 cookie

SDK 定位只用稳定特征，不依赖行号、变量名、函数名：

- MD5：`1732584193`
- HMAC ipad/opad：`909522486` / `1549556828`
- UUID v1：`122192928e5` 或 `12219292800000`
- OB 协议：`~~~~`、`split("|")`
- payload XOR：`charCodeAt(...) ^ 50`
- anti-tamper：`% 10 + 1`、`% 10 + 2`
- SID Variation Selector：`917760` / `0xE0100`
- collector：`/api/v2/collector`、`/assets/js/bundle`
- `/ns`：`tzm.px-cloud.net`、`ift.px-cloud.net` 或当前抓包里的 ns host
- 浏览器字段：`navigator.*`、`screen.*`、`performance.*`、`document.*`、`Intl.*`

如果稳定常量缺失，按 SDK 大版本变化处理，不要继续套旧算法。

## EV 字段恢复

对每个 event 的 `d` 做多批 diff：

- STATIC：同一浏览器/设备/SDK 下多批完全一致，保留模板值
- DYNAMIC：多批变化，需要算法或 state 生成
- CONDITIONAL：部分批次出现，多为 warm visit、历史 cookie、challenge cache；cold 基线通常不要主动新增

生成器只能 override 模板中已有 key。不要为了“看起来完整”向 EV2 添加模板不存在的字段。跨 event 复用 b64 key 是高频低信任原因。

对每个 `state.no/appId/to/qa/vid/pxsid/cts/jf/o111val/hid`，在 6+ 批 EV 中找值完全匹配或类型等价匹配的 key。

规则：

- `state.no` 写入 EV 时必须按模板类型转 number：`parseInt(state.no, 10)`
- `state.to`、`state.appId` 通常保持 string
- 多候选时增加样本数或用类型先验收敛
- 0 候选时检查是否根本不入 EV、被 anti-tamper 包装、或被 HMAC/MD5 包装
- 每个站、每次 SDK 大升级都重做，不复用旧站 key

HMAC 字段不能跨站照抄。即使 b64 key 一样，input 也可能不同。

候选 input 至少包括：

- session uuid
- `state.vid`
- `state.pxsid`
- `state.cts`
- `state.qa`
- `state.appId`
- `uuid + suffix`
- storage/cookie 中的 session 值
- UA 或 UA 相关拼接

每个字段都用 6+ 批验证。同一个公式能命中 6/6 才能写入生成器。

## EV1 / EV2 / EV3 生成约束

采用模板法：

```text
deepClone(real Chrome cold template)
-> 只覆盖 DYNAMIC
-> 保留 STATIC 值、字段顺序、anti-tamper 原位置
-> serialize 前完成所有动态字段
```

必做约束：

- 每次新 uuid；同一 session 内 EV1/EV2/EV3 复用同一 uuid
- UA、client hints、HMAC input、HTTP header 必须完全一致
- Date、Intl、timezone、language、screen、platform 自洽
- `state.no` 等数字字段按模板类型转换
- anti-tamper 需要原地替换，禁止 delete 后 append
- `sid` 使用正确的 pxsid 或 session id，并保留 Variation Selector 字节
- 如果真抓有 EV3 cookie confirmation beacon，必须发送；不要当 cleanup ping 跳过
- 如果真抓没有 EV3，不要主动造 EV3

单张 EV diff 全过不代表高信任。必须从真实包提取跨事件规则：

- CONSTANT：页面加载 epoch、uuid、platform、location、某些 seed 跨 EV 不变
- MONOTONIC：`performance.now`、sendTime、当前时间戳、counter 跨 EV 递增
- DICT：counter 子字段之间存在相等、镜像、0/N 模式或合法组合空间

生成器输出 EV1/EV2/EV3 后，用同一规则对比。不满足就先修生成器，不要先怀疑 TLS/IP。

## 常见环境面

PX 补环境不是补几个字段，而是让当前 PX SDK 走真实浏览器路径。按模块推进：

```text
window/self/top/parent/frames/globalThis/document.defaultView
Navigator 构造器、prototype、实例、webdriver=false、UA、platform、languages、plugins、mimeTypes、hardwareConcurrency、deviceMemory、userAgentData
Document/HTMLDocument、document.cookie getter/setter、query API、script/meta/body/head/documentElement
Storage、localStorage、sessionStorage、历史状态
Location/History/Screen，与 URL、referer、window size 自洽
performance.now/timeOrigin/timing，统一虚拟时钟派生跨事件时间
crypto.getRandomValues/subtle，typed array 与异常行为
canvas/WebGL/audio/plugins/fonts/screen 指纹，优先采真 Chrome 种子
XHR/fetch/sendBeacon/WebSocket，保证 SDK telemetry 能按真实路径发出
Event/Mouse/Pointer/Keyboard/Touch、isTrusted、timeStamp、target/currentTarget、dispatch 流
Worker/SharedWorker/MessageChannel/BroadcastChannel，Bundle/PoW 路径优先
native toString、toString.toString、getter/setter toString、name、length
属性描述符：enumerable/configurable/writable、prototype vs instance、ownKeys、Symbol.toStringTag
异常和栈：隐藏 Node/vm/本地路径包装层
document.all 特殊对象
```

先用 v8trace 吐访问路径、方法参数、返回值和缺口，再把稳定缺口固化为 prototype / descriptor / native patch。不要把 v8trace 事实本身当最终补丁，仍需 ruyitrace 回证。

## ruyitrace/jscall 优先动作

命中 PX 后，优先做：

```text
1. 用 jscall 与 http_packet 确认触发页面、PX block、SDK / captcha main、collector、bundle、/ns、/d/p、业务 exact retry 请求
2. 归因 source host，建立或更新 profile 矩阵，确认 app id、captcha/main hash、collector、command map、cookie scope
3. 对 6+ 批同 SDK hash 的 cold-visit 样本做 POST 数量、seq/rsc、headers、Origin、Referer、UA、client hints、Cookie 初始状态对照
4. 在 jscall 和 http_packet 中定位 collector / bundle POST 发起栈、request body、response do/ob、Set-Cookie 和 server-state 命令
5. 解码 payload 与 OB，记录 state.no、state.qa、state.vid、state.pxsid、state.cts、_px3/_pxvid/pxcts 命令来源
6. 对 EV1/EV2/EV3 字段做 STATIC / DYNAMIC / CONDITIONAL 分类和 state.* value-match
7. 对 HMAC/MD5 字段逐字段验证 input，必须 6/6 命中才写入生成器
8. 用 v8trace 和 ruyitrace 记录 PX SDK 实际读取的环境属性、descriptor、prototype、native 外观和事件对象
9. 对本地输出、collector 响应、cookie 签发、exact retry 和业务响应做同触发步骤对照
```

jscall / http_packet / trace 证据只用于定位和对照。不要把大范围 Hook、Proxy、VM tracer、VMP 探针或调试框架沉淀到本地 `code.js`。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ 必要浏览器环境骨架和 v8trace 观察面
├─ 当前目标版本的 PX SDK / captcha main / bundle
├─ 当前 profile 的 state、Cookie、storage、UA、client hints、screen、timezone、performance 种子
├─ collector / bundle / XHR 边界最小截获层
├─ build_px_collector_payload(input)
├─ build_px_bundle_payload(input)
└─ get_px3(input) 或 build_px_cookies(input)

test.py
├─ 建立真实会话，保持 UA / client hints / TLS / IP / Cookie scope 自洽
├─ 请求当前触发入口，保存 PX block 或 captcha context
├─ 获取当前 SDK / captcha main / bundle 和当前 collector host
├─ 调用 code.js 生成本轮 collector 或 bundle 请求材料
├─ 发送 collector / bundle / /ns / /d/p，解析 do / ob / Set-Cookie
├─ 合并 _px3 / _pxvid / pxcts / server-state
└─ 对原始 PX-gated 请求 exact retry，并继续验证业务链是否推进
```

如果失败点是 TLS / HTTP2 / IP / Cookie scope，修复位置在 `test.py` 的请求客户端、传输配置、代理策略和会话连续性，不在 `code.js`。

## Bundle / Press 专项

`bundle-press`、`blocked-page-press`、`xhr-press` 需要额外确认：

- 需要 captcha.js、可能有 WASM、PoW、iframe、pointer/mouse、large payload
- Bundle#1/#2 可能在 captcha iframe 里发，hook 主页面 XHR/fetch 不够
- 必须触发 SDK 创建真实 challenge target/listeners 后再发 pointer/mouse
- press 后 exact retry 需要延迟，先试 3000/5000/8000 ms
- PoW 用同步 SHA-256，不能在 65536 次循环中 `await crypto.subtle.digest`
- WASM 前先设置 `_pxUuid`，Node mock 中 `instanceof_Window/Document/HTMLElement` 要返回真
- `b()` 输出不是标准 base64，不要解码后再填
- Bundle#3 事件顺序敏感，少 metrics 或换顺序会导致 PC 不对
- 鼠标轨迹不能是直线、整数坐标或不合理时长

如确需事件轨迹，只对齐事件形态、点数量级、总耗时范围、间隔分布、空间方向、速度变化、target 命中和关键事件字段。不要逐点复制 trace 轨迹。

## 传输与 Session 收紧

高信任目标要让 mint 链和业务链自洽：

- `/ns`、collector、edge/business request 尽量走同一 Chrome-like TLS 持久 session
- UA、`sec-ch-ua`、Chrome major、ALPN、HTTP/2 行为保持一致
- 每个 cookie mint 绑定当前 uuid/vid/IP/UA/时间，不复用旧 cookie
- 干净住宅 IP 优先；不要用单 IP 高频 mint 后再判断算法失败
- Cookie 按 source host 和 domain scope 发送，广告 host-only cookie 不能盲发给 identity
- storage/cookie continuity 要跟真实浏览器一致，特别是 `_pxvid`、`pxcts`、`TSe...`、server state

当 `_px3` 已签发但业务仍 block，用 4-way trust 矩阵定位：

| 组合 | 目的 |
| --- | --- |
| 真浏览器 cookie + 真浏览器请求 | 基线 |
| 真浏览器 cookie + curl/脚本请求 | 检查传输/IP是否足够 |
| 我们 cookie + 真浏览器请求 | 检查 cookie 内容信任 |
| 我们 cookie + curl/脚本请求 | 实际生产路径 |

如果真 cookie 也开始失败，先换干净 IP 再判断。不要把污染的 IP 误判为字段回归。

## 验证重点

最终验证不只看 `_px3` 是否存在，还要看：

- 当前 source host、app id、SDK / captcha main hash、collector、command map、cookie scope 是否同轮对应
- 6+ 批样本是否同 SDK hash，字段分类、value-match、HMAC/MD5 input 是否已验证
- payload、PC、sid、OB、state 命令和 Set-Cookie 是否字节级合理
- collector / bundle POST 的 URL、Method、Header、Body 编码、seq/rsc、Origin、Referer、UA 和 client hints 是否与浏览器一致
- `_px3`、`_pxvid`、`pxcts`、server-state 是否按当前响应正确合并
- exact retry 的是原始 PX-gated 请求，而不是另一个简单 endpoint
- PX acceptance 与 business acceptance 是否分开记录
- 多轮重新获取 SDK 后是否仍能稳定签发并通过业务验证

分层验收标签：

| 标签 | 通过条件 |
| --- | --- |
| `_px3 issuance 10/10` | 10 次独立运行签发 `_px3`，每次新 uuid，间隔足够，值不同 |
| `PX acceptance 10/10` | 同一 source profile 的原始 PX-gated 请求 exact retry 后不再 PX block |
| `advertising entry acceptance 10/10` | 广告 sign-in -> `/signin/auth/` -> server Location -> generated identity login |
| `identity PX solve 10/10` | 10 个真实 identity block 被 identity profile 解出并 exact retry 推进 |
| `end-to-end business 10/10` | 完整广告/identity/回调链无未解决 PX block，且非 PX gate 已正确分类 |

验收时不要连发测 throttle。单 IP 每次运行至少间隔 10-30 秒；高信任/严档+ 每个 cookie 尽量换干净住宅 IP。

## 常见坑

- 把 Akamai、GraphQL/business 或下游风控误判为 PX
- 混用 `www`、`advertising`、`identity` 的 profile、Cookie scope、command map 或模板
- 只看 `_px3` 签发，不做原始 PX-gated 请求 exact retry
- 用旧 app id、TAG、FT、BI、collector、SDK hash 或旧 command map
- 6 批样本 SDK hash 不一致，导致 STATIC / DYNAMIC 误判
- 解析 POST body 时把 base64 中的 `+` 转成空格
- 用 `JSON.stringify` 替代 PX serialize，或用 Latin-1 base64 替代 UTF-8 base64
- OB 解码不用 binary/latin1，或分隔符不是 4 个 `~`
- command parser 按函数名识别，而不是按 cookie-name shape 识别
- `state.no`、`o111val`、timestamp、memory、performance 类型不匹配模板
- `state.* -> EV key` 未通过 6+ 批 value-match
- HMAC/MD5 input 跨站照抄，没有逐字段 6/6 验证
- 新增模板不存在的字段，或跨 EV 复用不该复用的 key
- anti-tamper delete 后 append，而不是原位置替换
- 忽略跨事件 CONSTANT / MONOTONIC / DICT 规则
- 真抓有 EV3、hid、cookie confirmation beacon 却跳过
- `/ns` token 长度和来源 TLS 不匹配真实浏览器
- Bundle / press 缺 iframe XHR、PX target/listeners、pointer/mouse、large payload、`/d/p`
- post-solve delay 不足
- Cookie scope 错发到另一个 host
- IP/TLS/UA/client hints 不自洽
- 长期保留大范围 VM tracer、全局 Proxy、全局 Hook 或 VMP 探针

## 维护要求

每次上线或修复后维护以下内容，不保存 live secret：

- 更新 profile 矩阵
- 记录 app id、captcha hash、main hash、collector、command map、cookie scope
- 记录触发请求和 exact retry 请求的 method + URL 形状
- 记录 `_px3/_pxvid/pxcts` 是否签发，但不记录完整值
- 记录验收标签和通过率
- 新命令名按 source profile 归档
- 如果 identity 仍只有烟测证据，保持 `resource-discovered`，不要升为 `business-verified`
- 如果业务失败被分类为 Akamai 或 GraphQL/business，停止 PX 资源改动
- 对任何 SDK hash 变化，重跑字段分类、value-match、HMAC/MD5 公式恢复
- 对任何 score/acceptance 下降，先跑 payload coverage 和 4-way trust，再改字段

建议周期：

- 每日：签发 smoke、资源 hash 轻量检查、业务入口小样本验收
- 每周：6+ 批 cold capture 回归、字段数和 command map 对比
- 每月：重建模板 freshness、HMAC/MD5 抽样验证、环境种子更新
- 每次 Chrome 大版本变化：更新 UA/client hints、stack 模板、audio/WebGL/canvas、TLS impersonation
- 每次 captcha/main hash 变化：重新抓样本并按分档走升级响应

## 使用边界

本文只指导 PX 产品识别、优先观察点、字段恢复、补环境方向和验收口径，不提供可直接套用的固定环境值、固定指纹、固定 cookie 或固定算法。

补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。

不得把 live `_px3`、raw payload、raw ob、账号、代理、OTP、OAuth 一次性值写入 skill、进展清单、日志模板或交付文档。
