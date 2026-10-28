# One Wx 开发规范

本文档约束后续开发。新增功能、重构、提交前都按这里执行。

---

## 1. 目录结构

```text
Tweak.x                          # 只放 UIView 全局 Hook + %ctor
Sources/
├── API/                         # 模块间契约（内部公共 API）
├── Core/                        # 配置与通用工具
├── WeChat/                      # 微信适配层
├── Services/                    # 跨功能服务
├── UI/                          # 通用界面
└── Features/<Feature>/          # 一个功能一个目录
```

### 各目录职责

| 目录 | 放什么 | 不放什么 |
|---|---|---|
| `API/` | 跨模块函数的声明、对外类型 | 实现、状态、静态变量 |
| `Core/` | 设置 key 与默认值、KVC、窗口、Toast、震动 | 微信私有类、具体功能逻辑 |
| `WeChat/` | 微信私有类声明、账号、私有 API 封装 | 功能逻辑、UI |
| `Services/` | AI、翻译等可复用能力 | 手势判断、Hook |
| `UI/` | 设置页、弹窗、插件入口 Hook | 业务逻辑 |
| `Features/` | 功能实现 + 该功能的 Logos Hook | 其他功能的代码 |

**判断标准**：新增一个功能，应当只需新建 `Features/<Feature>/`，不需要改其他功能目录。

---

## 2. 依赖规则

1. **实现文件只允许一个项目内 import**：

   ```objc
   #import "Sources/API/WCGestureInternal.h"
   ```

   不允许再直接 import 其他模块的实现头。

2. **`API/` 内的头文件只能引用基础头**：

   - `Sources/Core/WCGestureConfig.h`
   - `Sources/WeChat/WCGestureWeChatClasses.h`

   不允许 API 头之间互相引用（除伞头文件 `WCGestureInternal.h`）。

3. **功能之间禁止直接 import**。A 功能需要 B 的能力时，B 把函数声明放进 `API/`。

4. **禁止循环依赖**。`Sources/API/*.h` 不得 import `WCGestureInternal.h`。

5. 基础头（Config、WeChatClasses、Account、PrivateAPI）由伞头文件统一引入，功能文件不再单独引入。

---

## 3. 内部公共 API 规范

- 每个领域一个 API 头：`WCGesture<Domain>API.h`。
- 新增领域时，同时修改 `Sources/API/WCGestureInternal.h` 加入该头。
- API 头只写声明和注释，不写实现、不定义变量。
- 新增的跨模块函数使用 `WCGesture` 前缀：

  ```objc
  void WCGestureMessageSynchronize(...);
  ```

  已经存在的 `WC...` 跨模块函数（如 `WCSynchronizeReplyGesture`）保持原名，
  不为统一前缀而重命名，避免破坏所有调用点。功能内部的 `static` 函数使用
  `WC` 前缀，不进入 API。

- 跨模块类型、枚举放在对应 API 头；纯微信类型放 `WCGestureWeChatClasses.h`。
- 内部 API 可以使用微信私有类型（同一进程内的契约）；**未来的对外 API 不允许**，见第 10 节。

---

## 4. 功能目录规范

```text
Features/<Feature>/
├── WCGesture<Feature>.m         # 实现
├── WCGesture<Feature>Hooks.x    # 该功能的 Logos Hook（可选）
└── WCGesture<Feature>Internal.h # 仅功能内部共享时使用（可选）
```

- 一个功能一个目录，目录名用大驼峰，语义明确（`KeyboardStrip`、`GlobalActions`）。
- `.m` 里不出现 `%hook`，`.x` 里不写业务逻辑；Hook 方法体尽量一行转发。
- 功能内部共享的头文件必须命名为 `...Internal.h`，不得被其他功能引用。

---

## 5. Hook 规范

1. **每个 `.x` 文件必须有且只有一个**：

   ```objc
   %ctor {
       %init;
   }
   ```

   Logos 的 `%init` 是文件作用域，漏掉会导致该文件的 Hook 不生效。

2. **同一个类的同一个方法只能 Hook 一次**。拆分 Hook 文件前先确认没有重复。

3. **App 级 `%hook UIView` 固定在 `Tweak.x`**。
   原因：键盘 dock 的运行时 Hook 必须在 `%init` 之后安装，才能链到 `UIView` 的 `layoutSubviews`。不要把 `UIView` Hook 移到功能目录。

4. 运行时 Hook（`class_addMethod` / `method_setImplementation`）放在所属功能的 `.m` 中，不放进 `.x`。

5. `%new` 方法统一 `wc_` 前缀，例如 `wc_handleReplyPan:`。

6. Hook 里只做三件事：读配置、调用功能函数、`%orig`。复杂判断放进 `.m`。

---

## 6. 命名规范

| 对象 | 规则 | 示例 |
|---|---|---|
| 功能实现文件 | `WCGesture<Feature>.m` | `WCGestureKeyboard.m` |
| Hook 文件 | `WCGesture<Feature>Hooks.x` | `WCGestureMessageHooks.x` |
| API 头 | `WCGesture<Domain>API.h` | `WCGestureInputAPI.h` |
| 跨模块函数 | 新增用 `WCGesture` + 大驼峰；既有 `WC...` 保持原名 | `WCGestureAIPerform`、`WCSynchronizeReplyGesture` |
| 功能内部函数 | `WC` + 大驼峰，`static` | `WCKeyboardEnhanceApply` |
| 类 | `WCGesture` 或 `WC` 前缀 | `WCPopup`、`WCGestureSettingsController` |
| 关联对象 key | `static char WC<Feature><Thing>Key;` | `WCReplyPanRecognizerKey` |
| 通知 | `WCGesture...Notification` | `WCGestureDidChangeNotification` |

