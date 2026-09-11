# DY a_bogus 参考文档

本文用于识别和处理 DY / ByteDance Web 体系中常见的 `a_bogus` 补参链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

## 命中特征

出现以下特征时，可优先按 DY / ByteDance Web 安全链路分析：

- 目标参数为 `a_bogus`
- 目标接口路径常见于 `/aweme/v1/`、`/aweme/v2/`、`/webcast/` 等路径
- 页面或运行链中出现 `webmssdk`、`sdk-glue`、`bdms`、`SecureSDK`、`web_protect`
- 初始化链中出现 `_SdkGlueInit(...)`、`window.byted_acrawler.init(...)`、`window.bdms.init(...)`
- 目标请求最终被追加 `a_bogus`、`msToken`、`verifyFp`、`fp`
- `URLSearchParams.has/append/set` 能观察到 `a_bogus`、`msToken`、`verifyFp`、`fp`
- 业务代码里找不到直接返回 `a_bogus` 的函数，但请求发出前 URL 被安全链改写

注意：`a_bogus` 不等同于 `X-Bogus`。如果页面存在 `frontierSign -> X-Bogus`，只能说明存在相关签名能力，不能直接推断它就是当前接口的 `a_bogus` 生成逻辑。

## 常见链路

典型链路是：

```text
业务请求入口
→ 统一请求包装器
→ SecureSDK / web_protect 判断是否需要保护
→ sdk-glue 接管 fetch / XHR
→ bdms 或相关运行时执行补参
→ URLSearchParams.append("a_bogus", value)
→ fetch / XHR 发出最终请求
```

业务入口通常只负责组装业务参数，例如 `item_id`、`comment_id`、`cursor`、`count` 等。`a_bogus` 往往不是在业务入口生成，而是在请求出口或安全 SDK 包装层追加。

## 常见脚本角色

```text
webmssdk / byted_acrawler
= 安全运行时基础能力，可能负责 init、状态维护、token、webid、ttwid、referer 或签名上下文

sdk-glue
= 请求接管和调度层，常见职责是 blockFetch / blockXhr、路径匹配、加载 bdms 或安全 SDK

bdms
= 常见补参执行层，可能检查 URL 参数并追加 msToken / a_bogus / verifyFp / fp

SecureSDK / web_protect
= 更上游的保护策略层，可能决定哪些路径需要进入安全链

runtime bundle / async chunk
= 真实调度逻辑或 VM 逻辑可能隐藏在运行时包或异步 chunk 中

业务 client-entry
= 业务参数组装层，不应默认认为它直接生成 a_bogus
```

## 参数产出方式

`a_bogus` 常见产出方式是“请求边界产出”，不是普通函数直出。

优先确认：

- `a_bogus` 最终出现在哪里：URL Query、Header、Body、Cookie
- 是谁执行了 `append/set`
- 追加前是否检查了 `has("a_bogus")` 或 `has("msToken")`
- `msToken`、`verifyFp`、`fp` 是否与 `a_bogus` 同时被追加或参与计算
- 同一页面不同请求的 `a_bogus` 是否不同
- 参数是否依赖当前完整 query、referer、webid、ttwid、uifid、浏览器环境或事件状态

优先观察点：

```text
URLSearchParams.prototype.has
URLSearchParams.prototype.append
URLSearchParams.prototype.set
URLSearchParams.prototype.delete
fetch
XMLHttpRequest.open / send / setRequestHeader
```

观察时记录：

```text
参数名
参数值
调用栈
append/set 前后的 URL
最终发出的请求 URL
请求前后的 Cookie / Storage 变化
```

## 常见环境面

DY / ByteDance Web 安全链常见会触达这些环境面：

```text
navigator.language
navigator.languages
navigator.userAgent
navigator.platform
screen.width / screen.height
window.innerWidth / innerHeight
document.referrer
location.href
document.cookie
localStorage / sessionStorage
performance
crypto
MouseEvent / KeyboardEvent / TouchEvent
visibilitychange
deviceorientation
URLSearchParams
fetch / XMLHttpRequest
```

