# 瑞数 RS6 参考文档

本文用于识别和处理瑞数 RS6 / RuiShu 类动态防护链路。RS6 常见形态不是单纯业务签名，而是页面 challenge、长 cookie、行为/环境采集和业务请求动态后缀共同组成的混合链。

本文是产品专项经验参考，不替代当前目标实测。任何补入 `code.js` / `runtime/*.code.js` 的 DOM/BOM 值、环境外观、事件顺序、cookie 名和值、动态参数、Header、URL 和请求体，都必须来自当前目标的 `jscall`、`http_packet`、`cookie/event/domtrace/descriptor` 或匹配当前目标的 `ruyitrace/` 证据。

## 命中特征

出现以下特征时，优先按 RS6 链路分析：

- 页面首屏或业务页返回 challenge HTML，包含动态 `meta content`、内联 `script` 和外链自动化 JS
- 页面或脚本出现 `$_ts`、`$_ts.nsd`、`$_ts.cd`、`$_ts.lcd`
- 脚本通过 `document.cookie` 写入长 cookie，cookie 名和值每站点或每轮可能变化
- 业务接口需要额外动态 query 参数，且参数由 JS 请求边界或 XHR/fetch 包装生成
- 运行链触达 `XMLHttpRequest.open`、`fetch`、`sendBeacon` 或等价请求边界，用来推导请求后缀或校验状态
- 脚本注册或采集 `mousemove`、`scroll`、`mousedown`、`mouseup`、`mouseenter`、`mouseleave`、`click` 等行为事件
- 同一流程出现两阶段或多阶段 challenge：入口页先下发 cookie，业务页再下发 cookie 或业务请求动态参数
- API 请求前需要刷新 challenge cookie，否则同样的业务 URL 会失败、返回空数据、重定向或重新进入 challenge

当前样本中的强证据：

```text
站点: https://ganghang.gdtspace.com/
业务页: https://ganghang.gdtspace.com/ContainerQuery
业务 API: https://ganghang.gdtspace.com/ghzh/api/Container/111/A
动态 query: fr8o9lcS
样本 cookie 名: 2aCTSJaVda98P
样本 meta id: 7tsNdbbO0cdZ
样本 cookie 值长度: 471 / 492 左右
```

这些样本值只能作为命中特征和对照证据，不允许写死成通用规则。新目标必须重新确认 cookie 名、meta 位置、脚本位置、cookie 长度、动态参数名和请求链顺序。

## 目标类型判定

阶段 0-3 先判断当前任务目标：

```text
只恢复业务动态 query / 请求后缀
= signature，但必须保留前置 RS cookie challenge

恢复 cookie challenge + 业务动态 query
= hybrid

从入口页、业务页、cookie 刷新一路跑到最终业务 API
= full_flow

只处理入口页能否放行，尚未进入业务接口
= captcha/challenge 类前置防护，不要误判为最终业务成功
```

RS6 任务很容易被误判为“只有一个签名参数”。如果业务 API 前仍需要刷新 cookie，或者动态 query 与 cookie 必须同轮生成，应按 `hybrid` 或 `full_flow` 推进。

## 当前样本字段表

以下字段来自 `rs_cnsha_20251119` 样本，仅用于说明分析粒度：

```text
meta_content
= 页面 meta content。入口页样本取 meta[2]，业务页样本取 meta[6]。
  新目标不要固定 XPath，必须按当前 HTML 和 trace 定位。

ts_js
= 页面内联 script。样本取 script[1].text。

auto_js
= 页面外链自动化 JS。样本取 script[2].src 后请求完整 JS。

rs_cookie
= challenge JS 通过 document.cookie 写入的长 cookie。
  样本 cookie 名为 2aCTSJaVda98P，值长度约 471 / 492。

fr8o9lcS
= 当前样本业务 API 动态 query 参数。
  由 get_hz(method, url + query) 触发 XHR.open 后取得。

method
= 业务请求方法。必须作为动态参数生成输入的一部分。

full_url_with_query
= 完整业务 URL，包含 path 和原始 query。
  不能只传 path，也不能漏掉业务查询参数。

session_cookie
= 登录态或业务会话 cookie，例如当前样本中的 gdtspace6、loginuserkey_2024 等。
  这些属于业务会话，不是 RS6 通用字段。
```

## 当前样本请求链

样本表现为入口页 challenge、业务页 challenge、业务 API 前刷新 cookie 三段：

