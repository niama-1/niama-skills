# Cloudflare 5s / WAF Challenge 参考文档

本文用于识别和处理 Cloudflare 5s / WAF Challenge / Challenge Page 链路，重点覆盖 `_cf_chl_opt`、`/cdn-cgi/challenge-platform/h/...`、`chl_page/v1`、`flow/ov1`、内部 Turnstile、`cf-chl`、`__cf_chl_tk`、`cf_clearance`、环境检测面和最终业务回打。

它是产品经验参考，不是算法说明，也不能替代当前目标实测。命中 Cloudflare 后，所有准备写入 `code.js` / `runtime/*.code.js` 的环境值、descriptor、prototype、native `toString`、异常栈和请求边界，都必须回到当前目标的 `ruyitrace/`、`jscall`、HTTP 包和真实业务验证确认。

## 命中特征

出现以下特征时，优先按 Cloudflare 5s / WAF Challenge 分析：

- 初始业务页出现 `Just a moment...`、`Checking if the site connection is secure`、`Verifying you are human` 或 Cloudflare challenge HTML。
- HTML 内联 `_cf_chl_opt`，字段常见 `cvId`、`cZone`、`cType`、`cRay`、`cH`、`cUPMDTk`、`cFPWv`、`cITimeS`、`cTplC`、`cTplV`、`cTplB`、`fa`、`md`、`mdrd`。
- 请求链出现 `/cdn-cgi/challenge-platform/h/{branch}/orchestrate/chl_page/v1?ray=...`。
- 请求链出现 `/cdn-cgi/challenge-platform/h/{branch}/flow/ov1.../{cRay}/{cH}`。
- POST header 出现 `cf-chl`、`cf-chl-ra`，响应或 cookie 出现 `cf_clearance`。
- `_cf_chl_opt.cUPMDTk` 或 URL 中出现 `__cf_chl_tk`。
- 页面或子链加载 `https://challenges.cloudflare.com/cdn-cgi/challenge-platform/.../turnstile/...`。
- Turnstile iframe / runtime 中出现 `sitekey`、`chlPageData`、`page_data`、`cData`、`action`。
- 业务响应头出现 `cf-mitigated: challenge`、`server: cloudflare`，或失败时一直回到 challenge 页。

只看到 Cloudflare CDN 响应头不等于命中 5s。必须出现 challenge page、`_cf_chl_opt`、`flow/ov1`、Turnstile 子链或 `cf_clearance` 这类链路证据。

## 标准链路

典型 WAF / 5s 链路：

```text
业务 URL
-> Cloudflare Challenge HTML，内含 _cf_chl_opt
-> GET /cdn-cgi/challenge-platform/h/{branch}/orchestrate/chl_page/v1?ray={cRay}
-> 反混淆/解析当前版本 orchestrate，得到 init payload 动态 key 和压缩字符集
-> POST /cdn-cgi/challenge-platform/h/{branch}/flow/ov1.../{cRay}/{cH}
-> 返回 main VM / challenge runtime
-> 从 main VM 提取内部 Turnstile sitekey、page_data、token 字段名
-> 进入内部 Turnstile token 子链，action 通常取 cType，cData 通常取 cRay
-> 组装 WAF final payload，带 Turnstile token、__cf_chl_tk、md、time、环境 entry
-> POST 同类 flow 路径
-> Set-Cookie: cf_clearance=...
-> 使用同 UA、同代理、同 header/TLS 指纹回打原业务 URL
```

`cf_clearance` 只是 challenge 阶段成功。最终结论必须看原业务 URL 或原业务接口是否返回真实业务内容，不再返回 challenge / block。

## 必须固定的目标信息

命中后先在 `param_info.md` 和进展清单记录：

```text
原始业务 URL
origin / host / path
首次 challenge HTML 文件或 http_packet 位置
_cf_chl_opt 原始对象
branch / version / cRay / cH
orchestrate chl_page/v1 URL、状态码、响应长度、Content-Encoding
flow/ov1 init URL、POST header、body 长度、响应长度
内部 Turnstile sitekey、page_data、action、cData
WAF final URL、POST header、body 长度、响应 Set-Cookie
cf_clearance 的 Domain/Path/Max-Age/SameSite/Secure
最终业务回打 URL、状态码、block marker、业务成功 marker
```

这些可以固定为目标上下文：业务 URL、`cZone`、当前 HTML 中的 `_cf_chl_opt` 字段、当前 orchestrate 资源、当前版本的动态 key 映射、内部 Turnstile 的 sitekey/page_data 提取位置。

这些必须当轮动态生成或当轮确认：`cRay`、`cH`、`__cf_chl_tk`、flow body、Turnstile token、payload 中的时间/性能/环境 entry、`cf_clearance`。

## `_cf_chl_opt` 重点字段

WAF / 5s 页面常见字段：

