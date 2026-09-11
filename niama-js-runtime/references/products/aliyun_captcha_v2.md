# 阿里云验证码 v2 callback-proof 参考文档

本文用于识别和处理现代 `AliyunCaptcha.js` 链路：页面调用 `initAliyunCaptcha`，服务端通过 `InitCaptcha` 为当前轮选择 `CaptchaType`、`CertifyId`、`StaticPath` 和 `DeviceConfig`，浏览器加载当轮 `dynamicJS/sg` 与 FeiLin，最终由 `captchaVerifyCallback` 把 proof 交给站点业务后端消费。

本文的实测来源会话为 `019f562a-5c15-7692-b792-bae0d03ddf54`，完成时间为 2026-07-13。会话事实只证明该 callback/business-consume profile；新目标仍必须以当前 `ruyitrace/`、请求包、动态资源和业务响应为准。

如果目标是 `requestInfo + captcha-pro-open.aliyuncs.com + device.captcha-open.aliyuncs.com + Result/direct verify` 的旧式 v2，读取 `references/products/aliyun_captcha.md`。如果主要出现 `securityHeader`、`AWSC.configFYEx`、`bx-ua`、`fire_ua`、`tfstk`、`x5secdata` 或 punish，读取 `references/products/alibaba_h5sec_awsc_fireye.md`。

## 命中特征

出现以下组合特征时，优先命中本产品：

- 页面加载 `https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js`
- 页面调用 `window.initAliyunCaptcha({...})`
- 初始化配置出现 `SceneId`、`prefix`、`mode`、`element`、`button`、`captchaVerifyCallback`、`getInstance`、`slideStyle`
- 请求发往 `https://<prefix>.captcha-open.aliyuncs.com/`，表单含 `Version=2023-03-05`、`Action=InitCaptcha`、`SceneId`、`Mode`、`DeviceData`
- InitCaptcha 响应同时出现 `Success`、`CaptchaType`、`StaticPath`、`CertifyId`、`DeviceConfig`
- 当前轮加载 `https://g.alicdn.com/captcha-frontend/dynamicJS/<semver>/sg.<3 digits>.<16 hex>.js`
- 当前轮加载 `https://g.alicdn.com/captcha-frontend/FeiLin/<version>/feilin...js`
- 设备链出现 `cloudauth-device-dualstack.<region>.aliyuncs.com` 与 `Action=Log2` 或 `Action=Log3`
- 诊断链出现 `upload.captcha-open.aliyuncs.com` 与 `Action=UploadLog`
- DOM 或运行时出现 `TRACELESS`、`SLIDING`、`startTracelessVerification`、`aliyunCaptcha-sliding-slider`
- SDK callback proof 包含 `sceneId`、`certifyId`、`deviceToken`、`data`
- 站点业务请求把原始 proof 包装为 `captchaRequestParam` 或同义字段，callback 返回值包含 `captchaResult`

不要仅凭单个 `StaticPath`、`AWSC`、`acw_tc` 或 `Log3` 判定。强命中至少应满足以下组合之一：

- `AliyunCaptcha.js + initAliyunCaptcha`
- `Action=InitCaptcha + CaptchaType/StaticPath/CertifyId/DeviceConfig`
- `dynamicJS/sg + FeiLin + 四字段 callback proof`

## 产品分流

| 证据形态 | 优先文档 |
| --- | --- |
| `AliyunCaptcha.js`、`Action=InitCaptcha`、`CaptchaType`、callback proof | 本文 |
| `requestInfo`、`captcha-pro-open`、`device.captcha-open`、`Result/direct verify` | `aliyun_captcha.md` |
| `securityHeader`、`AWSC.configFYEx`、`bx-ua/fire_ua`、punish | `alibaba_h5sec_awsc_fireye.md` |
| 只有 `acw_tc`、阿里 CDN 或边缘响应头 | 只能算弱线索，继续按请求链判门 |

