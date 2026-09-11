# AI 代理错误案例 7: 只分析动态数据，忽略静态代码

**严重程度**: ⭐⭐⭐⭐⭐ (最高)  
**影响范围**: 整个项目的理解和实现  
**发现时间**: 2025-01-20  
**项目背景**: CSAIR 验证码破解项目

---

## 1. 问题描述

过度依赖 RuyiTrace 的动态追踪数据（HTTP 请求、jscall 记录），而**完全忽略了静态代码分析**（HTML 源码、JS 文件），导致：
- 参数来源不明
- 算法理解基于猜测
- 实现严重简化
- 成功率远低于预期

**这是最严重的方法论错误！**

---

## 2. 错误表现

### 实际案例 (CSAIR 验证码项目)

```
❌ 我做了什么:
  ✅ 分析 HTTP 请求序列 (http_packet/)
  ✅ 提取 jscall 函数调用记录
  ✅ 破解 AES 解密算法
  ✅ 实现纯 HTTP 协议代码
  
❌ 我没做什么:
  ❌ 分析 HTML 页面源码
  ❌ 深入分析 JS 文件具体实现
  ❌ 建立 HTML → JS → HTTP 的完整调用链
  ❌ 从 JS 中提取真实参数值 (如 AccessKeySecret)
  
结果:
  - 硬编码了应该从源码提取的参数
  - 简化了复杂的设备指纹采集逻辑（只实现 30%）
  - 用猜测代替了真实的算法实现
  - AccessKeySecret 用空字符串（应该从 JS 提取）
  - 成功率 30-50%（而不是预期的 60-70%）
```

---

## 3. 为什么这是错的？

### 3.1 HTML 包含初始化配置

```html
<!-- 真实的 HTML 可能包含 -->
<div id="captcha-container" 
     data-scene-id="19x5u7lo"
     data-prefix="3de2b640a24066e37069acd3c974ee12"
     data-app-key="XXXX"
     data-access-key-id="YYYY">
</div>

<script>
  var captchaConfig = {
    sceneId: "19x5u7lo",
    accessKeyId: "...",
    accessKeySecret: "...",  // ⭐ 关键参数！
    endpoint: "https://...",
    version: "2023-03-05",
    ...
  };
</script>
```

**如果只看 HTTP 请求，你会错过**:
- 参数的真实来源（HTML data-* 属性）
- 初始化的完整配置（内联脚本）
- 关键常量（accessKeySecret, endpoint）
- 版本号和其他元数据

---

### 3.2 JS 包含真实算法实现

```javascript
// feilin.js (591KB) 中的真实代码
function generateDeviceData() {
  var data = {
    // Canvas 指纹
    canvas: getCanvasFingerprint(),
    
    // WebGL 信息
    webgl: getWebGLInfo(),
    
    // 字体检测
    fonts: detectFonts(),
    
    // 插件检测
    plugins: getPluginList(),
    
    // 音频指纹
    audio: getAudioFingerprint(),
    
    // 屏幕信息
    screen: getScreenInfo(),
    
    // 时区
    timezone: getTimezone(),
    
    // ... 数十个其他字段
  };
  return base64Encode(JSON.stringify(data));
}

function calculateSignature(params, secret) {
  // 真实的签名算法（可能不是简单的 HMAC-SHA1）
  var sorted = Object.keys(params).sort();
  var canonicalized = sorted.map(k => {
    return encodeURIComponent(k) + '=' + 
           customEncode(params[k]);  // ⚠️ 自定义编码！
  }).join('&');
  
  // 可能使用特殊的哈希算法
  return customHash(canonicalized, secret);
}
```

**如果只看 HTTP 请求和 jscall 记录，你会**:
- 不知道设备指纹的完整字段列表
- 严重简化设备指纹采集逻辑
- 用标准 HMAC-SHA1 代替可能的自定义算法
- 遗漏关键的编码/解码步骤
- 不知道真实的 AccessKeySecret 值

**实际影响**:
```
真实实现: 30+ 个设备指纹字段
我的实现: 5 个基础字段

覆盖率: 仅 16%！
```

---

### 3.3 调用链断裂

