# 静态 JavaScript 解混淆流水线

## 适用范围

本参考用于离线分析已保存的 JavaScript 样本，尤其适用于以下特征：

- Babel/webpack 输出中大量短变量、逗号表达式和嵌套三目表达式；
- `while`/`for` + `switch` 或多层 `if` 构成的控制流平坦化（CFF）；
- 字符串数组、索引偏移、解码函数和字符串临时变量；
- 空对象上连续挂载函数的“对象花指令”/代理 helper；
- 压缩的 `bind`/`apply` wrapper、generator 回调和翻译表保护代码。

它是**静态候选生成流程**，不是“保证等价”的自动反编译器。涉及 DOM、网络、时间、随机数、Cookie、WASM 或 JSVMP 时，应回到浏览器/运行时采样路径。

## 总体流程

```text
原始样本（只读 + SHA-256）
  → 解析与 AST 规范化
  → 基础表达式还原
  → 对象 helper / 字符串解码
  → CFF 状态机恢复
  → 清理无引用代码
  → 固定点迭代
  → 原始/候选差分验证
  → 输出候选、diff、日志和未解析清单
```

每个阶段都应输出独立文件或快照；不要覆盖唯一原样本。候选代码必须标记为 analysis artifact，不能直接替换生产签名逻辑。

## 1. 解析与规范化

优先使用 Babel：`@babel/parser`、`@babel/traverse`、`@babel/types`、`@babel/generator`。解析选项应覆盖目标样本的 JSX、TypeScript、class properties、optional chaining 等语法；解析失败时记录错误并切换兼容解析器，不要静默截断。

先做低风险结构规范化：

1. 给 `if`、`for`、`for…in`、`switch case` 补 Block；
2. 拆分语句位置上的逗号表达式和 `return (a(), b())`；
3. 将 `!(a < b)` 还原为 `a >= b` 等等价比较；
4. 将静态计算属性 `obj["name"]` 转成 `obj.name`，但只在属性名和求值语义确定时执行；
5. 保留节点位置、原始文本和 pass provenance，便于 diff 与回溯。

不要一开始重命名变量。先完成绑定解析和语义改写，最后再按作用域重命名。

## 2. 字符串解码与传播

### 识别

按 AST 绑定关系识别，而不是只按变量名匹配：

- 数组字面量或函数返回的字符串数组；
- 通过索引偏移访问数组的函数；
- 包含 `fromCharCode`、Base64、XOR、RC4、URL 解码或位运算的基础 decoder；
- decoder 的别名、计算属性调用和多层 wrapper。

### 求值边界

先建立最小表达式环境（如 `Math`、`Number`、`String`、`parseInt`、`decodeURIComponent`），只对白名单 AST 求值。表达式包含动态标识符、未知成员、网络/文件系统、随机数、时间或副作用时，返回 `unknown`，不要强行替换。

替换条件：

- 调用目标绑定唯一且未被重新赋值；
- 输入为字面量或可证明的常量；
- 结果为稳定原始值；
- 求值没有副作用，并能在回放样本中复现。

输出 `string-map.json`，至少记录原表达式、明文摘要、位置、算法猜测和置信度。动态解密器无法静态求值时，使用运行时 Hook 捕获输入/输出，再把证据作为旁路映射，不要凭猜测回填。

### 传播顺序

建议按以下顺序重复执行：

```text
decoder 替换
  → 字符串字面量拼接
  → 块内字符串传播
  → 常量字符串变量内联
  → 删除未引用字符串临时赋值
```

保留 `this`、`arguments`、getter、短路运算和异常行为；局部同名的 `atob`/`parseInt` 不能误当作全局函数。

## 3. 对象花指令 / 代理 helper

常见结构是空对象加连续属性赋值：

```js
const h = {};
h.add = (a, b) => a + b;
h.eq = (a, b) => a === b;
```

还原时：

1. 确认对象由空对象初始化；
2. 收集静态属性名和函数绑定；
3. 跳过嵌套函数、class、动态属性和存在未知读取的对象；
4. 只内联“返回表达式只依赖参数”的 helper；
5. 检查调用时的 `this`、参数求值顺序和 getter 副作用；
6. 局部作用域和跨作用域 alias 分开处理。

无法证明属性访问集合完整时，不删除属性赋值。只有确认某属性从未读取且赋值无副作用时，才允许清理。

## 4. 控制流平坦化恢复

### 状态机识别

识别以下组合，而不是单独依赖 `switch` 数量：

- 初始状态赋值；
- `while (true)` / `for (;;)` dispatcher；
- `switch (state)` 或按状态查找的对象分发表；
- case 末尾对状态变量的赋值、复合赋值或位运算；
- `break`、`continue`、`return`、`throw` 和异常边。

### 恢复算法

```text
入口状态
  → 建立 case → 基本块映射
  → 解析每个块的 next-state 候选
  → 计算可达 case
  → 统计入度和共享目标
  → 只内联安全的单分支/共同目标
  → 删除顶层状态赋值与 dispatcher break
  → 按执行顺序生成普通语句
```

状态表达式无法确定时保留分支并记录 warning。设置 case/队列上限，防止异常样本导致路径爆炸；不要仅凭一个具体输入的轨迹删除其他可能路径。对 `try/catch/finally`、循环控制和异步边界必须保守处理。

### 缺失跳转诊断

恢复结束后检查：

- 状态赋值是否指向不存在的 case；
- 是否存在不可达 case；
- case 是否缺少终止语句；
- 是否残留 dispatcher 或状态变量写入。

这些应进入报告，而不是被静默吞掉。

## 5. 固定点调度

一个 pass 的结果经常会暴露另一个 pass 的新目标。例如状态机展开后才出现可求值字符串，字符串替换后才出现可合并的 case。因此使用有上限的固定点循环：

```js
for (let round = 0; round < maxRounds; round++) {
  const before = structuralHash(ast);
  for (const pass of passes) {
    const result = pass.run(context);
    report.record(pass.name, result);
  }
  if (structuralHash(ast) === before) break;
}
```

每个 pass 应尽量幂等，并返回 `changed`、`warnings`、`edits`。不能用无限循环或只比较生成文本长度判断收敛。

推荐顺序：

```text
normalize
→ object-helper
→ string-decode
→ constant/alias propagation
→ CFF recovery
→ dead-code cleanup
→ generator/strict-mode compatibility repair
```

Generator 修复、严格模式裸赋值修复、翻译表缺失 key 保护等属于样本兼容插件，默认关闭并在报告中标明。

## 6. 验证与安全边界

- 原始和候选代码分别保存 SHA-256、diff、输入 fixture 和运行日志；
- 对代表性输入比较返回值、类型、异常、调用顺序和关键副作用；
- 时间、随机数、URL、Body、Cookie 等动态输入必须固定或显式传入；
- `vm` 只用于受限表达式求值，不应当作强安全边界；未知代码应放在无网络、无文件系统、有限 CPU/内存的子进程或容器中；
- 不要为了“变得可读”删除可能有副作用的赋值、getter、Proxy、异常边或动态属性；
- JSVMP/WASM/反调试环境依赖明显时，停止静态激进改写，转入浏览器采样、源码插桩或 I/O 级验证。

## 7. 报告契约

至少输出：

```text
original.js / candidate.js
sha256.json
pass-report.jsonl
string-map.json（如有）
state-machine-warnings.json（如有）
diff.patch
verification.json
```

`pass-report.jsonl` 每行建议包含 `pass`、`round`、`changed`、`warnings`、`locations` 和 `confidence`。最终报告必须区分“已改写”“已通过样本验证”和“尚未证明等价”。