同一业务可以同时命中多个阿里安全产品。必须先按请求角色和目标集合分层，不能把动态验证码 runtime、加密配置、WAF 参数和站点业务加密脚本归为同一个对象。

## 请求与状态机

### v2 通用初始化到校验流程

阿里云验证码 v2 的核心不是单个 `captchaData` 或单次 `verify` 请求，而是一轮由服务端初始化材料驱动的状态机。每轮必须从一次成功的 `InitCaptcha` 开始，并在同一轮内完成资源加载、行为材料生成、日志上报和最终校验出口消费。

通用顺序为：

```text
业务触发
-> 获取 requestInfo 或 initAliyunCaptcha 配置
-> 发 InitCaptcha
-> 记录本轮 CertifyId / StaticPath / DeviceConfig / CaptchaType
-> 按 StaticPath 拉本轮 dynamicJS/sg
-> 按页面脚本或 InitCaptcha 结果拉本轮 FeiLin
-> 在同一个 JS runtime 执行 AliyunCaptcha / FeiLin / sg
-> 生成行为材料、DeviceToken、Data
-> 发送 Log2 / UploadLog / Log3
-> 进入校验出口
```

各阶段含义如下：

1. `业务触发`
   目标业务动作触发验证码链路。这里通常能观察到页面初始化配置、按钮点击、接口拦截、业务前置响应或 SDK 初始化调用。此阶段只负责确认验证码被触发，不代表已经有可用 proof。

2. `获取 requestInfo 或 initAliyunCaptcha 配置`
   v2 入口常见两种形态：一种是页面或 HTML 中给出 `requestInfo`，后续本地环境用它生成初始化请求；另一种是页面直接调用 `initAliyunCaptcha({...})`，配置中包含 `SceneId/prefix/mode/element/button/captchaVerifyCallback/getInstance/language` 等字段。两种形态都只是初始化输入，不能跨会话复用。

3. `发 InitCaptcha`
   初始化请求通常带 `Action=InitCaptcha`、`Version`、`SceneId`、`Mode`、`DeviceData` 等字段，请求发往当前配置指定的验证码域名。只有 HTTP 成功且响应业务字段为成功时，才允许创建当前 round。

4. `记录本轮材料`
   成功响应里的 `CertifyId`、`StaticPath`、`DeviceConfig`、`CaptchaType` 是本轮核心材料。必须同时记录响应 hash、请求 URL、请求 body 摘要、时间、UA/TLS/Cookie/session、round id。后续所有 proof、日志和业务消费都必须能回溯到这一轮材料。

5. `按 StaticPath 拉本轮 dynamicJS/sg`
   `StaticPath` 是服务端为本轮选择的精确动态脚本路径，不是版本号递增序列，也不是 latest。应按本轮 `StaticPath` 拼出精确 `dynamicJS/sg...js` URL 并真实加载，记录 URL、bytes、SHA-256、HTTP 状态和来源 round。禁止按 `sg` 编号选择本地最大值或复用上一轮资源。

6. `拉本轮 FeiLin`
   FeiLin 可能由页面脚本、初始化响应、bootstrap 逻辑或设备配置间接决定。它与 sg 都属于当前轮运行材料，网络下载顺序可能并行或交错，不能用抓包毫秒先后硬编码依赖。判断标准是它们是否属于同一轮 `InitCaptcha` 选择出的 runtime。

7. `同一个 JS runtime 执行`
   `AliyunCaptcha` bootstrap、FeiLin、dynamic sg 必须共享同一个 `window/document` realm、cookie/storage、timer、event、layout、crypto/btoa 等运行环境。独立执行 sg 后缺少 bootstrap 全局对象时，应先判定为加载拓扑错误，不要伪造内部 AES、VM 或 SDK 私有对象。