这些值和行为不能猜，不能套旧项目固定值。命中新目标时，必须从当前 `jscall` 定位证据和匹配 `ruyitrace/` 的目标参数相关证据中取真实值。

## 常见算法观察点

`a_bogus` 可能同时包含：

- 当前请求 query 的摘要
- `msToken`
- `verifyFp` / `fp`
- `webid`
- `ttwid`
- `uifid`
- `referer`
- 浏览器基础信息
- 事件或行为状态
- VM 内部随机数或时间状态
- 编码表或自定义 base64
- 哈希链、二次哈希或字节混合

如果目标链路涉及 VMP 或高度混淆逻辑，只允许在 VMP 外围识别：

- 最终执行 `URLSearchParams.append("a_bogus", value)` 前的值来源
- 参与最终值的 query 串是否包含中间 `a_bogus`
- 是否存在多阶段补参：先生成中间值，再生成最终值
- 哈希输入、哈希输出、字节数组长度、最终编码表
- 随机数和时间戳是否可复放

严禁为了确认上述内容在 VMP / VM 解释器 / opcode handler 内下探针、插日志、插桩、改 handler、改字节码或改执行语义。

## ruyitrace/jscall 优先动作

命中 DY / `a_bogus` 后，优先做：

```text
1. 用 `jscall` 与 `http_packet` 捕获目标请求最终 URL
2. 用 `jscall` 调用栈、入参/返回值和请求边界定位 fetch / XHR 发起栈
3. 在 `jscall` 的脚本来源、函数名、调用栈和入参/返回值中搜索 webmssdk、sdk-glue、bdms、SecureSDK、web_protect
4. 在 `jscall` 记录中确认 URLSearchParams.has/append/set/delete 的调用时机和入参
5. 在 `jscall` 与 `http_packet` 记录中确认 fetch / XMLHttpRequest 请求边界
6. 记录请求前后的 Cookie / Storage / Header / Body
7. `rtwatch` / `rt_log` 和 `ruyitrace` 记录目标链路实际读取的环境属性
8. 对本地异常与浏览器异常做同触发步骤对照
```

如果本地 `code.js` 报错，必须回到浏览器同触发步骤确认浏览器是否也有相同异常。浏览器也有则优先视为目标逻辑正常行为；浏览器没有才按缺环境排查。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ 必要浏览器环境骨架
├─ 当前目标版本的安全脚本
├─ 触发安全链的包装入口
└─ get_a_bogus(input) 或 build_target_request(input)

test.py
├─ 准备真实 headers / cookies / params
├─ 调用 code.js 获取 a_bogus / verifyFp / fp
└─ 发起真实请求并验证返回
```

如果 `a_bogus` 只在请求边界出现，不要强行寻找单独返回函数；应复现最小请求组装链，并在包装入口里返回最终参数或最终 URL。

## 常见坑

- 把 `a_bogus` 和 `X-Bogus` 混为一谈
- 只搜业务入口，忽略请求出口层
- 忽略 `msToken / verifyFp / fp` 与 `a_bogus` 的同链关系
- 写死一次请求里的 `a_bogus`
- 用旧项目的 UA、宽高、语言、webid、ttwid、uifid、msToken 直接套新目标
- 在本地长期保留大范围 VM tracer、全局 Proxy 或全局 Hook
- 用浏览器跑出来的最终参数替代本地实现
- 用 VMP 探针、VMP 插装或改写后执行结果当作值基准
- 只验证参数能生成，不验证真实接口返回

## 验证重点

最终验证不只看 `a_bogus` 是否存在，还要看：

- 最终 URL 参数顺序和编码是否一致
- `msToken / verifyFp / fp` 是否匹配当前会话
- headers / cookies 是否匹配当前会话
- 请求是否命中真实目标接口
- 返回是否为正常业务 JSON，而不是风控、空数据、重定向或验证码状态
- 多次请求、翻页请求或不同业务参数下是否仍能稳定生成

## 使用边界

本文只指导优先观察点和常见问题，不提供可直接套用的固定环境值或固定算法。

补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。
