# FunCaptcha / Arkose Labs

> 本文是 FunCaptcha（Arkose Labs）音频挑战链路的产品识别与技术定位参考。
>
> 文档只用于当前目标的请求链定位、环境缺口分析和证据整理。文中出现的 URL、字段、版本、响应值和算法描述均不能直接作为当前项目的运行时常量；最终环境值、请求参数和验证结论必须以当前目标的 `jscall`、`ruyitrace/`、本地 `code.js` 及实时请求为准。

## 1. 目标边界

### 1.1 研究范围

- 目标站点示例：
  `https://www.amazon.com/aaut/verify/flex-offers/challenge`
- 当前记录只覆盖：
  - FunCaptcha 音频挑战（audio game）
  - 客户端参数加密和请求链还原
  - 音频题目的分段、识别和答案映射
- 当前记录不覆盖：
  - 图像旋转、拼图、骰子等图像题型
  - Arkose 服务端风控评分模型
  - 设备信任、历史 token 信誉和完整指纹对抗
  - `dapib` / `tguess` 等图像挑战相关动态脚本或 PoW 链路

### 1.2 成功判定

不能只依据 `/fc/ca/` 返回 `solved:true` 判定业务完成。对亚马逊示例链路，至少需要确认：

1. `/fc/ca/` 的每一轮挑战都返回 `solved:true`。
2. 后续 `/verify/flex-offers/` 请求被正常放行。
3. 响应头 `amz-aamation-resp` 中的 `actionType` 为 `PASS`。
4. 获取到激活后的 `sessionToken`，并确认后续业务接口真实放行。

## 2. 产品识别特征

命中以下特征时，可将目标初步归类为 FunCaptcha / Arkose Labs：

- 页面或脚本出现 `arkoselabs.com`、`funcaptcha`、`FunCaptcha`、`api.js`。
- 请求路径出现：
  - `/fc/gt2/public_key/`
  - `/fc/gfct/`
  - `/fc/ca/`
  - `audio_challenge_urls`
- 请求字段出现：
  - `public_key`
  - `session_token`
  - `challengeID` 或 `game_token`
  - `guess`
  - `bio`
  - `render_type`
- 响应或业务页面出现 `amz-aamation-resp`、`sessionToken`、`actionType`。
- 题面为音频选项，并要求用户输入选项编号或选择对应声音。

仅出现 `audio` 或 `challenge` 不足以确认 FunCaptcha；应结合 Arkose 域名、`/fc/*` 路径和字段名综合判断。

## 3. 请求时序

### 3.1 获取 public key 配置

**请求：** `POST /fc/gt2/public_key/`

常见表单字段如下：

| 字段 | 说明 |
| --- | --- |
| `public_key` | 站点对应的 Arkose public key |
| `site` | 常见为 `https://iframe.arkoselabs.com` |
| `userbrowser` | 当前 User-Agent |
| `capi_version` | 当前 Arkose CAPI 版本，例如 `4.0.14` |
| `capi_mode` | 常见为 `inline` |
| `style_theme` | 常见为 `default` |
| `rnd` | 当前轮随机数 |
| `language` | 页面语言，例如 `zh-CN` |
| `c` | 加密后的客户端指纹数据，旧版本常称为 `bda` |
| `data[blob]` | 业务页面下发的 blob，通常为 Base64 或短 hash 组合 |

重点响应字段：

- `token`：后续请求通常作为 `session_token` 使用。
- `challenge_url`、`challenge_url_cdn`：挑战资源地址或配置。
- `string_table`：题面或脚本使用的字符串表。
- `compatibility_mode_enabled`：兼容模式状态。

**常见问题：** 指纹数据不匹配时，本接口可能仍返回 HTTP 成功，但后续 `/fc/gfct/` 可能下发异常挑战、不可解音频或低分结果。这属于静默失败，不能只看本接口状态码。

### 3.2 获取业务侧初始 session token

**请求：** `GET` 或 `POST /verify/flex-offers?options`

亚马逊示例会在响应头 `amz-aamation-resp` 中返回类似结构：

```json
{
  "sessionToken": "<pending-session-token>",
  "clientSideContext": "<context>",
  "actionType": "ARKOSE_LEVEL_2"
}
```

这里的 token 通常处于待激活状态。FunCaptcha 通过后，业务侧会再次返回激活后的 token 和 `PASS` 状态。

### 3.3 获取音频挑战

**请求：** `POST /fc/gfct/`

常见字段：