```
完整的调用链应该是:

HTML 加载
  ↓ (读取 data-scene-id 等属性)
JS 初始化 (captcha.init)
  ↓ (读取 captchaConfig)
生成设备 ID (generateAaduaneId)
  ↓ (调用随机数生成器)
采集设备指纹 (sg.js)
  ↓ (调用数十个采集函数)
构造请求参数 (buildRequestParams)
  ↓ (组装所有参数)
计算签名 (calculateSignature)
  ↓ (HMAC-SHA1 或自定义算法)
发送 HTTP 请求 (ajax.post)
  ↓
服务器响应

═══════════════════════════════════════

如果只看 HTTP 请求，你只看到了最后一步！
前面所有的参数生成、算法细节都不知道！
```

---

## 4. 数据源对比

| 数据源 | 获取方式 | 包含信息 | 重要性 | 是否必需 | 我是否分析了 |
|--------|---------|---------|--------|---------|-------------|
| **HTML 源码** | 浏览器查看源代码 | 初始化参数、配置常量 | ⭐⭐⭐⭐⭐ | ✅ 必需 | ❌ 没有 |
| **JS 源码** | DevTools/RuyiTrace | 完整算法、真实逻辑 | ⭐⭐⭐⭐⭐ | ✅ 必需 | ❌ 提取但未分析 |
| **HTTP 请求** | RuyiTrace http_packet | 接口序列、参数格式 | ⭐⭐⭐⭐ | ✅ 必需 | ✅ 详细分析 |
| **jscall 记录** | RuyiTrace jscall | 运行时调用、参数值 | ⭐⭐⭐ | ✅ 必需 | ✅ 详细分析 |
| **DOM 结构** | DevTools Elements | 页面结构、事件绑定 | ⭐⭐ | 可选 | ❌ 没有 |

**问题**:
- 5 个数据源，我只分析了 2 个（40%）
- 最重要的 2 个（HTML/JS）完全遗漏
- 导致理解不完整、实现基于猜测

**核心原则**:
```
静态分析 (HTML/JS) + 动态追踪 (RuyiTrace) = 完整理解

两者缺一不可！
```

---

## 5. 正确的分析流程

### 阶段 0: 静态代码收集（在启动 RuyiTrace 之前）⭐

```
目标: 收集所有静态代码资源

1. 提取 HTML 页面
   □ 访问目标网站 (https://m.csair.com/)
   □ 右键 → 查看页面源代码
   □ Ctrl+S 保存完整的 HTML 文件
   □ 提取内联的 <script> 内容
   
2. 提取 JS 文件
   □ 从 HTML 中找到所有 <script src="...">
   □ 从浏览器 DevTools → Sources 面板下载
   □ 或使用 curl/wget 下载
   □ 使用 js-beautify 格式化压缩的代码
   □ 识别混淆类型（无混淆/简单混淆/复杂混淆）
   
3. 初步分析
   □ 识别验证码初始化的入口点
   □ 列出所有可能相关的 JS 文件
   □ 提取 HTML 中的配置参数
   □ 记录初始化的 DOM 结构

工具:
  - 浏览器 DevTools (F12)
  - js-beautify (npm install -g js-beautify)
  - curl/wget
```

---

### 阶段 1: HTML 源码分析

```
目标: 提取 HTML 中的所有配置和初始化信息

1. 验证码容器分析
   □ 找到验证码的根元素 (<div id="captcha">)
   □ 提取 data-* 属性（配置参数）
   □ 记录容器的 ID 和 class
   □ 查看是否有其他相关元素
   
2. 内联脚本分析
   □ 提取所有 <script> 标签内容
   □ 识别配置对象（如 window.captchaConfig）
   □ 提取关键常量：
      - sceneId
      - appKey / accessKeyId / accessKeySecret
      - endpoint URL
      - 版本号
   □ 记录初始化函数调用 (如 captcha.init(...))
   
3. 外部资源分析
   □ 列出所有 <script src="...">
   □ 记录 JS 文件的加载顺序
   □ 识别异步加载的资源 (async/defer)
   □ 记录 CDN 地址和版本号
   
4. 元数据提取
   □ 页面标题和描述
   □ <meta> 标签中的 API 端点
   □ CSP (Content-Security-Policy) 配置
   □ 版本号或构建信息

示例命令:
  # 提取所有 data-* 属性
  grep -oP 'data-[\w-]+="[^"]*"' page.html
  
  # 提取内联脚本
  sed -n '/<script>/,/<\/script>/p' page.html
```

**输出文档**: `<项目>_html_analysis.md`

**必须包含**:
- 验证码容器的完整 HTML 代码
- 所有提取的配置参数（表格形式）
- 初始化流程（文字描述）
- 外部 JS 文件清单