8. `生成行为材料、DeviceToken、Data`
   SDK 会根据当前题型、设备指纹、页面环境、滑动/点击/无感行为、FeiLin 状态和 sg 逻辑生成 `DeviceToken` 与 `Data`。这些字段必须由当前轮 runtime 产出，不能在 Python 或业务层手拼，不能从历史 `captchaData`、历史 Log2/Log3 或多轮候选中挑选。

9. `发送 Log2 / UploadLog / Log3`
   `Log2` 通常是设备或初始化阶段日志，`UploadLog` 是诊断日志，`Log3` 通常靠近验证或提交阶段。它们只能证明对应 SDK 请求已发出并拿到响应，不能单独证明验证码通过，更不能单独证明业务放行。日志请求必须保留 SDK 原始 body 形态、长度、hash、Action、URL 和响应摘要。

10. `进入校验出口`
    v2 的最终出口按当前链路证据分流，不要强行补造不存在的接口。常见出口有两类：

```text
direct verify 出口:
  SDK 产出 verify body
  -> POST 验证码服务端 verify
  -> 响应 Result / Success / VerifyResult 明确通过
  -> 再回到业务接口确认是否放行

callback proof 出口:
  SDK 产出 proof / captchaData
  -> proof 至少包含 sceneId / certifyId / deviceToken / data
  -> captchaVerifyCallback 或业务请求消费 proof
  -> 业务接口返回明确成功码和目标状态
```

分层验收口径：

| 状态 | 可接受证据 | 不能代表 |
| --- | --- | --- |
| `init_selected` | 成功 `InitCaptcha` 响应与本轮材料 | runtime 已就绪 |
| `runtime_loaded` | 本轮 FeiLin 与 sg 已按精确 URL 加载并记录 hash | proof 已生成 |
| `runtime_executed` | bootstrap/FeiLin/sg 在同一 realm 执行到实例可用 | 验证通过 |
| `behavior_generated` | 当前轮行为材料、`DeviceToken`、`Data` 已产出 | 服务端接受 |
| `logs_accepted` | `Log2/UploadLog/Log3` 有成功响应 | 业务放行 |
| `challenge_verified` | direct verify 出口明确通过 | 业务完成 |
| `proof_consumed` | callback proof 被业务方消费并返回明确结果 | SDK UI 成功 |
| `business_released` | 目标业务接口返回明确成功码和目标状态 | 仅验证码通过 |

通用禁止项：

- 混用不同轮的 `CertifyId/StaticPath/DeviceConfig/FeiLin/sg/deviceToken/data`。
- 用失败或超时的 `InitCaptcha` 响应选择 dynamicJS。
- 把 `StaticPath` 当成递增版本号，按编号选择“最新” sg。
- 从多轮结果里做候选池、评分或择优，正常流程只接受当前轮 SDK 产物。
- 复用历史 proof、历史 `captchaData`、历史 verify body 或历史日志 body。
- 只看 `Log2/Log3` 成功就认为验证码通过。
- callback 分支里补造 direct verify；direct verify 分支里伪造 callback proof。
- 业务接口已经返回明确结果后，为验证稳定性重复发送同一个 guarded action。

本会话确认的 callback/business-consume 分支为：

```text
业务触发
-> initAliyunCaptcha
-> Action=InitCaptcha
-> 成功响应选择本轮 CertifyId/CaptchaType/StaticPath/DeviceConfig
-> 加载本轮 FeiLin 与 dynamicJS/sg
-> getInstance / runtime_ready
-> 按 CaptchaType 进入 TRACELESS 或 SLIDING
-> 本地挑战完成
-> 业务按钮或产品入口触发 Log3
-> SDK 生成 proof
-> captchaVerifyCallback(proof, continuation)
-> 站点后端消费 proof 并执行原业务
-> callback 返回 {captchaResult:true/false}
-> SDK 展示成功或失败
-> SDK 可自动 refresh，新的 InitCaptcha 属于下一轮
```

