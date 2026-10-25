# One Wx 交接文档

最后更新：2026-10-25

本次会话补充：用户要求跳过 CI 结果查询；后续反编译任务开启子代理并指定
`gpt-6-luna`。明确的开发任务直接推进，仅在需求不清或按提交/推送规则需要授权时询问。

本文件用于交接当前状态、架构、已知问题和下一步工作。开发规范见
[`docs/CONVENTIONS.md`](CONVENTIONS.md)。

---

## 1. 项目概况

| 项目 | 值 |
|---|---|
| 产品名 | One Wx |
| 旧名 | WCGesture / 微信手势 |
| 包名 | `com.qiu7c.onewx` |
| 版本 | 2.0.0 |
| dylib / plist | `OneWx.dylib` / `OneWx.plist` |
| 注入目标 | `com.tencent.xin`、`com.tencent.wx`、`com.tencent.qy.xin` |
| 设置命名空间 | `com.qiu7c.onewx.*` |
| 旧命名空间 | `com.qiu7c.wcgesture.*`（仅用于迁移） |
| 仓库 | https://github.com/qiu7c/WCGesture.git |
| 分支 | `main` |
| 本地目录 | `C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCGesture` |

> 注意：产品、包名、dylib 已全部改为 One Wx，但**顶层文件夹和 GitHub 仓库名仍是
> WCGesture**。改名需要在关闭 IDE 后手动执行，见第 7 节。

### 最近提交

| 提交 | 内容 |
|---|---|
| `1987c4c` | 更名为 One Wx，新增布局与字号模块并迁移旧设置 |
| `f6c5c0e` | 修复设置页重复声明 `WCActiveWindow` |
| `4627c53` | 修复布局 Hook 中 `%orig` 嵌套调用 |
| `3fc3e2e` | 修复全局手势模块缺失头文件与可空参数 |
| `d23c002` | 补齐 `WCTranslateEnabledKey` 定义并加入设置迁移 |

最后一次推送触发了 CI（rootful + rootless）。本机没有 `gh`，GitHub API 也经常限流，
构建结果需要在仓库 Actions 页面确认。

---

## 2. 当前状态

### 已完成

- 代码从单一 `Tweak.x` 拆分为模块化结构（`Tweak.x` 约 86 行）
- 内部公共 API 集中到 `Sources/API/`，实现文件只 import 一个伞头文件
- 27 个 Hook 方法全部保留，无重复
- 完整更名为 One Wx（包名、dylib、plist、界面文案、CI artifact）
- 旧设置自动迁移（67 个 key）
- 新增布局模块：聊天字号级别 + 朋友圈高度补偿
- 外部菜单第一轮改名（聊天与输入 / 朋友圈 / 界面与布局 / 插件与 AI / 全局手势）

### 待验证 / 未完成

- **CI 是否全绿**：最后一次推送后未确认
- **设备测试**：布局模块完全没上过真机
- **顶层文件夹 / 仓库改名**：仍是 WCGesture
- **菜单深度整理**：键盘增强独立卡片、AI 与插件设置拆分
- **后续功能转型**：尚未开始第二批功能模块

---

## 3. 目录结构

```text
WCGesture/
├── Tweak.x                       # 只保留 UIView 全局 Hook + %ctor
├── OneWx.plist                   # Theos 注入配置
├── Makefile
├── control
├── docs/
│   ├── CONVENTIONS.md            # 开发规范
│   └── HANDOVER.md               # 本文档
└── Sources/
    ├── API/                      # 模块间契约（内部公共 API）
    │   ├── WCGestureInternal.h   # 唯一伞头文件
    │   └── WCGesture*API.h       # 各领域契约
    ├── Core/                     # Config、Support 实现
    ├── WeChat/                   # 微信类声明、账号、私有 API
    ├── Services/                 # AI、翻译
    ├── UI/                       # 设置页、弹窗、入口 Hook
    └── Features/
        ├── MessageGestures/      # 消息气泡手势 + 语音上传 Hook
        ├── InputGestures/        # 输入框手势
        ├── KeyboardStrip/        # 键盘底部触控区
        ├── Moments/              # 朋友圈双击点赞
        ├── GlobalActions/        # 多指全局手势
        ├── InterfaceTweaks/      # 分割线隐藏
        └── ChatLayout/           # 聊天字号 + 朋友圈高度补偿
```

