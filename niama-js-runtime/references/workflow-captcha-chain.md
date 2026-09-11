## 验证码 / Challenge 请求链工作流

本文件只在阶段 0-3 判定目标类型为 `验证码`、`签名+验证码`，或 `完整业务链` 明确包含验证码 / challenge 子链时读取；典型证据包括验证码、challenge、滑块、点选、九宫格/多宫格、行为验证、`validate`、`vt`、`tp/img`、验证码 ticket、业务中途验证码拦截。

验证码链路不是普通签名参数链。必须先明确验证码触发点、题面、行为证明、提交校验、通过凭证、凭证注入位置和最终业务验证口径，再决定是否补环境。

## 目标分类

```text
登录验证码
= 登录前或登录中验证码，例如账号密码提交前出现滑块、图形验证码、短信前置验证

业务中途验证码
= 登录后或已有业务会话中，翻页、搜索、详情、下单、领券等业务请求被验证码拦截

登录签名+验证码
= 登录验证码通过凭证 + 登录签名 / 加密，例如 vt + h5st/_stk + aksParamsU/B

业务签名+验证码
= 业务中途验证码通过凭证 + 业务签名 / 加密，例如 validate + h5st / x-sign / encrypted body
```

## 通用请求链

阶段 0-3 必须尽量整理成这条链：

```text
页面入口 / 已登录会话 / 原业务动作
→ 原业务请求或登录请求
→ 拦截响应 / challenge 上下文
→ 验证码初始化接口
→ 验证码 JS / WASM / worker / iframe 资源
→ 题面接口
→ 题面响应：图片、题型、traceId、sessionId、riskId、st、token
→ 行为答案：滑块 offset、点选坐标、九宫格格子序号/坐标、轨迹、点击、设备/环境证明
→ 提交校验接口
→ 通过凭证：vt / ticket / validate / token / cookie / header
→ 凭证注入：Header / Cookie / Query / Body / Storage / 后续 JS 状态
→ 回到登录接口或原业务接口验证是否真正放行
```

验证码提交接口成功只是中间口径。最终口径必须是后续登录接口或原业务接口真正放行。

## 阶段输出要求

验证码任务阶段 0-3 结束时必须输出：

```text
验证码触发点:
原业务请求:
拦截响应:
challenge 上下文字段:
验证码初始化接口:
验证码题面接口:
验证码提交校验接口:
验证码资源脚本:
题型字段:
题面字段:
行为答案字段:
通过凭证字段:
凭证注入位置:
后续验证请求:
成功口径:
失败口径:
code.js / runtime 负责:
test.py 负责:
```

## 登录验证码

登录验证码常见链路：

```text
登录页
→ 读取 hidden fields / cookie / storage / public key
→ 获取验证码 session / challenge 上下文
→ 初始化验证码 SDK
→ 拿题面
→ 提交答案证明
→ 拿通过凭证
→ 注入登录 plain body 或 header/cookie
→ 生成登录签名 / 加密参数
→ 提交登录接口
```

成功口径：
- 验证码校验接口返回通过凭证
- 登录接口不再返回图形验证码、滑块、challenge 或验证码参数错误
- 登录接口进入账号密码错误、安全验证、登录成功或其它业务层响应

失败口径：
- 验证码校验接口返回验证失败
- 登录接口返回验证码参数校验失败
- 通过凭证为空、过期、被消费或与 session/cookie 不同轮

## 业务中途验证码

业务中途验证码常见链路：

```text
已有登录态 / 业务会话
→ 发起翻页、搜索、详情、下单、领券等原业务请求
→ 服务端返回 challenge、验证码页、短 HTML、403、业务错误码或验证配置
→ 按拦截响应提取 captchaId / riskId / scene / sessionId / token / traceId
→ 初始化验证码并拿题面
→ 提交答案证明
→ 拿 pass token / ticket / validate / cookie / header
→ 注入原业务请求
→ 重放或继续原业务请求
→ 原业务接口返回正常业务数据
```

成功口径：
- 验证码提交接口通过
- 原业务请求不再返回 challenge / 验证码页 / 风控错误
- 原业务请求返回正常列表、详情、下单结果、领券结果或目标业务 JSON

失败口径：
- 验证码接口通过但原业务请求仍被拦截
- pass token 注入位置错误
- token 与原业务请求的 cookie、UA、IP、TLS、session、riskId 不同轮
- 原业务请求签名 / 加密参数与验证码通过凭证不同步

## 题面与答案

先确认题型：

```text
slider      = 滑块 / 拼图
click       = 点选 / 文字点选 / 图标点选
grid        = 九宫格 / 多宫格 / 选择包含目标的格子 / 按格子顺序点击
rotate      = 旋转
logic       = 问答 / 语义 / 顺序点击
behavior    = 无显式图片，主要提交行为轨迹和环境证明
unknown     = 证据不足
```

九宫格 / 多宫格必须作为独立题型记录，不要简单归入普通点选。优先从 trace 和请求链判断：

```text
http_packet: rows / cols / grid / cell / tile / matrix / question / prompt / imageList / 9 张图或多张图
jscall: 提交字段是否为 cell index、row/col、点击坐标列表、顺序列表或加密后的答案对象
event/domtrace: 是否存在多个格子的 click listener，格子中心点如何换算成提交坐标
```

