# One Wx

Current package version: 1.0.0.

- 2026-10-28 WeChatX 源码接入：界面类新增主页右滑扩展、主页分组；聊天类新增突破多选限制；广告精简扩展为去除广告。包含原生会话动作、9999/999 多选、421 条候选广告规则、分组成员/排序/即时消息/外观调节。新增总开关默认关闭，广告沿用原开关。尚未编译或真机验收，见 [接入记录](docs/WECHATX_PORTS.md)。

- 2026-10-28 源码接入：聊天类 → 图片编辑增强（圆/椭圆、箭头、颜色及线宽）；增强类 → 替换头像（按账号/联系人保存、修改与恢复）；视频通话增强 → 虚拟视频（文件、方向/镜像、文件音轨/麦克风混音）；钱包金额本机显示新增零钱通/经营账户；本地聊天编辑新增记录卡片标题/描述；贴纸新增基础文字。新增能力默认关闭，尚未编译/真机验证。原版证据、One Wx适配和未还原的在线模板/PAG范围见 [接入依据](docs/REVERSE_IMPLEMENTATION_EVIDENCE.md)。

- 聊天类功能 → 本地聊天编辑：独立开关控制文字、时间标签、图片/视频替换、当前聊天排序和转账卡片金额显示。长按对应消息操作；时间分隔标签直接长按修改、留空恢复。媒体通过系统照片选择器选择，点击替换媒体打开本地预览；原文件不覆盖。菜单统一使用“修改 / 恢复 / 排序 / 结束排序”；恢复作用于当前消息，离开会话恢复所持内存内容；排序只调整当前控制器的节点数组，不写数据库顺序。
- 增强类功能 → 钱包余额本机显示：仅替换钱包余额控件的显示数字，金额 0 或关闭时恢复原生更新值；不修改真实余额或支付请求。
- 手势类功能 → 输入框手势 → 长按动作 → 现场录音后发送：长按录音、松开发送微信原生语音条、上滑 60pt 后松手取消，最短 0.5 秒、最长 60 秒。麦克风权限、离页、切后台、音频中断、账号/会话切换及编码完成时均核对状态，取消的录音不会发送；首次授权期间松开后需重新长按。编码复用 WCAtlas 的原版 Silk SDK，保留 Vendor/Silk/LICENSE-SKYPE.txt。上述新增功能默认关闭/不设置，尚未编译和真机验证；虚拟视频未接入。

- 增强类功能 → 虚拟定位：迁移 WCAtlas 的原生地图选点、手动经纬度、最多20个收藏、四向微调及朋友圈独立开关。默认关闭，取消选点不保存，选点期间暂停替换坐标，清除或关闭后恢复原生坐标；待编译和设备验证。

- 增强类功能 → 页面上锁: independent locks for Me → Services, Favorites and personal Moments album entries, using system biometrics with device-passcode fallback. Each entry needs a new verification; canceled, failed or stale requests do not navigate, and authorization is scoped to that page. All disabled by default; compilation/device verification pending. See docs/SERVICE_PAGE_LOCK.md.

- 朋友圈功能 → 朋友圈转发: adds Forward to the native More menu and the compact inline action row, opening WeChat's native Moments composer for text, up to nine photos, video, or supported structured shares. The native menu entry works independently of custom feed layout. Media are downloaded through WCMediaDownloader when needed; publication remains manual. Disabled by default. Live Photos follow WCAtlas's static-image forwarding path. Compilation/device verification pending.

- 朋友圈功能 → 朋友圈排版: adjustable extra spacing (0–48pt, default 8), wrapping native location labels and timestamp text, and Like/Comment/Forward buttons aligned with the time text, using 16pt icons to the left of 13pt captions in a 32pt row, with more space below the post body. An optional switch hides button text; narrow layouts use icons. Native permission/delete icons sit below location, followed by at least 12pt × layout scale of space before comments; the actual table row gets a measured minimum height. Location text, color and taps remain native; action icons use the system label color (black in light mode). Disabled by default; source integrated, awaiting compilation and device validation. The full-page preview offers live 60–180% button sizing (100% keeps the current compact size), the existing 0–40pt Moments corner setting, title visibility and spacing. Photos, video, location and owner controls are sample content; actual buttons and the preview share metrics/style and the corner-radius resolver. Location now precedes the time/action row. Row remeasurement waits until scrolling stops, and button styling is cached. Preview is also accessible from 圆角设置 → 朋友圈圆角.