禁止无前缀的全局符号。新增符号前先全局搜索，避免与微信或其他 tweak 冲突。

---

## 7. 设置项规范

新增一个设置项必须同时完成：

1. 在 `Sources/Core/WCGestureConfig.h` 声明 key：

   ```objc
   FOUNDATION_EXPORT NSString *const WC<Feature><Option>Key;
   ```

2. 在 `WCGestureConfig.m` 定义，命名空间为：

   ```text
   com.qiu7c.onewx.<area>.<feature>.<option>
   ```

3. 在 `WCGestureRegisterDefaults()` 中注册默认值（**必须有默认值**）。

4. 在 `Sources/UI/WCGestureSettingsVC.m` 增加设置行。

5. 修改后调用 `WCPostChange(key)`，让功能重新同步：

   ```objc
   WCPostChange(WCKeyboardEnhanceEnabledKey);
   ```

6. 需要实时响应的功能，在 `Tweak.x` 的 `WCGestureDidChangeNotification` 观察者里补充 resync。

---

## 8. 新增功能清单

1. 新建 `Sources/Features/<Feature>/`。
2. 写 `WCGesture<Feature>.m`，实现逻辑。
3. 写 `WCGesture<Feature>Hooks.x`，只保留 Hook 转发，并加 `%ctor { %init; }`。
4. 其他模块需要调用的函数：新建或修改 `Sources/API/WCGesture<Feature>API.h`，并加入 `WCGestureInternal.h`。
5. 需要的微信类：加到 `Sources/WeChat/WCGestureWeChatClasses.h`，只声明实际用到的属性/方法。
6. 需要的设置项：按第 7 节添加 key、默认值、界面行。
7. 如果功能依赖键盘或窗口状态，确认初始化时机（见第 5 节第 3 条）。
8. 本机验证：

   ```sh
   # 括号结构检查（本地临时脚本）
   node <checker> Tweak.x $(find Sources -type f -name '*.m' -o -name '*.h' -o -name '*.x')

   # 引用检查：实现文件应只 import 伞头文件
   grep -rn '^#import "Sources/' Tweak.x Sources --include=*.m --include=*.x

   git diff --check
   ```

9. 提交前必须通过 CI（推送后自动构建 rootful + rootless）或设备编译。

---

## 9. 回退与兼容

- 删除或重命名对外 API 函数时，先搜索所有调用点。
- 设置 key 一旦发布不得改名；需要废弃时保留读取兼容，新增新 key。
- 旧手势动作枚举值不得复用（例如 `WCInputActionTranslateLegacy`），避免已保存设置行为变化。

---

## 10. 对外 API（预留）

如果以后需要让其他 tweak 调用 WCGesture，另建：

```text
Sources/Public/
├── WCGesturePublic.h
└── WCGesturePublic.m
```

约束：

- 不出现任何微信私有类型；
- 只有稳定、带版本的 C 函数 / 通知；
- 全部使用 `WCGesture` 前缀；
- 提供 `WCGestureAPIVersion`；
- `.m` 只做转发，实现仍在 `Features/` / `Services/` 内。

---

## 11. 设置界面样式

- 首页六类按聊天类功能/手势类功能/朋友圈功能/界面类功能/增强类功能/插件类配置排列；禁用类已合并：隐藏入口/群标题/分割线归界面类，长按菜单管理归聊天类，去广告归增强类。功能增强放增强类，插件配置保留入口、名称、震感、AI配置、翻译配置与导入导出。

- 首页分类主标题、全部设置页导航标题统一使用半粗字重（用户于 2026-10-28 更新要求），保持原有标题字号并跟随插件界面缩放；子页设置行、分组标题、调节面板和弹窗正文继续使用常规字重。
- 设置列表不添加独立说明小字行；没有子选项的功能直接显示开关，不提供展开箭头或折叠交互。
- 有实际子选项的分组保留箭头及逐层 18pt 缩进。2026-10-28 用户要求每次进入设置页时全部默认收起（含圆角及主页分组设置）；仅搜索定位按需展开目标，展开状态不持久化。输入范围放在占位文字中，不另设说明段落；错误与操作结果可保留。
- 消息时间等功能本身的文字加粗选项不属于设置界面字重，不随界面清理删除。

- 首页页脚居中显示两行：One Wx by Cc，下方为版本号（当前 1.0.0）；这是用户于 2026-10-26 更新的要求。

## 12. 提交规范

- 提交信息用中文概括改动，例如：

  ```text
  拆分 Logos hooks 并按功能整理 Sources
  ```

- 提交前确认：

  - [ ] `git diff --check` 通过
  - [ ] 实现文件只 import 伞头文件
  - [ ] Hook 方法无重复
  - [ ] 新增设置 key 有默认值
  - [ ] README / 本文档的结构说明已同步

- 推送后 CI 会自动构建；构建失败先修复再继续。

- 2026-10-28：分类设置页、圆角设置和主页分组选项合并为每页一张圆角卡片：保留16pt左右留白和顶部/底部圆角，中间功能连续衔接，不逐功能分卡；保留折叠、子项缩进和独立设置页。首页分类卡片、好友/群聊选择卡片保留。
