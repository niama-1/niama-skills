## 原型链模板硬规则

本文件只在目标链路明确命中原型、constructor、descriptor、`instanceof`、`Object.getPrototypeOf`、`Object.prototype.toString` 或 `Symbol.toStringTag` 检测时读取。它不提供默认浏览器原型链，不要求普通补环境创建任何宿主对象的 prototype；所有原型相关补法必须由当前目标匹配的 `ruyitrace/descriptor` 或 `domtrace` 证据触发。

## 落位

- 原型链收口只在当前 trace 证实需要时执行，位置放在命中的宿主对象区内、对应对象定义之后；不设置独立原型链大区或全局绑定区。
- 宿主对象实例必须沿用代理模板在对应大区创建的唯一对象壳，例如 `document = rtwatch({}, "document")`、`location = rtwatch({}, "location")`；正式补环境时把真实字段直接填入这对大括号，不得重建或换壳。
- 没有 trace 明确检测时，不创建构造器、不创建 prototype、不执行 `Object.setPrototypeOf(...)`，也不补 `constructor`。
- 一旦 trace 证明必须补原型，构造器和 prototype 只能定义一次；后续只允许按证据往既有 prototype 上补方法、getter、descriptor。

## 最小核心链

以下只是命中原型检测时的候选参考，不是默认补环境清单。只有 trace 明确检测到对应对象的原型关系时，才按真实证据最小补对应链路：

```text
EventTarget
└─ Node
   └─ Document
      └─ HTMLDocument

EventTarget
└─ Node
   └─ Element
      └─ HTMLElement
         ├─ HTMLDivElement
         ├─ HTMLCanvasElement
         ├─ HTMLFormElement
         ├─ HTMLInputElement
         └─ HTMLIFrameElement

Window
Location
Navigator
Screen
History
Storage
Performance
Event
MessageEvent
```

扩展规则：
- 只补目标链路触达的具体 HTML*Element，不批量生成全量 DOM 类型。
- `document.__proto__ === 某个构造器.prototype` 这类关系，只有当前目标 trace 明确检测时才补。
- DOM 节点和返回对象的 prototype 也只在 trace 证明确实检测时补；未命中时优先把真实字段和方法直接填入对应对象字面量。
- `Audio.prototype === HTMLAudioElement.prototype` 这类别名关系只在目标链路命中时按证据补。

## 构造器规则

每个构造器必须同时处理：
- 构造器函数名和 native-like `toString`。
- `Ctor.prototype.constructor === Ctor`。
- `Object.prototype.toString.call(Ctor.prototype)` 依赖的 `Symbol.toStringTag`。
- 构造器是否允许直接调用或 `new`，以及对应异常外观。
- 构造器静态继承和 prototype 继承要分开处理，例如 `Document.__proto__` 与 `Document.prototype.__proto__` 不是一回事。

默认策略：
- 无证据时，浏览器内置 DOM 构造器按 illegal constructor 处理，不允许随手 `new` 出真实实例。
- 目标链路没有检测构造行为时，只保留最小异常外观，不展开无关构造能力。

## 实例规则

实例只允许在对象大区创建。普通补环境只把真实字段、方法和状态直接填入 `rtwatch({}, "name")` 的大括号内部：
- `document = rtwatch({}, "document")`
- `location = rtwatch({}, "location")`
- `navigator = rtwatch({}, "navigator")`
- `screen`、`history`、`localStorage/sessionStorage`、`performance` 同理

模板区不得默认给这些对象绑定 prototype；只有 trace 明确检测时，才在模板区按证据处理对应对象的最小原型关系。

禁止：
- 在对象初始化后用 `document.URL = ...`、`location.href = ...` 这类语句散补，或之后重新 `document = ...` 换壳。
- 在 helper 区、绑定区或目标 JS 后面重建宿主对象。
- 同一个对象先设 `__proto__`，后面又 `Object.setPrototypeOf` 到另一条链。
- 为了让 `instanceof` 过关，把多个无关对象挂到同一个 prototype。

## descriptor 与 getter

- 自身属性和原型属性要分清；不能把浏览器原型属性随手写到实例上。
- getter/setter 定义在实例还是 prototype，必须按目标证据补。
- getter/setter 函数也要有合理 `name`、native-like `toString`，且不暴露普通函数 `prototype`。
- descriptor 默认值要显式写清，不能依赖 `Object.defineProperty` 的默认 false 或普通赋值的默认 true。

## 验收断言

命中对应对象时，至少检查：
- `Object.getPrototypeOf(instance) === Ctor.prototype`
- `instance instanceof Ctor`
- `Ctor.prototype.constructor === Ctor`
- `Object.getPrototypeOf(Ctor.prototype)` 是否等于父级 prototype
- `Object.getPrototypeOf(Ctor)` 是否等于父级构造器或证据要求的函数对象
- `Object.prototype.toString.call(instance)` 与 `Object.prototype.toString.call(Ctor.prototype)` 的外观
- 目标 JS 实际读取的 descriptor、枚举结果、getter/setter、异常外观是否与 trace 一致

## 记录位置

每次补原型链只以代码和验证结果为事实来源：
- 原型链实际补法必须体现在对应 `code.js` / `runtime/*.code.js` 的所属宿主对象区；
- 证据来源必须能回到匹配当前目标的 `ruyitrace/descriptor`、`domtrace`、`jscall` 或本地运行结果；
- 已验证断言和未补范围写在本轮回复、验证记录或代码附近必要注释中，不写入 `补环境进展清单.md`。
