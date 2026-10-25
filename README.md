# One Wx

Current package version: 1.0.0.

One Wx is a WeChat enhancement plugin that grew out of WCGesture (originally extracted from [WCAtlas](https://github.com/qiu7c/WCAtlas)). It covers gestures, the keyboard strip, AI, translation, global actions, layout and interface tweaks.

## Features

The home page has six categories: 聊天类功能 / 手势类功能 / 朋友圈功能 / 界面类功能 / 禁用类功能 / 插件类配置.
The search bar finds settings even when their feature is disabled and opens the relevant group without enabling it.

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

- Interface cleanup: hide group title tails, screenshot sharing overlays, and selected Me-page entries. Reopen the affected page after changing title/entry visibility.
- Moments: image rounding (0–40pt, default 8) and precise publication dates with a custom format. Rounding saves/restores native layers, rechecks reused images, clips puzzle containers as a whole, and excludes avatar/text/player containers.
- Chat: native search button, quote location with image/video filters, and a +1 menu item sharing the existing repeat pipeline and menu management.
- Native original-quality selection in asset picker/preview; auto transcription for visible voice cells, with private/group/self filters and reuse-safe deferred requests.
- New feature switches default to off. Auto transcription ignores self-sent voices by default. Configuration share codes preserve old aliases and add 64 setting aliases; runtime records are excluded.

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
