# 阿里云验证码 / AWSC / noCaptcha 参考文档

本文用于识别和处理阿里云验证码 v2 滑块、AWSC/noCaptcha、阿里系 WAF 1036 和 x5sec 处罚页链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据、`http_packet` 请求证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

## 命中特征

出现以下特征时，可优先按阿里系验证码 / WAF 链路分析：

- 验证码请求域名为 `captcha-pro-open.aliyuncs.com` 或 `device.captcha-open.aliyuncs.com`
- 首轮初始化响应含 `StaticPath`，后续加载 `https://g.alicdn.com/captcha-frontend/dynamicJS/<StaticPath>.js`
- 动态脚本链继续加载 `https://g.alicdn.com/captcha-frontend/FeiLin/.../feilin...js`
- 受保护页面或 HTML 中出现 `var requestInfo = {...};`
- 最终验证码响应含 `Result`，或本地环境输出多段用于 init、log2、verify 的 query string
- 页面或脚本出现 `AWSC`、`AWSCInner`、`AWSCFY`、`__awsc_et__`、`__awscnc_wrapper_id__`、`fyglobalopt`、`nc`
- 页面加载 `g.alicdn.com/AWSC/et/.../et_f.js`、`g.alicdn.com/AWSC/fireyejs/.../fireyejs.js`、`g.alicdn.com/AWSC/nc/.../nc.js`
- 页面请求 `cf.aliyun.com/nocaptcha/initialize.jsonp`、`fourier.taobao.com/ts`、`tdum.alibaba.com/dss.js`
- WAF/处罚页出现 `aliyun_waf_aa`、`aliyun_waf_oo`、`aliyun_waf_00`、`aliyun_waf_bb`、`_waf_bd8ce2ce37`、`sufei-punish`
- 阿里系业务链出现 `refer__1036`、`ssxmod_itna`、`ssxmod_itna2`、`acw_tc`
- 1688 / detail 类处罚链出现 `x5secdata`、`_____tmd_____/punishTextFetch`、`__bx__`

这些特征可能同时出现，也可能只命中其中一条。先用请求链确认当前目标依赖的是 v2 滑块、AWSC/noCaptcha、1036/WAF，还是 x5sec 处罚页，不要只按脚本名猜产品。

## 常见链路

阿里云 v2 滑块常见链路：

```text
请求受保护业务入口或页面
-> 页面返回或内嵌 requestInfo
-> 页面环境按 requestInfo 生成首轮 init query
-> POST captcha-pro-open.aliyuncs.com
-> 响应返回 StaticPath 和初始化状态
-> 按 StaticPath 加载 dynamicJS/sg...js
-> 用初始化响应定位并加载 FeiLin 脚本
-> 浏览器环境执行 sg + FeiLin + 交互事件，产出多段 query
-> POST device.captcha-open.aliyuncs.com 记录 log2
-> POST captcha-pro-open.aliyuncs.com 做 v2 verify
-> 检查 Result，再回到业务请求验证是否放行
```

东航 v2 滑块案例里，`东航v2.py` 的核心顺序是：`req_index_html()` 从 `https://m.ceair.com/m-base/sale/shoppingv2` 提取 `requestInfo`，本地运行 `al_env.js` 得到 init query；`req_one()` 请求 `captcha-pro-open.aliyuncs.com`，按 `StaticPath` 读取 `dynamicJS/sg`，再通过 `feilin_info` 分支拿 FeiLin；最后把 `sg_code`、`feilin_jscode`、初始化响应和浏览器环境拼在一起，按输出行顺序请求 log2 与 verify。

1036 / WAF 业务链常见链路：

```text
业务参数加密为 req
-> 当前 req 参与 1036 环境计算
-> 产出 ssxmod_itna / ssxmod_itna2 / refer__1036
-> 携带 acw_tc、ssxmod cookie 和 refer__1036 请求业务接口
-> 如果返回 HTML/WAF 页，保存当前处罚页并更新算法
-> 重新计算 cookie/param 后再次请求
-> 解密业务 res 并验证业务数据
```

