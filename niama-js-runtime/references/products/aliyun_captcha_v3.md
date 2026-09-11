# 阿里云验证码 V3 direct-verify / CHECK_BOX

本文用于处理现代 Aliyun Captcha V3 的 direct-verify 分支。强特征是 `Log1/DeviceConfig -> FeiLin -> Log2 -> InitCaptchaV3/StaticPath -> dynamicJS/cx -> UploadLog/Log3 -> VerifyCaptchaV3`，最终得到 `VerifyResult/VerifyCode` 与站点使用的 `captchaVerifyParam`。

证据来源分两层：会话 `019f5b32-c8ae-74d3-b5ca-2b513079f716` 只完成了行为轨迹缺口的只读诊断；后续同项目才实现随机轨迹、传输重试并完成严格连续 `5/5` live 验证。不得把后续结果倒写成该诊断会话本身已完成。

如果链路是 `Action=InitCaptcha + dynamicJS/sg + captchaVerifyCallback`，读取 `aliyun_captcha_v2.md`。如果链路是 `requestInfo + captcha-pro-open/device.captcha-open + Result`，读取 `aliyun_captcha.md` 的旧式分支。AWSC/H5Sec/WAF/punish 继续读取 `alibaba_h5sec_awsc_fireye.md`。

## 强命中特征

优先命中本产品的组合证据：

- 页面加载 `o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js`
- 页面调用 `initAliyunCaptcha`
- 设备接口出现 `Action=Log1`，响应 `ResultObject.DeviceConfig`
- 当前轮加载 `captcha-frontend/FeiLin/.../feilin...js`
- 随后出现 `Action=Log2`
- 初始化请求出现 `Action=InitCaptchaV3`
- 成功响应出现 `CaptchaType=CHECK_BOX`、`StaticPath`、`CertifyId`
- 当前轮加载 `captcha-frontend/dynamicJS/<semver>/cx.<digits>.<hash>.js`
- 诊断或设备链出现 `Action=UploadLog`、`Action=Log3`
- 校验请求出现 `Action=VerifyCaptchaV3`
- 校验响应出现 `Success`、`VerifyResult`、`VerifyCode`
- SDK 成功边界产生非空 `captchaVerifyParam` 或同义字段

强匹配建议至少满足：

```text
Log1 + DeviceConfig + InitCaptchaV3 + dynamicJS/cx + VerifyCaptchaV3
```

只看到 `AliyunCaptcha.js`、`DeviceConfig`、FeiLin 或 `StaticPath` 不能区分 v2/v3。必须继续看 Action 名、dynamicJS 文件族和最终校验形态。

## 请求状态机

```text
页面/业务触发
-> static AliyunCaptcha.js bootstrap
-> Log1
-> 从本轮成功 Log1.ResultObject.DeviceConfig 派生 FeiLin URL
-> GET fresh FeiLin
-> Log2
-> InitCaptchaV3
-> 从本轮成功响应 StaticPath 派生 dynamicJS/cx URL
-> GET fresh business-stage dynamicJS/cx
-> getInstance / runtime_ready
-> CHECK_BOX 行为事件
-> UploadLog / Log3
-> VerifyCaptchaV3
-> 服务端 VerifyResult/VerifyCode
-> SDK 生成 captchaVerifyParam
-> 站点 guarded business，例如 /sendCode
```

请求角色必须分开记录：

| 请求或事件 | 角色 | 不能证明 |
| --- | --- | --- |
| Log1 | 选择设备配置 | FeiLin 已执行 |
| FeiLin GET | 加载设备 runtime | 验证码已初始化 |
| Log2 | 设备/初始化日志 | challenge 已通过 |
| InitCaptchaV3 | 选择本轮题型和 cx runtime | 交互已完成 |
| dynamicJS/cx GET | 加载业务阶段验证码 runtime | Verify 已接受 |
| UploadLog | 诊断或遥测上报 | challenge 已通过 |
| Log3 | 验证阶段材料 | 服务端已接受 |
| VerifyCaptchaV3 | 独立 challenge 校验 | 后续业务已执行 |
| captchaVerifyParam | 站点业务消费凭证 | guarded business 已成功 |
| 站点业务响应 | 最终业务结果 | 以明确业务码判定 |

