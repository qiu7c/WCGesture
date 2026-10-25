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
| 版本 | 1.0.0 |
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

### 最新修改（已完成源码接入，待 CI / 真机）

本轮已按用户同意接入推荐的 1–5 组功能：

- 禁用类：隐藏群标题人数/免打扰尾标、截屏分享浮层；“我”页面作品、小店与卡包、表情入口隐藏。更改群标题与入口后重新进入对应页面。作品工厂参数按 8.0.79 改为 CGSize；插件入口不参与隐藏。
- 朋友圈：图片圆角（默认关闭，0–40，默认 8）、精确发布时间（默认关闭，默认 yyyy-MM-dd HH:mm:ss）。日期格式沿用统一编辑器。
- 聊天类：顶栏搜索、引用定位及图片/视频子开关、长按菜单 +1、自动原图、可见语音自动转文字及群聊/私聊/自己过滤；功能默认关闭，默认忽略自己语音。
- 新模块：InterfaceCleanup、MomentsImageCorner、MomentsTime、ChatUtilities、MessageRepeatMenu、AutoOriginal、VoiceTranscription。Tweak.x 只追加通知内 API 同步；已有 BaseMessageCellView 菜单入口和 WCTimeLineCellView 生命周期统一转发，避免重复 Hook。
- 圆角没有照搬 WCAtlas 的全局 depth、仅尺寸缓存和关闭不恢复逻辑：按朋友圈 root 有界遍历图片白名单，排除头像/按钮/文字，不裁整个播放器；拼图整体裁切，半径限制到短边一半，0 为直角。记录原半径/曲线/裁切，复用及关闭恢复；同尺寸换图仍重新识别。
- 聊天搜索直接调用 8.0.79 的 onSearchButton:，复用微信自有搜索生命周期。引用定位不使用其他会话控制器，图片/视频子开关实际参与判断。
- 自动原图合并同一轮待处理请求，调用原生复选框回调；关闭后停止自动选择，不撤销用户当前选择。语音转写延迟再次检查 window、消息身份和开关；防重复请求，3 秒检查结果前再次核对复用身份，不重新实现语音识别。
- 消息 +1 复用现有复读发送 API，接入隐藏/排序/改名链路，按关联标记识别已改名的插件菜单，避免重复添加。
- 配置口令保留旧别名并新增 64 个设置别名，覆盖此前新增及本轮配置；不导出运行记录和自动发现菜单列表。
- 新增 19 个设置 key，全部位于 Core 并注册默认值；更新后仍需 CI 和越狱设备验证。


- 完成 WCAtlas 待迁移盘点与推荐顺序，见 [MIGRATION_BACKLOG.md](MIGRATION_BACKLOG.md)。配置分享白名单本轮已补充；通话音频相关配置项未找到完整实现，不能据此声称可直接迁移。

- 插件设置、预览调节与长按菜单管理的开关统一使用系统蓝色。

- 首页、子页与聊天预览统一使用 20pt semibold 左箭头；原生导航按钮隐藏上一页标题，保留系统返回行为。外观仅设置在插件页面 navigationItem，不修改微信共享导航栏。

- 版本统一为 1.0.0：control 与微信插件注册版本一致。
- 移除界面大小的整页预览入口、调节目标及模拟缩放逻辑，只保留实际布局比例与包含插件界面。
- 聊天预览与调节面板之间留 12pt 间距；展开时缩短预览区域，完整显示输入栏，收起恢复整页。
- 当前账号头像改用 WCAtlas 的 MMHeadImageHelper 三种原生工厂接口，优先高清 URL；服务暂不可用时以缓存 wxid 查询联系人；进入窗口时重试一次未加载头像。
- 全局头像圆角迁移到 Features/AvatarAppearance，默认关闭，程度 0–100（默认 100）。保留原图层状态，关闭恢复；预览头像共用实现。
- 语音转发迁移到 Features/VoiceForward，默认关闭；复用现有语音重发与上传标志流程，混合消息保留 origin 索引对应关系。
- 长按菜单隐藏、排序、重命名迁移到 Features/LongPressMenu；独立管理页沿用卡片、自绘搜索和 WCPopup，支持自动发现与手动添加原名。
- 新功能契约位于 Sources/API，key/defaults 位于 Core。Tweak.x 仅增加现有通知内的同步调用。上版 015e58f 已推送；本轮包含以下迁移、UI 修正和配置备份扩展，统一提交。
- 真机需验证头像加载及圆角恢复、语音单条/混合/多联系人转发、菜单隐藏/排序/重命名、预览面板间距及横竖屏。