| 字段 | 含义与补环境用途 |
|---|---|
| `cvId` | challenge 版本/会话标识，进入 init/final payload |
| `cZone` | zone / host，上下文和 Turnstile origin 绑定 |
| `cType` | challenge 类型，常用于内部 Turnstile `action` |
| `cRay` | 当前挑战主 ID，请求路径、解密、POW、cData 都可能依赖 |
| `cH` | flow path 和 `cf-chl` header 关键值 |
| `cUPMDTk` | 内含 `__cf_chl_tk`，WAF final payload 必须处理 |
| `cFPWv` | challenge 参数/版本线索 |
| `cITimeS` | challenge 时间字段，进入 payload |
| `cTplC` / `cTplV` / `cTplB` | 模板计数、版本和分支线索 |
| `fa` | 页面特征字段 |
| `md` / `mdrd` | WAF init/final payload 必填上下文 |

不要把 `_cf_chl_opt` 的字段位置写死成通用协议。不同 Cloudflare 版本里字段顺序、包装方式和动态 key 都可能变化。

## Turnstile 子链

WAF 5s 里经常不是单独拿 Turnstile token，而是 WAF 主链内部拉起 Turnstile：

```text
WAF main VM
-> 提取 sitekey
-> 提取 page_data / chlPageData
-> action = cType
-> cData = cRay
-> 运行 Turnstile init / second payload
-> 得到 token
-> 写入 WAF final payload 的动态 token 字段
```

需要区分三种成功口径：

```text
Turnstile token issued
= final VM 提取到以 0. 或 1. 开头的 token

WAF clearance issued
= WAF final 响应 Set-Cookie 出现 cf_clearance

business accepted
= 同轮 cf_clearance、同 UA、同代理、同 header/TLS 指纹回打原业务 URL 成功
```

`600010` 一类返回通常表示 Turnstile / challenge 被标记，不要误判为 token。

## 环境检测面

Cloudflare 5s 的环境面通常来自 VM entry，不要一次泛补整套浏览器。优先按当前 VM 实际命中的 entry 补：

- UA / headers / UA-CH：`User-Agent`、`navigator.userAgent`、`navigator.userAgentData`、`sec-ch-ua*` 必须一致。
- `navigator` 基础：`platform`、`languages`、`hardwareConcurrency`、`deviceMemory`、`webdriver`、plugins、mimeTypes。
- `Intl` 与语言：`Intl.DateTimeFormat`、`Intl.ListFormat`、`Intl.NumberFormat`、`Intl.DisplayNames` 的 locale 输出。
- DOM 基础：`window`、`document`、`location`、`history`、`URL`、`URLSearchParams`、script/iframe 创建。
- DOM layout / CSSOM：`querySelector`、`getComputedStyle`、styleSheets、`getBoundingClientRect()`、ShadowRoot / iframe realm。
- Worker 通信：`Worker`、`Blob`、`URL.createObjectURL`、`postMessage`、MessageEvent、worker 内 `performance.now()`。
- Performance：`performance.now()`、`getEntriesByType()`、navigation/paint/resource/mark、`performance.memory`。
- Canvas / WebGL / WebGPU：canvas context、`WEBGL_debug_renderer_info`、extensions、`getParameter`、`readPixels`、`toDataURL`、`navigator.gpu` 外观。
- Audio / WebRTC / Speech / Font：OfflineAudioContext、RTCPeerConnection/SDP/candidate、speechSynthesis、FontFace、document.fonts。
- 自动化与篡改：Function native `toString`、descriptor、constructor/prototype、Error.stack、getter stack、console 方法、Selenium/WebDriver 痕迹。
- POW / 点击分支：MouseEvent/PointerEvent 字段、`isTrusted` 外观、target/activeElement、click trace 形态、POW hash 输入。

补环境顺序建议：

```text
1. UA、headers、UA-CH、language、platform 一致
2. Challenge HTML 所需 DOM/BOM 基础
3. iframe / Worker / Blob / object URL / postMessage
4. navigator 基础字段
5. Intl 和 timezone
6. DOM layout / CSSOM
7. performance entries / memory / timing
8. Canvas / WebGL / Audio / WebRTC / Speech / Font
9. native toString / descriptor / Error.stack / console / plugins
10. managed/interactive 分支需要的 click / PointerEvent / POWClick
```

## 可反推环境值索引

以下值来自一个历史 Cloudflare Rust solver 的 `cloudflare_env.json`、`build_fingerprint()` 和 `entries/*`，只能作为补环境候选基线。写入当前项目之前，必须用当前目标 trace 校准。