One Wx is a WeChat enhancement plugin that grew out of WCGesture (originally extracted from [WCAtlas](https://github.com/qiu7c/WCAtlas)). It covers gestures, the keyboard strip, AI, translation, global actions, layout and interface tweaks.

## Features

The home page has seven categories: 聊天类功能 / 手势类功能 / 朋友圈功能 / 界面类功能 / 禁用类功能 / 增强类功能 / 插件类配置.
The search bar lists first-level feature entries only, including disabled features, and opens their group without enabling them. Nested settings stay inside their feature pages.

**聊天工具 (Chat tools)**:
- Anti-revoke ports WCAtlas's original message lookup/interception, local system-message or side-prompt display, templates, light/dark colors, optional sender reply and age filter, searchable records and optional local persistence. Disabled by default; automatic replies are also off by default.
- Message times port WCAtlas's below-avatar / bubble-side modes, avatar spacing, custom date format, 8–18pt font, bold, light/dark colors, split-message handling and reuse-safe refresh. Disabled by default.
- A full-page chat preview includes the chat header, native account avatars, separate message rows and an input-bar mock. The top-right control opens a panel for time / anti-revoke / input-rounding adjustments, dragging, numeric entry, reset and light/dark preview. The panel has a 12pt gap from the preview. Layout scaling has no simulated preview.
- Voice forwarding reuses the native recipient picker and existing voice resend/upload pipeline; off by default.
- Long-press menu management supports discovery, manual names, hiding, drag sorting and renaming with the current card/search UI; off by default.
- Global avatar rounding supports 0–100% (100% circular), restores original layers when disabled and applies to preview avatars. Avatar loading uses WCAtlas's MMHeadImageHelper factories and the current account contact.
- The old inline previews have been removed from settings. Real labels and full-page previews share formatting/style and row-local coordinate helpers; the input bar is illustrative and sends no messages.
- Time labels hide when there is insufficient side space. Actual message rendering and recall behavior still require device validation.

**消息手势 (Message gestures)** — on chat message bubbles:
- Left swipe / right swipe (separately for your own vs. the other party's messages)
- Double tap / triple tap (separately for your own vs. the other party's)
- Per-gesture selectable action: 引用 (quote) · 撤回 (revoke, self only) · 复制 (copy) · 删除 (delete) · 复读 (repeat)
- Adjustable trigger distance (36–100 points)

**界面大小 (Layout)** — smaller, denser native layouts based on WCAtlas:
- Enable “界面大小” under “界面类功能”, then choose 70–100% (default 90%)
- “包含插件界面” also scales One Wx's own settings and popup metrics; off by default
- Scales WeChat's `#font_set` theme values (`alllevel` / `chatLevel`) from font level 1, plus WebView text
- 100% means the unscaled level-1 baseline; switch the feature off to restore WeChat's original font level
- Native content reflows through WeChat; fixed-size images and controls are not universally scaled
- Restart WeChat after changing or disabling the feature to refresh cached native layouts
- Previously enabled legacy chat-font and Moments-height settings can be adjusted or disabled when interface scaling is off; they are suspended while it is on

**聊天输入栏圆角 (Chat input rounding)** — ported from WCAtlas:
- Under 界面类功能, independently round the input field and outer toolbar (0–40pt; defaults 18/22)
- Master switch is off by default; disabling restores each view's original radius, corner curve and clipping
- The full-page preview has a 圆角 target with single/three/five-line input modes, sliders and numeric entry
- Radius is capped at half the current view height; native and preview controls use the same implementation

**输入框滑动 (Input-box swipe)** — on the chat text input:
- Left swipe clears the input
- Right swipe pastes the clipboard

复读 (repeat) covers text, image, video, and voice messages. Voice repeat sends through WeChat's native `AudioSender` resend pipeline; other types go through the native `ForwardMessageLogicController`. Unlike WCAtlas, this build does **not** include the send-confirmation dialog — repeat fires immediately.

## Latest WCAtlas migrations (device validation pending)

- 聊天类功能 → 指定会话发送前确认：默认关闭；好友和群聊按账号保存名单，支持资料页及自绘资料卡快捷开关。沿用 WCAtlas 的前台当前会话保护范围，接入文字、图片、视频、表情和插件复读，提供仅发送本条、发送并临时暂停（默认 60 秒）及取消。普通录音语音、支付和其他发送入口不属于此覆盖范围，尚待编译与真机验证。

- 聊天类功能 → 图片编辑快捷发送：编辑图片菜单新增“发送到当前会话”，跳过联系人选择并保留微信原生发送确认；仅使用编辑结果，默认关闭。
- 聊天类功能 → 通话接通自动扬声器：语音接通后切换一次，排除视频通话及蓝牙/有线等外接路由，默认关闭。两项均待编译与设备验证。

- Interface cleanup: hide group title tails, screenshot sharing overlays, and selected Me-page entries. Reopen the affected page after changing title/entry visibility.
- Moments: image rounding (0–40pt, default 8) and precise publication dates with a custom format. Rounding now covers the native inline video container, native grid media and the contact-profile album entrance. It preserves each target’s original layers with one owner, reapplies after private layout, and excludes avatars/text/fullscreen players; the supplied album hierarchy now permits media inside the photo/video cells’ UIButton wrappers and rounds each grid thumbnail separately, including three-thumbnail album rows, while keeping each individual puzzle thumbnail clipped as one tile. The contact-profile video-channel entrance also rounds direct cover thumbnails from its native coverStackView, preserving sibling identity/authentication content. Device verification remains pending.
- Chat: native search button through MMUICommonUtil and the current chat’s MsgSearchHelper/WCSearcher, with cancel/return cleanup (latest correction awaits device validation); quote location with image/video filters; a +1 menu item sharing the existing repeat pipeline and menu management.
- Native original-quality selection in asset picker/preview; auto transcription for visible voice cells, with private/group/self filters and reuse-safe deferred requests.
- New feature switches default to off. Auto transcription ignores self-sent voices by default. Configuration share codes preserve old aliases and add 64 setting aliases; runtime records are excluded.

## Automatic device login confirmation (device validation pending)

“增强类功能 → 自动确认登录” confirms computer/tablet device-login cards through WeChat’s native confirm action. Off by default; enabling skips manual confirmation. Detached cards, disabled/error states and replaced login info are checked again before confirmation. Each login-info object is attempted once per card; a failure remains available for manual handling. The setting is included in configuration share codes.

## Moments monitoring and background keep-alive (device validation pending)

- 朋友圈功能 → 朋友圈特别关心: searchable friend selection with native avatars, 30–3600 second checks (default 60), an initial baseline and per-account deduplication. Optional text forwarding to yourself or File Transfer Assistant; images and videos are separate opt-ins, including the Live Photo video branch.
- 朋友圈功能 → 朋友圈互动通知: native unread-count/message observation for likes and comments, optional details and native Moments initialization. Foreground banner queue and background local notifications open Moments when tapped.
- 增强类功能 → 后台保活: native background tasks plus on-demand looping silent audio, with cleanup on foreground entry or disable. This remains an independent switch; enabling reminders does not enable keep-alive.
- All three main switches and forwarding switches default to off. Runtime state is excluded from share codes. Background execution depends on iOS and cannot survive process termination; detection, notifications, media sending and audio coexistence require device testing.

## Small chat tools and contact information (device validation pending)

- 聊天类功能 → 通话气泡二次确认: asks before redialing from a voice/video call-record bubble. Checks the original message again when confirming to avoid acting on a reused cell. Other call entry points are outside this feature.
- 界面类功能 → 资料信息卡片: adds a 资料信息 row to friend/group/member profiles. Opens a centered rounded popup, sized to fit the safe area and its fields, with a lighter material-blur background, aligned field/value rows and uncropped native avatars. Basic information stays on one page; region and sex are omitted, while the common-group list can scroll. Fields support tap-to-copy; common groups use native asynchronous lookup and an in-popup list that opens the selected conversation after dismissal. Reads locally available account/profile/group fields; unavailable fields are omitted. It does not include WCAtlas's unrelated payment-name lookup, message-block/send-confirmation controls or group-member removal actions.
- 聊天类功能 → 自动勾选合并发送: requires 自动勾选原图 and the native eligible/visible combine option. Sets the native control center and selection view together, once per eligible control-view period, so ordinary refreshes respect manual deselection. Turning it off stops automatic selection without clearing the user's native choice.
- All three switches default to off and are included in configuration share codes.

## Central corner settings (device validation pending)

“界面类功能 → 圆角设置” contains avatar, input/toolbar, Moments, emoticon and chat-image rounding. Existing setting values are preserved. New emoticon/image switches default to off with an 8pt radius (0–40pt, capped at half the view's short side). Emoticon rounding covers the native picker media slots and sent MMEmoticonView; image rounding is separate and scoped to YYAsyncImageView in ImageMessageCellView. Original layers restore on disable/reuse; image scale and source files are unchanged. Native rendering and GIF/reuse behavior still need device validation.

## Chat top capsules (device validation pending)

“界面类功能 → 胶囊顶栏” ports WCAtlas's avatar/name/back capsule and more/search capsule; off by default. The existing full-page message-time preview adds a “顶栏” target, sharing the native capsule renderer and your current-account avatar. It supports frosted/pseudo-liquid glass, 0–100% glass transparency (default 50), 20–100% blur, independent 80–140% outer-shell sizing and 12–26pt icon sizing, plus 24–34pt avatars and 12–18pt names. Glass transparency leaves text and icons fully visible. Long names truncate within the available navigation width; compact glass follows the interface scale inside a 44pt navigation host. Search and multi-select restore the native bar, and leaving/turning off restores saved navigation state, including shared navigation backgrounds. The pinned-message header uses the same blur intensity on frosted glass, capped at the original 40pt even when the list expands, without applying the interface scale a second time. The existing preview includes a pinned-row sample. No separate preview page or explanatory small-print rows are introduced. Background cleanup is confined to the navigation bar and chat-specific views. Shared backgrounds restore before the native leaving callback; only the chat item stays through the outgoing transition, and cancelled transitions reinstall it. Private navigation backgrounds, transitions, dark mode and search coexistence require device verification.

## Notification direct chat (device validation pending)

“聊天类功能 → 通知直达聊天” ports WCAtlas's notification tap routing; off by default. A normal message-notification tap uses the native conversation navigation with the notification's `u` username. Quick replies and other notification actions retain native handling. Startup/unlock retries are bounded, newer taps replace pending navigation, and account changes cancel it.

## Ad cleanup (device validation pending)

“禁用类功能 → 广告精简” is off by default. It covers the ported Moments ad-list, public-account ad insertion/push, mini-app splash and known ad-resource URL paths. Private signatures are adapted to 8.0.79. Following a reported Moments crash, native ad-update inputs and model metadata are preserved; list reads return separate mutable empty lists when enabled. The crash fix still needs device verification. This does not establish complete coverage of video-channel ads; refresh/reopen affected pages when testing.

## Code layout

`Tweak.x` contains only the app-wide `UIView` hook and the `%ctor` that wires
everything together. Each feature owns a folder with its logic and its Logos
hooks; shared code sits outside `Features/`:

| Folder | Responsibility |
|---|---|
| `Sources/API/` | Internal public API: one contract header per domain plus the `WCGestureInternal.h` umbrella |
| `Sources/Core/` | Settings keys and shared helpers (KVC, window, presentation, toast, haptics) |
| `Sources/WeChat/` | WeChat class declarations, account/current user, private API wrappers |
| `Sources/Services/` | Cross-feature services: AI completion client and translation engines |
| `Sources/UI/` | Settings page, popup helpers, the Me-page entry hook |
| `Sources/UI/WCGestureSettingsHome.m` | Six-category home and settings search |
| `Sources/UI/WCGestureChatPreview.m` | Full-page chat scene and row-local metadata previews |
| `Sources/Features/AntiRevoke/` | Verified other-party revoke interception |
| `Sources/Features/MessageTime/` | WCAtlas message-time modes, split-part selection and reuse cleanup |
| `Sources/UI/WCGestureChatOptions.m` | Shared full WCAtlas chat-settings catalog and editors |
| `Sources/UI/WCGestureAdjustmentController.m` | Full-page preview with an optional adjustment panel |
| `Sources/Features/MessageGestures/` | Bubble swipes/taps, repeat path, voice-upload hooks |
| `Sources/Features/InputGestures/` | Input-box swipes/taps and their actions |
| `Sources/Features/KeyboardStrip/` | Keyboard bottom gesture strip |
| `Sources/Features/ChatLayout/` | WCAtlas theme/WebView size scaling and legacy layout compatibility |
| `Sources/Features/ChatInputAppearance/` | Input/toolbar rounding, restoration and native layout hooks |
| `Sources/Features/InterfaceCleanup/` | Group title, screenshot overlay and Me-entry visibility |
| `Sources/Features/MomentsImageCorner/` | Scoped image rounding, reuse and original-state restoration |
| `Sources/Features/MomentsTime/` | Precise Moments publication dates |
| `Sources/Features/ChatUtilities/` | Native chat search and referenced-message location |
| `Sources/Features/MessageRepeatMenu/` | +1 menu using the existing repeat API |
| `Sources/Features/AutoOriginal/` | Original-quality picker/preview selection |
| `Sources/Features/VoiceTranscription/` | Native visible-voice transcription with filtering and deduplication |
| `Sources/Features/AvatarAppearance/` | Global avatar rounding and restoration |
| `Sources/Features/VoiceForward/` | Native voice forwarding using the shared resend pipeline |
| `Sources/Features/LongPressMenu/` | Discover, hide, order and rename native menu items |
| `Sources/Features/Moments/` | Moments double-tap like |
| `Sources/Features/GlobalActions/` | Multi-finger global actions and custom pages |
| `Sources/Features/InterfaceTweaks/` | App-wide interface enhancements (separator hiding) |

All cross-module contracts live in `Sources/API/`. Implementation files import
only `Sources/API/WCGestureInternal.h`; a feature never includes another
feature's header directly. Foundational headers (`WCGestureConfig.h`, the
WeChat class declarations, `WCGestureAccount.h`, `WCGesturePrivateAPI.h`) are
pulled in by that umbrella.

A new feature is one folder under `Sources/Features/`; anything other modules
need to call is declared in `Sources/API/` and exposed through the umbrella.
Every `.x` file declares its own `%ctor { %init; }`, as Logos requires for each
translation unit that defines hooks. The app-wide `UIView` hook stays in
`Tweak.x` so the keyboard dock hook is always installed after it.

Development conventions (layout rules, API and hook rules, new-feature
checklist) are in [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md).
Project status, architecture notes and build/CI pitfalls are in
[`docs/HANDOVER.md`](docs/HANDOVER.md).

## Entry

A **One Wx** row is injected into WeChat's Me page (`MoreViewController`) function section. Tapping it opens the settings sheet. When WeChat's `WCPluginsMgr` registration API is available, the entry is also registered there.

## Build

The GitHub Actions workflow from WCAtlas builds rootful and rootless `.deb` for `arm64`/`arm64e`. You can also build locally with Theos:

```sh
make clean package FINALPACKAGE=1
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

## Settings keys

All keys live under the `com.qiu7c.onewx.*` namespace. Settings saved by the old WCGesture build (`com.qiu7c.wcgesture.*`) are migrated once on first launch.

| Key | Default |
|---|---|
| `com.qiu7c.onewx.enabled` (master) | YES |
| `com.qiu7c.onewx.chat.reply-swipe` | NO |
| `com.qiu7c.onewx.chat.reply-swipe.self-action` | Quote (1) |
| `com.qiu7c.onewx.chat.reply-swipe.other-action` | Quote (1) |
| `com.qiu7c.onewx.chat.reply-swipe.right.self-action` | None (0) |
| `com.qiu7c.onewx.chat.reply-swipe.right.other-action` | None (0) |
| `com.qiu7c.onewx.chat.reply-swipe.trigger-distance` | 56.0 |
| `com.qiu7c.onewx.chat.message-gesture.double-tap.self/other-action` | None (0) |
| `com.qiu7c.onewx.chat.message-gesture.triple-tap.self/other-action` | None (0) |
| `com.qiu7c.onewx.chat.input-swipe-actions` | NO |
| `com.qiu7c.onewx.chat.anti-revoke.enabled` | NO |
| `com.qiu7c.onewx.chat.message-time.enabled` | NO |
| `com.qiu7c.onewx.chat.message-time.format` | MM-dd HH:mm:ss |
| `com.qiu7c.onewx.chat.message-time.font-size` | 10.0 (8–18) |
| `com.qiu7c.onewx.chat.message-time.bold` | NO |
| `com.qiu7c.onewx.chat.message-time.position` | 2 (bottom; 0 top, 1 center) |
| `com.qiu7c.onewx.chat.message-time.below-avatar` | YES (new installations) |
| `com.qiu7c.onewx.chat.message-time.bubble-side` | NO (existing bubble-only settings are preserved) |
| `com.qiu7c.onewx.chat.message-time.avatar-spacing` | -2.0 (-6–8) |
| `com.qiu7c.onewx.chat.message-time.offset-x/y` | 0.0 (-80–80) |
| `com.qiu7c.onewx.interface.page-scale.enabled` | NO |
| `com.qiu7c.onewx.interface.page-scale.percent` | 90.0 (70–100) |
| `com.qiu7c.onewx.interface.page-scale.plugin-ui` | NO |
| `com.qiu7c.onewx.interface.chat-input-rounding.enabled` | NO |
| `com.qiu7c.onewx.interface.chat-input-rounding.inner` | YES |
| `com.qiu7c.onewx.interface.chat-input-rounding.outer` | YES |
| `com.qiu7c.onewx.interface.chat-input-rounding.inner-radius` | 18.0 (0–40) |
| `com.qiu7c.onewx.interface.chat-input-rounding.outer-radius` | 22.0 (0–40) |
| `com.qiu7c.onewx.chat.layout.enabled` | NO |
| `com.qiu7c.onewx.chat.layout.font-level` | 2 |
| `com.qiu7c.onewx.chat.layout.moments-enabled` | NO |
| `com.qiu7c.onewx.chat.layout.moments-scale` | 115.0 |

## License

WCAtlas setting-by-setting coverage, runtime behavior and device-validation checklist:
[`docs/WCATLAS_PARITY.md`](docs/WCATLAS_PARITY.md).

See WCAtlas for upstream attribution. This extraction is derivative of WCAtlas by qiu7c.

## Automatic personal status updates (device validation pending)

- 增强类功能 → 自动更新微信状态: daily hour (0–23, default 08:00), native status icon or a custom icon ID/description, optional custom text or a plain-text API, and local/image-API/video-API backgrounds. Off by default; the “立即更新” action bypasses the schedule.
- Reconstructed from static analysis of the user-provided PKC 0.9-9-Beta2 package, using WeChat's native TextStatePublishViewController, image callback and SightDraft video path. Only the requested feature is recreated; no package executable, licensing code or bundled private network service is included.
- The existing careEnoughForTheLiving callback checks the local calendar day and hour. Each account records an attempt before publishing, so an automatic failure does not retry that day; manual update remains available. This follows the original attempt timing, with per-account isolation.
- Background imports run outside the UI thread, are copied into managed local storage and are excluded from share codes. Importing an image/video replaces the other local background type. API fields accept user-supplied HTTP/HTTPS URLs; text APIs return UTF-8 plain text, media APIs return image/video bytes.
- Native compatibility, server acceptance, media processing and daily execution require device verification. Static checks do not confirm successful publication or guaranteed background execution. See [static analysis notes](docs/PKC_AUTO_STATUS_ANALYSIS.md).

Chat image/video rounding now clips the dedicated message media container, including native backgrounds, video duration overlays and playback controls, using the existing chat-image radius setting. It resolves the native image/thumb slot and excludes the full message row, avatars and timestamps; device verification is pending.

The existing 朋友圈圆角 setting also rounds the individual 发表 / 私密发表 album entry buttons. 聊天媒体圆角 is the image/video rounding setting label; existing keys and saved values remain compatible.

The shared full-page preview now includes avatar rounding. Its editing toolbar remains visible with or without capsule navigation, opens the matching panel on entry and uses named adjustment targets. Preview message avatars follow the layout percentage (42pt × scale); actual chat avatar dimensions are unchanged. Glass rendering is frosted only; the old style setting is retained solely for config compatibility. Blur intensity is 0–100%, with opacity controlled separately; device verification remains pending.

## Settings entry locations and profile clearing (device validation pending)

- 插件类配置 → 设置入口 uses a three-way segmented control: 我的页面 / 插件管理 / 微信设置. The initial automatic choice prefers a compatible WCPluginsMgr; when unavailable, the Me-page option is selected. Explicit settings-page selection remains available without the manager. Entries follow the configured plugin name and only one location is maintained.
- Manager registration passes the settings controller's class-name string, with deduplication/removal limited to One Wx models. Native page rows are individually marked and rebuilt as needed. The settings-page technique was checked against [Mieing/WCTestHook](https://github.com/Mieing/WCTestHook); its MIT notice is retained in docs/THIRD_PARTY.
- 清空地区与性别信息 is a confirmed action, not a switch: it clears the native profile's country/province/city, attempts sex=0 and calls WeChat's native Save. The source plugin itself states sex clearing may be unsupported. One Wx reports that the save was invoked, without claiming a server-acknowledged result. No action runs merely from installing the plugin or opening settings.

增强类功能 contains 自动确认登录, 自动更新微信状态, 后台保活 and 清空地区与性别信息. 插件类配置 retains entry location, plugin name, haptics, AI 配置, 翻译配置 and configuration import/export. Existing settings and collapsed states are preserved.

Payment/receive-code shortcuts are currently removed. The retired global-action value 11 is reserved and old two-/three-finger assignments are cleared to 不设置 during gesture synchronization. Personal contact QR and scanning remain available.


## 视频通话增强（源码接入，待编译与真机验证）

聊天类功能 → 视频通话增强：视频美颜、图片贴纸、前摄视频镜像，默认关闭。美颜用微信资源与引擎，列表滑杆实时预览、松手保存；通话调节使用半透明模糊面板，默认约320pt，可拖动导航栏调整高度；入口跟随原生通话操作区。贴纸在透明通话画布上拖动、双指缩放/旋转，可再次调整已有贴纸，完成后才合成到发送帧。镜像改用系统采集连接水平翻转，移除私有旋转换轴和渲染器覆盖；合成链路增加运行时四角颜色方向校验。图片仅保留本次通话，挂断清理；效果仍待真机验证。

本轮不含在线素材、文字模板、PAG动态手势或妆容/滤镜。接口、方向、对端效果与原生美颜叠加仍需设备验证，不能将源码接入视为完整复刻。实现与验证边界见 [接入记录](docs/VIDEO_CALL_EFFECTS.md)。
