# Douyin Creator IM 私信链路参考

本文用于识别和处理抖音 Creator Web 私信发送链路。它属于 `full_flow` 类型：不是单个 `a_bogus` 参数，也不是单个 WebSocket 连接，而是 Cookie 会话、会话创建/初始化、identity token、ticket guard、action_report、IM HTTP 接口和可选 WS 观察共同组成的完整业务链路。

本文只记录链路结构、观察点和常见坑，不记录任何真实 Cookie、token、私钥、`guard_material`、会话票据或账号专属值。命中新目标时仍必须以当前目标的 `ruyitrace/`、`jscall`、`http_packet` 和真实请求响应为准。

## 命中特征

出现以下特征时，优先命中本产品文档：

- `imapi.douyin.com/v1/message/send`
- `imapi.douyin.com/v2/message/get_by_user_init`
- `imapi.douyin.com/v2/conversation/create`
- `imapi.douyin.com/v3/conversation/mark_read`
- `frontier-im.douyin.com/ws/v2`
- `creator.douyin.com/passport/safe/get_identity_security_token/`
- `creator.douyin.com/aweme/v1/im/consistency/action/report`
- Header 或 Cookie 中出现 `bd-ticket-guard-client-data`、`bd-ticket-guard-ree-public-key`、`bd_ticket_guard_client_data`
- 运行链中出现 `identity_security_token`、`identity_security_device_id`
- 运行链中出现 `ActionConsistencyManager`、`ActionType`、`getUidFromSecUid`
- 业务字段中出现 `conversation_id`、`conversation_short_id`、`ticket`

如果同一链路同时出现 `a_bogus`、`msToken`、`webmssdk`、`sdk-glue`、`bdms`、`SecureSDK`、`web_protect`，还必须同时读取 `references/products/dy_abgous.md`。

## 链路类型

该链路通常判定为 `full_flow`，并同时命中这些子类型：

```text
full_flow_stateful_business
= 依赖 Cookie 登录态、SELF_UID、TARGET_UID、会话状态、动态 token 和最终发送状态。

full_flow_protocol_business
= 依赖 IM SDK、protobuf、conversation、ticket、WS / 回执等协议状态。

full_flow_guarded_send
= 私信发送属于主动发送动作，必须验证行为上报、风控材料、服务端状态和实际到达。
```

典型链路：

```text
Cookie / 登录态
-> 获取或刷新 identity_security_token
-> action_report 行为一致性上报
-> 获取已有会话或创建会话
-> 可选 mark_read
-> /v1/message/send 发送文本消息
-> 可选 frontier-im WS 观察回执或消息推送
```

注意：WS 能连接成功不等于私信发送链路完整。私信发送的关键业务路径是 HTTP IM 接口，WS 更多用于长连接、通知、回执、消息推送和辅助观察。

## 关键接口

常见接口角色如下：

```text
GET  /passport/safe/get_identity_security_token/
= 获取 fresh identity_security_token / identity_security_device_id，上下文通常是 scene=im_send_msg。

POST /aweme/v1/im/consistency/action/report
= 发送前行为一致性上报，常见实现来源是 ActionConsistencyManager。

POST /v2/message/get_by_user_init
= 已有会话初始化，返回 conversation_short_id、conversation_id、ticket 等会话发送所需字段。

POST /v2/conversation/create
= 对无历史会话目标创建或打开 1:1 会话，返回 conversation_id、conversation_short_id、ticket。

POST /v3/conversation/mark_read
= 发送前标记已读。动态目标没有 read_index 时不要硬套旧 trace 的 read_index。

POST /v1/message/send
= 最终发送消息接口。文本消息常见 msg_type 为 7，aweType 可见 774。

WSS frontier-im.douyin.com/ws/v2
= 长连接通道，常见用于收取通知、回执、心跳和二进制 protobuf 包。
```

## 目标 UID 与会话

交付脚本的最小业务输入通常应收敛为：

```text
COOKIE
SELF_UID
TARGET_UID
SEND_TEXT
```

字段含义：

- `SELF_UID` 是当前 Cookie 对应账号的数字 UID。
- `TARGET_UID` 是目标账号的数字 UID，不是昵称，也不是短抖音号。
- 1:1 会话 `conversation_id` 常见格式是 `0:1:{SELF_UID}:{TARGET_UID}`。
- `conversation_short_id` 是平台返回的会话短 ID，不应从旧 trace 固定复用。
- `ticket` 是会话维度或请求链路中的动态票据，换目标、换账号、换会话时都需要重新取。

如果只有 `sec_uid`，trace 中可见的转换接口是：

```text
GET /aweme/v1/creator/relation/transform/uid?sec_uid=...
```

如果只有昵称或短抖音号，需要先通过搜索/主页资料链路拿到 `sec_uid`，再转换为数字 UID。不要把昵称、短抖音号、`sec_uid` 直接当作 IM numeric UID 使用。

## 无历史会话

给没有会话记录的目标发消息时，不能依赖旧 trace 里的 `conversation_short_id` 或 `ticket`。推荐链路：

```text
1. 使用 SELF_UID + TARGET_UID 组装 1:1 conversation_id 候选。
2. 调用 /v2/conversation/create 创建或打开会话。
3. 从返回里取 conversation_id、conversation_short_id、ticket。
4. 刷新 identity_security_token。
5. 执行 action_report。
6. 可选 mark_read。
7. 调用 /v1/message/send。
```

已有会话时可先走 `/v2/message/get_by_user_init`，拿到当前会话字段后再发送。

## ticket guard

抖音 Creator IM 链路常见需要动态 `bd-ticket-guard-client-data`。它不是一个可以长期复制的静态 Header。

优先确认：