| 字段 | 说明 |
| --- | --- |
| `token` | 第一步获得的 `session_token` |
| `sid` | 区域或会话标识，例如 `us-west-2` |
| `render_type` | 常见为 `canvas` |
| `lang` | 题目语言，例如 `zh` |
| `isAudioGame` | 音频题标识 |
| `analytics_tier` | 当前 SDK 配置项 |
| `is_compatibility_mode` | 兼容模式标识 |
| `apiBreakerVersion` | 当前 API breaker 配置 |

重点响应字段：

- `session_token`：当前会话 token 的回显或更新值。
- `challengeID`：当前轮挑战 ID，后续通常作为 `game_token`。
- `audio_challenge_urls[]`：音频选项或挑战资源地址。
- `sec`：单轮时限配置。
- `lang`、`game_data`、`string_table`：题面和挑战状态。

### 3.4 提交单轮音频答案

每个音频挑战通常提交一次，具体轮数由 `audio_challenge_urls[]` 和当前挑战状态决定。

**请求：** `POST /fc/ca/`

常见表单字段：

| 字段 | 说明 |
| --- | --- |
| `session_token` | 当前 FunCaptcha session token |
| `game_token` | `challengeID` 或等价挑战标识 |
| `sid` | 区域或会话标识 |
| `guess` | 加密后的答案对象，通常是 JSON 字符串 |
| `bio` | Base64 编码的行为轨迹对象 |
| `render_type` | 常见为 `canvas` |
| `analytics_tier` | 当前 SDK 配置项 |
| `is_compatibility_mode` | 兼容模式标识 |

典型响应状态：

| `response` | `solved` | 含义 |
| --- | --- | --- |
| `not answered` | `null` | 参数、答案或当前挑战状态未通过校验 |
| `answered` | `false` | 当前提交已处理，但挑战整体仍未通过 |
| `answered` | `true` | 当前轮通过，且当前挑战状态满足服务端校验 |

### 3.5 回到业务侧激活

全部音频轮次通过后，页面继续请求业务侧的 `/verify/flex-offers/`。需要检查响应头：

```json
{
  "sessionToken": "<activated-session-token>",
  "actionType": "PASS"
}
```

只有当前请求实时返回业务通过，并且后续业务接口放行，才能将验证码链路标记为完成。

## 4. 客户端参数 `c`（旧称 `bda`）

### 4.1 定位路径

可按以下顺序在当前版本脚本中定位：

1. 在 `/fc/gt2/public_key/` 请求处设置 XHR 或 fetch 条件断点。
2. 沿调用栈进入当轮 `api.js`，并保存当前版本脚本。
3. 定位 `encryptedFPData` 或同类字段的生成位置。
4. 确认输入通常包括：
   - 已采集的指纹对象
   - Arkose 配置对象
   - 当前站点 public key
   - 当前 API 或 SDK 版本标识
5. 在请求组装函数中确认字段名是 `c` 还是旧版本的 `bda`。

常见请求组装形态类似：

```js
append("c", encryptedFingerprint);
append("site", location.origin);
append("userbrowser", navigator.userAgent);
```

字段名、加密格式和调用路径可能随 Arkose 版本及站点集成方式变化，不能直接套用历史样本。

### 4.2 指纹采集范围

常见采集项包括：

- 基础环境：User-Agent、screen、时区、plugins、字体。
- Canvas：`cfp` 或同类 canvas hash。
- WebGL：renderer、vendor、extensions 和相关能力。
- 音频：`audio_fingerprint` 或 OfflineAudioContext 分析结果。
- 浏览器检测：`headless_browser_generic`、`fake_browser`、`hasFakeOS`、`browser_object_checks`。
- 媒体能力：media devices、音频/视频 codec、语音列表。
- 窗口结构：`wh`、`window__tree_index` 等窗口对象统计或 hash。
- 扩展字段：`ef` 段可能包含视频硬件、GPU 行为和其他异步采集结果。

环境补全时只实现当前目标链路实际读取的最小对象集合。`rtwatch` / `rt_log` 只能用于发现本地缺口，不能作为浏览器真实值来源。

### 4.3 加密结构记录

历史资料通常将 `c` 描述为 AES-GCM 加密后的指纹数据，并使用 Arkose 下发的 RSA 公钥保护会话密钥。常见抽象结构为：

1. 对指纹对象进行无空格 JSON 序列化。
2. 生成随机 AES 密钥和 IV。
3. 使用 AES-GCM 生成密文和认证标签。
4. 使用 Arkose RSA 公钥加密 AES 密钥。
5. 按当前版本定义的字段顺序进行 Base64 或 URL-safe Base64 编码。

不同 SDK 版本可能采用不同的字段顺序、编码方式或分支格式。部分历史实现还出现过 AES-CBC、盐值和字典包装格式，因此必须以当前脚本和请求边界证据确认，不能仅凭字段名称判断算法。

