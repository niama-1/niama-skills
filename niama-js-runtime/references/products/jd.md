# 京东 h5st 参考文档

本文用于识别和处理京东 PC / Web 链路中的 `h5st`、`request_algo`、`tk03/tk06`、`fp`、`x-api-eid-token`、`x-skuid-param` 等签名和风控相关参数。它是站点专项经验参考，不是固定套用方案；命中京东目标后，仍必须以当前目标的 `jscall` 定位证据、`http_packet` 请求证据、`storage/domtrace` 状态证据和匹配当前目标的 `ruyitrace/` 真实证据为准。

如果目标是京东 PC 登录图形验证码 / JCAP 滑块，或请求链出现 `jcap.m.jd.com`、`requireCaptchaPc.js`、`jdCAP.captcha`、`graphicCaptchaVerifyToken`、`vt`、`ct/tk/cs`，先读取 `references/products/jd_jcap.md`。本文件继续负责登录提交里的 `h5st/_stk`、`ParamsSign`、`request_algo`、业务签名和京东 Web/PC 业务接口风控判断。

## 命中特征

出现以下特征时，优先按京东 h5st 链路分析：

- 域名或 Referer 命中 `item.jd.com`、`search.jd.com`、`api.m.jd.com`
- 登录验证码联动场景中同时出现 `jcap.m.jd.com`、`graphicCaptchaVerifyToken` 或 `vt` 时，需同时命中 `jd_jcap`
- 业务接口路径为 `https://api.m.jd.com/` 或 `https://api.m.jd.com/api`
- 请求参数出现 `h5st`、`t`、`uuid`、`loginType`、`appid`、`clientVersion`、`client`
- 详情接口出现 `functionId=pc_detailpage_wareBusiness`、`appid=pc-item-soa`
- 列表接口出现 `functionId=pc_search_searchWare`、`appid=search-pc-java`
- Header 出现 `x-api-eid-token`、`x-skuid-param`、`x-referer-page`、`x-rp-client`
- Cookie 出现 `3AB9D23F7A4B3CSS`、`3AB9D23F7A4B3C9B`、`sdtoken`、`thor`、`flash`、`TrackID`、`pin`、`token`
- `h5st` 字段中出现 `tk03...` 或 request_algo 阶段出现 `tk06...`
- 固定抓包重放出现 HTTP `403` 空 body、服务端下发新的 `X-Rp-Sdtoken`，或业务响应出现签名/风控类错误码

## 常见链路

京东 PC h5st 链路通常不是单个函数直出，至少要分清三层：

```text
页面入口 / 业务上下文
→ 读取 cookie、storage、eid、fp、地区、sku/search 参数、Referer
→ request_algo 或同类前置算法链路生成/刷新 tk03
→ 本地 h5st 逻辑使用 tk03、fp、t、body、functionId、appid 等字段生成业务 h5st
→ 携带 h5st、t、x-api-eid-token、x-skuid-param/pcdk、cookie 请求业务接口
→ 根据响应状态判断签名、cookie、TLS/HTTP、账号态或风控状态问题
```

`tk03` 和 `tk06` 必须区分：

- 业务请求 `h5st` 中最终使用的通常是 `tk03...`。
- `tk03` 来自 `request_algo` 响应或等价前置算法响应。
- `request_algo` 请求自身可能需要 `tk06` 算法或对应签名链路。
- 不要把 `tk06` 直接当成业务请求 `h5st` 的 token 字段。
- `tk03` 可以按 trace 证明的缓存周期复用；过期、cookie/账号/环境变化或服务端刷新后必须重新请求。

## h5st 字段判断

不同版本的 `h5st` 字段含义和数量可能变化，不能只靠固定位置命名。应按当前 `jscall` 和 `http_packet` 确认：

```text
时间格式字段
fp 字段
appid / appId / algo 标识字段
tk03 token 字段
业务摘要 / hash 字段
版本字段，例如 5.3
毫秒时间戳字段
环境指纹密文 / env 字段
二次摘要 / 校验字段
末尾固定或半固定配置字段
```

硬性要求：

- `t` 必须动态生成，通常与 `h5st` 内部毫秒时间戳同轮对齐，不允许长期写死抓包值。
- `fp` 不应默认写死；如果 trace 证明存在缓存，可以按缓存逻辑维护，否则应复现生成算法。
- `h5st` 的 canonical string、`stk`、字段排序、URL 编码、body 序列化必须按当前 `jscall` 证据确认。
- 同一个接口在详情、列表、店铺、活动页可能有不同 `appid`、`client`、`x-rp-client`、`stk` 和 body 结构。