东航案例中，`搜索接口.py` 里的 `AES.js` 只负责 CEAir 业务 `req/res` 的加解密；`1036_env.js` 产出 `ssxmod_itna`、`ssxmod_itna2` 和 `refer__1036`；`shoppingv2` 返回 HTML 时说明 WAF 算法或输入已失效，需要用新的处罚 HTML 更新本地材料。不要把 AES 加密结果误认为验证码通过参数。

## 参数产出方式

阿里系目标不要只收敛到一个“万能 token”。按链路拆稳定入口更容易验证：

- v2 滑块 init：由当前 `requestInfo`、UA/版本、页面环境产出首轮 query
- `StaticPath`：来自当前 init 响应，用于加载当轮 `sg` 动态脚本
- FeiLin URL：由当前 init 响应和页面环境推导，不能长期复用旧文件名
- log2 query：执行 `sg + FeiLin + 交互事件` 后的设备/行为日志请求体
- verify query：最终提交到 `captcha-pro-open.aliyuncs.com` 的校验请求体
- 1036 放行参数：`ssxmod_itna`、`ssxmod_itna2`、`refer__1036`，通常与业务 `req`、会话和 WAF HTML 状态绑定
- 业务加密：站点自己的 `req/res` 加解密，只负责业务接口载荷，不代表验证码或 WAF 已通过

本地入口可以按目标命名为 `get_aliyun_captcha_v2(input)`、`get_aliyun_1036(input)` 或更贴近目标字段的名字，但 `test.py` 必须继续负责真实请求、TLS 指纹、Header、Cookie、动态脚本拉取和业务验证。

## v2 关键字段

阿里云 v2 滑块至少要盯住这些字段和落点：

```text
requestInfo.data              # 原业务 POST 数据，部分场景用于验证通过后的 reform
requestInfo.region            # 区域，常见 cn
requestInfo.sceneId           # 场景 ID，页面 init 时映射为 SceneId
requestInfo.token             # 页面 token，成功回调时映射为 u_atoken
requestInfo.traceid           # TraceID，页面 init 时映射为 UserCertifyId
requestInfo.type              # 验证通过后的业务回跳方式，GET 或 POST
requestInfo.userId            # initAliyunCaptcha 入参 userId
requestInfo.userUserId        # initAliyunCaptcha 入参 userUserId
requestInfo.refer             # 可选，成功后映射为 u_aref
requestInfo.captchaEndpoint   # 可选，覆盖验证码 server endpoint
StaticPath                    # init 响应下发，用来加载 dynamicJS/sg
FeiLin URL                    # 由 init 响应和页面环境推导，用来加载 FeiLin 脚本
log2 query                    # 设备/行为日志，提交到 device.captcha-open.aliyuncs.com
verify query                  # v2 最终校验，提交到 captcha-pro-open.aliyuncs.com
Result                        # verify 响应里的通过状态
u_atoken / u_asig / u_aref    # 页面 success 回调后回写业务 URL 或 form 的参数
```

东航案例里还要记录本地输出行的语义：`output_lines[2]` 被 `req_log2()` 当作 log2 body，`output_lines[4]` 被 `req_v2()` 当作 verify body。这个下标是该工程的本地约定，新目标要以当前 `jscall` 和请求包确认，不要盲套固定下标。

`requestInfo` 是 v2 链路的起点，不是普通静态配置。`sceneId`、`token`、`traceid`、`userId`、`userUserId`、`captchaEndpoint` 这些字段必须来自当前页面返回；`StaticPath`、FeiLin URL、log2 query、verify query 必须来自同一轮 init 和同一会话。跨轮复用会导致 `Result` 失败，或者验证码通过但业务页仍回 WAF/处罚 HTML。

## 常见环境面

阿里 v2/AWSC/noCaptcha 常见会触达这些环境面：

