# 抖音 VerifyCenter 滑块验证码

本产品文档用于抖音 / 字节 VerifyCenter 滑块验证码链路识别、补环境观察顺序和常见误判复盘。它不替代当前目标 trace，任何环境值、hash、事件序列和请求字段都必须以当前任务的 `ruyitrace/`、v8trace 与在线请求结果为准。

来源复盘会话：`019f314e-4912-7750-8ae7-6974faae1e08`。

## 命中特征

- 请求链出现 `https://rmc.bytedance.com/verifycenter/captcha/v2`、`https://verify.zijieapi.com/captcha/get` 或 `https://verify.zijieapi.com/captcha/verify`。
- 初始化 URL 或题面参数出现 `aid`、`repoId`、`subtype=slide`、`fp=verify_*`、`host=https://verify.zijieapi.com`、`h5_check_version`、`vc_version`。
- 页面或资源链出现 `rmc-captcha`、`captcha.js`、`index.wasm`、`bdms.js`、`verifycenter-collect`、`webmssdk`、`SecureSDK`、`web_protect`。
- 日志或 trace 中出现 `turing_verify_sdk`、`h5_init`、`h5_aquire_data`、`h5_show_picture`、`h5_action`、`h5_wasm_call`、`h5_jm`、`h5_result`。
- 最终提交字段为 `captchaBody`，且运行链出现 `captcha.wasm.encrypt`、`TextDecoder.decode(Uint8Array ...)`、`encrypt_version=7`。
- 登录触发验证码时业务响应常见 `error_code=1105`，验证码通过后再次登录进入业务层，响应可变但应不再是同一轮滑块失败。

同链路如果还出现 `a_bogus`、`msToken`、`verifyFp`、`fp`、`bdms/webmssdk/SecureSDK` 签名追加，必须同时读取 `references/products/dy_abgous.md`。

## 成功链路

标准链路按真实请求边界判定：

1. `POST /passport/web/user/login/` 返回需要滑块验证，例如 `error_code=1105`。
2. `GET /verifycenter/captcha/v2` 初始化 SDK 和题面上下文。
3. `GET /captcha/get` 获取本轮 `challenge`、`mode=slide`、图片、缺口和提示字段。
4. 本地或浏览器侧生成滑动事件、行为 proof 和环境聚合。
5. `captcha.captcha.verify({modified_img_width}) -> captcha.wasm.encrypt -> TextDecoder.decode(Uint8Array) -> h5_jm -> JSON.stringify({captchaBody})`。
6. `POST /captcha/verify` 提交 `captchaBody`，响应 `code=200` 且消息为验证通过。
7. 再次 `POST /passport/web/user/login/`，响应进入登录业务层；不要把验证码通过后的业务失败误判为滑块失败。

本会话成功样本口径：`000513 POST /captcha/verify` 返回 `{"code":200,"data":null,"message":"验证通过"}`，后续 `000515 POST /passport/web/user/login/` 返回 `error_code=1467`，说明验证码已经通过并进入业务层。

## 必读证据

- `ruyitrace/http_packet`：优先抽取登录触发、`captcha/v2`、`captcha/get`、`captcha/verify`、验证码后登录这几个请求包。
- `ruyitrace/domtrace`：抽取成功 round 中 `h5_action`、`h5_jm`、`h5_result` 附近的环境聚合值和提交前读取。
- `ruyitrace/jscall`：抽取公开 DOM/BOM/API 调用，重点是 Canvas、WebGL、Font、Audio、事件派发、`TextDecoder.decode`、`JSON.stringify`。
- v8trace：默认使用去代理 host 模式，用 `param-fast` 确认可复现，用 `param-env/request-call/raw` 定向吐出写入、异常、缺失和请求边界事实。
- 最终请求：必须以真实 `/captcha/verify` 响应和后续登录响应同时验收，不只看本地 body 长度。

## 本会话复盘难点与处理

