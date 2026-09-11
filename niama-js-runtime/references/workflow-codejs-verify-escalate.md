## 工作流程：阶段 7-11

### 阶段 7：test.py 请求联调

当 `node_mode` 已能稳定生成目标参数、验证码请求体、行为证明或加密请求片段后，进入 `test.py` 真实请求联调。`test.py` 负责通过 `subprocess` 调用一个或多个 Node 入口，取回结构化 JSON 后组装并发起真实请求。

执行层调用方式：
- `test.py` 调用 `node code.js` 或 `node runtime/*.code.js`
- `code.js` / `runtime/*.code.js` 读取 CLI JSON 入参，输出结构化 JSON
- 多 runtime 项目由 `test.py` 按真实请求链顺序编排多个 Node 入口

联调重点：
- `test.py` 调用的入口函数、CLI 入参和 JSON 输出是否稳定
- 多 runtime 项目中，`test.py` 调用顺序是否与真实请求链一致
- URL / Header / Cookie / Body / Query 是否与目标请求链一致
- 验证码任务中，初始化、题面、提交校验、通过凭证和后续业务验证是否串成同一会话
- 前置请求、预热请求、重定向、preflight 是否需要复现
- 登录态、账号状态、代理、IP、时间窗口是否影响请求成功
- 参数正确但请求失败时，不要继续盲目补 DOM/BOM，先判断是否是请求链或会话态问题

`test.py` 的请求面要求：
- 以抓包目标请求和关键前置请求为基线，尽量保留完整 headers、cookie、query、body、method、URL、redirect、preflight 和会话状态；不要只保留动态参数或签名字段
- 不得省略看似基础的 headers，例如 `Accept`、`Accept-Language`、`User-Agent`、`Origin`、`Referer`、`Sec-Fetch-*`、`Sec-CH-UA-*`、`Content-Type`、`Authorization`、`X-*`、业务自定义 header、设备 / 风控 header
- `Cookie` 必须按同一会话状态处理：要么保留抓包中的完整 `Cookie` header，要么用 session/cookie jar 重建等价 cookie 集合
- 只有 HTTP 客户端必须自动计算或不能安全手写的字段才允许不直接放入 headers，例如 `Content-Length`、部分 hop-by-hop 头、HTTP/2 `:method/:path/:authority/:scheme` 伪头；省略时必须记录原因、客户端等价行为和是否影响签名 / 风控
- 如果目标对 header 顺序、大小写、HTTP/2、TLS 指纹、压缩编码或 connection 语义敏感，`requests` 不足以复现时，不要删 header 迁就 `requests`；改用 `httpx`、curl、导出的 HAR/flow 或更接近真实客户端的方式验证
- 每次 `test.py` 请求失败时，先把 `test.py` 实际发出的请求与抓包基线做 diff，至少覆盖 URL、method、query、headers、cookie、body、content-type、redirect/preflight、前置请求顺序和响应摘要；请求面未对齐前，不得把失败直接归因于签名算法或 DOM/BOM 补环境
- 如果请求面已经对齐，且证据证明失败原因属于环境语义缺口，必须回到阶段 4.0：按 `environment-detection-signal-index.md` 重新扫描当前失败相关 trace；命中高风险信号时先写检测语义卡，再按 `ruyitrace` 检测语义补环境，不能直接顺手补字段
- 本阶段只允许请求面 diff。不得做参数字节集、签名、密文、算法输入输出、字段扰动、bit/byte 翻转、批量样本或普通样本层面的差分逆向；这些 diff 不得作为算法真值、环境真值或继续插桩探针的依据

### 阶段 8：收敛验证

至少确认：
- `code.js` 可通过 Node 稳定运行
- 如果使用多 runtime，所有 `runtime/*.code.js` 都可通过 Node 稳定运行
- 任务目录内存在可独立交付的 `assets/rtproxy.js` 项目副本
- 所有 `code.js` / `runtime/*.code.js` 都只用项目相对路径引用本地 `assets/rtproxy.js`，不存在指向 skill 目录、绝对路径、软链接或外部代理文件的运行时依赖
- 进入收敛验证前已完成 skill 源代理、项目副本和 runtime 引用路径校验；代理资产校验不写入补环境进展清单
- `get_参数名(input)` 或 `build_target_request(input)` 输出稳定
- `test.py` 能调用 `code.js` 或 `runtime/*.code.js`
- 如果条件允许，`test.py` 能稳定请求目标接口
- `test.py` 的真实请求面已与抓包基线对齐；所有省略或由客户端自动处理的 headers 都已记录原因和等价行为
- 验证码任务中，验证码提交接口通过后，后续登录接口或原业务接口必须真正放行，不能只看验证码接口成功
- 不要求 `补环境进展清单.md`；收敛状态以 `target.lock`、当前代码、当前入口运行结果、`proxylog.txt`、`param_info.md` 和 `test.py` 当前验证结果为准
- `code.js` 和 `runtime/*.code.js` 保持 `rtproxy.js` 格式顺序，目标 JS 位于 `// 目标js` 分界之后
- runtime 和 `test.py` 不读取 `ruyitrace/`、`http_packet`、旧响应体、请求基线文件或 trace 中目标生成值来产出参数、token、`captchaBody`、签名、密文、验证码通过凭证或业务成功响应
- 每个补环境方法都已做 `fun_to_native` 或等价 native `toString` 保护
- 没有 VMP 探针、VMP 插装、VM tracer、opcode hook、解释器 proxy 残留
- 已记录 VMP / 动态载荷覆盖状态；单 trace 下不得声明跨版本稳定

