# Akamai 参考文档

本文用于识别和处理 Akamai Bot Manager、BMP、CSC 和 TLS 指纹相关链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

## 命中特征

出现以下特征时，可优先按 Akamai 链路分析：

- Cookie 中出现 `_abck`、`bm_sz`、`ak_bmsc`、`bm_sv`、`bm_mi` 等 Akamai 相关字段
- `_abck` 初始值尾部常见 `~-1~-1~-1~-1~-1`，通过后会更新为带时间戳或状态段的值
- 页面加载随机路径脚本，路径看起来像无扩展名的混淆资源
- 运行链中出现 `bmak`、`get_telemetry`、`sensor_data`
- 浏览器侧可观察到 `sensor_data` 提交到 Akamai 脚本同路径或相邻路径
- 响应状态为 `403`，HTML 中出现 `sec-if-cpt-container`、Akamai challenge 容器或保护页标记
- Python 标准 HTTP 客户端出现 HTTP/2 stream reset、连接超时、TLS 指纹不匹配，但浏览器正常

Akamai 不是单一形态。至少先区分三类：

```text
BMP / Bot Manager
= 常见 _abck + bm_sz + sensor_data 链路

CSC / Client-Side Challenge
= 更强 challenge 页面，常见 iframe / challenge 容器 / 保护页

TLS / HTTP2 指纹层
= JS 还没执行，请求在传输层已经被 reset、timeout 或策略拦截
```

## 常见链路

BMP 典型链路是：

```text
请求首页或受保护页面
→ 服务端下发 _abck / bm_sz
→ 页面加载 Akamai 混淆脚本
→ 脚本收集浏览器环境、指纹和行为状态
→ 生成 sensor_data
→ POST sensor_data 到 Akamai 校验端点
→ 服务端更新 _abck / 相关 Cookie
→ 带更新后的 Cookie 请求目标页面或接口
```

CSC 典型链路是：

```text
请求受保护入口
→ 返回 403 或短 HTML challenge 页面
→ 页面加载二次 challenge 脚本
→ challenge 脚本验证环境、事件、iframe、storage 或行为
→ 成功后触发 reload、跳转、cookie 更新或继续请求
→ 再访问业务页面或业务接口
```

TLS 指纹层不属于 `code.js` 补环境问题。如果 Python 请求在未进入 JS 链路前就 reset、timeout 或被 HTTP/2 策略拦截，优先在 `test.py` 的客户端、TLS、HTTP/2、Header 顺序和 UA 层排查，不要把它误判为浏览器 JS 环境缺失。

## 参数产出方式

Akamai 场景里的目标通常不是业务函数直出，而是保护链路产出。

常见目标包括：

- `sensor_data`
- 更新后的 `_abck`
- `bm_sz` 派生状态
- challenge POST body 或同一轮多个 challenge XHR body
- challenge 后的最终 Cookie 组合
- 业务请求能否在当前 Cookie 下放行

如果页面存在 `window.bmak.get_telemetry()`，只能把它作为当前目标的候选入口，仍需用 `jscall` 定位并用匹配 `ruyitrace/` 确认：

- 当前目标是否真的调用它生成 `sensor_data`
- 它是否依赖当前 `_abck / bm_sz`
- 调用前是否需要事件、timer、iframe 或 storage 状态
- POST 目标、Header、Body 编码是否与浏览器一致
- 提交后 `_abck` 是否真实更新

如果 `sensor_data` 只在请求边界出现，不要强行寻找普通函数直出；应复现最小保护链，并在稳定入口中返回完整 POST body 或更新后的 Cookie 状态。

CSC 场景中不要默认只有一个 challenge body。某些站点会在同一轮 challenge JS 中发起多条同路径 XHR，例如先发短 body，再发一到多条长 body；每条响应可能都是空 body、状态码 `200/202`，并通过 `bm_s`、`bm_lso` 或相关 Cookie 逐步推进状态。此时稳定入口应输出捕获到的全部 challenge XHR 边界，`test.py` 按浏览器产生顺序去重后逐条提交，而不是只取最长 body。

## 常见环境面

Akamai 常见会触达这些环境面：

```text
navigator.userAgent / platform / language / languages / webdriver
navigator.plugins / mimeTypes / hardwareConcurrency / cookieEnabled
screen.width / height / availWidth / availHeight / colorDepth
window.innerWidth / innerHeight / outerWidth / outerHeight / devicePixelRatio
document.cookie / referrer / visibilityState / readyState
location.href / origin / pathname
localStorage / sessionStorage
performance.now / timing / getEntries
Date / Math.random / crypto
canvas 2d / toDataURL / getImageData / measureText
WebGL getParameter / getExtension / readPixels
AudioContext / OfflineAudioContext
MouseEvent / KeyboardEvent / TouchEvent / pointer events
setTimeout / setInterval / requestAnimationFrame
XMLHttpRequest / fetch / sendBeacon
```