## 详情链路

详情页常见业务请求：

```text
functionId=pc_detailpage_wareBusiness
appid=pc-item-soa
client=pc
clientVersion=1.0.0
body={"skuId":"...","area":"...","num":"1","sfTime":"1,0,0"}
headers: x-skuid-param, x-referer-page, x-rp-client=h5_2.2.0, x-api-eid-token
```

重点确认：

- `skuId`、`area`、`num`、`sfTime` 是否进入 h5st 摘要。
- `x-skuid-param` 是否由页面链路生成，是否参与 h5st 或只作为业务 header；必须以当前 `jscall` 的 `stk` / canonical string 为准。
- `x-api-eid-token` 与 Cookie `3AB9D23F7A4B3CSS` 是否同轮一致。
- `area`、`ipLoc-djd`、`areaId`、`PCSYCityID` 是否一致。
- `Referer`、`Origin`、`x-referer-page` 和 `x-rp-client` 是否与页面入口匹配。

## 列表链路

搜索列表常见业务请求：

```text
functionId=pc_search_searchWare
appid=search-pc-java
client=pc
clientVersion=1.0.0
keyword=...
body={"enc":"utf-8","pvid":"...","from":"home","area":"...","page":1,...}
headers: x-referer-page=https://search.jd.com/Search, x-rp-client=h5_2.1.0, x-api-eid-token
```

重点确认：

- `keyword`、`pvid`、`page`、`s`、`area`、`body` 是否进入 h5st 摘要。
- 列表请求可能出现两个 `t` 值或同名参数数组，必须按抓包和 `test.py` 请求库实际序列化方式复现。
- 列表和详情可以共用同一套 tk03 缓存逻辑，但 `appid`、`fp`、`stk`、body 和 header 不能混用。

## fp 规则

京东 h5st 中的 fp 通常是动态设备/环境指纹字段，不应只因为某次抓包固定为 `yzebz52b2i5jbyy2` 就写死。

分析顺序：

1. 在 `jscall` 中搜索 `fp`、`fingerprint`、`h5st`、`request_algo`、`genFp`、`random`、`Math.random`、`Date.now`。
2. 在 `storage` 中确认 fp 是否写入 cookie、localStorage、sessionStorage 或内存缓存。
3. 在 `domtrace` 中确认 fp 生成是否读取 navigator、screen、canvas、webgl、performance、timezone、language 等环境。
4. 如果 fp 算法已经从 trace 中可还原，应在 `code.js` 实现动态生成。
5. 如果当前 trace 证明 fp 是服务端/页面缓存值，必须记录缓存来源、有效期和刷新条件。

## request_algo / tk03 缓存

`request_algo` 是京东 h5st 链路的关键前置节点。需要明确：

- 请求 URL、method、body/query、headers、cookies。
- 请求是否需要 `tk06` 或其它前置签名。
- 响应中哪个字段是 `tk03`、哪个字段是算法脚本、版本、过期时间或配置。
- `tk03` 缓存 key 是否与 `appid`、fp、cookie、eid、UA、账号态绑定。
- 什么时候复用，什么时候刷新。

推荐在 `code.js` 中只负责生成 `h5st` 和必要的 fp/签名片段；在 `test.py` 中负责判断 `tk03` 是否存在、是否过期、是否需要重新请求 `request_algo`，并维护 cookie/session。

## 需要动态维护的字段

至少逐项判断这些字段是否动态：

```text
h5st
t
fp
tk03
request_algo 入参签名 / tk06
x-api-eid-token
x-skuid-param / pcdk
sdtoken / X-Rp-Sdtoken
token
area / ipLoc-djd / areaId / PCSYCityID
pvid / s / page / keyword
body JSON 字符串
cookie 中的 __jda / __jdb / __jdc / TrackID / thor / flash
```

不要默认把这些值写死到 `code.js`。如果暂时使用固定样本，必须在进展清单中标记为“固定样本，仅用于对照”，不能视为最终实现。

## 403 / 605 / 空 body 判断

常见现象和优先判断：