---

### 阶段 2: JS 文件深度分析

```
目标: 理解 JS 文件的完整逻辑和算法细节

1. 文件职责识别
   对每个 JS 文件:
   □ 文件大小和复杂度
   □ 主要的导出函数/类
   □ 依赖的其他模块
   □ 在整体流程中的作用
   
   例如 CSAIR 项目:
   - feilin.js (591KB): 验证码核心逻辑
   - sg.js (438KB): 设备指纹采集
   
2. 关键函数提取
   对每个 JS 文件，找到:
   □ 初始化函数 (init, initialize)
   □ 参数生成函数 (generateDeviceId, generateAaduaneId)
   □ 设备指纹函数 (getFingerprint, collectDeviceInfo)
   □ 签名计算函数 (sign, calculateSignature, hmac)
   □ 请求构造函数 (buildRequest, createParams)
   □ 响应处理函数 (handleResponse, parseResult)
   □ 加密/解密函数 (encrypt, decrypt, aesDecrypt)
   
   工具:
   grep -E "function\s+\w+|const\s+\w+\s*=\s*function" feilin.js
   
3. 算法细节分析
   对每个关键函数:
   □ 输入参数（类型、来源、默认值）
   □ 内部逻辑（步骤分解、伪代码）
   □ 使用的工具函数 (base64, md5, hmac等)
   □ 返回值（格式、用途、编码）
   □ 与其他函数的调用关系
   □ 错误处理逻辑
   
   特别注意:
   - 自定义的编码/解码函数
   - 非标准的算法实现
   - 魔法数字和常量
   
4. 常量和配置提取
   □ 硬编码的字符串
      - API URL
      - 密钥 (AES key/IV, HMAC secret)
      - 魔法数字 (如 "FqJB6iRNVYdEGpwb")
   □ 默认参数值
   □ 算法配置
      - AES: key, IV, mode, padding
      - HMAC: algorithm, encoding
   □ 版本号和标识
   
   工具:
   grep -i "key\|secret\|encrypt\|hmac\|aes" feilin.js
   
5. 数据结构分析
   □ 请求对象的完整结构
   □ 响应对象的字段
   □ 中间数据的格式
   □ 复杂对象的嵌套关系
   
   例如设备指纹对象:
   {
     canvas: {...},
     webgl: {...},
     fonts: [...],
     plugins: [...],
     screen: {...},
     ...
   }
```

**输出文档**:
- `<项目>_js_analysis_<文件名>.md` (每个 JS 一个)
- `<项目>_js_functions.md` (关键函数索引)
- `<项目>_js_constants.md` (常量清单)

**必须包含**:
- 每个关键函数的详细分析（包括伪代码）
- 所有提取的常量（表格形式）
- 函数调用关系图
- 数据结构定义

---

### 阶段 3: 调用链映射 ⭐⭐⭐

```
目标: 建立 HTML → JS → HTTP 的完整映射

1. HTML → JS 映射
   □ HTML 的哪个元素触发了 JS 初始化？
      例如: <div id="captcha" data-scene-id="...">
   □ data-* 属性如何传递给 JS 函数？
      例如: elem.dataset.sceneId → captcha.init(sceneId)
   □ 内联脚本如何调用外部 JS？
      例如: window.captchaConfig → feilin.init(config)
   
2. JS → HTTP 映射
   对每个 HTTP 请求:
   □ 由哪个 JS 函数发起？
      例如: sendRequest() in feilin.js:1234
   □ 参数从哪里生成？
      例如: AaduaneId from generateAaduaneId()
   □ 签名如何计算？
      例如: calculateSignature(params, secret)
   □ Headers 如何设置？
      例如: setHeaders({...})
   
3. 完整的数据流追踪
   对每个关键数据 (如 AaduaneId):
   □ 生成位置: feilin.js → generateAaduaneId() line 567
   □ 传输路径: generateAaduaneId() → buildParams() → sendRequest()
   □ 使用位置: InitCaptchaV2 请求的 AaduaneId 参数
   □ 格式转换: 无（直接使用字符串）
   
   对每个关键数据 (如 DeviceData):
   □ 生成位置: sg.js → collectFingerprint() line 1234
   □ 传输路径: collectFingerprint() → JSON.stringify() → base64Encode()
   □ 使用位置: InitCaptchaV2 请求的 DeviceData 参数
   □ 格式转换: Object → JSON → Base64
   
4. 绘制流程图
   使用 Mermaid 或其他工具绘制:
   
   □ HTML 初始化流程图
   graph TD
     A[HTML 加载] --> B[读取 data-scene-id]
     B --> C[调用 captcha.init]
     C --> D[加载 feilin.js]
     D --> E[初始化完成]
   
   □ JS 调用序列图
   sequenceDiagram
     participant HTML
     participant feilin.js
     participant sg.js
     participant Server
     HTML->>feilin.js: init(config)
     feilin.js->>sg.js: collectFingerprint()
     sg.js-->>feilin.js: deviceData
     feilin.js->>Server: InitCaptchaV2
     Server-->>feilin.js: response
   
   □ HTTP 请求依赖图
   □ 数据流转示意图
```

