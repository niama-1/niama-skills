# 腾讯 / TX 滑块验证码参考文档

本文用于识别和处理腾讯验证码 `TCaptcha` / `TDC` 滑块链路，重点是 `t.captcha.qq.com` 的初始化、当前轮 `tdc.js` 产出的 `collect/eks`、滑块答案 `ans`、PoW 字段，以及校验成功后返回的 `ticket/randstr`。

本文是产品专项经验参考，不替代当前目标实测。任何补入 `code.js` 的 DOM/BOM 值、环境外观、事件顺序、轨迹数据、Header、Cookie、请求体和坐标，都必须来自当前目标的 `jscall`、`http_packet`、`storage/domtrace` 或已收敛的当前 trace 资产。

## 命中特征

出现以下特征时，优先按腾讯滑块验证码链路分析：

- 页面加载 `https://t.captcha.qq.com/TCaptcha.js`
- 页面脚本出现 `new TencentCaptcha(appid, callback, options)`、`TencentCaptcha`、`captcha.show()`
- 请求链出现 `https://t.captcha.qq.com/cap_union_prehandle`
- 请求链出现 `https://t.captcha.qq.com/cap_union_new_verify`
- 初始化响应或脚本中出现 `tdc.js`、`tdc_path`、`window.TDC`、`TDC.setData`、`TDC.getData`、`TDC.getInfo`
- 验证码 iframe 或模板来自 `captcha.gtimg.com/static/template/drag_ele...html`
- Cookie、storage 或脚本中出现 `TDC_itoken`、`__tdc_st_`
- 题型或脚本中出现 `move_slide`、`watermarkMoveSlide`、`DynAnswerType_POS`
- 初始化响应出现 `comm_captcha_cfg`、`dyn_show_info`、`bg_elem_cfg`、`sprite_url`、`fg_elem_list`、`pow_cfg`、`sess`
- 校验请求体出现 `collect`、`tlg`、`eks`、`sess`、`ans`、`pow_answer`、`pow_calc_time`
- 校验成功响应或页面回调出现 `ticket`、`randstr`

## 核心边界

TX 滑块链路的目标通常是拿到当前会话可用的验证码通过凭证：

```text
ticket + randstr
```

`ticket/randstr` 的来源是 `cap_union_new_verify` 校验成功后的服务端响应或页面回调，不是 `tdc.js` 本地直接生成的值。

关键绑定通常包括：

- 绑定同轮 `cap_union_prehandle` 返回的 `sess`
- 绑定同轮 `tdc_path` 下载到的 live `tdc.js`
- 绑定同轮 `pow_cfg`
- 绑定同一浏览器环境、UA、Cookie/storage 状态和 TDC token
- 绑定滑块题面中的背景图、小块图、初始位置和当前答案坐标
- 短时效，拿到后应立即注入原业务回调或原业务请求

如果当前任务是验证码本身，`cap_union_new_verify` 返回 `errorCode == "0"` 且带 `ticket/randstr` 可以作为验证码口径成功。如果当前任务是登录、下单、活动领取等业务链，必须继续验证原业务接口是否真正放行。

## 总请求链

腾讯滑块常见链路：

```text
目标页入口
→ 加载 TCaptcha.js
→ new TencentCaptcha(appid, callback, options)
→ captcha.show()
→ GET t.captcha.qq.com/cap_union_prehandle
→ 得到 sess、tdc_path、pow_cfg、dyn_show_info、背景图和滑块小图路径
→ GET 当前轮 tdc.js
→ 加载 captcha.gtimg.com 拖拽模板或 iframe
→ 下载背景图、sprite 图，解析 fg/bg 配置
→ 识别滑块答案 x/y
→ 在 code.js 中执行当前轮 live tdc.js
→ window.TDC.setData(...) 注入当前轮环境和轨迹上下文
→ window.TDC.getData(true) 产出 collect
→ window.TDC.getInfo().info 产出 eks
→ 根据 pow_cfg 计算 pow_answer 和 pow_calc_time
→ POST t.captcha.qq.com/cap_union_new_verify
→ 返回 errorCode=0、ticket、randstr
→ 回到页面 callback 或原业务接口验证放行
```

## prehandle

常见请求：

```text
GET https://t.captcha.qq.com/cap_union_prehandle
```

常见 query 字段：

```text
aid / appid
protocol
accver
showtype
ua
clientype
lang
entry_url
js
callback
sess
```

字段说明：

- `aid/appid`：站点接入的腾讯验证码应用标识，必须从当前页面或请求链取，不跨目标复用
- `ua`：通常与当前浏览器 UA 绑定，常见为编码后的 UA；后续执行 TDC 时必须保持一致
- `entry_url`：验证码所在业务页，影响来源和风控上下文
- `js`：TCaptcha frame 脚本版本路径，随版本变化
- `sess`：首轮可能为空，服务端返回后参与后续校验

常见响应字段：

```text
sess
data.comm_captcha_cfg.tdc_path
data.comm_captcha_cfg.pow_cfg
data.dyn_show_info.bg_elem_cfg
data.dyn_show_info.sprite_url
data.dyn_show_info.fg_elem_list
```