```text
window / self / document / location / navigator / screen / history
navigator.userAgent / appVersion / userAgentData / webdriver
Object.keys / Object.getOwnPropertyNames / Object.getOwnPropertyDescriptor
Function.prototype.toString / native-like constructor 外观
Error.prepareStackTrace / 异常栈 / iframe contentWindow
localStorage / sessionStorage / WAF 相关 storage key
performance.now / timing / getEntries / resource timing
document.createElement / script.src / appendChild / onload
EventTarget / addEventListener / dispatchEvent
MouseEvent / pointer/mouse move-down-up-click 事件序列
canvas 2d / WebGL / ImageData / measureText / toDataURL
AudioContext / OfflineAudioContext
RTCPeerConnection / WebRTC SDP
XMLHttpRequest / fetch / sendBeacon
```

这些值、descriptor、prototype、`toString`、异常栈、资源列表和事件顺序不能靠旧项目硬套。命中新目标时，先用 `jscall` 定位入口、调用栈和请求边界，再从匹配当前目标的 `ruyitrace/`、`domtrace`、`storage`、`http_packet` 里取真实值。

UA 一致性是高频问题。HTTP Header 里的 `User-Agent`、`sec-ch-ua`、`sec-ch-ua-platform`，本地 JS 环境里的 `navigator.userAgent`、`navigator.appVersion`、`navigator.userAgentData`，以及 TLS impersonation 使用的 Chrome 版本要对齐。东航案例使用 `curl_cffi.requests.Session(impersonate='chrome131')`，并把随机 Chrome 版本写入 `al_env.js` 的前置变量；新目标不要只改 Header 而漏掉 JS 环境。

## ruyitrace/jscall 优先动作

命中阿里系验证码 / WAF 后，优先做：

```text
1. 在 jscall、脚本缓存和 http_packet 中搜索 requestInfo、StaticPath、FeiLin、captcha-pro-open.aliyuncs.com、device.captcha-open.aliyuncs.com、dynamicJS、sg.、Result
2. 搜索 AWSC、AWSCInner、AWSCFY、__awsc_et__、__awscnc_wrapper_id__、nocaptcha、nc.js、fireyejs.js、et_f.js、cf.aliyun.com/nocaptcha
3. 搜索 refer__1036、ssxmod_itna、ssxmod_itna2、acw_tc、aliyun_waf、_waf_bd8ce2ce37、x5secdata、punishTextFetch、__bx__
4. 用 http_packet 确认 init、StaticPath 脚本、FeiLin 脚本、log2、verify、业务重试的真实顺序
5. 用 jscall 调用栈确认 requestInfo 从哪里进入算法，以及生成 init/log2/verify query 的函数边界
6. 从 storage/domtrace 确认 localStorage、sessionStorage、script 注入、iframe、MouseEvent、canvas、WebRTC、AudioContext 的真实触达点
7. 用 rtwatch / rt_log 只观察外部宿主对象、方法入参和请求边界
8. 本地 code.js 只产出目标 query/cookie/param，由 test.py 组装真实请求并验证 Result 与业务响应
```

如果目标没有 `ruyitrace/`，但已有可跑通旧工程，只能把旧工程当案例材料：先抽出真实 URL、Header、Cookie、动态脚本版本、输入输出顺序和缺环境点，再回到当前目标重新采集或用当前请求链验证。旧工程里的大面积宿主对象伪装、固定 canvas/audio/WebRTC 值或运行时特性不应直接搬到新目标。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ rtproxy.js 底座与 native toString 保护
├─ 当前目标触达的 BOM/DOM/storage/performance 环境
├─ UA / userAgentData / appVersion / sec-ch-ua 对齐输入
├─ script 注入、iframe、Error.prepareStackTrace、EventTarget/MouseEvent
├─ canvas / WebGL / AudioContext / RTCPeerConnection 等已触达指纹面
├─ 当前目标版本的 sg / FeiLin / AWSC 逻辑
└─ get_aliyun_captcha_v2(input) 或 get_aliyun_1036(input)