| 环境面 | 候选值或形态 |
|---|---|
| UA | `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36` |
| 浏览器 / OS | Chrome 144，macOS，`navigator.platform=MacIntel` |
| CPU / 内存 | `deviceMemory=8`；`hardwareConcurrency` 样本存在 `20` 与 `6` 两套值，必须实测定值 |
| language | `navigator.language=zh-CN`，`navigator.languages=["zh-CN","zh"]`，`Accept-Language=zh-CN,zh;q=0.9` |
| UA-CH | `platform=macOS`，`platformVersion=26.2.0`，`architecture=arm`，`bitness=64`，`mobile=false`，`model=""` |
| Battery | `charging=true`，`level=1`，`chargingTime=0`，`dischargingTime=-1` |
| matchMedia | dark / forced-colors / reduced-motion / inverted-colors / reduced-data / reduced-transparency 均为 false |
| Intl | `十二月 中国标准时间`、`世界语（乌克兰）`、`Bippity-boppity、Mumbo-jumbo或hocuspocus`、`21,000万亿` |
| WebGL masked | vendor=`WebKit`，renderer=`WebKit WebGL` |
| WebGL unmasked | vendor=`Google Inc. (Apple)`，renderer=`ANGLE (Apple, ANGLE Metal Renderer: Apple M1 Pro, Unspecified Version)` |
| WebGPU | `navigator_gpu_data=null`，是否表现为缺失或 null 需按当前浏览器证据确认 |
| WebGL limits | max texture / cube map 常见 16384，renderbuffer 2048，vertex attribs 16，且扩展列表含 `WEBGL_debug_renderer_info` |
| DOM rect | 会读取多组 `{bottom,height,left,right,top,width,x,y}`；数值随环境变，不可死抄 |
| querySelector | 会形成 `#id` 查询列表，历史样本还追加过 `#undefined` |
| CSS image | 会构造 challenge platform 下的 `/cmg/1` 背景图 URL |
| Selenium / DOM attrs | 关注 `html/body lang`、`app-root`、`app-cloudflare-captcha-container` 等属性和 HTML comments |
| Tampering | 检查 getter `name/message/stack`、console 方法、`toString`、`configurable`、PluginArray/MimeTypeArray |
| Performance | navigation、first-paint、first-contentful-paint、resource、mark，mark 名可能含 `cRay` |
| Worker timing | 历史样本有 `0.09999990463256836` 这类 worker timing 字符串 |
| Worker blob | `blob:https://{zone}/{uuid}` 或 `blob:{origin}{uuid}` 形态 |
| Audio / WebGL hash | 历史实现会随机生成 hash，说明只应对齐长度、字段集合和类型，不应固定旧值 |
| WebRTC | audio/video codec、host candidate、SDP、mDNS `.local` host、network-cost 等形态 |
| Error / eval stack | 栈中 URL 常指向 `https://challenges.cloudflare.com/...` 或当前 solve URL，函数名和行列号外观要像浏览器 |
| POW | 输入形态常含 `{cRay}|{performance.now 或 timestamp}|{difficulty}|{nonce}` |
| Click event | `pointerType=mouse`、`isTrusted=true`、`pressure=0`、target/activeElement、坐标和 trace 数组 |

这些值能帮助反推“该补哪些环境面”和“形态大概是什么”，但不是跨站、跨版本、跨 UA 的通用真值。

## 请求与传输层

Cloudflare 对 JS 环境、HTTP headers、TLS/HTTP 指纹、代理、Cookie 会话一致性都敏感：

- `User-Agent`、`sec-ch-ua*`、`Accept-Language`、JS 中的 UA/UA-CH/language 必须一致。
- Challenge、Turnstile 和最终业务回打必须使用同代理或同出口 IP，不要中途切换。
- `cf_clearance` 对 UA、IP、TLS/HTTP 指纹和 cookie scope 敏感，不能只复制 cookie 到另一个客户端就断言可用。
- GET HTML、GET orchestrate、POST flow 的 header 集合和顺序要参考真实浏览器包。
- POST flow 常见 `Content-Type: text/plain;charset=UTF-8`、`Origin`、`Referer`、`cf-chl`、`cf-chl-ra`。
- 响应可能有 gzip / deflate / br / zstd，读取 VM 或 JS 前先确认解压正确。

## 常见坑

- 只拿到 `cf_clearance` 不等于业务通过，必须回打原业务 URL。
- 只完成内部 Turnstile token 不等于 WAF 通过，WAF final 仍可能失败。
- `__cf_chl_tk` 往往来自 `cUPMDTk`，不要当成独立固定配置。
- WAF final 中某些数组不能直接照搬内部 Turnstile payload。历史样本中 cookie 名数组应为空数组，复制内部 Turnstile cookie 名会导致失败。
- 动态 key 名、payload key、orchestrate 字符集、flow path 都是版本相关，不要跨版本写死。
- `hardwareConcurrency`、DOM rect、WebGL/Audio/computed style hash、performance timing、click trace 都需要当前 trace 校准。
- 不要为了匹配 trace 卡顿强行拉长 timer、`performance.now()` 或事件间隔；trace 时间通常只能作为阶段顺序证据。
- 不要在 VM / opcode handler 内插装推进补环境。只从 DOM/BOM 宿主对象、请求边界、v8trace 事实吐出、ruyitrace 回证和业务差异推进。

## 记录要求

命中本产品后，进展清单至少写明：

```text
命中特征：哪些 URL / header / cookie / 字段证明是 Cloudflare 5s
读取文档：references/products/cloudflare_5s.md
当前阶段：challenge HTML / orchestrate / init flow / Turnstile / final flow / business retry
必须处理参数：_cf_chl_opt、flow URL、Turnstile sitekey/page_data、__cf_chl_tk、cf_clearance
已确认环境面：当前 VM 实际命中的 entries
待回证环境面：准备写入 code.js 但尚未由 trace 确认的值
最终口径：cf_clearance issued / business accepted
```