```text
GET https://ganghang.gdtspace.com/
→ 解析 meta content
→ 解析内联 ts_js
→ 拉取外链 auto_js
→ 使用首阶段 challenge 模板执行 JS
→ get_cookie()
→ 写入生成的 RS cookie

GET https://ganghang.gdtspace.com/ContainerQuery
→ 解析 meta content
→ 解析内联 ts_js
→ 拉取外链 auto_js
→ 使用 RS6 业务页模板执行 JS
→ get_cookie()
→ 写入新的 RS cookie

每次业务 API 请求前
→ update_cookie2() 重新生成 challenge cookie
→ get_hz(method, full_url_with_query)
→ 生成动态 query 参数 fr8o9lcS
→ 用同一 session / cookie jar 请求真实业务 API
```

当前样本业务 API 示例：

```text
GET https://ganghang.gdtspace.com/ghzh/api/Container/111/A?fr8o9lcS=<hz>
```

后续同类 API 也要用完整 URL 参与 `get_hz`：

```text
/ghzh/api/CntrHistory/<containerNo>
/ghzh/api/ContainerDetail/<id>
/ghzh/api/ContainerGoodsDetail/<id>
/ghzh/api/ContainerPlanDetail/<id>
/ghzh/api/ContainerHistoryList/<containerNo>
/ghzh/api/ScheduleRCV?Vname=...&Voyage=...&Terid=...&Gzfg=...
```

## 网上房地产 fangdi.com.cn 成功细节

`www.fangdi.com.cn` 的成功链路已经验证过以下关键点。它们属于 RS6 外围宿主面和真实请求链细节，Node 补环境必须按同样语义补齐。

```text
目标 Cookie: UA1L1zGonajvO / UA1L1zGonajvP / enable_UA1L1zGonajv
目标后缀: XJlCTRRM
目标接口: POST /service/freshHouse/getHosueList.action?XJlCTRRM=...
成功口径: HTTP 200 且响应 JSON 包含 htmlView，不是 challenge、400 空体或重定向
```

已验证的放行顺序：

```text
GET 列表页或入口页拿 412 challenge
→ 解析当前轮 r='m' meta content、内联 $_ts.cd、外链 /jhKGIvczkKbR/*.0515a6f.js
→ 本地只执行 challenge cookie 阶段，先不要触发业务 XHR 后缀
→ 合并 JS 写入的 UA1L1zGonajvP 与服务端 UA1L1zGonajvO
→ GET /index.html 建立站点会话与 JSESSIONID 等业务 cookie
→ GET /new_house/new_house_list.html?... 获取正常列表 HTML
→ API 前用同一页面 HTML、当前轮静态脚本、同一 cookie jar 生成 XJlCTRRM
→ POST getHosueList.action?XJlCTRRM=...，body 带 currentPage
```

已验证的宿主面关键差异：

- `window.ActiveXObject` 必须是“属性存在但值为 `undefined`”。不要简单删除该属性；RS6 会区分 `"ActiveXObject" in window` 与直接取值。
- 动态 meta content 不只通过 `document.getElementById(...).content` 参与，也可能通过 `window.dolphinmeta` 读取；本地应把当前轮 `r='m'` meta `content` 同步到 `window.dolphinmeta`。
- `document.currentScript.src` 必须跟随当前轮外链脚本，不得硬编码旧的 `jNafbsZdWo4R` 或其它历史路径；实时变体可能是 `8WwVutQAyu6q` 等。
- HTML 中 IE 条件注释脚本在 Firefox/Gecko 下不会执行；本地解析 `r='m'` 脚本顺序时要先剔除 legacy conditional comments。
- 首跳 challenge 阶段只用于生成 cookie，不能提前触发业务 `XMLHttpRequest.open` 后缀；否则可能污染同轮状态。
- 请求层优先使用 Firefox/Gecko 一致的 TLS/HTTP 指纹；在 Python 中可用 `curl_cffi` Firefox impersonation，普通 `requests` 仅作为兜底。
- 真实会话里 `/index.html` 不是可省略步骤：成功样本中它负责建立后续列表页需要的站点会话 cookie。只拿到 `P` 后直接重试原 URL，常见结果是 `400` 空体。

RS6 meta 闭环规则：

```text
发现 document.getElementById(meta_id) / querySelector / getElementsByTagName 返回 HTMLMetaElement 后，不得只补“能返回 meta 对象”。
必须继续追踪该 HTMLMetaElement 后续读取点：
  - content / getAttribute("content")
  - getAttribute("r") 是否为 "m"
  - parentNode / removeChild / appendChild 等 DOM 父子关系
  - currentScript.src 是否对应当前轮外链脚本
  - window/global 别名读取，例如 fangdi 样本中的 window.dolphinmeta
```