### 依赖规则（重要）

1. 实现文件只允许：

   ```objc
   #import "Sources/API/WCGestureInternal.h"
   ```

2. `Features/*` 之间禁止互相 import；跨功能调用必须经过 `Sources/API/`。
3. `Sources/API/*.h` 不得 import 伞头文件（避免循环）。
4. 每个 Logos `.x` 必须有且只有一个 `%ctor { %init; }`。
5. 同一个类的同一个方法只能 Hook 一次。
6. `%hook UIView` 固定在 `Tweak.x`：键盘 dock 的运行时 Hook 必须在它之后安装。

完整规则见 `docs/CONVENTIONS.md`。

---

## 4. 核心机制

### 设置与迁移

- 所有 key 定义在 `Sources/Core/WCGestureConfig.{h,m}`
- `WCGestureRegisterDefaults()` 注册默认值
- 启动顺序（`Tweak.x` 的 `%ctor`）：

  ```objc
  WCGestureMigrateLegacyDefaults();   // 先迁移
  WCGestureRegisterDefaults();        // 再注册默认值
  ```

- 迁移标记：`com.qiu7c.onewx.migrated-from-wcgesture`
- 迁移列表是 `WCGestureAllSettingKeys()` 里的静态数组。
  **以后新增 key 时，如果旧版本有对应值，需要手动加进这个数组。**
- 设置变更通过 `WCPostChange(key)` 发 `WCGestureDidChangeNotification`，
  `Tweak.x` 里的观察者负责重新同步键盘、消息手势、全局手势。

### Hook 分发

| 文件 | 内容 |
|---|---|
| `Tweak.x` | `%hook UIView`（分割线）、`%ctor` |
| `Sources/UI/WCGestureEntryHooks.x` | 我页面入口 |
| `Sources/Features/MessageGestures/WCGestureMessageHooks.x` | 消息气泡、聊天控制器 |
| `Sources/Features/MessageGestures/WCGestureVoiceHooks.x` | 语音上传 4 个类 |
| `Sources/Features/InputGestures/WCGestureInputHooks.x` | MMGrowTextView |
| `Sources/Features/Moments/WCGestureMomentsHooks.x` | 朋友圈 Cell |
| `Sources/Features/GlobalActions/WCGestureGlobalHooks.x` | UIWindow |
| `Sources/Features/ChatLayout/WCGestureChatLayoutHooks.x` | CLocalInfo、朋友圈高度类方法 |

---

## 5. 功能清单

| 功能 | 位置 |
|---|---|
| 消息气泡左/右滑、双击/三击（引用/撤回/复制/删除/复读/转发/收藏/翻译/朗读/AI 回复） | `Features/MessageGestures` |
| 语音复读上传 Hook | `Features/MessageGestures/WCGestureVoiceHooks.x` |
| 输入框滑动/多击（清空、粘贴、复制、剪切、大小写、去空格、翻译、AI） | `Features/InputGestures` |
| 键盘底部触控区 + 签名 + 调试框 | `Features/KeyboardStrip` |
| 朋友圈双击点赞 | `Features/Moments` |
| 多指全局手势（截图、返回、首页、扫码、菜单、设置、朋友圈、加好友、自定义页、二维码、付款码） | `Features/GlobalActions` |
| 分割线隐藏 | `Features/InterfaceTweaks` |
| 聊天字号级别、朋友圈高度补偿 | `Features/ChatLayout` |
| AI 回复/回答/润色、动态提示词方案 | `Services/WCGestureAI` + `API/WCGestureAIAPI.h` |
| 翻译（Edge / MyMemory / AI） | `Services/WCGestureTranslate` |
| 设置页 | `UI/WCGestureSettingsVC.m` |

---

## 6. 布局模块说明

### 2026-10-25：以缩小界面为目标整合 WCAtlas

用户明确布局功能的主要目标是缩小、提高同屏信息量。现已在既有 ChatLayout 模块
接入用户编写的 WCAtlas 主题缩放实现，设置入口为「界面与布局 → 界面大小（缩小布局）」。

- 新 key：`com.qiu7c.onewx.interface.page-scale.enabled`（默认 NO）与
  `com.qiu7c.onewx.interface.page-scale.percent`（默认 90，限制 70–100）。
