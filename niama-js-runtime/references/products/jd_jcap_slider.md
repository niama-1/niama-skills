# 京东 JCAP 滑块专项参考

会话编号：`019f2e52-4e91-7440-858d-179f6395a4f7`

本文记录京东 PC 登录 JCAP 滑块 / 旋转验证码的实战处理要点，作为 `jd_jcap.md` 的专项补充。重点是 `tp=30` 滑块、`tp=26` 旋转、`ct/tk/cs` 动态生成、轨迹 proof、视觉答案边界、同轮会话状态和真实在线成功判定。

本文只作为产品经验索引，不替代当前目标实测。任何 `code.js` 环境值、事件轨迹、DOM layout、`ct/tk/cs` 入参、offset、angle、Cookie、`st/fp/vt` 都必须以当前 trace、当前请求链和当前在线响应为准。

## 命中特征

出现以下特征时，除读取 `references/products/jd_jcap.md` 外，建议同时读取本文：

- 请求链出现 `https://jcap.m.jd.com/cgi-bin/api/fp` 和 `https://jcap.m.jd.com/cgi-bin/api/check`
- JCAP 脚本来自 `storage.360buyimg.com/jsresource/jcap/version/.../jcap_*.js`
- 页面或运行时出现 `window.jdCAP`、`jdCAP.captcha`、`requireCaptchaPc.js`
- `/api/check` 题面响应含 `tp=30`、`img.b1`、`img.b2`
- `/api/check` 题面或源码中出现 `tp=26`、`rotate_img`、`drag_box`、`slider`、`slide_path`
- proof 对象中出现 `ht/wt/bw/sw/mw/list/ii` 或 `bw/sw/track/list/ii`
- 提交失败返回 `code=16807`、`s_code=16130`、`msg=验证失败，请重新验证`
- 任务目标是判断“动态生成是否成立”，而不是只重放 trace 成功包

## 成功判定

真实成功只看当前在线第二次 `/cgi-bin/api/check`：

```text
response.code == 0
response.vt 非空
```

不要把以下现象单独当成成功：

- 本地 `code.js` 能跑完
- 本地 fixture 能生成请求
- `/api/fp` 返回 `code=0`
- 题面阶段 `/api/check` 返回 `code=0`
- `tk/ct/cs` 长度接近 trace
- 响应字段、body 长度或 proof 形态和 trace 相似
- trace 里的历史样本本身是 `code=0`

trace 的 `code=0/vt` 只证明当时浏览器链路成功；当前任务成功必须由本地 `test.py --online` 重新动态生成请求并真实提交后拿到新的 `vt`。

## 动态生成边界

推荐边界：

```text
code.js
= 运行目标 JCAP JS、补 DOM/BOM、触发 instance.create、派发拖动事件、生成 fp/check 请求体

test.py
= 获取 fresh session/jwt/cookie、发送真实 HTTP、保存题面、识别答案、维护响应状态、判断 vt
```

禁止把服务端返回状态回灌进 `code.js` 伪造成生成逻辑：

- 不把旧 `vt` 写进 `code.js`
- 不把服务端 `st/fp` 当成本地算法产物
- 不把真实响应 token 固定进本地 JS
- 不把已消费的会话状态拿来证明当前在线通过

单 VM bridge 比 split runtime 更可靠。`fp`、题面、拖动和答题 proof 应尽量在同一个 JCAP runtime 内完成，避免拆散 instance 内部状态、records、fpt、计时器和回调状态。

## 请求难点

### 同轮状态

JCAP 滑块强依赖同轮状态：

```text
sessionId
jwtToken
cookie jar
fp response
challenge st
challenge img
answer proof
vt
```

常见失败原因：

- `sessionId/jwtToken` 是旧的
- `st` 来自上一轮题面
- 题面图片和 answer proof 不是同一轮
- `vt` 被浏览器或上一轮请求消费
- `test.py` 与浏览器或其它请求共用/污染 cookie 状态
- `code.js` split runtime 后 records/fpt/instance 状态断裂

### `/api/check` 双阶段

`/api/check` 可能既用于题面阶段，也用于答题阶段。

题面阶段可能返回：

```text
code=0
tp=30 或 tp=26
img=...
st=...
```

答题阶段成功才返回：

```text
code=0
vt=...
```

因此 `check_challenge code=0` 不能当作验证通过。

### 失败码

`code=16807`、`s_code=16130`、`验证失败，请重新验证` 通常优先排查：

- offset 或 angle 错误
- 轨迹过线性、点数不合理或端点不自然
- `A.list` / `touchList` / `track` 与 offset 不一致
- `tk/ct/cs` 由不同 runtime 或旧状态生成
- `st`、`fp`、`sessionId`、Cookie 不同轮
- `ct/tk/cs` 入参顺序或 `encodeURI(JSON)` 形态不一致