**输出文档**:
- `<项目>_call_chain.md`
- `<项目>_data_flow.md`
- 流程图 (PNG/SVG 或 Mermaid 代码)

**必须包含**:
- 每个 HTTP 参数的完整来源追踪
- HTML → JS → HTTP 的逐步映射
- 数据格式转换的详细说明
- 可视化的流程图

---

### 阶段 4: 动态验证（使用 RuyiTrace）

```
目标: 用动态数据验证静态分析的准确性

1. 验证参数来源
   □ HTML 中的 sceneId 是否出现在 HTTP 请求中？
   □ JS 生成的 AaduaneId 格式是否符合预期？
   □ DeviceData 的字段是否与 sg.js 中的一致？
   
   方法:
   - 对照 http_packet 中的请求参数
   - 检查 jscall 记录中的函数调用
   
2. 验证算法实现
   □ 签名算法的实际执行是否与 JS 代码一致？
   □ AES 解密的 key/IV 是否与 JS 中的常量匹配？
   □ 设备指纹采集是否调用了所有预期的函数？
   
   方法:
   - 在 jscall 中搜索关键函数名
   - 对比参数值和返回值
   
3. 验证调用顺序
   □ jscall 记录的函数调用顺序是否与分析一致？
   □ HTTP 请求的发送时机是否符合预期？
   □ 是否有未预期的函数调用？
   
   方法:
   - 绘制实际的调用序列
   - 与阶段 3 的流程图对比
   
4. 发现遗漏
   □ 有哪些函数被调用但未在静态分析中识别？
   □ 有哪些参数出现但不知道来源？
   □ 有哪些请求在 HTTP 记录中但未在 JS 中找到？
   
   方法:
   - 对比 jscall 和 JS 分析文档
   - 标记所有未知项
   - 回到阶段 2 补充分析
```

**输出文档**:
- `<项目>_validation_report.md`

**必须包含**:
- 静态分析 vs 动态数据的对比表
- 发现的差异和遗漏
- 需要补充的分析项

---

### 阶段 5: 完整性对照

```
在实现代码之前，必须完成以下对照检查:

□ 每个 HTTP 参数都知道真实来源（HTML 或 JS 的哪个函数）
□ 每个关键函数都理解其真实实现（有伪代码或详细描述）
□ 每个算法都有 JS 源码的支持（不是"应该是"，而是"代码写的是"）
□ 每个常量都从源码中提取（不是硬编码或猜测）
□ 调用链完整（从 HTML 到 HTTP 的每一步都清楚）
□ 数据流清晰（每个数据的生成、传输、使用都明确）
□ 所有简化都已评估影响（知道哪些组件简化了，影响多大）

只有全部打勾，才能开始实现！
```

**输出文档**:
- `<项目>_readiness_checklist.md`

---

## 6. 实战检查清单

**在开始任何逆向分析项目时，确保完成**:

```
阶段 0: 静态收集
□ HTML 页面已保存
□ 所有 JS 文件已下载
□ JS 代码已美化/格式化
□ 文件清单已列出

阶段 1: HTML 分析
□ 验证码容器已识别
□ 配置参数已提取
□ 初始化脚本已分析
□ HTML 分析文档已生成

阶段 2: JS 深度分析
□ 每个 JS 文件的职责已明确
□ 关键函数已全部识别
□ 算法细节已分析（有伪代码）
□ 常量和配置已提取
□ JS 分析文档已生成

阶段 3: 调用链映射
□ HTML → JS 映射已完成
□ JS → HTTP 映射已完成
□ 数据流已追踪
□ 流程图已绘制
□ 调用链文档已生成

阶段 4: 动态验证
□ RuyiTrace 追踪已执行
□ 静态分析已用动态数据验证
□ 遗漏已识别并补充
□ 验证报告已生成

阶段 5: 完整性确认
□ 所有参数来源明确
□ 所有算法理解正确
□ 调用链完整无断裂
□ 准备好开始实现

警告: 如果任何阶段未完成，不要开始实现代码！
```