- Hook `MMThemeManager` 两个 `getValueOfProperty:inRuleSet:` 变体与 `WAThemeProxy`
  类方法，仅复制并缩放 `#font_set` 下 `alllevel` / `chatLevel` 数组首值，保留数字/字符串类型。
- 嵌套主题查询按线程计数，避免代理和 manager 相互调用时重复缩放。
- 开启时 `CLocalInfo` 全局/WebView 字号均返回 1，WebView 同步文字缩放；100% 是
  level 1 基准，不代表用户原字号。关闭才恢复原始 getter 结果。
- 旧字号与朋友圈高度配置保留，开启新模式时暂停旧逻辑。朋友圈使用原生测量高度，
  不直接把整格高度乘以小于 1 的比例，避免图片、评论被裁切。
- 新模式默认关闭，不自动迁移 WCAtlas 或旧字号配置，避免未经选择改变用户布局。
- 设置变更通知刷新当前窗口布局/WebView；原生缓存的完整刷新仍需重启微信。
  WebView 记录微信请求的 zoom，关闭后恢复该请求值。
- Makefile 增加 WebKit；跨模块 API 仍经 `WCGestureChatLayoutAPI.h` 暴露。

能力边界：目前缩放微信主题控制的文字/布局与网页文字，不保证固定头像、图片、
所有控件等比例缩小。黄白二进制的具体补偿算法仍未确认，不将推测当成已实现行为。
本次未本地编译、未查询 CI、未完成真机验证。

真机重点验证：70/80/90/100% 下聊天长文、引用、图片、语音、朋友圈正文/评论的
换行与触控位置；网页反复进出不累乘；关闭并重启恢复原设置；旧高度补偿开启时新模式
不叠加。与 WCAtlas 同装时须关闭其中一个插件的界面缩放，避免两套 Hook 叠加。

### 逆向结论（黄白助手 2.1.9）

分析对象：

- 原始 deb：`C:\Users\HX2026\Desktop\Tweak\黄白助手2.1-9_无根(1).deb`
- 解包目录：`C:\Users\HX2026\Desktop\Tweak\_analysis_huangbai`
- 参考头文件：`C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\Wechat Header 8079\WeChat_headers_2026-10-25_09-18-08`

可确认的实现方式：

1. **聊天字号**：通过 `CLocalInfo.m_uiGlobalFontLevel` 控制微信全局字号，
   布局由微信自己重排。
2. **朋友圈高度**：引用/覆盖 `WCListBaseCellView`
   `+getLayoutHeightWithGroup:groupItem:width:isFirstOneInsection:isLastOneInSection:`
   和 `WCTimeLineCommentCellView`
   `+getCellHeightForDataItem:RowIndex:pageContext:`。
3. 设置页 `TheSpecialController` 有 `setChatLayoutSize`、`setTextSizeFromChat`、
   `enableSizeFontSet:` 等入口。

限制：类名和界面字符串有混淆，二进制中没有 Logos 符号，还存在反逆向
category，**具体倍率和 Hook 绑定类无法静态确认**。

### 我们的实现

- `Features/ChatLayout/WCGestureChatLayout.m`
  - `WCChatLayoutResolvedFontLevel(original)`：开关开启时返回 1–8 的配置级别
  - `WCMomentsLayoutAdjustedHeight(height)`：按 100–160% 缩放
- Hook：
  - `CLocalInfo -m_uiGlobalFontLevel`
  - `WCListBaseCellView +getLayoutHeightWithGroup:...`
  - `WCTimeLineCommentCellView +getCellHeightForDataItem:RowIndex:pageContext:`
- 设置项在「界面与布局」：
  - 聊天字号定制 / 字号级别
  - 朋友圈高度补偿 / 高度比例

### 调参注意

- 字号级别范围暂定 1–8，需要真机确认微信实际接受的区间
- 朋友圈补偿默认关闭，避免和字号改动叠加
- 如果发现高度被重复缩放，检查是不是两个高度方法同时作用于同一类 Cell

---

## 7. 更名与兼容

### 旧 → 新

| 旧 | 新 |
|---|---|
| `com.qiu7c.wcgesture` | `com.qiu7c.onewx` |
| WCGesture / 微信手势 | One Wx |
| `WCGesture.dylib` | `OneWx.dylib` |

### 迁移逻辑

