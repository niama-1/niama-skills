## 登录态状态型业务链路工作流

本文只在阶段 0-3 判定目标类型为 `full_flow`，且链路更像登录态业务动作而不是验证码 / challenge 链路时读取。典型场景包括私信发送、评论、发布、下单、领券、创建会话、创建草稿、提交审核、关注/取关、点赞等主动业务动作。

如果链路明确出现验证码题面、滑块、点选、九宫格、多宫格、`vt`、`validate` 或验证码通过凭证，优先读取 `workflow-captcha-chain.md`；如果同一任务同时存在验证码和登录态业务状态，两份文档都要读取，但职责必须分清：验证码文档处理通过凭证，本文处理业务状态机和最终动作。

如果链路包含 WebSocket / WSS / 长连接 / 二进制帧 / protobuf / 心跳 / ACK / 回执 / 推送同步 / 自动回复，继续读取 `workflow-websocket-business-flow.md`；本文负责业务状态机，WebSocket 文档负责协议连接、帧结构、心跳、ACK 和重连。

## 目标子类型

```text
full_flow_stateful_business
= 登录态下的状态型业务动作，依赖账号态、目标对象、业务对象状态、动态 token、风控 header、行为上报和最终业务接口。

full_flow_protocol_business
= 带 SDK / protobuf / WS / 长连接 / 会话创建 / 回执状态的业务协议链路。

full_flow_guarded_send
= 发送、私信、评论、发布、下单等主动动作，重点是行为一致性、设备/票据材料、目标对象和服务端状态。
```

这些子类型可以同时命中。例如抖音 Creator 私信发送通常同时命中 `full_flow_stateful_business`、`full_flow_protocol_business` 和 `full_flow_guarded_send`。

## 通用业务链

阶段 0-3 必须尽量整理成这条链：

```text
页面入口 / 已登录会话
-> 用户触发动作
-> 当前账号身份确认
-> 目标对象确认
-> 业务对象状态确认
-> 前置动态安全材料
-> 行为一致性 / 风控上报
-> 最终业务接口
-> 服务端状态 / 回执 / 实际到达验证
```

不要一开始就只找“签名函数”。这类任务的失败点经常不是单个参数，而是账号态、目标对象、会话状态、动态票据、行为上报和最终动作之间没有同轮对齐。

## 必须确认的状态

```text
账号态
= Cookie、登录态、当前账号 UID / user_id / sec_uid / device_id / webid / session 绑定关系。

目标对象
= 对方 UID、商品 ID、订单 ID、草稿 ID、作品 ID、会话 ID、发布目标或其它业务对象。

业务状态
= conversation、conversation_short_id、ticket、order token、draft token、publish token、read_index、cursor、sequence、server id 等。

协议连接态
= WebSocket URL、前置 token、auth/register/init 包、heartbeat、ACK、message id、mid、uri、lwp、cmd、sync 状态等。

动态安全材料
= identity token、csrf、ticket guard、device token、行为 token、access key、风控 header、加密 body、签名 query。

行为上报
= action report、consistency report、埋点、前置预检、mark_read、初始化接口等。

成功口径
= HTTP 200 只是传输成功；必须继续确认业务 code、服务端 ID、回执、状态变更、实际到达或后续查询结果。
```

## ruyitrace / jscall 优先观察点

优先顺序：

```text
1. http_packet / index.jsonl
   确认最终业务接口、前置接口、上报接口、初始化接口、创建对象接口、查询状态接口。

2. jscall
   定位触发动作、fetch/XHR 发起栈、SDK 调用、protobuf encode/decode、动态 token 生成、header 注入、行为上报。

3. cookie / storage
   确认登录态、账号 ID、device/session 绑定、安全材料线索和本地缓存状态。

4. eval / async chunk
   固定业务 SDK、Action/Consistency 管理器、协议编解码、目标对象转换函数、签名或加密模块。

5. profile
   只在需要时定向读取 SQLite、IndexedDB、LocalStorage 或安全材料线索；不得把整个 profile 当全文日志读取。
```

## 阶段输出要求

阶段 0-3 输出必须包含：

```text
目标类型:
full_flow 子类型:
用户触发动作:
当前账号身份字段:
目标对象字段:
业务对象状态字段:
前置动态安全材料:
行为上报 / 预检接口:
最终业务接口:
最终业务 body / protobuf / SDK command:
WebSocket / 长连接节点:
成功口径:
失败口径:
是否存在验证码链:
是否存在产品命中特征:
```

如果缺少 `SELF_UID`、`TARGET_UID`、`conversation_short_id`、`ticket`、order token、draft token 等状态字段，不要用旧 trace 的固定值直接填充新目标。必须先找到对应的初始化、查询、创建或转换接口。

## 本地实现原则

- 最终交付脚本的外部输入应该尽量收敛为用户真实能提供的业务输入，例如 Cookie、自己 UID、目标 UID、发送内容、商品 ID、订单 ID。
- 旧 trace 只能作为开发证据，不应该成为交付脚本运行依赖。
- 不要保留 `ruyitrace`、`TRACE_DIR`、`DY_TRACE_DIR` 这类本地采样路径作为默认运行依赖。
- 动态 token、ticket、guard header、行为上报 payload 应尽量由脚本同轮生成或刷新。
- 如果某些材料绑定浏览器环境且无法从 Cookie 自动恢复，必须明确标记为“同环境绑定材料”，不要说成通用配置。
- `code.js` / `runtime/*.code.js` 只保留生成目标材料的稳定入口；真实请求编排由 `test.py` 负责。

## 验证重点

验证不能只看请求有没有发出。必须至少确认：

- 最终业务接口命中真实目标 URL。
- headers / cookies / body / query 与当前账号、当前目标、当前业务状态一致。
- 动态安全材料是 fresh 的，不是旧 trace 固定值。
- 服务端返回业务成功状态，而不是风控、审核、空 ID、降级、异步处理中或静默失败。
- 对主动动作类任务，确认服务端 ID、回执、状态查询或实际到达。
- 换目标对象、换账号或无历史状态时，仍能走初始化 / 创建 / 查询链路拿到新状态。

## 常见坑

- 把 `full_flow` 默认理解成验证码链，导致一直找 challenge，却忽略业务状态机。
- 把 HTTP 200 当成最终成功。
- 复用旧 trace 的 conversation、ticket、order token、draft token、read_index、cursor、server id。
- 从 Cookie 中猜账号 UID，但该字段并不是纯数字业务 UID。
- 有目标名称或短 ID 时，跳过目标对象转换接口，直接当作业务 UID 使用。
- 只实现最终接口，漏掉初始化、创建对象、行为上报或 mark/read/precheck。
- 把环境绑定材料套给另一个 Cookie、另一个账号或另一个浏览器 profile。
- 交付脚本依赖本地 trace 文件，导致给别人无法运行。

## 产品文档命中

出现安全产品、风控 header、动态 token、验证码、签名、加密、行为上报或平台特征时，必须先读 `references/products/index.md` 并命中对应产品。

例如出现抖音 Creator IM 私信特征时，读取：

```text
references/products/dy_creator_im.md
```

如果同链路还出现 `a_bogus`、`msToken`、`webmssdk`、`sdk-glue`、`bdms`、`SecureSDK`、`web_protect`，同时读取：

```text
references/products/dy_abgous.md
```

商家后台 WebSocket / 长连接类任务可按特征读取：

```text
references/products/jd_daojia_ws.md
references/products/ele_accs_lwp.md
references/products/mt_waimai_ws.md
```