test.py
├─ 使用当前目标 trace 的 URL、Header、Cookie、Body 和代理配置
├─ 使用 curl_cffi 或等价 TLS impersonation 保持客户端指纹一致
├─ 请求业务入口并提取 requestInfo 或 WAF HTML
├─ 拉取当轮 StaticPath、sg、FeiLin 动态脚本
├─ 调用 node code.js 产出 init/log2/verify 或 1036 参数
├─ 按真实顺序请求 captcha-pro-open / device / 业务接口
└─ 同时验证 Result、Cookie 状态、业务 JSON 和解密后的业务数据
```

动态 JS 必须按当前响应固定或缓存。`StaticPath`、`sg`、FeiLin、`requestInfo`、WAF HTML 都可能和会话或时间绑定；缓存只用于复现当轮，不是长期稳定算法。

## 案例注意点

东航 v2 滑块案例的关键点：

- 入口业务页是 `https://m.ceair.com/m-base/sale/shoppingv2`
- 先用固定会话材料触发滑块并提取 `requestInfo`
- init 请求发往 `https://979fced494ac3fc62d669d916ca7239b.captcha-pro-open.aliyuncs.com/`
- log2 请求发往 `https://device.captcha-open.aliyuncs.com/`
- verify 请求仍发往 `captcha-pro-open.aliyuncs.com`，成功口径看 JSON 的 `Result`
- `pe_code_list/3.25.1/sg...js` 和 `pe_code_list/feilin/feilin...js` 是当轮动态脚本缓存
- `al_env.js` 里包含 UA、Error stack、EventTarget、MouseEvent、canvas、Audio、WebRTC、performance resource 等环境面
- `搜索接口.py` 里的 AES 加解密、`ssxmod_itna`、`ssxmod_itna2`、`refer__1036` 属于业务 1036/WAF 放行链

1688 / detail 处罚页案例的关键点：

- HTML 内可能有 `<textarea id="renderData">`，其中写入 `_waf_bd8ce2ce37`
- meta 中可见 `aliyun_waf_aa`、`aliyun_waf_oo`、`aliyun_waf_00`、`aliyun_waf_bb`
- 资源链常见 `sufei-punish`、`AWSC/et`、`AWSC/fireyejs`、`AWSC/nc`、`cf.aliyun.com/nocaptcha/initialize.jsonp`
- 处罚链可能请求 `_____tmd_____/punishTextFetch`，并携带 `x5secdata=...__bx__...`
- 该链路与 CEAir v2 滑块不完全相同，但同属阿里系 AWSC/noCaptcha/WAF 观察范围

## 常见坑

- 只看 HTTP 200，不看 `Result` 和业务接口是否真正放行
- 跳过 `device.captcha-open.aliyuncs.com` 的 log2，直接打 verify
- 复用旧 `StaticPath`、旧 `sg`、旧 FeiLin、旧 `requestInfo` 或旧 WAF HTML
- Header 的 Chrome 版本、JS 环境 UA、`sec-ch-ua` 和 TLS impersonation 不一致
- 把业务 AES `req/res` 当作验证码参数，或把验证码 `Result` 当作业务数据成功
- 只改 Cookie，漏掉与当前 `req` 绑定的 `refer__1036`
- 只模拟最终 verify query，不还原 init、动态脚本和事件行为的产出顺序
- 只补 canvas/WebGL，却漏掉 script 注入、iframe、Error stack、MouseEvent、performance entries
- 把旧项目中的全量 BOM/DOM、固定 SDP、固定 canvas/audio 值直接搬到新目标
- 在混淆/VMP/opcode 层插装推进补环境；补环境只围绕外部宿主对象、方法入参和请求边界

## 验证口径

阿里 v2 滑块至少同时满足：

```text
captcha-pro-open init 正常返回 StaticPath
sg 与 FeiLin 是当前 init 响应对应的动态脚本
device log2 已按真实顺序提交
verify 返回 JSON，Result 表示通过
回到业务接口后不再返回 WAF/处罚 HTML
业务响应字段、解密后的 res 或目标数据符合预期
```

1036/WAF 至少同时满足：

```text
ssxmod_itna / ssxmod_itna2 / refer__1036 与当前业务 req 同步生成
acw_tc、业务 Cookie、Header、TLS 指纹与当前会话一致
业务接口返回 JSON 而不是 HTML/WAF 页
加密业务响应能正常解密
业务状态码、msg、data 符合目标接口预期
```

任何一个条件不满足，都不要把本地环境视为完成。先回到 `jscall`、`http_packet`、`storage`、`domtrace` 和本地 `rtwatch` 日志确认差异点。