该 profile 不要求出现显式 `Action=VerifyCaptcha`。如果 trace 中没有 direct verify，不得因为旧案例有 `Result` 就补造一个阿里 verify 请求。

### 请求角色

| 请求 | 角色 | 成功能证明什么 |
| --- | --- | --- |
| `Action=InitCaptcha` | 初始化并选择当前轮材料 | 只证明 `init_selected` |
| FeiLin GET | 加载设备运行时 | 只证明资源取得 |
| dynamicJS/sg GET | 加载当前轮验证码运行时 | 只证明资源取得 |
| `Action=Log2` | 设备或初始化日志 | 不能证明验证码通过 |
| `Action=UploadLog` | 诊断日志 | 不能按时间重叠推断交互因果 |
| `Action=Log3` | 提交交互或验证阶段材料 | 不能单独证明业务放行 |
| `captchaVerifyCallback` | 把 proof 交给站点 | 只证明 callback 已派发 |
| 站点业务接口 | 消费 proof 并执行目标动作 | 以明确业务成功码判定最终结果 |
| 成功后的新 InitCaptcha | SDK refresh / 下一轮 | 禁止混入上一轮 proof |

FeiLin 与 sg 的网络下载可能并行。它们的逻辑关系是由同一个成功 InitCaptcha 响应选中，不要用抓包中的毫秒先后硬编码加载依赖。

## 同轮状态边界

每一轮至少绑定以下材料：

```text
page/session/cookie/IP/UA/TLS/time
sceneId/prefix/mode/language
certifyId/captchaType/staticPath/deviceConfig
FeiLin runtime/dynamic sg runtime
deviceToken/data/proof
business request/business response
```

必须建立 round id 或等价状态表。以下行为均禁止：

- 用超时或失败 InitCaptcha 的响应选择 dynamicJS
- 用 refresh 后的新 `CertifyId` 替换当前 proof 内的旧值
- 混用不同轮的 `certifyId/deviceToken/data`
- 复用历史 `captchaRequestParam`
- 把同 URL 的 manifest 样本当成下一轮的选择依据
- 业务接口已经返回明确结果后再次发送 guarded action

## 请求级 dynamicJS

`StaticPath` 是成功 InitCaptcha 响应对当前请求轮次的资源选择，不是升级号、latest 版本或单调序列。`sg.042` 后面可以出现 `sg.001`、`sg.000` 或其它编号。

推荐 loader 规则：

1. 每次只读取本轮成功 InitCaptcha 响应中的精确 `StaticPath`。
2. 仅放行严格 host/path 形态，例如 `https://g.alicdn.com/captcha-frontend/dynamicJS/<semver>/sg.<3digits>.<16hex>.js`。
3. 对未知但形态合法的当前轮 URL 执行真实 GET，不按编号选择本地“最新”文件。
4. 校验 HTTP 状态、JavaScript content-type、非空 body 和合理大小上限。
5. 记录完整 URL、bytes、SHA-256、来源 InitCaptcha 请求、会话和 round id。
6. manifest 只保存精确 URL 样本，用于相同资源审计和离线回归。
7. 同进程可以合并相同 URL 的 body fetch，但每个真实 script node 仍按页面语义执行。

动态 `DeviceConfig` 是加密配置。解密后若得到 `key/switch/sessionId/version/pluginElements/pluginResource/globalVariable/timestamp/ip` 等配置字段，不应称为 JavaScript 源码。

动态 sg 属于阿里验证码运行时，也不应直接称为站点业务加密 JS。只有发现独立站点域响应，并具备“响应载荷 -> 解密函数 -> eval/Function/Worker/调用入口 -> 业务参数产出”的完整证据，才能登记第二层业务动态脚本。

## 初始化与实例门禁

典型初始化形态：

```js
initAliyunCaptcha({
  SceneId,
  prefix,
  mode: "embed",
  element: "#captcha-element",
  button: "#captcha-button",
  captchaVerifyCallback,
  getInstance,
  slideStyle,
  language: "cn",
});
```