## 三类脚本角色

必须区分：

1. 静态 loader：`AliyunCaptcha.js`，不属于用户口中的“两份动态 JS”。
2. fresh FeiLin：URL 由当前 attempt 的 `Log1.ResultObject.DeviceConfig` 派生。
3. fresh business-stage dynamicJS/cx：URL 由当前 attempt 的 `InitCaptchaV3.StaticPath` 派生。

`DeviceConfig` 是配置材料，不是 JavaScript 源码。`dynamicJS/cx` 是阿里验证码业务阶段 runtime，也不等于站点自己的业务加密 JS；只有存在独立站点载荷、解密执行链和业务参数产出证据时，才登记站点业务动态脚本。

动态策略：

- 设置 `dynamic_delivery=per_request`，不要描述成升级、latest 或单调版本序列。
- 每个 attempt 重新读取 fresh 响应并派生 exact URL。
- URL 重复不等于跨轮复用；freshness 看是否由本轮响应派生并实际请求。
- URL 不同也不等于 SDK 升级；编号可以前后跳变。
- 动态 GET 使用 `no-store`，不得把上一轮源码作为正式运行态输入。
- `resources/` 与 manifest 只保存精确样本，用于 fixture smoke、审计和差异对照。
- 每轮记录 URL、bytes、SHA-256、来源 request id、round id 和脚本角色。

## Runtime 与会话拓扑

本分支的三个脚本通常共享同一个 `window/document` realm、验证码实例、timer、DOM、storage 和 callback 状态。优先使用：

```text
长驻 Node JSONL bridge
  static loader
  -> response_in(Log1)
  -> fresh FeiLin
  -> response_in(Log2/InitCaptchaV3)
  -> fresh dynamicJS/cx
  -> interact
  -> Verify callback

Python test.py
  一个 canonical HTTP session/cookie jar
  -> 并发处理多个带 request id 的 in-flight XHR
  -> 把 status/headers/body 按 id 回送同一个 Node realm
```

关键规则：

- 同一 attempt 内保持同一规范 HTTP session、Cookie、UA/TLS/IP 与 Node realm。
- 不要把 FeiLin、cx 分到互不共享状态的独立 Node 进程。
- 不要用串行 Python bridge 阻塞浏览器本应并行的 Log2/XHR；这会制造假的 JS timeout。
- 顶层 retry 必须创建 fresh challenge；失败轮的 proof、CertifyId、StaticPath 和 captchaVerifyParam 不得重放。

## 为什么难，以及怎么解决

