# Reese84 参考文档

本文用于识别和处理 Reese84 / Imperva / Incapsula 体系中常见的动态 challenge、`p` 生成和 `84 / reese84` 放行链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

## 命中特征

出现以下特征时，可优先按 Reese84 链路分析：

- Cookie、响应体、脚本或日志中出现 `reese84`、`84`、`visid_incap_*`、`incap_ses_*`、`nlbi_*`
- 页面返回 `403`、短 HTML、iframe block 或 `_Incapsula_Resource` 资源
- 页面里动态写入 challenge script `src`，且 `src` 每轮可能变化
- challenge POST 通常发往当前动态脚本对应路径，常见带 `?d=当前域名`
- POST body 中出现 `solution`、`interrogation`、`p`、`st`、`sr`、`cr`、`og`、`performance`、`version`
- 页面中存在 `reese84-resubmit-data` 或类似 resubmit 字段
- challenge POST 返回 `200` 和 token，但业务页或业务接口仍可能继续被拦截

注意：拿到 `84 / reese84` 不等于业务请求已经成功。必须继续验证业务页、业务接口或最终目标响应是否真正放行。

## 常见链路

典型链路是：

```text
请求受保护页面
→ 从页面 HTML 提取本轮动态 challenge src
→ 请求当前 src 对应的 challenge js
→ 在浏览器环境或本地补环境中执行当前 challenge js
→ challenge js 通过 fetch / XHR 发出 challenge POST
→ 从真实 POST body 中截获 solution.interrogation.p 等字段
→ test.py 提交本轮 challenge POST
→ 服务端返回 84 / reese84 / 相关 Incapsula Cookie
→ 带当前 Cookie 请求业务页或业务接口
→ 如仍进入过渡页，再分析后续 _Incapsula_Resource、reload 或 resubmit 链
```

这条链路最重要的是“同一轮对应关系”：

```text
当前页面 HTML
当前动态 src
当前 challenge js
当前 challenge POST URL
当前 POST body.p
当前 84 / reese84
当前业务请求 Cookie
```

这些内容必须来自同一轮运行。不要复用旧 `src`、旧 challenge js、旧 `p`、旧 POST URL 或旧 token。

## 动态 Challenge 处理

Reese84 的核心通常不是手工拼出 `p`，而是让当前动态 challenge js 在足够接近真实浏览器的环境里自己跑出 POST body。

优先确认：

- 动态 `src` 从哪里写入或拼接
- challenge js 是否每轮变化，是否存在 `s=` 等动态参数
- challenge POST URL 是否由动态脚本路径推导
- POST body 是 JSON、form、文本还是其它格式
- `solution.interrogation.p` 是否由 fetch / XHR 边界产出
- 服务端返回的 token 写入 Cookie、localStorage，还是仅由 Python 会话保存
- token 后是否还有 `_Incapsula_Resource`、reload、resubmit 或二次 POST

如果目标参数由动态 challenge js 生成，先把本轮可验证的 challenge js 固定到本地 `code.js` 中，确认本地能稳定生成本轮 POST body 后，再恢复到 `test.py` 动态获取当前 `src` 和当前 JS 做联动测试。

## 参数产出方式

Reese84 场景里的目标值常见不是普通函数直出，而是请求边界产出。

可能的目标包括：

- `solution.interrogation.p`
- `st / sr / cr / og`
- `solution.version`
- `performance`
- 完整 challenge POST body
- 服务端返回的 `84 / reese84`
- 放行业务请求所需的最终 Cookie 组合

如果 `p` 只能在 fetch / XHR 边界出现，不要强行寻找单独返回 `p` 的函数；应复现最小 challenge 执行链，并在包装入口中返回完整 POST body 或关键字段。

本地稳定入口可以按目标命名，例如：

```js
function get_reese84_payload(input = {}) {
  const payload = run_current_challenge(input);
  return payload;
}

function get_reese84(input = {}) {
  const payload = get_reese84_payload(input);
  return submit_or_extract_token(payload);
}
```

这里的 `run_current_challenge` 不是固定函数名，而是指 `code.js` 中实际驱动当前 challenge js、补齐环境、截获 fetch / XHR POST body 的最小包装逻辑。

## 常见环境面

Reese84 常见会触达这些环境面：