这些字段必须按轮次整体使用。不要把上一轮的 `sess`、图片、`tdc_path` 或 `pow_cfg` 混到当前轮。

## TDC / collect

`collect` 和 `eks` 是 TX 滑块的核心客户端证明：

```text
collect = decodeURIComponent(window.TDC.getData(true))
tlg = collect.length
eks = window.TDC.getInfo().info
```

本地 `code.js` 的推荐职责：

- 接收当前轮 `tdc.js` 内容，不固定旧脚本
- 补齐当前 trace 命中的最小 DOM/BOM 环境
- 执行 live `tdc.js`
- 调用 `window.TDC.setData(...)` 注入同轮 UA、轨迹、控件位置、客户端尺寸等上下文
- 输出 `collect/tlg/eks`，交给 `test.py` 拼真实请求

TDC 链路常观察到的环境点：

- `navigator.userAgent`、`navigator.webdriver`
- `location.href`、`document.URL`、`document.referrer`
- `localStorage/sessionStorage`，尤其是 `__tdc_st_`
- `document.cookie`，尤其是 `TDC_itoken`
- `performance.getEntriesByType`
- `document.createElement`、`document.querySelector`、`getComputedStyle`
- `addEventListener` 监听 `mousemove/mousedown/mouseup/touch*`
- 必要时才补 `canvas`、图片、布局和指纹面，且必须以当前 trace 为准

不要在 VMP、opcode handler 或解释器内部插桩。只能围绕外部 DOM/BOM 宿主对象、方法入参、返回值和请求边界收敛。

## 滑块答案

TX 滑块校验的答案常见形状：

```text
ans = [{"elem_id":1,"type":"DynAnswerType_POS","data":"x,y"}]
```

处理要点：

- `x` 应按当前背景图与滑块小图匹配得到
- `y` 应按当前题面中的小块初始位置、控件坐标或 trace 证据确定
- 坐标参考系必须与当前 `dyn_show_info` 和模板一致
- 识别层可以使用 OpenCV、ddddocr 或外部打码服务，但识别结果不能替代 TDC 客户端证明

如果图片识别成功但校验失败，优先排查 `collect/eks`、`sess`、`pow_answer`、UA、Cookie/storage、坐标参考系和同轮绑定，而不是只反复调识别模型。

## PoW

初始化响应常见 `pow_cfg`，本地需要计算并提交：

```text
pow_answer
pow_calc_time
```

常见形态是服务端给出 `prefix` 和目标哈希，本地枚举 nonce，找到满足条件的 `prefix + nonce`，并记录计算耗时。`pow_answer` 必须来自当前轮 `pow_cfg`，不要复用旧值或固定耗时。

## verify

常见请求：

```text
POST https://t.captcha.qq.com/cap_union_new_verify
```

常见 body：

```text
collect=<TDC getData>
tlg=<collect length>
eks=<TDC getInfo().info>
sess=<prehandle sess>
ans=<slider answer json>
pow_answer=<pow result>
pow_calc_time=<milliseconds>
```

常见成功口径：

```text
errorCode == "0"
ticket
randstr
```

后续页面回调可能把 `ticket/randstr` 交给业务逻辑、原生桥或表单字段。不要把脚本加载失败时构造的 `terror_*` 票据当作通过凭证。

## ruyitrace / jscall 观察点

优先按以下顺序定位：

- `http_packet`：确认 `TCaptcha.js`、`cap_union_prehandle`、`tdc.js`、模板 HTML、图片资源、`cap_union_new_verify`
- `jscall`：定位 `new TencentCaptcha`、`captcha.show`、`TDC.setData/getData/getInfo`、校验请求体组装点
- `domtrace`：确认 TCaptcha/TDC 触达的 DOM/BOM、事件监听、布局读取、storage/cookie 读取
- `descriptor`：确认 `navigator.webdriver`、原型、descriptor、native 外观等检查点
- `cookie/storage`：确认 `TDC_itoken`、`__tdc_st_` 等状态读写和同站/三方上下文
- `eval`：确认动态脚本、webpack/eval 片段和当前轮 `tdc.js` 外围逻辑

## 常见坑

- 只解图片不跑 TDC，通常只能得到坐标，不能通过服务端校验
- 固定旧 `tdc.js`、旧 `collect`、旧 `sess`、旧 `pow_answer` 会破坏同轮绑定
- `tlg` 必须与实际 `collect.length` 一致
- prehandle 的 UA 与 TDC 执行时 UA 不一致，容易导致 `collect` 无效
- `ans` 坐标参考系错误，尤其是 sprite 裁剪坐标、背景图缩放和控件偏移混用
- `ticket/randstr` 短时效，浏览器现场先消费后，本地重放可能失败
- 单独验证码 `errorCode=0` 不代表原业务放行，业务链必须继续跑最终接口
- 脚本版本、`js` 路径、`tdc_path`、模板路径都可能变，必须从当前请求链取 fresh 值