## 5. 音频答案 `guess` 加密

### 5.1 明文答案

音频识别结果需要先转换为题目要求的答案表示：

- 选项编号，例如 `1`、`2`、`3`。
- 题目要求的单词或短语。
- 对“第几个声音”“哪个选项是目标声音”等题干进行语义映射后的索引。

当前目标必须确认答案是索引、单词还是其他编码，不能默认使用数字字符串。

### 5.2 `encryptECData` 形态

历史样本中，`guess` 常见为以下 JSON 结构：

```json
{
  "ct": "<base64-ciphertext>",
  "iv": "<hex-iv>",
  "s": "<hex-salt>"
}
```

字段含义通常为：

- `ct`：答案密文，常以 Base64 表示。
- `iv`：初始化向量；长度和编码必须以当前版本为准。
- `s`：盐值，可能参与会话或 User-Agent 派生密钥。

历史音频样本中曾出现 16 字节 hex IV 和 8 字节 hex 盐值，对应 AES-CBC 风格的 KDF；这与 `c` 可能采用的 GCM + RSA 体系不是同一条加密链，不能混用实现或参数。

## 6. 音频处理方案

音频处理是音频挑战链路的核心。建议将它拆分为“资源获取、音频解码、候选分段、内容识别、题干解析、答案映射、质量控制”七个阶段，并为每个阶段保留当前轮输入和输出摘要。

### 6.1 题型结构

常见题面结构为：

1. 顶部显示问题，例如“Which option is the sound of bees?”。
2. 页面提供多个音频选项，常见为 3 个。
3. 用户输入或选择目标选项的编号。
4. 点击 `Done` 或等价按钮提交。

题型可能包括：

- 朗读数字或短词。
- 选择某个动物、物体或环境声音。
- 根据题干选择“有蜂鸣声”“包含目标音效”等选项。

不要假设所有题目都适合普通语音识别；动物叫声、环境音和短促音效通常需要音频分类或模板匹配。

### 6.2 资源下载与格式统一

对 `audio_challenge_urls[]` 中的每个资源：

1. 保留当前请求的 URL、响应状态、Content-Type 和资源顺序。
2. 下载后统一转换为同一种采样率、声道数和采样格式。
3. 记录原始时长、采样率、声道数和解码是否成功。
4. 对异常资源单独标记，不要把下载失败误判为识别失败。

实现时可使用 WebAudio、FFmpeg 或 Python 音频库完成解码和重采样。当前项目应根据实际运行环境选择依赖，并避免把音频处理依赖与浏览器补环境逻辑混在一起。

### 6.3 候选音频分段

候选分段优先使用当前题型的实测证据，而不是默认固定时间窗口。

#### 方案 A：固定时间窗口

适用于选项位置、播放时序和音频长度长期稳定的题型：

- 通过多轮样本统计主声音的起止时间。
- 预先配置每个选项的时间区间。
- 对每个候选音频按对应区间截取。

优点是实现简单、速度快；缺点是对版本变化、静音前缀、延迟和资源时长变化敏感。

#### 方案 B：能量与端点检测

适用于前后静音长度不稳定的题型：

1. 计算短时能量、RMS 或响度曲线。
2. 使用能量阈值检测非静音区间。
3. 结合最小片段长度、静音合并阈值和前后 padding 修正边界。
4. 对多个非静音片段进行合并或拆分。

可选特征包括：

- 短时能量 / RMS
- 过零率（ZCR）
- 频谱质心、带宽和频带能量
- VAD 语音活动检测结果

参数应以当前题型样本校准，并记录阈值、窗口长度和 padding，便于复盘。

#### 方案 C：模板或嵌入匹配

适用于固定词汇、动物叫声或音效集合较小的题型：

- 归一化互相关（NCC）
- 动态时间规整（DTW）
- Mel 频谱或 MFCC 距离
- OpenL3 等音频嵌入相似度

模板匹配不要求完整语音转写，但需要维护版本相关的模板集合。模板来源、采样率和归一化方式必须记录，不能把不同版本资源直接混用。

### 6.4 识别策略

建议按题目类型选择识别器：

| 题目类型 | 推荐方法 | 主要风险 |
| --- | --- | --- |
| 朗读数字或短词 | Whisper、Vosk、SpeechBrain、Kaldi 等 ASR | 短音频、口音、背景噪声导致转写不稳定 |
| 动物叫声或环境音 | 音频分类器、模板匹配、嵌入相似度 | 普通 ASR 可能输出无意义文本 |
| 蜂鸣或特定音效 | 频带能量、谱特征、模板匹配 | 音量变化和压缩失真影响阈值 |
| “第几个选项”类题目 | ASR/分类结果 + 题干解析 | 识别结果和选项编号之间需要显式映射 |

