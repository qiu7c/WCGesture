# One Wx

One Wx is a WeChat enhancement plugin that grew out of WCGesture (originally extracted from [WCAtlas](https://github.com/qiu7c/WCAtlas)). It covers gestures, the keyboard strip, AI, translation, global actions, layout and interface tweaks.

## Features

**消息手势 (Message gestures)** — on chat message bubbles:
- Left swipe / right swipe (separately for your own vs. the other party's messages)
- Double tap / triple tap (separately for your own vs. the other party's)
- Per-gesture selectable action: 引用 (quote) · 撤回 (revoke, self only) · 复制 (copy) · 删除 (delete) · 复读 (repeat)
- Adjustable trigger distance (36–100 points)

**布局与字号 (Layout)** — chat text size and Moments spacing:
- Chat font level override (reflows chat layout through WeChat's own font level)
- Moments cell-height compensation for larger text

**输入框滑动 (Input-box swipe)** — on the chat text input:
- Left swipe clears the input
- Right swipe pastes the clipboard

复读 (repeat) covers text, image, video, and voice messages. Voice repeat sends through WeChat's native `AudioSender` resend pipeline; other types go through the native `ForwardMessageLogicController`. Unlike WCAtlas, this build does **not** include the send-confirmation dialog — repeat fires immediately.

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
| `Sources/Features/MessageGestures/` | Bubble swipes/taps, repeat path, voice-upload hooks |
| `Sources/Features/InputGestures/` | Input-box swipes/taps and their actions |
| `Sources/Features/KeyboardStrip/` | Keyboard bottom gesture strip |
| `Sources/Features/ChatLayout/` | Chat font level and Moments cell-height compensation |
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
| `com.qiu7c.onewx.chat.layout.enabled` | NO |
| `com.qiu7c.onewx.chat.layout.font-level` | 2 |
| `com.qiu7c.onewx.chat.layout.moments-enabled` | NO |
| `com.qiu7c.onewx.chat.layout.moments-scale` | 115.0 |

## License

See WCAtlas for upstream attribution. This extraction is derivative of WCAtlas by qiu7c.