完成标准以 `code.js` / `runtime/*.code.js` 的实际实现为准：上述 trace 下游读取点必须有对应环境实现，且返回值与当前轮 HTML / trace 语义一致。`rt_log`、结构化导出或请求边界捕获只能证明本地链路是否覆盖到该点，不能替代实现检查。

失败判定：

```text
P cookie 长度接近但 /index.html 或列表页仍 400
→ 优先检查 ActiveXObject、dolphinmeta、currentScript.src、首跳是否 skip XHR、是否先访问 /index.html、是否使用 Firefox 指纹。

XJlCTRRM 能生成但业务 POST 失败
→ 先确认 XJlCTRRM 与 UA1L1zGonajvP 是否同一轮，Referer 是否是当前列表页，Cookie jar 是否包含 /index.html 建立的 JSESSIONID 和业务 cookie。
```

## JS 入口与请求边界

RS6 目标通常不一定存在干净的普通函数直出。优先围绕请求边界确认参数产出：

```text
document.cookie setter
XMLHttpRequest.prototype.open
XMLHttpRequest.prototype.send
fetch
sendBeacon
$_ts.lcd
事件 addEventListener / dispatchEvent
```

当前样本里的稳定入口形状：

```js
get_cookie()
// 返回 document.cookie 中的 RS challenge cookie

get_hz(type, url)
// 创建 XMLHttpRequest
// 调用 xhr.open(type, url, true)
// 从 XHR.open 包装中取出动态后缀
```

如果动态参数只在 XHR/fetch 边界出现，不要强行寻找单独返回参数的内部函数。可以在 `code.js` 中保留最小请求边界包装，让目标 JS 自己走到边界，再返回完整动态 query 或请求片段。

## 行为事件与轨迹

RS6 常见会收集或依赖行为事件。当前样本中可见事件列表包括：

```text
mousemove
scroll
mousedown
mouseup
mouseenter
mouseleave
click
```

处理原则：

- 先用 `event` 分区和 `jscall` 确认真实浏览器注册了哪些事件、触发顺序如何、是否进入目标参数链
- 如果本地通过 synthetic event 推进，事件对象字段、坐标、时间、`isTrusted` 外观、target/view/path 等必须按当前 trace 对齐
- 轨迹、事件数量、时间节奏可能影响 cookie、行为证明或动态参数长度，但不是每个 RS6 目标都一定影响
- 若浏览器样本和本地样本的 cookie 长度、动态参数长度、编码后证明长度明显不一致，应把事件轨迹差异列为重点排查项

不要把“当前样本能用随机事件跑通”当成通用规则。新目标必须以当前 trace 判断事件是否参与校验。

## ruyitrace/jscall 优先动作

命中 RS6 后，优先做：

```text
1. 用 index.jsonl / *.http_packet.json 定位入口页、业务页、外链 JS、业务 API、重定向和拦截响应
2. 用 jscall 搜索 $_ts、nsd、cd、lcd、document.cookie、XMLHttpRequest.open、fetch、fr8o9lcS 或当前动态参数名
3. 用 jscall 调用栈确认 cookie 写入点、动态参数生成边界、目标 JS 来源和入参
4. 用 cookie 分区确认 cookie 名、值长度、Domain、Path、SameSite、刷新时机和同轮关系
5. 用 event 分区确认事件注册、触发顺序、事件对象字段和是否进入目标链
6. 用 domtrace / descriptor 确认 document、location、navigator、screen、history、performance 等真实外观
7. 用 storage 分区确认 localStorage / sessionStorage 是否参与 challenge 状态
8. 用 eval 分区确认动态 JS 片段来源和执行时机
9. 若出现 wasm，只读取外围加载关系、导出名、请求边界和环境读取证据
10. 回到 code.js / runtime 只补当前链路实际触达的 DOM/BOM 和请求边界
```

严格禁止在 VMP / VM 解释器 / opcode handler / 字节码分发层内部插桩、下探针、改写执行语义或把内部 tracer 沉淀到 `code.js`。遇到混淆执行器时，回到外部 DOM/BOM、事件、cookie 和请求边界证据推进。

## 本地落地建议

单目标可以继续使用 `code.js`：

```text
code.js
├─ rtproxy.js 底座
├─ 当前目标实际触达的 DOM/BOM 环境
├─ 当前页面 meta_content / auto_js / ts_js 注入点
├─ document.cookie / XHR/fetch 最小边界
├─ get_cookie(input)
└─ get_rs6_query(input) 或 get_fr8o9lcS(input)
```

多阶段或多参数建议拆成 `runtime/*.code.js`：

```text
runtime/rs6_entry_cookie.code.js
= 入口页 challenge cookie

runtime/rs6_page_cookie.code.js
= 业务页 challenge cookie

runtime/rs6_request_suffix.code.js
= 业务 API 动态 query / 请求后缀
```