不要先归因到登录 `h5st`、`aksParamsU/B` 或账号态。

## 补环境难点

### JCAP 运行时不是普通函数直调

JCAP 需要真实走实例化链路：

```text
window.jdCAP.captcha(info)
→ captchaFactory(option)
→ instance.create(createOption)
→ DOM 渲染题面和滑块/旋转组件
→ 派发 mousedown/mousemove/mouseup
→ 内部生成 proof
→ XHR/fetch 边界收集 /api/check
```

只找到加密函数或只重算 `tk` 不够；轨迹 proof、records、fpt、instance 状态都可能参与。

### DOM layout 影响 proof

滑块和旋转题会读取元素尺寸和坐标：

```text
slider.clientWidth
drag_box.clientWidth
main_img.width
slot_img.width
element.getBoundingClientRect()
event.clientX / clientY
```

本地 DOM 不能只返回空对象，需要给目标链路触达的元素合理 layout。`tp=30` 和 `tp=26` 的轨道宽度不同，不要混用。

### native 外观和宿主对象

需要维持浏览器外观：

- `Function.prototype.toString` native-like
- DOM 构造器和 prototype 链
- `addEventListener/removeEventListener/dispatchEvent`
- `document.createElement/querySelector/getElementById`
- `Image`、`canvas`、`style`、`classList`
- `Date`、`performance.now`、`Error.stack`
- `localStorage/sessionStorage/cookie`

但不要一次性补全整个浏览器。先用 v8trace 暴露缺口，再用当前目标 `ruyitrace/domtrace/descriptor` 校对真实外观。

### 不走 VMP 内部

即使 JCAP JS 混淆严重，也不要在 VMP/opcode/handler 内部插桩、改 handler 或写 VM tracer。允许的定位面是：

- 公开入口 `jdCAP.captcha`
- DOM/BOM 宿主对象
- XHR/fetch 请求边界
- `JSON.stringify` 外围调试
- 当前 trace 的 jscall/domtrace/http_packet 证据

## `tp=30` 滑块处理

`tp=30` 常见图片：

```text
img.b1 = 背景大图
img.b2 = 滑块小图
```

答案识别只是第一步。最终提交需要 JCAP 内部 proof：

```text
{
  ht,
  wt,
  bw,
  sw,
  mw,
  list,
  ii,
  ...版本噪声键
}
```

本会话经验：

- PIL 深色组件识别对当前 `tp=30` 样本更稳定
- 视觉 API 可作为 fallback，但容易因提示词、模型拒答或目标框解释偏差导致 offset 偏移
- 轨迹不能过短或完全机械线性
- 成功样本中 trace-like 轨迹比单纯直线拖动稳定
- offset 正确但轨迹/proof 不自然仍可能 `16807`

校验建议：

```text
1. 保存 b1/b2。
2. 人眼或 PIL/视觉确认 offset。
3. 生成轨迹并触发真实 JCAP drag。
4. 调试抓取 proof：ht/wt/bw/sw/mw/list/ii。
5. 发送第二次 /api/check。
6. 只以 code=0 且 vt 非空为成功。
```

## `tp=26` 旋转处理

`tp=26` 源码特征：

```text
rotate_img
drag_box
slider
slide_path
mouseXyzList
sliderXyzList
```

提交 proof 常见形态：

```text
{
  bw: slider.clientWidth,
  sw: drag_box.clientWidth,
  track: mouseXyzList,
  list: sliderXyzList,
  ii: H()
}
```

拖动距离和旋转角关系：

```text
max_offset = drag_box.clientWidth - slider.clientWidth
angle = offset / max_offset * 360
offset = angle / 360 * max_offset
```

本会话当前版本实测参数：

```text
trackWidth = 267
sliderSize = 48
max_offset = 219
```

注意事项：

- 视觉 API 返回的角度必须确认是“顺时针校正角”，不是“当前偏转角”
- 如果视觉直接返回 offset，需要 clamp 到 `[0, 219]`
- `tp=26` 不应沿用 `tp=30` 的 `trackWidth=290`
- `tp=26` 不应使用 `tp=30` 的 trace-like 拼图轨迹模板，线性或平滑旋转轨迹更符合组件
- 没有 fresh 在线 `tp=26` 题面时，只能验证轨迹产参路径，不能宣称在线通过

## 视觉 API 难点

视觉 API 只负责图片层答案，不负责：

- token
- cookie
- session
- `ct/tk/cs`
- proof 结构
- 事件轨迹
- 最终业务放行

本会话遇到的问题：