题面字段常见：

```text
img
bg
piece
b1 / b2
tp
captchaId
traceId
sessionId
st
token
```

答案通常不只是坐标。必须确认当前 JS 需要的结构：

```text
offset / points / click list
grid index list / row-col list / cell center points
轨迹 list
touchList / mouseList / pointerList
时间戳和耗时
设备 / 环境证明
采集记录 rec
脚本路径或文件路径 fpt
```

轨迹可能影响提交校验接口的证明字段和签名长度，是否影响必须以当前目标的 JS 入参、请求体和浏览器样本为准。滑块、点选、九宫格等任务在证据表明轨迹参与证明或签名时，需要记录并对齐：

```text
轨迹点数量
轨迹总耗时和采样间隔
起点 / 终点 / 中间抖动
touchList / mouseList / pointerList 与答案对象的同轮关系
JSON.stringify / encodeURI / base64 / 加密前后的长度级别
校验接口中 tk / ct / cs / proof / sign 等字段的长度级别
```

不要为了“看起来像轨迹”随意压缩、补点、排序或平滑轨迹。offset 正确但校验失败时，如果浏览器样本显示轨迹参与证明或签名，应检查轨迹长度、时间节奏和编码后证明长度；不要直接判为图片识别错误或签名算法错误。

solver、OCR 或三方打码平台只产出原始答案，例如滑块 offset、点选坐标、九宫格格子序号、row/col、文字或角度；不得把 solver 结果直接视为验证码通过。

只识别图片 offset、点选坐标或九宫格格子序号不等于验证码通过。必须把原始答案转成当前脚本要求的答案对象、点击列表、轨迹和行为证明。

## 通过凭证

通过凭证可能在这些位置：

```text
响应 JSON 字段：vt / ticket / validate / token / passToken / captchaToken
Set-Cookie
响应 header
localStorage / sessionStorage
内存回调参数，例如 onSuccess(payload)
后续请求 body/query/header 中的新字段
```

必须记录：

```text
凭证字段名:
凭证来源接口:
凭证有效期:
是否单次消费:
是否绑定 session/cookie/UA/IP/TLS:
注入到哪个请求:
注入位置:
```

如果凭证被浏览器现场先消费，本地重放失败不能直接判为算法错误；先检查单次消费、短时效和同轮绑定。

## 混合链

如果验证码通过后还需要签名或加密：

```text
验证码通过凭证
→ 注入 plain body / header / cookie
→ 再生成签名 / 加密
→ 发送业务请求
```

常见错误：
- 先生成签名，再把验证码 token 塞进 body，导致签名摘要没有覆盖 token
- 验证码 token 来自旧会话，签名来自新会话
- 验证码成功但业务请求仍被拦截，被误判为签名错误
- 签名正确但验证码 token 已消费，被误判为补环境缺口

混合链验证顺序：

```text
1. 验证验证码 token fresh 且同轮可用
2. 验证 token 已进入签名前的原始请求材料
3. 验证签名 / 加密覆盖的字段与浏览器一致
4. 验证最终业务接口是否进入业务层
```

## code.js / runtime 与 test.py 分工

`code.js` 或 `runtime/*.code.js` 负责：
- 运行目标验证码 JS 或签名 JS
- 生成验证码请求体、行为证明、签名、加密片段
- 暴露稳定入口 `get_xxx(input)`
- 输出结构化 JSON，供 `test.py` 调用

`test.py` 负责：
- 维护 session、cookie、headers、proxy、TLS/HTTP 客户端
- 请求验证码初始化和题面
- 保存图片或题面材料
- 调用 solver 或构造答案输入
- 调用 Node 入口生成证明字段
- 发送提交校验接口
- 拿通过凭证并注入后续请求
- 发送登录接口或原业务接口并判断最终成功口径

验证码任务中，真实请求不得长期放进 `code.js`；`code.js` 只负责本地 JS 逻辑和请求片段生成。

## 多 runtime 建议

同一个任务有多个 JS runtime 时，使用：

```text
runtime/
├── captcha_xxx.code.js
├── sign_xxx.code.js
├── encrypt_xxx.code.js
└── fingerprint_xxx.code.js
```

命名建议：

```text
runtime/jcap.code.js
runtime/h5st.code.js
runtime/aks.code.js
runtime/business_encrypt.code.js
```

每个文件必须只负责一个参数族或链路片段，并暴露稳定入口：

```js
get_jcap_request(input)
get_jcap_proof(input)
get_h5st(input)
get_aks_login_request(input)
get_business_encrypt(input)
```

`test.py` 编排多个入口的调用顺序。不要让多个 runtime 文件互相隐式调用，除非在 `param_info.md` 中明确依赖关系。

## 交付检查

交付前必须确认：
- 目标类型已记录
- 验证码触发点已记录
- 请求链已经从触发点写到最终业务验证
- 通过凭证来源和注入位置已记录
- 验证码成功口径和最终业务成功口径分开记录
- 多 runtime 项目已有目标矩阵
- `param_info.md` 写清每个目标的文件、入口、输入、输出和验证口径
- `test.py` 能从头编排到用户要求的目标范围：只验证码、只签名、混合链或全流程