至少分三层 smoke：

```text
chain: bootstrap/FeiLin/sg 能否按共享拓扑执行
init: init Promise fulfilled 且 getInstance 收到实例
proof/business: 交互、proof callback 与最终业务是否闭合
```

“三个脚本执行到文件尾”不等于公开初始化完成；`getInstance` 存在也不等于 proof 已生成。

bootstrap、FeiLin 和动态 sg 通常共享同一个 `window/document` realm，并依赖 bootstrap 提供的 `window.__ALIYUN_CRYPT`。独立运行 sg 后出现 `__ALIYUN_CRYPT.AES` 缺失，优先判为加载拓扑错误，不要伪造 AES 宿主能力。

## CaptchaType 与交互

先以本轮 InitCaptcha 响应和实例能力分流：

- `TRACELESS`：只有实际实例存在对应入口时才调用 `startTracelessVerification`
- `SLIDING`：以真实 slider DOM、document 级 move/up listener 和业务按钮触发链执行
- 未知类型：记录题型、实例 shape 和 DOM，不调用猜测的 verify 方法

外层对象存在 `startTracelessVerification` 不代表当前子实例支持无感入口。必须检查本轮 `CaptchaType`、实例方法和 DOM 三者是否一致。

### SLIDING 事件契约

本会话真实顺序为：

```text
slider mousedown
-> document mousemove x N
-> document mouseup
-> UI 进入 ok / 滑动完成
-> 点击 #captcha-button 内真实 BUTTON
-> Log3 / proof callback
```

关键规则：

- `mouseup` 本身不一定提交 proof
- 滑块完成后仍可能需要独立业务按钮 click
- 最大位移优先从实时 layout 推导；本会话是 `width - height = 342 - 31 = 311px`
- 对齐事件类型、target、路由、点数量级、方向和耗时范围，不复制 trace 的逐点坐标或毫秒时间
- 需要保留 `target/currentTarget/eventPhase`、`button/buttons`、坐标和 layout 派生字段
- trace 的 refPoint 坐标可能受缩放影响，不能直接当 CSS px

## Proof 与 callback

本会话 callback 首个参数是 JSON 字符串：

```json
{
  "sceneId": "<scene>",
  "certifyId": "<fresh>",
  "deviceToken": "<fresh>",
  "data": "<fresh>"
}
```

第二个参数可以是 SDK 内部 continuation callback，站点代码可能忽略。记录实际参数数量、类型、调用栈和返回值，不要按函数声明长度推断真实调用契约。

站点通常把原始 proof 字符串注入业务请求，例如：

```json
{
  "captchaRequestParam": "<captchaVerifyCallback 原始字符串>"
}
```

callback 返回 `{captchaResult:true}` 只表示应用层通知 SDK 继续成功流程。站点实现可以错误地在业务失败时仍返回 true，因此它和 SDK 的“验证通过”UI都不能单独作为最终成功口径。

## 分层成功口径

| 状态 | 证据 | 不能代表 |
| --- | --- | --- |
| `init_selected` | 成功 InitCaptcha 与本轮材料 | runtime 已就绪 |
| `runtime_ready` | 动态资源执行、DOM 就绪、`getInstance` | proof 已生成 |
| `local_challenge_complete` | `滑动完成` 或无感本地完成态 | 服务端接受 |
| `proof_ready` | 四字段 proof 已构造 | 业务放行 |
| `callback_dispatched` | `captchaVerifyCallback` 已调用 | 业务成功 |
| `challenge_verified` | 独立验证码校验接口明确接受 | 后续业务完成 |
| `business_released` | 目标业务接口返回明确成功码和目标状态 | 最终成功 |
| `sdk_ack` | `captchaResult:true`、SDK 成功 UI | 不可单独验收 |
| `refresh_next_round` | 新 InitCaptcha 与新 CertifyId | 不属于上一轮 |

