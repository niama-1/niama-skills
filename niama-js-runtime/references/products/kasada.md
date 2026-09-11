# Kasada 参考文档

本文用于识别和处理 Kasada KPSDK 体系中常见的动态脚本、`/fp`、`ips.js`、`/tl`、二进制指纹 payload 和 `x-kpsdk-*` token 链路。它是经验参考，不是固定套用方案；命中同类目标后，仍必须以当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

## 命中特征

出现以下特征时，可优先按 Kasada 链路分析：

- 请求或响应头中出现 `x-kpsdk-ct`、`x-kpsdk-v`、`x-kpsdk-h`、`x-kpsdk-im`、`x-kpsdk-dt`、`x-kpsdk-cr`
- Cookie 中出现 `KP_UIDz` 或其它 `KP_` 前缀状态
- 页面、脚本或请求路径中出现 `KPSDK`、`p.js`、`ips.js`、`/fp`、`/tl`、`/mfc`
- `/fp` 返回 iframe / HTML 初始化片段，包含 `window.KPSDK`、`KPSDK.now`、`postMessage("KPSDK:...")`
- `ips.js` 执行后自行发起 `POST /tl`
- `/tl` 请求常见 `Content-Type: application/octet-stream`，Body 是二进制指纹 payload
- 成功响应常见返回新的 `x-kpsdk-ct`，并伴随 `x-kpsdk-cr: true` 或 Cookie 更新
- 目标没有 `_abck / bm_sz`，不要误判为 Akamai BMP

Kasada 的核心通常不是“调用某个公开函数拿 token”，而是让当前 KPSDK 动态脚本在正确环境、当前 Cookie 和当前 Header 下自己走到 `/tl` 请求边界。

## 常见链路

典型链路是：

```text
请求受保护页面
→ 获取初始 Cookie / KPSDK 状态
→ 加载 p.js 或主 KPSDK 脚本
→ 请求 /mfc 获取或确认 x-kpsdk-h 等配置状态
→ 请求 /fp 获取 iframe HTML / KPSDK 初始化片段
→ 从 /fp 或页面中定位当前 ips.js
→ 执行当前 ips.js
→ ips.js 通过 XHR / fetch 发出 POST /tl
→ /tl body 为当前环境生成的二进制 payload
→ 服务端返回新的 x-kpsdk-ct / x-kpsdk-cr / KP_UIDz
→ 带当前 token、Cookie 和 Header 请求业务接口
```

这条链路最重要的是“同一轮对应关系”：

```text
当前页面或 /fp HTML
当前 p.js / ips.js
当前 KP_UIDz
当前 x-kpsdk-v / h / im / dt
当前 /tl URL
当前 /tl 二进制 body
当前 x-kpsdk-ct
当前业务请求 Header / Cookie
```

这些内容必须来自同一轮运行。不要复用旧 `ips.js`、旧 `/fp`、旧 `/tl` body、旧 `x-kpsdk-ct` 或旧 `KP_UIDz`。

## 动态脚本处理

Kasada 常见使用 VMP 或高度混淆的动态脚本。处理时优先按浏览器真实执行链外围定位，不要先假设能静态还原，也不得在 VMP 内下探针或插装补环境。

优先确认：

- `p.js`、`ips.js`、`/fp`、`/mfc`、`/tl` 的实际顺序
- `ips.js` 是在主窗口、iframe、worker 还是其它上下文执行
- `/tl` 是由 XHR、fetch 还是 sendBeacon 发出
- `/tl` body 是 `ArrayBuffer`、`Uint8Array`、Blob、form 还是字符串
- `x-kpsdk-*` Header 哪些由脚本生成，哪些来自服务端响应
- `KP_UIDz` 与 `/tl` body 是否绑定当前会话
- token 后业务请求是否还需要特定 Header、Referer、Origin、UA 或前置请求

如果目标参数由动态 JS 生成，先把本轮可验证的 JS 固定到本地 `code.js` 中，确认本地能稳定走到 `/tl` payload 或目标 token 后，再恢复到 `test.py` 动态获取当前脚本做联动测试。

## 参数产出方式

Kasada 场景里的目标值常见是请求边界产出，而不是函数直出。

可能的目标包括：

- `/tl` 完整二进制 body
- `/tl` 请求 Header 中的 `x-kpsdk-*`
- 服务端返回的 `x-kpsdk-ct`
- `KP_UIDz`
- 放行业务请求所需的 Header / Cookie 组合

如果 `/tl` body 只能在 XHR / fetch 边界出现，不要强行寻找单独返回函数；应复现最小 KPSDK 执行链，并在稳定入口中返回完整 `/tl` 请求材料。

本地稳定入口可以按目标命名，例如：

```js
function get_kasada_tl_payload(input = {}) {
  const request = run_current_kpsdk(input);
  return {
    url: request.url,
    headers: request.headers,
    bodyBase64: request.bodyBase64,
  };
}

function get_x_kpsdk_ct(input = {}) {
  const tl = get_kasada_tl_payload(input);
  return submit_or_extract_kpsdk_token(tl);
}
```

这里的 `run_current_kpsdk` 不是固定函数名，而是指 `code.js` 中实际驱动当前 KPSDK 动态脚本、补齐环境、拿到 `/tl` 请求材料的最小包装逻辑。

## 常见环境面

Kasada 常见会触达这些环境面：