### 已完成

本轮已完成源码修改（未提交，待 CI / 真机）：

新增 WCAtlas 聊天输入栏圆角迁移：

- 独立模块 `Sources/Features/ChatInputAppearance/`，契约
  `Sources/API/WCGestureChatInputAppearanceAPI.h`。仅 Hook MMInputToolView 的
  didMoveToWindow/layoutSubviews，未新增 UIView 全局 Hook。
- “界面类功能 → 聊天输入栏圆角”：总开关默认 NO；输入框内部/外部工具栏分别
  开关（默认 YES），半径 0–40，默认 18/22。五个 key 全部定义在 Core 并注册默认值。
- 沿用 WCAtlas 对 MMGrowTextView、外部容器的圆角/连续曲线/裁切处理，关闭时
  恢复原属性。优先使用实测 InputToolContainerView；不会裁切整屏 MMInputToolView。
- 使用弱引用记录工具栏及目标视图，关闭时不遍历输入树。与原配置缓存不同，每次
  原生布局都按当前控件高度更新半径，覆盖输入多行和键盘切换；更换目标时恢复旧视图。
- 整页预览新增“圆角”调节项：开关、滑杆、精确输入、重置、单行/三行/五行。
  预览与真实视图共用半径/图层状态处理；圆角页展开面板后，将工具栏放在面板上方，
  类似键盘展开，避免控件被遮住。总开关关闭时仍可预览配置，实际聊天不启用。
- 半径限制为 min(配置值, 当前高度/2)，0 为直角；非有限输入回退默认值。
  基于实际半径函数的算式执行了 8 个输入/工具栏尺寸案例和 120 个边界组合。
- Tweak.x 本轮仅在既有设置通知内增加圆角同步调用。尚未编译/真机验证，未提交。

最新 UI 修正（优先于下方上一轮保留内嵌预览的记录）：

- 删除旧设置页的防撤回/消息时间/布局内嵌小预览，只保留整页预览入口。
- 预览铺满当前页面，重建聊天顶栏、双方气泡、时间分隔行和底部输入栏。
  输入栏仅为样例，不会发送消息；右上角“调节”展开/关闭底部参数面板。
  同页可切换时间、防撤回、布局和输入栏圆角。离开预览恢复原导航栏状态。
- 按用户提供的 393×852 实测层级：短行高 53、头像 42×42，左头像 (9,2)，右头像
  (342,2)，气泡起点 (60,5)。每条样例都使用独立行 UIView 计算元数据坐标。
  修复旧预览按整页 bounds 裁切、32 点头像和标签未居中造成的偏移。
- 真实消息插入/拦截流程不变；消息时间样式函数仅补齐原生标签已具有的居中对齐。
  读取实际坐标函数的算式做本地回归：50×15 时间框分别得到 (5,38) / (338,38)，
  与用户层级一致；另验证不同宽度和间距。此验证不等于 UIKit 渲染或设备测试。
- 头像改为当前账号真实头像：在 WeChat 适配层通过 CContactMgr.getSelfContact
  获取用户与 URL，按 8.0.79 的 MMHeadImageView 初始化接口创建自动更新头像。
  每行独立实例，禁止头像交互；不写自己的下载器，不用 SF Symbol 冒充头像。
  服务未就绪且无缓存图像时显示中性空容器。