`captcha-only` 目标可以在真实独立校验明确接受后结束；`full_flow` 或 guarded send 必须以 `business_released` 为最终成功。

## 本会话难点与解决

### 共享 runtime 拓扑

难点是独立 sg 会稳定暴露假 AES blocker，脚本加载成功也不代表公开导出成立。最终按 `bootstrap -> InitCaptcha -> FeiLin -> 当轮 sg -> 交互 -> callback` 共享 realm 执行，并用 `chain/init/slide` 分层验收。

### 逐批因果补环境

FeiLin 和 sg 含大量存在性、反射和 webdriver 探针。不能按 Window 快照批量塞空函数，也不能进入 VMP/opcode/handler 插装。采用以下门禁：

```text
fresh run 首个未捕获异常
+ v8trace 当前路径候选
+ ruyitrace 精确 receiver/value/descriptor
+ 源码真实用法
-> 只补一个最小语义批次
```

本会话 blocker 逐步经过 `window/document/DOM factory/navigator/constructor/window methods/screen/documentElement/timer/querySelectorAll/insertAdjacentHTML/CSSOM/event/layout`，每批都要求旧异常消失并出现新的因果前移。

### DOM 需要真实树与索引

动态 sg 通过 `insertAdjacentHTML` 注入 embed UI，随后立即按 ID/class/tag 查询并绑定事件。只保存 opaque `innerHTML` 字符串会失败。

最终实现 fragment parser、真实 parent/child 关系、connected 状态、ID/tag 索引、HTMLCollection/NodeList snapshot、递归 disconnect，以及 `innerHTML/outerHTML` 的结构化序列化。禁止针对验证码 ID 硬编码伪节点。

### CSSOM 空字符串语义

动态分支会直接执行 `style.left.slice(...)`。浏览器中已知但未设置的 CSS 属性读取为空字符串，普通对象却返回 `undefined`。

最终用独立 CSSStyleDeclaration 状态实现 `cssText/setProperty/getPropertyValue/removeProperty/item/priority` 与常用直接属性，并让 fragment 中的 `style` attribute 同步进入 CSSOM。

### Node host 泄漏

直接暴露 Node timer 会让 FeiLin 在 JSON stringify 时遇到循环 `Timeout`；粗暴改成数字又会破坏 undici 对 host timer handle 的内部需求。

最终启动时保存 host timer/fetch/AbortController。目标页面 timer 返回递增整数并在内部 Map 保存 handle，仅对 undici 内部调用旁路回 host timer。不要给 `Number.prototype` 增加 `.refresh()` 之类污染补丁。

### Network Error 转写

Aliyun loader 可能把脚本调度内部异常统一转写为 `Network Error`。本会话曾因本地 allowlist 拒绝一个新 sg，表层却看起来像远端失败。

最终在资源调度 catch 中记录 `sourceURL/name/message/stack`，并分别记录 XHR 的 start/headers/body/error、耗时和响应大小。只有确认 transport timeout 才按网络问题处理。

### 交互不是直接 verify

当前 `SLIDING` 子实例没有可直接调用的 verify/traceless 方法。真实 proof 在 311px 滑动完成后，继续点击业务按钮才生成。

最终补齐 UIEvent/MouseEvent/PointerEvent、document listener 路由、Element layout 和真实 BUTTON 子节点，执行平滑多点轨迹后再 click，不本地拼装 proof。

### Cookie、proof 与业务时序

页面生成多个 Cookie，单字符串模型会覆盖前值。proof 字段、nonce、时间和业务请求也必须同轮。

最终使用多键 cookie jar，并在 `captchaVerifyCallback` 内立即发起站点业务请求，由明确业务结果决定 `{captchaResult:true/false}`。默认不回显 proof，不缓存历史材料。

### 重试与动态分支覆盖