成功口径硬规则：
- `ruyitrace/`、`http_packet`、`jscall` 和抓包响应只能证明浏览器当时发生过什么，不能证明当前项目已完成。
- 本地完成必须有当前运行产生的 Node 输出；真实联调完成必须有 `test.py` 使用当前生成值发出的当前请求结果。
- 如果只复用了 trace 里的目标值或响应结果，结论必须写成“离线材料复现 / 请求面基线提取 / dry-run fixture”，不得写“已跑通、已验证通过、已完成”。
- 如果 runtime 或 `test.py` 读取 trace、HTTP 包、请求基线、旧响应文件来产出目标值或成功响应，必须标记 `fake_completion_risk=true`，并停止完成性验收。
- 如果最终说明把 ruyitrace 的目标生成值、浏览器成功响应或旧响应摘要当作当前运行证据，必须视为未完成，而不是表述问题。
- 验证码任务中，不能只看 trace 中 `/captcha/verify` 的成功响应，也不能只看本地生成了 body；必须以当前 `test.py` 请求的实时响应为准。若实时服务返回参数错误、验证超时、challenge 过期或业务未放行，必须明确标记未完成。

稳定输出示例：

```js
if (require.main === module) {
  const input = JSON.parse(process.argv[2] || "{}");
  const value = get_xxx(input);
  console.log(JSON.stringify({ xxx: value }));
}
```

失败分类：
1. 运行时异常：对象缺失、descriptor 错误、原型链错误、Promise rejection；优先对照浏览器 `exception/`
2. 参数不一致：环境值、入参、时序、随机数、编码差异
3. 验证码失败：题面答案、轨迹证明、轨迹点数量、轨迹编码后长度、token 过期、token 单次消费、凭证注入位置错误
4. 请求失败：先 diff 完整请求面，再排查会话态、Cookie、Header、前置请求、IP/代理、风控状态
5. 偶发成功：时间窗口、nonce、缓存、异步事件、状态污染

VMP / 动态载荷覆盖验收状态：

```text
single_trace_current_version_passed
= 当前单 trace、当前版本材料、当前目标集合和当前状态下已通过；不得描述为跨版本稳定。

multi_trace_stable
= 多 trace 对照后，目标链路读取面、入口入参、事件/Worker 链、storage/cookie 状态、版本材料差异下的目标输出和最终请求验证均稳定。

multi_trace_divergent
= 多 trace 对照后，环境读取面、入口入参、事件/Worker 链、版本材料或请求结果出现影响目标集合的差异；需要拆 runtime、分版本适配，或暂停等待更多证据。

insufficient_trace_coverage
= 存在 VMP / VM-like runtime / 动态执行载荷 / 不透明 payload / Worker/WASM 执行载荷等多版本风险候选，但当前 trace 覆盖不足以判断跨版本稳定。
```

每轮只修一批差异，不大范围重写。

### 阶段 9：回到 jscall 做升级诊断

仅当本地已接近正确但仍失败时进入。

优先排查：
- 请求前 payload
- 最终 transport wrapper
- 验证码通过凭证是否同轮、fresh、未消费，并在签名 / 加密前注入
- 验证码轨迹是否影响提交校验字段长度；对比浏览器和本地的轨迹点数量、JSON/URI 编码后长度、最终 proof/sign/tk/ct/cs 长度级别
- Cookie / Header 注入点
- `test.py` 是否省略了抓包中的基础 headers、业务 headers、设备 / 风控 headers、完整 Cookie 或前置请求
- storage 读写
- 时间戳和随机数来源
- service worker / websocket / preflight
- hidden iframe / worker / cross-context
- 隐藏分支进入条件
- native `toString`、descriptor、prototype、constructor、`toStringTag` 检测
- 浏览器 `exception/trace_exception_process_<pid>` 与本地 Node 异常是否一致

如果升级观测改变页面行为：
- 立即回退到无观察点状态
- 缩小日志范围或请求边界观察范围
- 改用请求边界记录、入参/返回值和 http_packet 对照

### 阶段 10：补齐或更新 ruyitrace 证据

只有满足以下条件之一时，才进入本阶段：
- 当前目录没有匹配目标的 `ruyitrace/`
- `ruyitrace/` 缺少目标链路实际读取的 DOM/BOM 真值
- `ruyitrace/` 与当前目标请求、账号状态、页面状态或触发步骤不匹配
- 固定样本对比只剩少量环境相关差异，但现有 `ruyitrace/` 无法解释
- 单 trace 未通过，且当前 trace 无法解释失败原因或证据不足，需要 `single_trace_failed_need_more_evidence` 多 trace 对照
- 单 trace 已通过，但目标链路存在 VMP / VM-like runtime / 动态执行载荷 / 不透明 payload / Worker/WASM 执行载荷等多版本风险候选，需要 `single_trace_passed_quality_check` 环境质量复核

补齐证据时仍不得使用浏览器自动化来实现目标；只能读取已有 trace、HTTP 包或用户明确提供的离线材料。

### 阶段 11：清理与交付

交付前确认：
- `code.js` / `runtime/*.code.js` 不含无关调试 Hook、VMP 探针或自动化依赖
- 项目内 `assets/rtproxy.js` 副本存在，runtime 只引用项目副本，不依赖 skill 目录代理
- 高噪声 `rt_loginfo` 默认关闭，必要日志可开关
- `param_info.md` 记录入参、输出、请求链和验证口径
- `补环境进展清单.md` 如旧项目存在，只能当人工摘要；AI 不维护、不依赖。证据位置和详细缺口保留在本轮回复、代码、验证输出、`proxylog.txt` 或 `param_info.md` 中
- `test.py` 保留完整请求面和 diff 逻辑
- 所有证据性结论都能回到 `ruyitrace/`、`jscall` 或 HTTP 包；所有完成性结论都能回到项目本地 Node 输出和 `test.py` 当前运行结果