| 难点 | 常见表象 | 根因 | 解决门禁 |
| --- | --- | --- | --- |
| 动态角色误判 | 把 cx 变化写成升级 | 服务端按请求选择动态 runtime | 按 static loader、fresh FeiLin、fresh cx 三角色建模 |
| 首异常遮蔽后续分支 | 连续出现 `Node/Location/print/... is not defined` | FeiLin 含存在性、原型和布尔控制谓词 | `v8trace 候选 -> ruyitrace 真值 -> 最小语义补丁 -> 下一轮差分` |
| 压缩 TypeError 难读 | `x[y(...)] is not a function` | 混淆成员名不可读，且可能是上游错误的次生症状 | 用相同 site/列号/栈回到 domtrace；旧错随上游修复消失时不继续补 |
| loader 遮蔽异常 | 表层统一为 `Network Error` | script onerror 把内部执行异常转写成网络失败 | bridge 记录 request id、role、script status、sourceURL 和原始 runtime error |
| 多异步错误漏报 | 修完一个 rejection 后又被另一个终止 | 一次性 unhandledRejection 监听只接住首错 | 覆盖整个等待窗口，结构化收集并区分首因与次生异常 |
| 诊断入口失真 | 以为跑了配置轮，实际跑默认 bootstrap | PowerShell/rtk/CLI 引号剥离 | 为常用 smoke 提供无 JSON 引号依赖的稳定入口；无效轮不得进结论 |
| harness 噪声 | v8trace 出现 Buffer/process root | root 来自 CLI/harness 而非目标脚本 | 按 isolate/script_id/site 归属过滤，不能只看名字隐藏 Node 全局 |
| 空壳语义失败 | API 已存在仍走错误分支 | 目标继续读返回内容、身份、原型、descriptor 或状态 | 补链路内真实可观察语义，不只补空函数/native 外观 |
| iframe 指纹 | `contentWindow.document` 后继续失败 | loader/FeiLin 使用独立 about:blank realm | 建最小 child realm，保持 Window/Document/Element/CSSStyle 身份独立 |
| Node 宿主泄漏 | JSON 循环 Timeout、Event 字段写入报错 | Node timer 返回对象，浏览器返回数字；Node Event 字段只读 | 目标 timer 用数字 id 映射 host handle；事件字段安全写入 |
| DOM 无状态 | cx 初始化缺 `insertAdjacentHTML/NodeList/Image/classList` | cx 会真实构建 UI、查询节点、加载图片并绑定事件 | 实现最小真实树、属性、集合、CSSOM、图片 load 和 EventTarget |
| HTTP 指纹差异 | requests 端点断开，浏览器正常 | HTTP/1.1/TLS 外观与目标不一致 | 用匹配浏览器的 curl_cffi/HTTP2/TLS 会话并保持 JS/HTTP UA 一致 |
| fixture 假阳性 | fixture captcha_success，live Verify false | fixture 只按 Action 回放成功包，不校验 proof | fixture 只到 chain_replayed，最终看 live Verify |
| 行为 proof 不完整 | JS 无异常、完整发 Verify，但返回 false | 只有瞬时 down/up/click，缺 move、Pointer、焦点、相位和可信外观 | 用 trace 证明的事件族与形态生成每轮独立轨迹，再做多轮 live |

## 环境缺口分类

不要把所有缺口都处理成“补一个函数”。按以下六类定性：

```text
存在性谓词: typeof / in / !name / constructor root
身份与原型: instanceof / prototype / constructor / toStringTag / native source
状态对象: DOM tree / CSSOM / collection / cookie / storage / location / screen
异步与事件: timer / Promise / EventTarget / iframe / callback / request ordering
网络与协议: HTTP2 / TLS / timeout / redirect / Cookie owner / concurrent XHR
行为 proof: move/down/up/click/focus/target/phase/timestamp/pointer fields
```

每轮只修当前首个因果批次。上游修复后自动消失的 TypeError、loader error 或 secondary rejection 不应变成新环境补丁。

## CHECK_BOX 行为契约

本案例证明瞬时 `mousedown -> mouseup -> click` 不足。目标读取了 mouse/pointer/focus 字段，并把行为材料带入 Verify。

证据支持的事件族：

```text
pointermove + mousemove x N
-> pointerdown
-> mousedown
-> focusout 或当前页面证实的焦点转移
-> pointerup
-> mouseup
-> click
```

至少保持：

- `target/currentTarget/eventPhase` 与真实冒泡路由一致
- `button/buttons`、client/page/screen/offset 坐标关系一致
- PointerEvent 的 `pointerType/pressure/width/height/isPrimary` 按证据建模
- 浏览器相对 `timeStamp` 外观，不使用 epoch 代替
- 当前执行层可观察的 `isTrusted` 外观按 trace 建模；不要宣称浏览器合成事件本身变成 trusted
- endpoint 从当前 DOM/layout 推导，不复制旧站点坐标
- 只对齐点数量级、方向、速度变化和时长范围，不逐点逐毫秒复制 trace

