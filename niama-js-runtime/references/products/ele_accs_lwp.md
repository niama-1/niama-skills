# 饿了么商家 ACCS / DingTalk LWP WebSocket 参考

本文用于识别饿了么商家后台的 ACCS 通知通道与 DingTalk IMPaaS LWP 业务通道。该链路通常属于 `full_flow_protocol_business`，自动回复或消息发送时也命中 `full_flow_guarded_send`。

本文只记录链路结构和观察点，不记录任何真实 Cookie、ksid、shopId、deviceId、loginToken、groupId 或消息内容。

## 命中特征

- `ws-msgacs.m.taobao.com/accs/auth`
- `wss-cntaobao.dingtalk.com`
- `ACCS_H5`
- `getAccsToken`
- `AuthCenterService.getToken`
- `app-api.shop.ele.me/fulfill/device/controller/getAccsToken/`
- `alsc-im-paas.AlscImPaasService.getLoginToken`
- `imPaaS2LoginToken`
- `LWP`
- `/reg`
- `/s/sync`
- `/r/MessageSend/sendByReceiverScope`
- `app-key`
- `did`
- `wv=im:3,au:3,sy:6`
- `sync`
- `mid`
- `cid`
- `conversationType`

## 双通道模型

饿了么商家 IM 常见是双通道：

```text
ACCS 通道
= ws-msgacs.m.taobao.com/accs/auth?token=...
= 更偏通知、信号、业务唤醒。

DingTalk LWP 通道
= wss-cntaobao.dingtalk.com
= /reg 注册后承载真正业务消息、同步、发送消息。
```

不要把 ACCS 能收到通知误判为已经具备发送消息能力。文本发送通常走 LWP 的 `/r/MessageSend/sendByReceiverScope`。

## 典型链路

```text
商家 Cookie / ksid / shopId / deviceId
-> HTTP getAccsToken
-> 连接 ws-msgacs.m.taobao.com/accs/auth?token=...
-> 接收 ACCS 通知并 ACK

商家 Cookie / ksid / shopId / deviceId
-> HTTP getLoginToken
-> 取 imPaaS2LoginToken
-> 连接 wss-cntaobao.dingtalk.com
-> 发送 /reg 注册包
-> /reg 返回 code=200
-> 每 15 秒发送 /! 心跳
-> 接收 LWP 推送或 /s/sync 同步信号
-> 必要时 getState / ackDiff 补拉和确认
-> 使用 /r/MessageSend/sendByReceiverScope 发送文本
```

## LWP 注册包观察点

典型 `/reg` headers 字段：

```text
cache-header: app-key token ua wv
app-key
token = imPaaS2LoginToken
ua
dt
wv
sync
did
subscribe-server-push
```

这些字段应来自当前登录态和当前设备环境。不要复用旧 `imPaaS2LoginToken` 或旧 `did`。

## 发送消息观察点

发送文本常见接口：

```text
/r/MessageSend/sendByReceiverScope
```

典型 body 结构：

```text
[
  {
    uuid,
    cid,
    conversationType,
    content: {
      contentType,
      text: { content, extension }
    },
    redPointPolicy,
    extension,
    ctx,
    mtags,
    msgReadStatusSetting
  },
  {
    actualReceivers
  }
]
```

`cid` 通常是当前客户会话 / groupId，必须从当前消息或会话列表动态取得。不要固定旧会话的 `cid`。

## 同步和 ACK

需要重点观察：

- ACCS 消息是否需要 ACK。
- LWP push 包是否需要返回 `code=200`。
- `/s/sync` 是否只是同步信号，需要进一步 `getState` / `ackDiff`。
- `mid` 如何匹配请求和响应。
- 发送消息返回是否只是请求成功，还是业务发送成功。

## 常见坑

- 只连 ACCS，不连 LWP，导致只能收到信号不能发消息。
- `/reg` 未成功就发送业务消息。
- `imPaaS2LoginToken`、`ksid`、`deviceId` 与 Cookie 不属于同一登录态。
- 固定旧客户 `cid` / groupId。
- 忽略 `/s/sync` 后的补拉和 `ackDiff`。
- 没有按 `mid` 匹配 LWP request/response。
- 只看 WebSocket 连接成功，不看 `/reg code=200`。

## 验证口径

成功至少需要确认：

- ACCS token 和 LWP login token 都能从当前 Cookie 获取。
- LWP `/reg` 返回 `code=200`。
- 心跳持续正常。
- 能解析当前客户会话 `cid`。
- 发送文本接口返回业务成功，并能在目标会话实际看到消息或收到服务端回执。