InitCaptcha、FeiLin 和日志请求存在偶发 timeout。失败轮 proof 不能重放，明确业务响应后也不能重发 guarded action。

最终只对 init/resource/proof/transport 类失败启动完整 fresh challenge，每次新进程、新 InitCaptcha、新动态脚本和新 proof。输出 URL/bytes/hash、drag、proof shape、Cookie 名、业务结果和 attempts。

### appVersion 隐藏分支

单次成功不能证明动态分支覆盖完整。五轮随机验证前，一个 `sg.004` 分支调用 `navigator.appVersion.trimEnd()`，暴露此前未触达的 getter。

ruyitrace 多次给出 `Navigator.get appVersion -> "5.0 (Windows)"`，因此只补该原型 getter。没有据此批量补其它 Navigator 字段。修复后重新创建 fresh challenge，连续五轮不同 sg 分支全部业务成功。

## ruyitrace / jscall 优先动作

1. 搜索 `AliyunCaptcha.js`、`initAliyunCaptcha`、`Action=InitCaptcha`、`StaticPath`、`CaptchaType`、`CertifyId`、`DeviceConfig`。
2. 建立请求表，区分 InitCaptcha 重试、成功响应、Log2、Log3、UploadLog、业务请求和成功后 refresh。
3. 只从成功 InitCaptcha 响应创建 round，记录当前 URL/hash/bytes 和会话材料。
4. 搜索 FeiLin 与 dynamic sg 的 script 注入、onload/onerror、调用栈和共享全局读取。
5. 搜索 `getInstance`、`startTracelessVerification`、slider DOM、document move/up listener 与业务 button click。
6. 定位 Log3 initiator、proof 构造、`captchaVerifyCallback` 的真实参数和返回 Promise。
7. 定位 proof 注入站点业务请求的字段、Cookie、Origin/Referer、幂等键和最终业务响应。
8. 分别记录 SDK UI、callback 返回和成功后 refresh，不把它们合并成业务成功。
9. 如果 jscall 过滤器仍指向旧域名或只有 `trace_init`，明确记为不匹配，不能声称覆盖目标调用链。
10. 动态脚本内部即使疑似 VMP，也只观察外围 DOM/BOM、请求和 callback，不对 opcode/handler 下探针。

## 本地落地建议

```text
code.js
├─ 浏览器宿主对象与 native toString 保护
├─ shared window/document realm
├─ DOM tree/CSSOM/layout/EventTarget/timer/cookie 状态
├─ bootstrap 与固定 FeiLin 样本
├─ 本轮 InitCaptcha 响应驱动的 exact dynamicJS loader
├─ chain/init/proof 三层稳定入口
└─ proof callback 输出与可选业务回调桥接

test.py
├─ 创建 fresh challenge
├─ 保持当前会话、Header、Cookie、TLS、IP 与时间材料
├─ 调用 code.js 完成本轮 runtime 和交互
├─ 在 callback 边界提交真实业务请求
├─ 仅对 pre-business 网络类失败启动新挑战
└─ 输出 dynamicResources/proofShape/cookies/business/attempts

resources/manifest.json
├─ bootstrap 与 FeiLin 精确样本
└─ dynamic sg 精确 URL/hash 样本，仅用于审计和离线回归
```

## 常见错误路线

- 把 `StaticPath` 变化描述成升级、版本漂移或 latest
- 固定 trace 的 sg，或按编号选择最大的 sg
- 把加密 DeviceConfig 或阿里 sg 称为站点业务加密 JS
- 独立运行 sg 后伪造 `__ALIYUN_CRYPT.AES`
- 把 chain returncode 0 当成 init、proof 或业务完成
- 看到 `Network Error` 就直接归因于远端网络
- 批量补完整浏览器、空壳 API 或固定指纹值
- 在 VMP、opcode、handler 或字节码分发层插装
- 用 opaque innerHTML、固定 outerHTML 或 captcha ID 特判代替 DOM 树
- 让已知未设置 CSS 属性返回 `undefined`
- 让目标脚本看到 Node Timeout、Node EventTarget 私有 brand
- 直接调用不存在的 verify/traceless 方法
- 只发 mouseup，不执行 slider move 和后续业务 button click
- 把 `滑动完成`、Log3、callback、`captchaResult:true` 或 SDK UI 当最终业务成功
- 复用 proof、跨轮混用 CertifyId，或把 refresh 新轮材料写入旧轮
- 对明确业务响应重试 guarded send
- 为了形式完整继续补未进入成功链的 `document.all`、canvas、WebGL 或其它指纹面