当多轮 live 证明固定轨迹产生重复度风险时，在证据形态内独立生成轨迹。当前案例后续验证使用 `11-15` 点三次 Bezier，并随机化 start/control、lead/move/settle/hold/click；这些范围是案例起始 profile，不是所有站点的固定常量。

动态 URL 可以合法重复，但 interaction profile 不应跨轮完全相同。记录每轮 profile 摘要，不记录或交付可直接复用的完整 proof。

## 传输与重试边界

把资源 transport 和 Verify 风险拒绝分层：

- fresh URL 已产生但 script GET timeout，属于资源 transport，尚未进入行为验证。
- script 已 loaded、interaction 已派发、Verify 返回 `VerifyResult=false`，才进入行为 proof 或同轮状态归因。
- 动态 script GET 可以在同一逻辑会话内顺序重试，校验 2xx、非空 body、合理 content-type/size。
- 不要对同一个动态 URL同时启动不同 Cookie/TLS 指纹的并发 race；败者通常无法取消，还会破坏可解释性。
- Init/Log 等浏览器本来允许 fallback 的请求按页面语义处理。
- VerifyCaptchaV3、captchaVerifyParam 和 guarded business 不能按资源重试逻辑盲目重发。
- transport 失败后的顶层重试必须创建新进程、新 challenge、新动态材料。

## 分层成功口径

| 状态 | 必要证据 |
| --- | --- |
| `chain_replayed` | fixture 路由、脚本角色和请求顺序可执行 |
| `runtime_ready` | 两份 fresh 动态脚本 loaded，实例和 DOM 就绪 |
| `interaction_dispatched` | 当前轮独立事件 profile 已执行 |
| `verify_request_sent` | VerifyCaptchaV3 请求已发出，不代表成功 |
| `challenge_verified` | 2xx Verify 响应、`Success=true`、`VerifyResult=true`、当前目标接受的成功 VerifyCode、非空 captchaVerifyParam、无 runtime/control error |
| `business_released` | guarded business 返回明确成功码和目标状态 |

`T001` 是当前案例观测到的成功码，不应在没有当前目标证据时写成所有 V3 的通用常量。callback 名为 success、fixture `captcha_success`、SDK UI 成功或 Verify 请求已发出，均不能替代 `challenge_verified`。

## 连续多轮验收

当用户要求 `N/N`：

1. 每轮使用独立进程、fresh Log1、fresh InitCaptchaV3、fresh 动态资源和 fresh proof。
2. 分母固定为启动的全部 N 轮；资源下载失败、脚本异常、timeout 和 Verify false 都计失败。
3. 失败轮不能用后续补跑替换。
4. 校验每轮两种动态脚本都来自本轮响应并成功 loaded；URL 不要求互不相同。
5. 行为进入 proof 时，校验 N 个 interaction profile 独立，不复用完全相同轨迹。
6. `N/N` 全部满足 `challenge_verified` 才通过；full_flow 还要逐个目标满足 `business_released`。

本案例固定轨迹首批为 `3/5`，失败响应出现 `F001/F008`；这些码没有官方语义证据，不作释义。随机轨迹首批实际进入 Verify 的 `4/4` 均通过，但另有一轮 script transport 失败，因此严格仍是 `4/5`。增强同会话顺序资源重试后，新批次达到 `5/5` 且五个 profile 均不同。该 A/B 只证明当前案例中“行为随机化”和“资源重试”解决了不同层级的问题。

当项目 `test.py` 输出本文建议的结构化 summary 时，可直接使用 skill 验收器：

```powershell
rtk python "$env:USERPROFILE\.codex\skills\spider-skill-js\scripts\verify_aliyun_v3_batch.py" `
  --runs 5 `
  --run-timeout 120 `
  --verify-code T001 `
  -- python test.py --mode live --captcha-only --timeout 100
```

只有脚本最终输出 `all_success=true` 且进程退出码为 `0` 才通过。`--verify-code` 只在当前目标已确认成功码时使用；没有证据时省略，但仍要求非空 VerifyCode 与 `VerifyResult=true`。