```text
HTTP 403 + 空 body + 下发 X-Rp-Sdtoken
= 通常优先怀疑请求算法链、h5st、fp、cookie/eid 绑定、TLS/HTTP 指纹或请求形态错误。

HTTP 200 + 业务 code 为签名/风控错误
= 通常说明传输层和接口形态基本进入业务层，优先查 h5st 摘要、字段顺序、body 编码、t/fp/token 新鲜度。

固定浏览器 h5st + cookie 原样重放失败
= 不要立刻归因 cookie；先查 h5st 是否过期、t 是否固定、tk03 是否失效、sdtoken 是否刷新、请求客户端指纹是否不一致。
```

如果 `curl_cffi` 默认、`chrome136`、普通 `requests` 表现不同，需要先区分：

- JS 算法错误。
- cookie/session/eid/sdtoken 失效。
- TLS/HTTP2/JA3/Header 顺序或压缩协商问题。
- 请求参数序列化、重复参数、body 编码、Referer/Origin 不一致。

## ruyitrace/jscall 优先动作

命中京东后，优先做：

```text
1. 用 `http_packet` 对齐成功样本和失败样本，记录 functionId、appid、body、h5st、t、headers、cookies、响应状态。
2. 在 `jscall` 中搜索 h5st、request_algo、tk03、tk06、fp、x-api-eid-token、x-skuid-param、pcdk。
3. 在 `storage` 中确认 fp、token、sdtoken、eid、cookie 的读写和更新顺序。
4. 在 `domtrace` 中确认 h5st/fp/request_algo 链路读取的环境指纹、descriptor、prototype、toString 外观和事件调用。
5. 明确 request_algo 请求和业务请求的边界：哪个由 `test.py` 请求，哪个由 `code.js` 生成参数。
6. 明确 `tk03` 缓存逻辑、fp 生成逻辑、t 动态逻辑和 body 序列化逻辑。
7. 对详情和列表分别记录 appid、x-rp-client、body、stk/canonical string，不能互相套用。
8. 用 `test.py` 与 `http_packet` 基线做成功/失败请求面 diff，先定位是 403 空 body、业务 code 错误，还是数据正常返回。
```

## 本地落地建议

建议 `code.js` 暴露稳定入口：

```js
get_h5st(input)
get_jd_fp(input)
build_jd_detail_params(input)
build_jd_search_params(input)
```

建议 `test.py` 负责：

- 维护 `curl_cffi` / requests 客户端、headers、cookies、代理和会话。
- 请求或刷新 `request_algo`，缓存 `tk03`。
- 调用 `node code.js` 获取 h5st、fp、x-skuid-param/pcdk 等本地生成值。
- 动态生成 `t`，并保证与 h5st 内时间戳同轮对齐。
- 对齐 `body` JSON 字符串、重复 query 参数和 header 顺序。
- 打印状态码、响应前 200 字符、关键响应 header、是否下发 `X-Rp-Sdtoken`，便于判断问题层级。

## 常见错误

- 把 request_algo 阶段的 `tk06` 当成业务 h5st 的 `tk03` 使用。
- 固定抓包 `h5st`、`t`、fp、`x-skuid-param` 后长期重放。
- 只换 cookie，不同步 `x-api-eid-token`、`3AB9D23F7A4B3CSS`、`sdtoken`、area、pvid 等绑定字段。
- 详情和列表混用 `appid`、`x-rp-client`、body 或 `stk`。
- body 在 h5st 摘要中使用一种 JSON 字符串，实际请求又用另一种序列化。
- 忽略列表请求中的重复 `t` 或请求库对列表参数的编码方式。
- 看到 HTTP `403` 就只怀疑 cookie，忽略算法错误、fp/tk03 失效或请求客户端指纹差异。
- 看到 HTTP `200` 但业务错误就继续补 DOM/BOM，未先检查 h5st 摘要、字段顺序、时间戳和 token 新鲜度。

## 交付记录要求

命中京东链路时，进展清单或阶段输出必须记录：

- 当前接口类型：详情、列表或其它业务接口。
- `functionId`、`appid`、`client`、`x-rp-client`。
- `h5st` 字段来源、tk03 来源、fp 来源、t 动态方式。
- `request_algo` 是否已复现，tk06 是否只用于 request_algo 阶段。
- `x-api-eid-token`、`x-skuid-param/pcdk`、sdtoken、cookie 的来源和刷新条件。
- 详情/列表 body 的 canonical string 或摘要入参证据。
- 最近一次请求结果：HTTP 状态、业务 code、是否下发 `X-Rp-Sdtoken`、是否完整返回数据。
