# WebSocket 业务协议链工作流

本文用于阶段 0-3 判定目标类型为 `full_flow`，且链路包含 WebSocket / WSS / 长连接 / 二进制帧 / ACK / 心跳 / 回执 / 推送同步 / 自动回复等协议状态时读取。它是 `full_flow_protocol_business` 的专项工作流，可与 `workflow-stateful-business-flow.md` 同时使用。

典型场景：

- 商家后台订单推送、客服消息、自动回复。
- IM / 客服 / 订单 / 配送状态的长连接通知。
- WebSocket 连接前需要 HTTP token、签名、设备 ID 或登录态。
- 连接后需要发送 auth、register、init、subscribe、heartbeat、ack。
- 消息体是文本 JSON、protobuf、自定义二进制协议或 SDK command。

## 判定特征

出现以下特征时，优先按 WebSocket 业务协议链处理：

```text
wss:// 或 ws://
new WebSocket(...)
WebSocket.OPEN / onopen / onmessage / onclose / onerror
ws.send / socket.send / _doSend
ping / pong / heartbeat / keepalive
ack / receive_ack / read_ack / client_heartbeat
binary frame / ArrayBuffer / Uint8Array / ByteBuffer / protobuf
cmd / uri / lwp / service / method / sequence / mid / message_id
register / /reg / auth / init / subscribe / sync / getState / ackDiff
reconnect / run_forever / ping_interval / ping_timeout
```

## 通用链路

阶段 0-3 必须尽量整理成这条链：

```text
页面入口 / 登录态
-> 连接前 HTTP 前置请求
-> 获取 token / loginToken / nonce / deviceId / 签名 / 会话状态
-> WebSocket 握手 URL、Origin、Cookie、Header、Subprotocol
-> onopen 后 auth / register / init / subscribe
-> 心跳策略：客户端主动心跳 / 服务端探测 / pong / ack
-> 消息接收：文本帧 / 二进制帧 / protobuf / 自定义协议
-> 业务消息解析：类型、会话、订单、发送人、内容、序号
-> ACK / 已读 / 同步确认 / 回执
-> 可选业务动作：自动回复、发送消息、接单、出餐、状态更新
-> 断线重连 / token 刷新 / 账号冲突处理
-> 成功口径验证
```

不要把“WebSocket 已连接”当作成功。成功口径至少要到业务层：能鉴权、能收到目标业务消息、能按协议 ACK、能发送业务动作并拿到服务端回执。

## 必须确认的字段

```text
连接入口
= WebSocket URL、query、Origin、Host、Cookie、User-Agent、Sec-WebSocket-Protocol、扩展参数。

前置材料
= HTTP token、login token、nonce、device id、shop id、account id、station id、h5st / a_bogus / x-sign 等签名或风控 header。

初始化包
= auth / register / init / subscribe 的 lwp、cmd、uri、headers、body、app-key、token、did、wv、sync。

心跳
= 频率、方向、opcode、uri / cmd、时间戳字段、服务端 ping 后是否必须回 pong。

消息协议
= 文本 JSON、二进制 header、长度字段、uri、appid、flags、protobuf schema、payload 编码、压缩或 base64。

业务字段
= conversation id、cid、groupId、orderId、stationNo、sender、receiver、mid、msgId、sequence、read_index。

ACK / 回执
= receive ack、read ack、sync ack、ackDiff、client_heartbeat ack、send receipt、failure code。

重连
= 断线原因、账号冲突、token 过期、指数退避、是否需要重新取 token 和重新 init。
```

## ruyitrace / jscall 观察顺序

优先看：

```text
1. http_packet / index.jsonl
   找 WebSocket 握手、101 Switching Protocols、连接前 token 请求、签名请求、初始化 HTTP 接口。

2. jscall
   定位 new WebSocket、onopen、onmessage、send、JSON.stringify、protobuf encode/decode、ArrayBuffer、Uint8Array、DataView。

3. eval / async chunk
   固定 WebSocket SDK、IM SDK、二进制协议类、protobuf 模型、send packet builder、heartbeat builder。

4. cookie / storage
   确认登录态、店铺/账号/设备字段、token、push token、device id、webid、station id、shop id。

5. event
   确认用户触发动作、消息事件、断线重连事件、visibilitychange 是否影响心跳或连接。

6. profile
   只在需要时定向读取 IndexedDB、LocalStorage、SQLite 或缓存中的 token / device / 会话状态。
```

## 本地实现建议

交付结构通常应拆成：

```text
code.js / runtime/*.code.js
= 只负责生成初始化包、发送包、签名、protobuf / 二进制片段等稳定材料。

test.py
= 负责 HTTP 前置请求、WebSocket 连接、auth/register/init、心跳、接收、ACK、发送和重连。

param_info.md
= 记录连接前置、WS URL、初始化包、心跳、消息类型、ACK、成功口径和失败口径。
```

本地脚本必须明确 `code.js` 和 `test.py` 的边界。不要把 WebSocket 长连接运行逻辑塞进 `code.js`；`code.js` 只产出协议材料，真实连接和业务编排由 `test.py` 负责。

## 验证重点

- HTTP 前置 token / 签名是否 fresh，且与当前 Cookie、店铺、账号、设备一致。
- WS 握手是否带正确 Origin、Cookie、Header、Subprotocol。
- onopen 后是否发送正确 auth/register/init 包。
- 心跳频率、payload 和服务端探测回包是否符合 trace。
- 收到业务消息后是否按协议 ACK，避免只接收不确认导致后续不推。
- 二进制协议是否按长度、大小端、字段顺序、protobuf schema 正确编解码。
- 自动回复或发送类动作是否使用当前消息动态解析出的会话/发送人/接收人，而不是固定旧 trace 值。
- 断线重连是否重新取必要 token、重新注册和恢复订阅。
- 成功口径是否到业务层：收到目标事件、发送回执成功、订单状态变化、服务端查询可见。

## 常见坑

- 只复制浏览器里最终的 `wss://` URL，漏掉连接前 token / nonce / 签名请求。
- 只看到 WebSocket 101 成功，就判断业务完成。
- 忽略 onopen 后的 auth/register/init 包。
- 心跳方向搞反：服务端 ping 需要客户端 pong，客户端心跳还需要服务端 ack。
- 忽略 ACK / read / sync 确认，导致能收到一条但后续不推。
- 把二进制 payload 当普通 UTF-8 文本直接解析。
- 固定旧会话 ID、订单 ID、sender、receiver、mid、sequence。
- 用另一个 Cookie、店铺、账号或设备 ID 的 token / push token / login token。
- `websocket-client` 自动 ping 与业务心跳混用，导致频率或 payload 不一致。
- 重连时只重连 WS，不刷新前置 token，不重新注册订阅。
- 日志打印完整 Cookie、token、loginToken、店铺账号信息。

## 产品文档命中

出现平台特征时必须同时命中对应 products 文档：

```text
京东到家 / 京东外卖商家 WS:
references/products/jd_daojia_ws.md

饿了么商家 ACCS / DingTalk LWP:
references/products/ele_accs_lwp.md

美团外卖商家 WebSocket:
references/products/mt_waimai_ws.md
```

如果链路还出现 `h5st`、`a_bogus`、验证码、ticket guard 或其它安全产品特征，继续按 `references/products/index.md` 命中对应产品。