---

## 7. 典型错误对比

| 场景 | 错误做法 | 正确做法 |
|------|---------|---------|
| **参数来源** | 看到请求中有 sceneId，直接硬编码 "19x5u7lo" | 从 HTML 的 data-scene-id 提取，或从 JS 的 config 对象提取 |
| **算法实现** | 看到请求中有 Signature，猜测是 HMAC-SHA1 | 分析 JS 中的 calculateSignature 函数，确认算法和参数 |
| **设备指纹** | 看到 DeviceData 是 Base64，简单生成几个字段 | 分析 sg.js (438KB) 的完整采集逻辑，实现所有字段 |
| **常量提取** | AccessKeySecret 用空字符串（因为不知道） | 从 JS 中搜索 "accessKeySecret" 或 "secret"，提取真实值 |
| **实现依据** | "应该就是这样" | "JS 代码第 567 行是这样写的" |
| **简化决策** | 觉得太复杂就简化，不评估影响 | 对照 JS 实现每个组件，明确简化的部分和影响 |

---

## 8. 文档输出要求

**每个项目必须生成以下文档**:

### 必需文档

1. **`<项目>_html_analysis.md`**
   - HTML 结构分析
   - 配置参数提取
   - 初始化流程

2. **`<项目>_js_analysis_<文件名>.md`** (每个 JS 一个)
   - 文件职责和大小
   - 关键函数列表
   - 算法细节（伪代码）
   - 常量和配置

3. **`<项目>_call_chain.md`**
   - HTML → JS → HTTP 完整调用链
   - 数据流转关系
   - 流程图

4. **`<项目>_comparison.md`**
   - 真实实现 vs 我们的实现
   - 简化的部分和影响
   - 成功率评估

5. **`<项目>_validation_report.md`**
   - 静态分析 vs 动态数据对比
   - 发现的差异和遗漏

### 可选文档

6. **`<项目>_js_functions.md`**
   - 关键函数索引

7. **`<项目>_js_constants.md`**
   - 常量清单

---

## 9. 工具推荐

### 静态代码分析工具

```bash
# JS 美化
npm install -g js-beautify
js-beautify feilin.min.js > feilin.js

# 代码结构分析
npm install -g esprima
esprima feilin.js --loc > feilin_structure.json

# 函数提取
grep -E "function\s+\w+|const\s+\w+\s*=\s*function" feilin.js > functions.txt

# 搜索关键字
grep -i "signature\|encrypt\|device\|fingerprint\|secret\|key" feilin.js

# 提取常量
grep -oP '(var|const|let)\s+\w+\s*=\s*"[^"]*"' feilin.js
```

### HTML 分析工具

```bash
# 提取脚本标签
grep -oP '(?<=<script>).*?(?=</script>)' page.html

# 提取 data-* 属性
grep -oP 'data-[\w-]+="[^"]*"' page.html

# 提取内联配置
sed -n '/<script>/,/<\/script>/p' page.html | grep -E "config|Config"
```

### 代码对比工具

- **Beyond Compare**: 对比分析前后的理解
- **Meld**: 开源的对比工具
- **VS Code Diff**: 内置的对比功能

---

## 10. 实际案例：CSAIR 项目的教训

### 应该怎么做（但我没做）

```
1. 访问 https://m.csair.com/
2. F12 打开 DevTools
3. 保存 HTML 页面
4. 在 Sources 面板下载 feilin.js 和 sg.js
5. js-beautify 格式化代码
6. 分析 HTML 的验证码容器和配置
7. 分析 feilin.js 的初始化函数
8. 分析 sg.js 的设备指纹采集
9. 建立 HTML → JS → HTTP 映射
10. 用 RuyiTrace 验证分析
11. 开始实现
```

### 我实际做了什么（错误的）

```
1. 启动 RuyiTrace
2. 浏览网站，采集数据
3. 分析 HTTP 请求
4. 分析 jscall 记录
5. 破解 AES
6. 直接写代码（基于猜测）
7. 发现成功率低
8. 用户质疑 ← 暴露问题
```

### 对比