## 本会话实测结论

- 初始 trace 选择 `sg.003`，后续 fresh InitCaptcha 观察到多个不单调 sg 编号，证明服务端按请求选择。
- 一个新 `sg.042` 曾被本地固定 allowlist 拒绝，Aliyun loader 把真实错误转写成 `Network Error`；改成请求级 exact URL loader 后恢复。
- `sg.043/sg.007` 暴露 `insertAdjacentHTML` 与 embed fragment tree 缺口。
- `sg.000` 暴露未设置 `style.left` 必须返回空字符串的 CSSOM 语义。
- `sg.004` 在随机覆盖时暴露 `navigator.appVersion.trimEnd()` 分支。
- 首次端到端成功前两轮是 FeiLin timeout，第三轮重新创建 fresh challenge 后业务成功，没有复用失败轮 proof。
- 最终连续五轮分别命中 `sg.026`、`sg.027`、`sg.042`、`sg.000`、`sg.010`，五轮均使用各自动态 URL 和 fresh proof，业务响应全部明确成功。
- 成功链中没有发现第二份独立站点业务密文 JS；DeviceConfig 是配置，dynamic sg 是阿里验证码 runtime。

## 验证口径

最低验收应同时满足：

```text
成功 InitCaptcha 响应被正确识别
当前轮 StaticPath 的精确 dynamicJS 被加载并记录 hash
FeiLin 与 sg 在正确 shared runtime 中执行
getInstance 或等价 runtime_ready 门禁通过
按当前 CaptchaType 进入真实交互入口
proof 的 sceneId/certifyId/deviceToken/data 均来自同一轮
Log3/callback/业务请求角色已正确区分
站点业务接口返回明确成功码和目标状态
callback 返回与 SDK UI 已记录但不代替业务成功
成功后 refresh 被标记为下一轮
至少执行多轮 fresh InitCaptcha，验证不同动态分支不依赖固定 sg
```

guarded send 的多轮验证必须遵守用户请求范围。每个业务目标在收到明确业务响应后停止，不用重发业务动作来验证稳定性；如需继续覆盖动态分支，优先使用只到 proof 的无副作用入口或新的明确测试目标。

## 交付记录要求

进展清单至少记录：

- 命中产品 `aliyun_captcha_v2` 的组合证据和已读文档
- 目标页面、动作、trace PID、请求包和会话范围
- 每个成功 InitCaptcha 的 round id、CertifyId、CaptchaType、StaticPath
- dynamicJS 与 FeiLin 的 URL、bytes、SHA-256 和来源请求
- DeviceConfig 密文与解密结果的类型归属，不泄漏可复用敏感值
- chain/init/proof/business 四层结果
- 当前首个 blocker、ruyitrace 真值、最小补丁和机械差分
- proof shape、Cookie 名、业务注入字段、业务响应与 SDK callback 返回
- timeout 重试是否创建 fresh challenge，是否发生业务重发
- 多轮动态分支覆盖结果，以及仍未覆盖的题型或 runtime 分支
- 已证伪路线和重新开启条件

本文不能替代当前目标 trace。任何旧 URL、hash、尺寸、proof 长度、坐标、UA、Cookie、SceneId、prefix 或业务 endpoint 都只能作为案例，不得直接复制到新目标。