资源有限时，可以先采用“端点检测 + 轻量 ASR/模板匹配”的组合；不要把音频识别、题干解析和 `guess` 加密写成一个不可观测的函数。

### 6.5 题干解析与答案映射

识别文本后还需要将结果映射为提交答案：

1. 清理大小写、标点和常见 ASR 误识别。
2. 从题干提取目标类别或目标词。
3. 将每个候选音频的识别结果转换为统一标签。
4. 根据候选顺序生成题目要求的答案索引或词值。
5. 对低置信度结果停止提交或进入人工复核，而不是盲目重试。

例如，题干要求“选择蜜蜂声音”，应先得到每个候选的分类标签，再返回对应候选的编号；不能直接把 ASR 输出的单词作为 `guess`，除非当前脚本已确认服务端要求单词格式。

### 6.6 识别质量控制

每轮音频处理至少记录以下信息：

- 资源序号和 URL 摘要。
- 音频格式、时长、采样率和声道。
- 分段起止时间和使用的分段策略。
- ASR 或分类结果及置信度。
- 题干解析结果和最终答案映射。
- 是否因为低置信度、解码失败或题型未知而停止。

不要使用历史挑战的答案、旧响应或 trace 中的 `solved:true` 作为当前轮识别成功证据。当前轮必须由本地音频处理实时产生答案，再由当前请求验证。

### 6.7 处理失败的优先级

出现识别失败时，建议按以下顺序排查：

1. 音频资源是否下载完整，Content-Type 是否正确。
2. 解码、重采样和声道转换是否成功。
3. 分段窗口是否覆盖了实际声音。
4. 题型是否属于 ASR 不擅长的动物叫声或音效分类。
5. 题干解析是否把识别标签正确映射到选项编号。
6. `guess` 的明文格式、加密字段和会话 token 是否与当前脚本一致。
7. `bio`、请求时序、Cookie 和其他请求面字段是否对齐。

在确认请求面一致前，不要直接把失败归因于识别模型或加密算法。

## 7. `bio` 行为轨迹

### 7.1 数据结构

历史样本中的 `bio` 通常为 Base64 编码对象，例如：

```json
{
  "mbio": "2606,0,73,144;2627,0,73,144;...",
  "tbio": "",
  "kbio": "18458,0,14;18555,1,14;"
}
```

常见字段：

- `mbio`：鼠标事件。
- `tbio`：触摸事件。
- `kbio`：键盘事件。

历史记录中常见事件类型为 `0=move`、`1=down`、`2=up`，但具体编码必须以当前目标脚本和 trace 证据确认。

### 7.2 生成时序

`bio` 通常在音频播放和答题交互期间采集。定位时重点确认：

- 事件是否由 `mousemove`、`mousedown`、`mouseup` 等监听器产生。
- 事件缓冲的保存顺序和时间戳基准。
- 音频播放、等待定时器和提交请求之间的先后关系。
- `mbio`、`tbio`、`kbio` 是否都被服务端读取。

不要用同步假回调、瞬时跳转或固定旧轨迹替代当前目标的真实事件语义。若证据不足，只记录缺口并暂停该项补全。

## 8. 推荐还原顺序

1. 固定当前目标的 User-Agent、会话状态和请求入口。
2. 确认 public key、业务侧 token 和 `/fc/*` 请求时序。
3. 定位客户端指纹 `c` 的实时生成入口。
4. 获取当前轮音频资源并完成解码、分段和识别。
5. 确认题干到答案索引或词值的映射规则。
6. 定位 `guess` 的实时加密入口。
7. 根据当前目标证据还原 `bio` 的字段和事件时序。
8. 先验证本地代码是否实时生成请求片段，再进入 `test.py` 请求验证。
9. 对真实请求与目标请求做 Header、Cookie、URL、Query、Body 和前置请求 diff。
10. 只有业务侧实时返回 `PASS` 并放行后续接口，才能标记链路完成。

## 9. 当前记录的能力边界

### 已覆盖

- FunCaptcha 音频挑战的常见请求时序。
- `c` / `bda`、`guess` 和 `bio` 的定位方向。
- 音频资源下载、解码、分段、识别和答案映射方法。
- 音频题型下 ASR、分类器和模板匹配的选型依据。

### 未覆盖

- Arkose 服务端设备信任和风控评分。
- 不同站点、不同 SDK 版本之间的稳定兼容性。
- 图像挑战和图像题专用动态脚本。
- 当前目标未提供证据的字段、事件、加密分支和浏览器环境值。

文档中的示例只用于帮助识别链路和组织证据，不能替代当前目标的实时生成与验证。