这些值、行为、descriptor、prototype、`toString`、异常栈和事件顺序不能猜。命中新目标时，必须从当前 `jscall` 定位证据和匹配 `ruyitrace/` 的目标参数相关证据中取真实值。

## ruyitrace/jscall 优先动作

命中 Akamai 后，优先做：

```text
1. 用 `jscall` 与 `http_packet` 确认首页、Akamai 脚本、sensor_data POST、Cookie 更新和目标业务请求
2. 确认失败发生在 TLS/HTTP2 层、challenge 页面层、sensor_data 层还是业务请求层
3. 在 `jscall` 的脚本来源、函数名、调用栈和入参/返回值中搜索 bmak、get_telemetry、sensor_data、_abck、bm_sz、sec-if-cpt-container
4. 用 `jscall` 调用栈、入参/返回值和 `http_packet` 请求记录定位 Akamai 脚本加载点和 sensor_data POST 发起栈
5. 在 `jscall` 与 `http_packet` 记录中确认 XMLHttpRequest / fetch / sendBeacon 的 POST URL、Header、Body 和调用栈
6. 在 `storage` / `http_packet` 记录中确认 _abck / bm_sz 更新前后
7. `rtwatch` / `rt_log` 和 `ruyitrace` 记录生成 sensor_data 时实际读取的环境属性
8. 对本地异常、参数长度、Cookie 更新结果和浏览器真实表现做同触发步骤对照
```

如果 historical trace seed 可以触发某个 `_abck` 状态变化，只把它作为隔离 marker 验证。不要把旧 `_abck / bm_sz / bm_s / bm_lso / sensor_data` 带入当前动态 JS 的 live 会话；Akamai 校验常与当前脚本、时间、Cookie、IP/TLS 状态绑定，旧 seed 可能污染 fresh 会话并导致当前 BMP 或 CSC 返回失败。

如果升级观测改变页面行为，立即回到干净浏览器基线，缩小 Hook 范围。不要把浏览器侧 Hook、trace、VM tracer 或全局 Proxy 沉淀到本地 `code.js`。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ 必要浏览器环境骨架
├─ 当前目标版本的 Akamai 脚本或最小入口
├─ 目标链路实际需要的 Cookie / storage / timing 输入
├─ build_akamai_payload(input)
└─ get_sensor_data(input) 或 build_akamai_cookie(input)

test.py
├─ 建立真实会话
├─ 获取首页和初始 Akamai Cookie
├─ 获取当前 Akamai 脚本
├─ 调用 code.js 生成 sensor_data 或 challenge body
├─ 对 challenge 场景，按捕获顺序提交所有 challenge XHR body，并保存每次响应后的 Cookie
└─ 带当前 Cookie 请求业务页面或业务接口并验证返回
```

如果失败点是 TLS / HTTP2 指纹，修复位置在 `test.py` 的请求客户端与传输配置，不在 `code.js`。`code.js` 只负责 JS 环境和保护脚本逻辑。

## 常见坑

- 把 TLS reset 当作 JS 补环境问题
- 只看 POST 状态码，不看 `_abck` 是否真实更新
- 复用旧 `_abck / bm_sz / sensor_data`
- 把 historical trace seed cookie 直接回灌到当前动态 JS live 会话，导致 fresh BMP/CSC 状态被旧会话污染
- 遇到 CSC 多段 XHR 时只提交最长 challenge body；正确做法是按浏览器请求顺序提交每个去重后的 body
- 使用旧项目固定宽高、UA、语言、canvas、webgl、audio 指纹
- 把 `bmak.get_telemetry()` 视为所有 Akamai 站点的固定入口
- 忽略 `sensor_data` 与当前 Cookie、当前脚本、当前页面 URL 的同轮关系
- 在本地保留大范围 timer 包装、全局 Hook、VM tracer 或全局 Proxy
- 只生成参数，不验证业务接口是否真正返回正常数据
- 遇到 CSC 保护页时仍按标准 BMP 路线硬套
- 忽略 Header 顺序、Content-Type、Referer、Origin、TE、Dynatrace trace header、HTTP/2 和 Cookie 合并细节

## 验证重点

最终验证不只看 `sensor_data` 是否存在，还要看：

- 初始 `_abck / bm_sz` 是否来自当前会话
- Akamai 脚本是否来自当前页面、当前版本
- `sensor_data` POST 的 URL、Method、Header、Body 编码是否与浏览器一致
- challenge POST 是否覆盖浏览器真实的全部 XHR body、顺序、Header 和每次响应后的 Cookie 更新
- POST 后 `_abck` 或相关 Cookie 是否按浏览器同样方式更新
- CSC 后是否出现 `sec-if-cpt-container=False`、保护页消失，且不是只看到 challenge POST 返回空 body
- 带更新 Cookie 请求业务页面或接口是否返回正常业务内容
- 多轮重新获取页面和脚本后是否仍能稳定复现
- 如果业务页仍是 challenge、短 HTML、403 或重定向，不能视为通过

## 使用边界

本文只指导优先观察点和常见问题，不提供可直接套用的固定环境值、固定指纹或固定算法。

补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。