## 诊断决策

```text
没有 script loaded / 没有 interaction profile / 没有 Verify
-> 初始化、资源 transport、runtime 或 bridge 层

Verify 2xx 且 VerifyResult=false
-> 行为 proof、同轮状态、环境读取面或服务端风险层

VerifyResult=true 但 captchaVerifyParam 为空
-> SDK callback/凭证组装层

captchaVerifyParam 非空但 guarded business 失败
-> 凭证注入、业务会话、Cookie/Header、业务规则层
```

看到 `Network Error` 时先展开原始 script runtime error 和 transport error。看到 `F001/F008` 等供应商码时只记录码值、响应和所在层级；没有官方文档或多组因果证据时不猜含义。

## 本地落地建议

```text
code.js
├─ 当前链路需要的 Window/DOM/CSSOM/Event/timer/iframe 语义
├─ static AliyunCaptcha.js bootstrap
├─ bridge request_out/response_in
├─ exact fresh FeiLin 与 dynamicJS/cx same-realm loader
├─ CHECK_BOX 独立轨迹生成
└─ status/runtime_error/script_status/captcha callback 结构化输出

test.py
├─ canonical HTTP session/cookie jar/TLS impersonation
├─ 并发 in-flight request id 调度
├─ fresh DeviceConfig/StaticPath 动态资源获取
├─ 仅资源层同会话顺序重试
├─ VerifyResult 与 captchaVerifyParam 严格门禁
├─ guarded business 单次提交
└─ fixture/live/N-of-N 结构化 summary

resources/manifest.json
├─ static loader sample
├─ FeiLin fixture sample_only + fresh_required
└─ dynamicJS/cx fixture sample_only + fresh_required
```

## 常见错误路线

- 把 dynamicJS/cx 编号变化称为升级或选择最大编号
- 把 static loader 算进“两份动态 JS”
- 把 DeviceConfig 当源码，或把 cx 当站点业务加密 JS
- 固定上一轮 FeiLin/cx 作为 live 正式资源
- 分进程独立运行 FeiLin 与 cx，伪造缺失共享全局
- Python 串行代理所有 XHR，制造浏览器不存在的 timeout
- 对同一 script URL并发使用两个不同 TLS/Cookie 客户端竞速
- 看到 loader `Network Error` 就继续补 DOM/BOM
- 只补 API 存在性，不补返回内容、状态和身份关系
- 用主 realm 别名伪造 iframe child realm
- 用 opaque innerHTML 或验证码 ID 特判代替 DOM 树
- 让未设置 CSS 属性返回 `undefined`
- 让目标看到 Node Timeout 或 Node Event 私有语义
- 把 fixture success、fallback callback 或 Verify request sent 当通过
- 固定一条成功轨迹并用单次 live 宣称稳定
- 把失败轮从 N/N 分母移除，或用补跑替换
- 对未经证实的 VerifyCode 写官方语义

## 进展记录要求

至少记录：

- 命中 `aliyun_captcha_v3` 的组合证据和已读文档
- `dynamic_delivery=per_request`
- static loader、fresh FeiLin、fresh dynamicJS/cx 三种角色
- 每种动态 URL 的派生响应、round id、cache policy、bytes/hash 和 fixture policy
- `single_runtime/shared_runtime_chain` 证据及 request bridge 顺序
- XHR 并发、Cookie owner、UA/TLS/IP 和 retry 边界
- fixture、runtime、interaction、Verify、captchaVerifyParam、business 分层状态
- 每个失败的主层级、原始响应和是否创建 fresh challenge
- 行为 profile 形态、是否跨轮独立生成和多轮完整分母
- `N/N` 每轮结果矩阵，资源失败也保留在分母
- 已证伪路线与重新开启条件

本文不能替代当前目标 trace。旧 URL、hash、坐标、时长、SceneId、prefix、UA、Cookie、VerifyCode 和业务 endpoint 都只能作为案例材料。