```text
navigator.language / languages
navigator.userAgent / platform / oscpu / hardwareConcurrency
navigator.plugins / mimeTypes
navigator.permissions.query
window.opener / external / visualViewport
window.innerWidth / outerWidth / screenX / screenY
screen.width / height / availWidth / availHeight
location.href / origin / ancestorOrigins / reload
document.cookie / referrer / readyState / visibilityState
iframe.contentWindow / contentDocument / load
localStorage / sessionStorage / history / indexedDB
performance.now / timing / getEntries / PerformanceObserver
crypto.getRandomValues / randomUUID
HTMLMediaElement.canPlayType
canvas 2d / toDataURL / getImageData / measureText
WebGL getParameter / getExtension / shader precision / readPixels
OfflineAudioContext / AudioBuffer / oncomplete / getChannelData
EventTarget / addEventListener / dispatchEvent / MutationObserver
requestAnimationFrame / postMessage
```

这些值、返回、descriptor、prototype、`toString`、异常栈和事件顺序都不能猜。命中新目标时，必须从当前 `jscall` 定位证据和匹配 `ruyitrace/` 的目标参数相关证据中取真实值。

## ruyitrace/jscall 优先动作

命中 Reese84 后，优先做：

```text
1. 用 `jscall` 与 `http_packet` 确认首页、动态 challenge js、challenge POST、业务请求和后续过渡资源
2. 用 `jscall` 调用栈、入参/返回值和请求边界定位 challenge script 注入点和 fetch / XHR 发起栈
3. 在 `jscall` 的脚本来源、函数名、调用栈和入参/返回值中搜索 reese84、interrogation、solution、resubmit-data、_Incapsula_Resource、visid_incap、incap_ses、nlbi
4. 在 `jscall` 与 `http_packet` 记录中确认 fetch / XMLHttpRequest 请求边界，截获 challenge POST URL、Header、Body、调用栈
5. 在 `jscall`、`storage` 和 `domtrace` 记录中确认 document.cookie、localStorage、location.reload、script.src、iframe load
6. `rtwatch` / `rt_log` 和 `ruyitrace` 记录 challenge 阶段实际读取的环境属性
7. 对本地异常与浏览器异常做同触发步骤对照
8. 记录 challenge POST 后的 Set-Cookie、Cookie 合并和业务请求最终状态
```

jscall/http_packet/trace 证据只用于定位和对照。不要把大范围 Hook、Proxy、VM tracer、VMP 探针或调试框架沉淀到本地 `code.js`。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ 必要浏览器环境骨架
├─ 当前目标版本的 challenge js 或动态加载入口
├─ fetch / XHR 最小截获层，只用于拿到真实 challenge POST body
├─ get_reese84_payload(input)
└─ get_reese84(input) 或 build_target_cookie(input)

test.py
├─ 请求当前首页
├─ 提取当前动态 src
├─ 请求当前 challenge js
├─ 调用 code.js 生成本轮 challenge POST body
├─ 提交 challenge POST 获取 84 / reese84
└─ 带当前 Cookie 请求业务页或业务接口并验证返回
```

如果 `code.js` 或 `test.py` 一开始为空，先用 `jscall` 浏览器侧分析真实请求链，不要假设目标参数一定已经有本地入口。

## 常见坑

- 复用旧 `src`、旧 challenge js、旧 `p` 或旧 token
- 把 challenge POST `200` 当成最终成功
- 业务页返回 `200` 但内容仍是 iframe block，却误判为放行
- 只看 `84 / reese84` 是否存在，不看最终业务响应
- 手工拼 `p`，没有让当前动态 JS 自己产出
- POST URL、`p`、Cookie 不是同一轮运行产物
- challenge 后丢掉服务端新下发的 `visid_incap_* / incap_ses_* / nlbi_*`
- 把一次成功的 Cookie、宽高、语言、canvas、webgl、audio 固定套到新目标
- 过早暴露不完整的 audio / WebGL / canvas 能力，反而改变 `p` 或降低 token 质量
- 用过死的随机数、时间戳、performance 值推进验证
- 在本地长期保留大范围 tracer、全局 Proxy 或全局 Hook
- 只补请求链，不补真实触达的环境值、指纹对象、descriptor 和事件顺序

## 验证重点

最终验证不只看 challenge 是否返回 token，还要看：

- 当前轮动态 `src`、challenge js、POST URL、POST body 和 token 是否对应
- challenge POST 是否返回 `200`，且响应中确实有当前可用的 `84 / reese84`
- Cookie 合并后是否包含当前服务端新下发的反爬 Cookie
- 业务页是否不再是 iframe block、短 HTML、验证码页或重定向页
- 业务接口是否返回正常业务 JSON，而不是空数据、风控结构或拦截 HTML
- 多轮重新获取动态 `src` 后是否仍能稳定生成和验证
- 如果 direct 业务请求失败，再考虑 resubmit 或后续过渡资源回放，不要默认先走 resubmit

## 使用边界

本文只指导优先观察点和常见问题，不提供可直接套用的固定环境值、固定指纹或固定算法。

补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。
