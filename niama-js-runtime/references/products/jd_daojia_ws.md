# JD 到家 / 京东外卖商家 WebSocket 参考

本文用于识别京东到家 / 京东外卖商家后台的订单推送 WebSocket 链路。该链路通常属于 `full_flow_protocol_business`，并常与京东 `h5st` 签名链路组合出现。

本文只记录链路结构和观察点，不记录任何真实 Cookie、token、nonce、店铺号、订单号或账号值。

## 命中特征

- `wss://ws1-dd.jd.com/`
- `store.jddj.com`
- `sff.jddj.com/api`
- `dsm.o2o.order.dongdong.token.query`
- `dsm.o2o.order.dongdong.update.connect`
- `dsm.o2o.order.cater.pcAllOrderListQuery`
- `dsm.o2o.order.cater.pickOrder`
- `open.msshop.cc`
- `open.msplatform.cc`
- `h5st`
- `x-rp-client`
- `dsm-eid`
- `auth`
- `auth_result`
- `client_heartbeat`
- `chat_message`
- `ack`
- `failure`
- `waiterPin`
- `eIdMd5`
- `nonce`
- `stationId` / `stationNo`

如果同链路出现京东 `h5st/_stk/request_algo/tk03`，同时读取 `references/products/jd.md`。

## 典型链路

```text
完整商家后台 Cookie
-> 通过 h5st 签名请求 dsm.o2o.order.dongdong.token.query
-> 获取 waiterPin、eIdMd5、token、nonce
-> 构造 wss://ws1-dd.jd.com/?appId=open.msshop.cc&clientType=comet&token=...&nonce=...
-> WebSocket 连接
-> 发送 type=auth，body.token=token
-> 收到 auth_result
-> 上报 dsm.o2o.order.dongdong.update.connect 在线状态
-> 定时发送 type=client_heartbeat
-> 收到 chat_message 订单推送
-> 发送 receive ack
-> 解析订单提醒、订单号、配送站、买家、消息序号
```

## 关键观察点

- `h5st` 是连接前 HTTP token 请求和在线状态上报的关键前置，不是 WebSocket 帧内字段。
- `token`、`nonce` 需要从当前 Cookie 同轮获取，不应复用旧 trace。
- WebSocket URL 的 `_wid_`、`token`、`nonce` 是动态上下文。
- `auth_result` 后才算业务鉴权成功，101 握手成功不等于订单推送可用。
- `client_heartbeat` 是业务层 JSON 心跳，不能只依赖 WebSocket 库的 ping。
- `chat_message` 里可能嵌套订单模板数据，需要从 body/template/payload 中提取订单字段。
- 收到订单推送后需要发送业务 ACK，避免后续推送或状态异常。
- 账号冲突或其它页面占用时可能返回 `errorCode=4281`。

## 与 HTTP 业务接口关系

该链路通常与 HTTP 订单接口配合：

```text
dsm.o2o.order.cater.pcAllOrderListQuery
= 主动拉取订单列表，适合补单和校验推送。

dsm.o2o.order.cater.pickOrder
= 对订单执行出餐动作。
```

这类 HTTP 接口仍需要当前 Cookie、完整 headers 和 `h5st`。不要把 WebSocket 推送里的订单号直接视为已完成业务动作，订单操作需要走对应 HTTP 接口并验证服务端返回。

## 常见坑

- 只复制 `wss://ws1-dd.jd.com/`，漏掉前置 `token.query`。
- 用 `document.cookie` 或裁剪 Cookie，导致 token 请求 401。
- `h5st` 使用旧值或没有覆盖当前 API/body。
- `auth_result` 未成功就开始等订单。
- 忽略 `update.connect` 在线/离线状态上报。
- 忽略 `ack`，只打印推送。
- 多窗口或多客户端占用同一客服账号导致账号冲突。
- 固定旧 `stationId`、`stationNo`、订单号或 `waiterPin`。

## 验证口径

成功至少需要确认：

- token 请求成功，并获得当前登录态对应的 `token` / `nonce`。
- WebSocket 握手成功并收到 `auth_result`。
- 心跳有业务层 ACK。
- 收到 `chat_message` 后能解析订单字段并发送 ACK。
- 通过订单列表或订单详情 HTTP 接口能交叉验证订单存在。