`test.py` 统一负责：

- 建立真实 HTTP session 和 cookie jar
- 请求入口页、业务页和外链 JS
- 解析当前轮 `meta_content`、`ts_js`、`auto_js`
- 调用 Node / execjs 执行 `code.js` 或 `runtime/*.code.js`
- 合并服务端 cookie 和 JS 生成 cookie
- API 前刷新 RS cookie
- 用完整 method + URL + query 生成动态参数
- 发送业务请求并验证最终业务响应

不要把真实请求、代理、登录态 cookie、Header 顺序和业务接口验证塞进 `code.js`。`code.js` 只负责 JS 运行时和参数产出，真实网络链路由 `test.py` 编排。

## 验证重点

最终验证不只看 cookie 或动态参数是否生成，还要看业务接口是否真正放行：

```text
1. 入口页能解析出当前 meta_content / ts_js / auto_js。
2. 首阶段 get_cookie() 能生成当前轮 RS cookie。
3. 业务页能解析出第二阶段 meta_content / ts_js / auto_js。
4. 第二阶段 get_cookie() 能生成业务页 RS cookie。
5. API 前 update_cookie2() 能刷新同轮 RS cookie。
6. get_hz(method, full_url_with_query) 能生成动态 query。
7. 业务请求使用同一个 session / cookie jar。
8. 业务响应是正常业务 JSON / 页面内容，不是 challenge HTML、空数据、重定向或风控错误。
9. 多轮重新拉页面、重新拉 auto_js 后仍能稳定复现。
10. 对多个业务 API 测试时，每个 API 都用自己的完整 URL 和原始 query 生成动态后缀。
```

如果只复现了样本固定 cookie 或固定 `fr8o9lcS`，不能视为完成。

## 失败排查

常见失败和优先排查方向：

```text
业务页仍返回 challenge
→ 入口页 cookie 没写入、Domain/Path 不对、cookie jar 没合并、首阶段不是当前轮。

业务 API 返回空数据 / 拦截结构 / 重定向
→ 漏跑业务页第二阶段 challenge，或 API 前没有刷新 RS cookie。

动态 query 生成但接口失败
→ get_hz 输入 URL 不完整，漏掉 method、原始 query、Referer 对应页面或同轮 cookie。

本地 cookie 长度和浏览器样本差异大
→ 检查 meta_content、auto_js、ts_js 是否当前轮，事件/环境/timing 是否进入链路。

同一个参数偶尔成功偶尔失败
→ 检查 cookie、动态 query、session、IP/TLS、时间戳是否同轮，是否复用旧 JS 或旧 cookie。

入口页成功但后续 API 失败
→ 不要继续补入口页，先确认业务页 challenge 和 API 前刷新逻辑。
```

## 常见错误

- 把 RS6 当成普通签名，只恢复动态 query，漏掉 challenge cookie
- 只跑入口页 challenge，漏掉业务页第二阶段 challenge
- 固定旧 `$_ts.cd`、旧 meta content、旧 auto_js、旧 cookie 名或旧 cookie 值
- 把当前样本的 `2aCTSJaVda98P`、`7tsNdbbO0cdZ`、`fr8o9lcS` 写成通用字段
- API 前不刷新 cookie，导致动态参数和 cookie 不同轮
- `get_hz()` 只传 path，不传完整 URL 和原始 query
- 多个业务 API 共用一个旧后缀
- 用浏览器现场先消费 cookie / 参数，再拿到本地重放
- 轨迹长度、事件顺序、编码后长度差异明显时仍只排查坐标或签名
- 忽略业务登录态 cookie，把会话失败误判成 RS6 失败
- 对 VMP / VM / opcode / handler 层做插桩、下探针或语义改写

## 交付记录要求

命中 RS6 链路时，进展清单或阶段输出必须记录：

- 命中特征和读取的产品文档：`references/products/rs6.md`
- 当前目标类型：`signature` / `hybrid` / `full_flow` / `unknown`
- 入口页 URL、业务页 URL、业务 API URL
- 当前轮 `meta_content`、`ts_js`、`auto_js` 的来源位置
- 写入的 RS cookie 名、长度、Domain/Path、刷新阶段
- 动态 query 参数名、生成入口、输入 method 和完整 URL
- 是否存在两阶段或多阶段 challenge
- 行为事件是否参与，事件类型、数量、顺序和证据来源
- `code.js` / `runtime/*.code.js` 的稳定入口和输入输出
- `test.py` 的请求链、cookie 合并方式和最终业务响应
- 哪些值是当前样本固定对照，哪些已实现为当前轮动态获取