- 67 个旧 key 在首次启动时复制到新 key
- 新 key 已有值时不覆盖
- 复制后写入迁移标记，避免重复执行
- key 改名后不得再次变更；需要废弃时保留兼容读取

### 仍未改名

- 顶层文件夹：`WCGesture`
- GitHub 仓库名 / remote：`WCGesture.git`

关闭 IDE 后手动执行：

```bat
cd C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat
ren WCGesture OneWx
```

GitHub 仓库改名需要在网页或 `gh repo rename` 中操作，改名后同步 remote。

---

## 8. 构建与 CI 踩坑记录

### 构建

```sh
make clean package FINALPACKAGE=1
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

CI：`.github/workflows/build.yml`，推送 `main` 时自动构建 rootful + rootless，
产物名为 `OneWx-<scheme>`。

### 已踩过的坑

| 报错 | 原因 | 修法 |
|---|---|---|
| `static declaration of 'WCActiveWindow' follows non-static declaration` | 设置页保留了旧的本地实现，和公共 API 冲突 | 删除本地 `static`，用 `WCGestureSupport.m` 的实现 |
| `expected ')'`（Logos 生成代码） | `%orig` 不能直接嵌在函数调用参数里 | 先赋给局部变量再传参 |
| `call to undeclared library function 'objc_msgSend'` | 拆模块时漏了 `<objc/message.h>` | 补 import |
| `null passed to a callee that requires a non-null argument` | API 参数标注了非空，但菜单回调传 nil | 参数改 `_Nullable`，实现里回退到 `WCRootTopController()` |
| `Undefined symbols: _WCTranslateEnabledKey` | 只有声明，Config.m 没有定义（来自未推送版本） | 补定义并加入迁移数组 |
| 键盘模块可能缺少 `objc/runtime.h` | 使用关联对象和 `imp_implementationWithBlock` | 已补 |

### 以后加文件时的自检

```sh
# 结构检查（本地临时脚本）
node <checker> Tweak.x $(find Sources -type f \( -name '*.m' -o -name '*.h' -o -name '*.x' \))

# 实现文件应只 import 伞头文件
grep -rn '^#import "Sources/' Tweak.x Sources --include=*.m --include=*.x

# 静态函数不要和 API 声明重名
# 每个 .x 必须有且只有一个 %ctor
git diff --check
```

---

## 9. 设备验证清单

安装后重点验证：

- [ ] 设置页能打开，五个入口正常
- [ ] 旧 WCGesture 设置迁移成功（翻译开关、AI key、手势动作）
- [ ] 聊天字号 1–8 切换后聊天布局正常，无裁切
- [ ] 关闭字号定制后恢复微信原生字号
- [ ] 朋友圈高度 100–160% 无空白、无截断
- [ ] 消息手势、输入框手势、键盘触控区不受影响
- [ ] 全局手势、扫码、付款码、自定义页面正常
- [ ] 分割线隐藏开关正常

日志过滤：

```sh
log show --last 5m --predicate 'process == "WeChat"' | grep WCGesture
```

---

## 10. 下一步

1. **确认 CI 全绿**，再上设备验证布局
2. 根据真机效果调整字号范围、朋友圈补偿算法
3. 顶层文件夹和 GitHub 仓库改名为 OneWx
4. 外部菜单深度整理：
   - 键盘增强独立卡片
   - AI 与插件设置拆开
   - 按「聊天 / 界面 / 朋友圈 / 全局 / AI」重新分组
5. 第二批转型功能（待定）：界面美化、自动化、通话/媒体等

---

## 11. 外部参考资料

| 内容 | 路径 |
|---|---|
| 微信 8.0.79 头文件（113,618 个） | `C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\Wechat Header 8079\WeChat_headers_2026-10-25_09-18-08` |
| 黄白助手 deb | `C:\Users\HX2026\Desktop\Tweak\黄白助手2.1-9_无根(1).deb` |
| 黄白解包与分析产物 | `C:\Users\HX2026\Desktop\Tweak\_analysis_huangbai` |
| WCAtlas 源码 | `C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCAtlas` |
| 关键头文件 | `CLocalInfo.h`、`UIFont.h`、`WCListBaseCellView.h`、`WCTimeLineCommentCellView.h` |

> `_analysis_huangbai` 是从不可信 deb 解包出来的，只用于分析，不要合并进仓库，
> 也不要直接运行其中的文件。