- 多次滑块失败后最后一次成功，不能混用失败 round。失败提交只能用于排除错误轨迹或环境，不得作为 proof 真值；成功链路以 `/captcha/verify` 通过和后续登录进入业务层为准。
- 曾被质疑找错加密参数出值入口，最终由 trace 与本地请求链共同证明入口是 `captcha.verify -> wasm.encrypt -> captchaBody -> /captcha/verify`。`/web/common` 发生在成功 verify/login 之后，不是 verify 前置边界。
- 用户要求不使用 RuyiDOM，本链路按 `$spider-skill-js` 走 ruyitrace + v8trace + 本地 JS 环境，不把 RuyiDOM 作为默认执行层。
- 旧 `rtproxy/rtwatch/Proxy` 发现层需要移除。去代理后保留 identity 暴露函数，环境事实依赖魔改 v8trace 的 `envcall/write/throw/request-call`，不再用 Proxy 作为缺口发现主路线。
- v8trace 对 `code.js` 内部 JS Canvas/WebGL 桩只能稳定吐写入、异常、缺失和请求边界；桩内方法级调用仍要靠非 Proxy 桩日志与 ruyitrace 公共 API 记录做 diff。
- Canvas、WebGL、Font hash 不要盲目硬改。trace 只给 `toDataURL` 摘要时不能反推完整 PNG；WebGL 参数表对齐不代表 hash 完整对齐；FontFaceSet.check 和 SPAN 字宽表对齐后不能继续盲补字体。
- `browser.vendor`、`c[7]`、`scale`、`fps` 等展示层差异必须先找公开 DOM/BOM 读取证据和因果作用，不能因为成功 trace 中不同就直接覆盖。
- 轨迹生成要保证 proof 进入加密。该会话稳定形态是约 65 步、约 2550 ms 的滑动轨迹，本地 `captchaBody` 与完整 body 长度对齐后才继续在线验证。
- 最小包不能依赖 `ruyitrace/`。本会话最小包曾因 fallback 使用简化 `captcha/v2` URL 导致 `captchaBody_len` 退化，修复方式是把成功 trace 的完整初始化 URL 固化到包内 fallback。

## 补环境顺序

1. 先锁定成功 round，不要把失败请求混入基准。
2. 先对齐请求边界、题面字段、challenge、滑动距离、body 结构和响应判定。
3. 再对齐 DOM/BOM 公开 API：`matchMedia`、Storage、HTMLCollection、document.all、External、TouchEvent/createEvent、Canvas、WebGL、Font、Audio、screen、MediaCapabilities。
4. 再用 v8trace 短跑确认写入点、异常点、缺失点和最终 `captchaBody` 生成路径。
5. 只有 trace 已证明存在且本地探针能改变目标输出的最小批次，才写入主 `code.js`。
6. 负向探针留在临时文件，不污染主环境。

## v8trace 注意事项

- 优先 host 魔改 v8trace；Docker 时区、字体、图形栈差异容易制造噪声。
- 推荐先 `param-fast` 验证执行稳定，再 `param-env` 针对 `browser`、`c`、`canvas_hash`、`webgl_hash`、`font_hash`、`audio_hash`、`fps`、请求边界做短跑。
- `TouchEvent is not defined`、`Operation is not supported`、post-verify apply 等异常可能是成功 trace 也存在的噪声，必须和成功进程 exception 分区比对后再判断。
- 搜索到 `JSGlobalProxy` 不等于 JS `Proxy` 包装；它是 V8 内部全局代理对象命名，不应作为代理残留证据。
- `param-complete` 噪声大，除非已有明确缩小范围，否则不作为默认主循环。

## 验收口径

- 本地 `node --check code.js` 与 `python -m py_compile test.py` 通过。
- 本地 `test.py` 输出 `node_exit=0`，`captchaBody_len` 与成功 trace 一致。
- 在线 `/captcha/verify` 返回 `code=200`，且后续登录响应与成功 trace 同口径进入业务层。
- 连续稳定性建议至少 5 次，记录 `verify_code`、`captchaBody_len`、`trace_len`、`delta`、`body_len`、`login_error_code`、`async_error_count` 和耗时。
- 本会话 5 次稳定口径：`verify_code=200`、`captchaBody_len=12512`、`trace_len=12512`、`delta=0`、`body_len=12530`、`login_error_code=1467`、`async_error_count=0`。

## 禁止误判

- 不把失败 verify round 当成功 proof。
- 不把 `/web/common` 当 `/captcha/verify` 前置边界。
- 不沿 VMP/opcode/handler/解释器内部路线推进。
- 不使用 RuyiDOM，除非用户重新明确允许。
- 不回退到 `rtproxy/rtwatch/Proxy` 作为默认补环境发现层。
- 不从截断的 dataURL、hash 或展示字段直接硬编码环境输出。