```text
navigator.userAgent / platform / language / languages / webdriver
navigator.plugins / mimeTypes / hardwareConcurrency / maxTouchPoints
screen.width / height / availWidth / availHeight / colorDepth
window.innerWidth / outerWidth / devicePixelRatio / visualViewport
document.cookie / referrer / readyState / visibilityState
location.href / origin / ancestorOrigins
iframe.contentWindow / contentDocument / postMessage / message
localStorage / sessionStorage / history
performance.now / timing / getEntries
Date / Math.random / crypto.getRandomValues
canvas 2d / toDataURL / getImageData / measureText
WebGL getParameter / getExtension / readPixels / shader precision
AudioContext / OfflineAudioContext / AudioBuffer
MouseEvent / KeyboardEvent / TouchEvent / PointerEvent
setTimeout / setInterval / requestAnimationFrame / queueMicrotask
XMLHttpRequest / fetch / Headers / Request / Response
ArrayBuffer / Uint8Array / Blob / TextEncoder
```

这些值、行为、descriptor、prototype、`toString`、异常栈和事件顺序不能猜。命中新目标时，必须从当前 `jscall` 定位证据和匹配 `ruyitrace/` 的目标参数相关证据中取真实值。

## ruyitrace/jscall 优先动作

命中 Kasada 后，优先做：

```text
1. 用 `jscall` 与 `http_packet` 确认页面、p.js、/mfc、/fp、ips.js、/tl 和业务请求
2. 用 `jscall` 调用栈、入参/返回值和请求边界定位 /tl 发起栈、iframe 上下文和 KPSDK 初始化入口
3. 在 `jscall` 的脚本来源、函数名、调用栈和入参/返回值中搜索 KPSDK、x-kpsdk、KP_UIDz、ips.js、postMessage、/tl、/fp、/mfc
4. 在 `jscall` 与 `http_packet` 记录中确认 /tl URL、Header、Body 类型、Body 长度和调用栈
5. 在 `jscall`、`storage` 和 `domtrace` 记录中确认 postMessage、iframe load、document.cookie、localStorage 的跨上下文状态
6. `rtwatch` / `rt_log` 和 `ruyitrace` 记录生成 /tl body 时实际读取的环境属性
7. 对本地异常、/tl body 长度、Header、token 响应和浏览器真实表现做同触发步骤对照
```

jscall/http_packet/trace 证据只用于定位和对照。不要把大范围 Hook、Proxy、VM tracer、解释器框架、VMP 探针或调试插桩沉淀到本地 `code.js`。

## 本地落地建议

如果采用本地补环境路线，推荐结构是：

```text
code.js
├─ 必要浏览器环境骨架
├─ 当前目标版本的 KPSDK 动态脚本或最小加载入口
├─ iframe / postMessage / XHR / fetch 的最小宿主对象实现
├─ get_kasada_tl_payload(input)
└─ get_x_kpsdk_ct(input) 或 build_kasada_headers(input)

test.py
├─ 建立真实会话
├─ 获取当前页面、/mfc、/fp、ips.js 和当前 Cookie
├─ 调用 code.js 生成本轮 /tl 请求材料
├─ 提交真实 /tl 获取当前 x-kpsdk-ct / KP_UIDz
└─ 带当前 Header / Cookie 请求业务接口并验证返回
```

本地 `XMLHttpRequest` / `fetch` 的实现只能作为目标脚本运行所需的最小宿主对象和输出边界，不应扩展成长期调试 Hook 框架。

## 常见坑

- 把 Kasada 误判为 Akamai，去找 `_abck / bmak / sensor_data`
- 复用旧 `ips.js`、旧 `/fp`、旧 `/tl` body 或旧 `x-kpsdk-ct`
- 只看 `/tl` 返回 token，不验证业务接口是否放行
- 忽略 `/tl` body 与当前 Cookie、Header、脚本版本和 iframe 上下文的同轮关系
- 把二进制 body 当字符串处理，导致长度、编码或字节内容变化
- 在本地长期保留大范围 VM tracer、全局 Proxy、全局 Hook 或解释器插桩
- 使用 catch-all 异常吞掉 VM 的非环境异常，导致脚本状态污染或死循环
- 过早暴露不完整的 canvas、webgl、audio、iframe 或 postMessage 能力，反而改变 `/tl` body
- 只补对象存在性或 native 外观，不补目标集合相关链路实际依赖的字段内容、返回对象、状态、副作用、身份关系、descriptor、prototype、异常和事件/Worker 顺序
- 忽略 Header 大小写、顺序、Content-Type、Origin、Referer、UA 和 Cookie 合并细节

## 验证重点

最终验证不只看 `x-kpsdk-ct` 是否存在，还要看：

- 当前 `/fp`、`ips.js`、`KP_UIDz`、`x-kpsdk-*` 和 `/tl` body 是否同轮对应
- `/tl` body 字节长度和类型是否与浏览器一致
- `/tl` Header、Content-Type、Origin、Referer、Cookie 是否与浏览器一致
- `/tl` 响应是否返回当前可用的 `x-kpsdk-ct` 和通过状态
- 带 token 后业务接口是否返回正常业务数据，而不是 403、429、空数据或二次 challenge
- 多轮重新获取动态脚本后是否仍能稳定生成和验证

## 使用边界

本文只指导优先观察点和常见问题，不提供可直接套用的固定环境值、固定指纹或固定算法。

补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。
