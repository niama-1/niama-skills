# 美团外卖商家 WebSocket 参考

本文用于识别美团外卖商家后台 WebSocket 长连接、二进制协议和客服自动回复链路。该链路通常属于 `full_flow_protocol_business`，自动回复时同时命中 `full_flow_guarded_send`。

本文只记录链路结构和观察点，不记录任何真实 Cookie、token、device_uuid、wmPoiId、acctId、店铺名、账号名或消息内容。

## 命中特征

- `wss://wmdxlwss.meituan.com`
- `wpush_server_url`
- `waimaie.meituan.com`
- `wmPoiId`
- `acctId`
- `device_uuid`
- `pushToken`
- `token`
- `ByteBuffer`
- `MTDXPacket`
- `get_ws_data`
- `get_ws_base64`
- `get_message_base64`
- `send_init_packet`
- `send_auto_reply`
- `uri=196619`
- `uri=196620`
- `uri=196611`
- `TGData.summary`

## 典型链路

```text
商家 Cookie
-> 提取 wmPoiId、acctId、token、device_uuid、店铺/账号信息
-> WebSocket 连接 wss://wmdxlwss.meituan.com
-> onopen 后调用 JS get_ws_data(...) 生成初始化二进制包
-> 发送初始化包
-> 每 8 秒发送业务心跳 uri=196619
-> 收到服务端 uri=196620 pong / 探测包
-> 必要时回 uri=196611
-> 收到业务二进制消息
-> 用 MTDXPacket / ByteBuffer / protobuf 或 JSON 片段解析消息
-> 提取客户 UID、公共通道 ID、消息文本
-> 调用 JS get_message_base64(...) 生成回复二进制包
-> 通过当前 WS 发送自动回复
```

## 二进制协议观察点

常见包头结构：

```text
total_length: uint32 big-endian
uri: uint32 big-endian
appid: uint16 big-endian
payload: bytes
```

观察重点：

- `uri` 决定包类型。
- 心跳和业务消息使用不同 `uri`。
- payload 内可能混合二进制字段、protobuf、JSON 字符串和 UTF-8 文本。
- JS 生成初始化包和发送包时可能返回 base64，需要 Python 解码成 bytes 再发送。
- `websocket-client` 的 ping 与业务心跳不是一回事。

## 登录态和初始化

常见输入：

```text
wmPoiId
acctId
token
device_uuid
shop name
account name
```

这些字段必须来自同一 Cookie / 同一店铺 / 同一账号 / 同一设备环境。换店铺或换账号时，不能只替换局部字段。

初始化包通常由 JS 入口生成：

```text
get_ws_data(poi_id, acct_id, token, device_id)
```

发送消息包通常由 JS 入口生成：

```text
get_message_base64(pub_uid, receiver_uid, text, acct_id, acct_name, poi_id, shop_name)
```

## 消息解析和自动回复

重点确认：

- 是否能从标准 JSON / `TGData.summary` 中提取消息。
- 标准摘要不完整时，是否需要从二进制前缀扫描 UTF-8 文本兜底。
- 是否能区分客户消息、商家侧消息、系统事件、售后/评价等不应自动回复的消息。
- 当前客户 UID 和公共通道 ID 必须从当前消息动态解析。
- 自动回复不能使用固定旧 `pub_uid` / `receiver_uid`。

## 重连和稳定性

美团商家 WS 常见需要：

- 业务心跳线程。
- send lock，避免多个线程同时写 WS。
- 连接状态记录。
- 指数退避重连。
- 断线后重新连接、重新初始化、重新启动心跳。
- token 失效或 Cookie 失效时提示重新登录。

## 常见坑

- 只用 `wss://wmdxlwss.meituan.com` 握手成功，不发送初始化包。
- 使用旧账号/旧店铺的 `get_ws_data` 初始化结果。
- `device_uuid` 没加实际页面使用的前缀或格式不一致。
- 把业务心跳和 WebSocket ping 混淆。
- 二进制包大小端、长度字段或 `uri` 解析错误。
- 自动回复固定旧客户 UID，导致回复错人。
- 没过滤商家自己发出的消息，造成循环回复。
- 日志打印完整 Cookie、token、店铺账号字段。

## 验证口径

成功至少需要确认：

- WS 握手成功后初始化包发送成功。
- 心跳和服务端探测回包正常。
- 能解析当前客户消息。
- 能动态提取回复所需的两个会话目标 ID。
- 发送回复二进制包后，目标会话实际收到或服务端有可验证回执。
- 换店铺/账号后，Cookie、店铺 ID、账号 ID、token、device_uuid 均同源。