- Cookie 中是否存在 `bd_ticket_guard_client_data`。
- 请求 Header 是否出现 `bd-ticket-guard-client-data`。
- 是否有配套 `bd-ticket-guard-ree-public-key`。
- 本地是否持有与同一浏览器登录环境匹配的 guard 材料。

常见判断：

- Cookie 里的 `bd_ticket_guard_client_data` 通常不足以单独生成所有请求所需签名材料。
- ticket guard 依赖同一登录/浏览器环境下的动态材料，例如 ticket、`ts_sign`、EC key、公钥、服务端证书等。
- 不要把另一个账号或另一个浏览器环境的 guard 材料套到当前 Cookie。
- `bd-ticket-guard-client-data` 需要按请求、路径、时间戳等上下文动态生成。

交付时可选择把 guard 材料外置为本地文件或内嵌到脚本，但必须明确它是账号/环境绑定材料，不得混用。

## identity token

`identity_security_token` 和 `identity_security_device_id` 是发送前的动态安全上下文字段。它们不应作为稳定配置交给使用者手填。

常见获取接口：

```text
GET https://creator.douyin.com/passport/safe/get_identity_security_token/
```

常见参数特征：

```text
scene=im_send_msg
aid=2906
passport_jssdk_version=5.1.4
id_token_version=2.1.5
msToken
a_bogus
```

出现 `a_bogus` 时按 `dy_abgous.md` 的请求边界方法处理，不要把旧请求中的 `a_bogus` 固定复用。

## action_report

私信发送前可能需要行为一致性上报：

```text
POST https://creator.douyin.com/aweme/v1/im/consistency/action/report
```

观察重点：

- JS 模块中的 `ActionConsistencyManager`。
- `ActionType` 或同类动作枚举。
- access key、payload 组装、时间戳、随机数、环境字段。
- action_report 与目标会话、目标 UID、发送文本之间是否存在绑定关系。

action_report 缺失或不匹配时，最终 `/v1/message/send` 可能返回风控、审核、空服务端 ID、检查码或看似发送但实际未到达的结果。

## Protobuf / IM SDK

IM 接口可能使用 protobuf body。创建会话链路中可见的常见结构：

```text
/v2/conversation/create
command/body: 609

request inner:
  field 1  conversation_type
  field 2  participants
  field 3  persistent
  field 4  idempotent_id
  field 6  name
  field 7  avatar_url
  field 8  description
  field 11 biz_ext

response inner:
  field 1 conversation
  field 2 check_code
  field 3 check_message
  field 4 extra_info
  field 5 status
```

字段编号只能作为当前版本经验。新目标必须从当前 trace 的 protobuf 请求体、响应体和 JS encode/decode 逻辑确认。

## ruyitrace / jscall 优先观察点

命中本链路后优先看：

```text
http_packet / index.jsonl
= 确认 send、get_by_user_init、create、mark_read、identity、action_report 的真实 URL、method、headers、body、status。

jscall
= 定位 fetch/XHR 发起栈、ActionConsistencyManager、getUidFromSecUid、protobuf encode/decode、ticket guard 注入点。

cookie / storage
= 确认 Cookie、msToken、bd_ticket_guard_client_data、登录态和本地安全材料线索。

eval / async chunk
= 固定 ActionConsistencyManager、IM SDK、protobuf、uid transform 等动态模块源码。

profile
= 仅在需要时读取 localStorage、IndexedDB、SQLite 或安全材料线索，不要把整个浏览器 profile 当日志全文读取。
```

`getUidFromSecUid` 的典型业务含义：

```text
sec_uid -> /aweme/v1/creator/relation/transform/uid -> numeric uid -> createConversation
```

## 本地交付建议

面向交付脚本时，建议保持外部输入尽量少：

```text
test1.py
= 用户填写 COOKIE、SELF_UID、TARGET_UID、SEND_TEXT 后直接运行。

code1.js
= 只保留 action_report、protobuf、ticket guard 或签名所需的稳定入口。

action_consistency_source.js
= 固定当前验证过的 ActionConsistencyManager 相关源码片段。

guard_material.json
= 如不能从 Cookie 自动恢复，则作为同环境绑定材料外置；不要把它说成通用配置。

requirements.txt
= 仅保留运行所需 Python 依赖。
```

交付目录不应依赖 `ruyitrace/`、`DY_TRACE_DIR`、`TRACE_DIR` 或本地 trace 路径。trace 只能作为开发证据，不能作为客户运行依赖。

## 常见坑

- 把 WS 能连上误判为私信发送链路完成。
- 给动态目标发送时仍使用旧 trace 的 `conversation_short_id`、`ticket` 或 `conversation_id`。
- 把 `uid_tt` 等 hash-like Cookie 值当作数字 IM UID。
- 把昵称、短抖音号、`sec_uid` 当作 `TARGET_UID`。
- 对无历史会话目标跳过 `/v2/conversation/create`。
- 把 `identity_security_token`、`identity_security_device_id` 当作长期固定配置。
- 把 `bd-ticket-guard-client-data` 当作静态 Header。
- 用另一个 Cookie/浏览器环境的 guard 材料。
- action_report 没有对齐就直接判断 `/v1/message/send` 本身错误。
- 看见发送回执或检查响应就认为对方一定收到，仍需从服务端 ID、检查码、业务状态和实际到达验证。
- 把旧 trace 的 `a_bogus`、`msToken`、ticket、conversation 字段复制到新账号或新目标。

## 安全边界

本文是产品识别和链路分析参考，不提供可直接套用的账号凭据、私钥、Cookie、固定 token 或绕过材料。补环境、签名、ticket guard 和业务发送都必须在当前授权目标、当前 Cookie、当前 trace 证据范围内验证。