- 只检查进程环境变量会误判“没有 key”；需要可选读取本地 Codex 配置
- 默认模型名可能被本地 OpenAI-compatible base 拒绝或返回 `502`
- 直接使用 CAPTCHA 字样可能触发模型拒答
- 中性“图像几何测量 / alignment”提示更适合返回结构化 offset/angle
- 即使视觉能返回 offset，`tp=30` 已稳定时仍建议 PIL 优先，避免引入额外误差

推荐环境读取顺序：

```text
VISION_API_KEY / OPENAI_API_KEY
VISION_API_BASE / OPENAI_BASE_URL
VISION_MODEL / OPENAI_VISION_MODEL
C:\Users\mile\.codex\config.toml
C:\Users\mile\.codex\auth.json
```

不要在日志中回显 key。

## 调试抓取点

建议保留 debug-only 抓取，不影响正式产参：

```text
JSON.stringify 包装，仅抓 touchList、ht/wt、bw/sw、track/list、rec/fpt
```

用于确认：

- 当前是否进入 answer proof
- `tp=30` 是否生成 `ht/wt/bw/sw/mw/list/ii`
- `tp=26` 是否生成 `bw/sw/track/list/ii`
- proof 点数和长度是否在合理区间
- 第二次 `/api/check` 是否确实由拖动后触发

调试 wrapper 只能在外围 `JSON.stringify` 层，不要进入 VMP/opcode。

## 本会话实测结论

环境：

```text
目标目录：D:\京东滑块
脚本版本：https://storage.360buyimg.com/jsresource/jcap/version/v2.8.5/1/jcap_ujb96b.js
任务类型：captcha / hybrid 前置
会话编号：019f2e52-4e91-7440-858d-179f6395a4f7
```

`tp=30`：

```text
真实在线完整验证 5 次
全部下发 tp=30
4 次 code=0 且 vt_len=192
1 次 code=16807，原因归类为图片 offset 识别偏差
```

`tp=26`：

```text
--prepare-only 自然采样 20 次
全部下发 tp=30
未采到 fresh tp=26 在线题面
```

本地合成 `tp=26` 轨迹产参验证：

```text
将保存题面 challenge.tp 改为 26
offset = 110
生成 2 个 /cgi-bin/api/check 请求
第二次请求字段长度：tk=5490, ct=1906, cs=2439
proof 命中：bw=48, sw=267, track=[...], list=[...]
```

因此本会话可确认：

- `tp=30` 已真实在线通过
- `tp=30` 成功不是 trace 响应重放，而是当前在线动态生成请求后返回新 `vt`
- `tp=26` 轨迹/proof 生成链路可走
- `tp=26` 尚未真实在线 `vt` 验收，因为当前登录链路未自然下发 fresh `tp=26`

## 推荐实现结构

```text
solve_challenge_offset(challenge)
→ if tp=30: PIL 优先识别 offset，必要时视觉 fallback
→ if tp=26: 视觉识别 angle/offset，angle 转 offset
→ save images and solve_info

run_code_bridge()
→ same VM runtime
→ send fp request
→ receive challenge
→ solve offset
→ setInput by tp
→ driveSlider
→ send answer check
→ verify vt
```

`tp` 分支参数建议：

```text
tp=30:
  trackWidth=290
  captchaWidth=290
  captchaHeight=179
  trace-like human path
  hold/endY/releaseY 保持滑块题形态

tp=26:
  trackWidth=267
  sliderSize=48
  maxOffset=219
  pathMode=linear 或平滑旋转轨迹
  holdMs=0
```

## 常见流程错误

- 用 trace 的 `code=0/vt` 当成本地成功，而不是重新在线提交。
- 只做到 `check_challenge code=0` 就停止。
- 固定旧题面和旧 `st`，却宣称动态通过。
- 把 `tp=30` 的轨道宽度、轨迹模板套到 `tp=26`。
- 视觉 API 返回角度后未区分当前角和校正角。
- `tp=30` 已经 PIL 稳定时强行改用视觉，造成 offset 偏差。
- split runtime 导致 instance 内部 records/fpt 状态断裂。
- 看到 `16807` 先补 DOM/BOM，而不是先核对 offset、proof、同轮状态。
- 在 VMP 内部插桩寻找 proof 生成函数。

## 交付记录要求

命中本文场景时，进展清单或阶段输出至少记录：

- 是否读取 `jd_jcap.md` 和 `jd_jcap_slider.md`
- 当前 JCAP 脚本 URL 和版本
- 题型 `tp`
- 题面图片保存路径
- offset 或 angle 来源
- `tp=30` 的 `ht/wt/bw/sw/mw/list/ii` 是否生成
- `tp=26` 的 `bw/sw/track/list/ii` 是否生成
- 第二次 `/api/check` 的 `code`、`s_code`、`msg`、`vt_len`
- 成功判定是否来自当前在线响应，而不是 trace 样本
- 如果未在线验收 `tp=26`，必须明确写“未采到 fresh 题面”或具体失败响应