- 跨模块声明新增 Sources/API/WCGestureAccountAPI.h；Tweak.x 本轮未改动。


- 首页保留六分类，恢复显式圆角卡片和同背景自绘搜索框。二级菜单去除竖杠，
  使用字号、18pt 逐层缩进和右侧折叠箭头。旧内嵌预览全部保留。
- 完整移植 WCAtlas 防撤回设置及后端：两种提示方案、本地/回复模板、浅深色、
  气泡旁文字与 X/Y、回复时间限制、记录中心搜索、记录持久化。两功能总开关及自动
  回复开关仍默认关闭。成功后按所选方案插入本地 10000 系统提示或记录侧边提示，
  不再是上一版的简单 Toast。
- 消息时间移植 WCAtlas 头像下方/气泡旁模式、头像间距、自定义格式、8–18 字号、
  加粗、浅深色、分段与复用安全刷新。原有设置 key 保留，旧气泡模式自动保留；新装
  默认头像模式、MM-dd HH:mm:ss。One Wx 另加气泡旁 X/Y 微调。
- 新建 `UI/WCGestureChatOptions.m`、`WCGestureAdjustmentController.m`、
  `WCGestureRevokeRecords.m`、`WCGestureSettingsStyle.m`；颜色/格式辅助放在
  `Core/WCGestureAppearance.m`。后端仍各自在 Features 下。
- 独立位置预览固定在顶部，可拖动、滑杆或输入精确值，自动保存；支持系统/浅/深
  预览与重置。通用入口可接受其他预览 UIView 和参数描述，供后续功能复用。
- “界面大小”去掉括号说明，增加“包含插件界面”（默认 NO）。插件设置和弹窗
  按选定比例调整字体、行高等；布局预览保留。微信原生布局缓存仍需重启完整刷新。
- 本轮 `Tweak.x` 只增加一行防撤回设置同步调用；Hook 仍在对应功能目录。
- 已核对新版 8.0.79 头文件以及 WCAtlas 原源码；本轮没有反编译需求。
- 详细设置逐项对照及设备清单见 [`WCATLAS_PARITY.md`](WCATLAS_PARITY.md)。

以下为此前交接的历史基线：

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
接入用户编写的 WCAtlas 主题缩放实现，设置入口为「界面与布局 → 界面大小」。

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

布局主题 Hook 的 `%orig` 必须单独占行：`@try { value = %orig; }` 的单行写法
会使当前 CI 的 Logos 展开吞掉后面的右花括号，产生 `unexpected '@'` / 缺失
`@finally` / 括号不匹配等连锁错误。改为多行 `@try`，把 `value = %orig;`
独立放一行。普通源码括号检查不能发现这类预处理问题，还需检查 `%orig` 行尾。

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
- [ ] 六分类及顶部搜索正常；关闭功能内的设置可搜索，点击不会自动启用功能
- [ ] 二级分组右侧箭头方向、逐层 18pt 缩进和卡片背景在 Cell 复用后不串位
- [ ] 对方在单聊/群聊撤回已接收消息时原消息保留；自己撤回、关闭开关、原消息缺失时行为正常
- [ ] 消息时间在双方文本/图片/语音、长文本分段、快速滚动复用时不串位、不叠标签、不挡气泡
- [ ] 时间格式/字号/加粗/位置修改后预览和当前聊天更新；关闭后标签隐藏
- [ ] 防撤回/界面缩放预览明确为示意，70–100% 下预览排版无重叠

日志过滤：

```sh
log show --last 5m --predicate 'process == "WeChat"' | grep WCGesture
```

---

## 10. 下一步

设置页最新层级样式：取消竖杠，使用右侧右/下箭头和逐层 18pt 缩进；
「界面大小」保持独立折叠卡片，分割线开关在禁用类功能。实际 iOS 排版仍需真机验证。

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