| 步骤 | 应该做 | 实际做了 | 后果 |
|------|-------|---------|------|
| **HTML 分析** | ✅ | ❌ | 不知道参数来源 |
| **JS 深度分析** | ✅ | ❌ | 算法基于猜测 |
| **调用链映射** | ✅ | ❌ | 流程不完整 |
| **常量提取** | ✅ | ❌ | AccessKeySecret 为空 |
| **完整性验证** | ✅ | ❌ | 简化过度 |

**结果**: 
- 成功率 30-50%（预期 60-70%）
- 设备指纹覆盖率仅 16%（5/30 字段）
- 用户严厉质疑
- 需要大量返工

---

## 11. 关键教训

### 核心原则

```
静态分析 (HTML/JS) + 动态追踪 (RuyiTrace) = 完整理解

两者缺一不可！
```

### 记住

1. **RuyiTrace 只是工具的一半**
   - 它捕获运行时数据（结果）
   - 但不告诉你源头（HTML）和逻辑（JS）

2. **不要跳过静态分析**
   - HTML 包含初始化配置
   - JS 包含真实算法
   - 这些是实现的基础

3. **建立完整的调用链**
   - HTML → JS → HTTP
   - 每一步都要清楚

4. **基于事实，不是假设**
   - "JS 代码是这样写的" ✅
   - "应该就是这样" ❌

5. **对照验证**
   - 用 RuyiTrace 验证静态分析
   - 用静态分析理解 RuyiTrace 数据

---

## 12. 更新项目流程

### 标准化的项目流程（更新版）

```
阶段 0: 静态代码收集 ⭐ 新增
  ✅ 保存 HTML 页面
  ✅ 下载所有 JS 文件
  ✅ 格式化和美化代码
  ✅ 建立文件清单

阶段 1: 探索分析 (第一轮追踪)
  ✅ 识别系统架构
  ✅ 理解 HTTP 流程
  ✅ 确定追踪目标

阶段 2: 静态深度分析 ⭐⭐⭐ 最关键
  ✅ 分析 HTML 源码
  ✅ 深度分析所有 JS 文件
  ✅ 绘制完整调用链 (HTML → JS → HTTP)
  ✅ 提取所有参数和常量
  ✅ 理解所有算法细节
  ✅ 生成完整的架构文档

阶段 3: 精确追踪 (第二轮~第N轮)
  ✅ 基于阶段 2 的分析配置追踪
  ✅ 用动态数据验证静态分析
  ✅ 识别和补充遗漏
  ✅ 迭代优化理解

阶段 4: 完整性验证 (在实现前)
  ✅ 对照 JS 文件验证所有理解
  ✅ 确认所有参数来源明确
  ✅ 确认所有算法理解正确
  ✅ 评估实现复杂度和成功率
  ✅ 制定详细的实现计划

阶段 5: 分层实现
  ✅ 实现核心算法（对照 JS 源码）
  ✅ 实现 HTTP 框架
  ✅ 实现辅助组件（逐个对照验证）
  ✅ 集成测试
  ✅ 成功率评估

阶段 6: 文档和总结
  ✅ 完整的技术文档
  ✅ 接口和架构图
  ✅ 真实 vs 实现的对比
  ✅ 经验教训
  ✅ 诚实的完成度评估
```

**关键变化**:
- 新增阶段 0（静态收集）- 在使用 RuyiTrace 之前
- 阶段 2 扩展为包含 HTML/JS 深度分析 - 最关键的阶段
- 每个阶段都强调静态+动态结合

---

## 13. 总结

### 这个错误的严重性

⭐⭐⭐⭐⭐ **最高级别**

- 影响整个项目的理解
- 导致实现基于猜测和假设
- 成功率远低于预期
- 需要大量返工

### 如何避免

1. **在使用 RuyiTrace 之前，先收集静态代码**
2. **深度分析 HTML 和 JS，不要跳过**
3. **建立完整的调用链映射**
4. **用 RuyiTrace 验证静态分析，而不是替代它**
5. **基于 JS 源码实现，而不是基于猜测**

### 记住

```
看到 HTTP 请求 ≠ 理解系统
提取 JS 文件 ≠ 分析 JS 文件
RuyiTrace 数据 ≠ 完整理解

完整理解 = 静态分析 + 动态追踪
```

---

**文档版本**: 1.0  
**创建时间**: 2025-01-20  
**相关项目**: CSAIR 验证码破解  
**严重程度**: ⭐⭐⭐⭐⭐
