# WCGesture

WCGesture is a standalone WeChat gesture tweak, extracted from [WCAtlas](https://github.com/qiu7c/WCAtlas). It brings two gesture features out of the larger WCAtlas enhancement suite so they can be installed, built, and extended independently.

## Features

**消息手势 (Message gestures)** — on chat message bubbles:
- Left swipe / right swipe (separately for your own vs. the other party's messages)
- Double tap / triple tap (separately for your own vs. the other party's)
- Per-gesture selectable action: 引用 (quote) · 撤回 (revoke, self only) · 复制 (copy) · 删除 (delete) · 复读 (repeat)
- Adjustable trigger distance (36–100 points)

**输入框滑动 (Input-box swipe)** — on the chat text input:
- Left swipe clears the input
- Right swipe pastes the clipboard

复读 (repeat) covers text, image, video, and voice messages. Voice repeat sends through WeChat's native `AudioSender` resend pipeline; other types go through the native `ForwardMessageLogicController`. Unlike WCAtlas, this build does **not** include the send-confirmation dialog — repeat fires immediately.

## Code layout

`Tweak.x` only contains the Logos hooks and the `%ctor` that wires everything
together. Feature logic lives in `Sources/`, one module per area:

| File | Responsibility |
|---|---|
| `WCGestureSupport.{h,m}` | KVC helpers, active window, presentation helpers, toast, haptics |
| `WCGestureMessage.{h,m}` | Message bubble gestures, transform animation, repeat path, AI reply action |
| `WCGestureInput.{h,m}` | Input-box text access and the configured input actions |
| `WCGestureKeyboard.{h,m}` | Keyboard bottom gesture strip (geometry, signature, debug frame) |
| `WCGestureGlobal.{h,m}` | Multi-finger global actions and custom pages |
| `WCGestureConfig.{h,m}` | Settings keys, enums and defaults |
| `WCGestureSettingsVC.{h,m}` | Settings UI |
| `WCGestureAI.{h,m}` / `WCGestureTranslate.{h,m}` | AI completion and translation clients |
| `WCGestureAccount.{h,m}` / `WCGesturePrivateAPI.{h,m}` | WeChat services, current user and contact lookup |
| `WCPopup.{h,m}` | Alert/action-sheet helpers used by settings |

Hooks stay in a single Logos translation unit, so each module only exposes
plain C functions in its header.

## Entry

A **微信手势** row is injected into WeChat's Me page (`MoreViewController`) function section. Tapping it opens the settings sheet. When WeChat's `WCPluginsMgr` registration API is available, the entry is also registered there.

## Build

The GitHub Actions workflow from WCAtlas builds rootful and rootless `.deb` for `arm64`/`arm64e`. You can also build locally with Theos:

```sh
make clean package FINALPACKAGE=1
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

## Settings keys

All keys live under the `com.qiu7c.wcgesture.*` namespace and are independent from WCAtlas's keys, so the two tweaks can coexist on the same device.

| Key | Default |
|---|---|
| `com.qiu7c.wcgesture.enabled` (master) | YES |
| `com.qiu7c.wcgesture.chat.reply-swipe` | NO |
| `com.qiu7c.wcgesture.chat.reply-swipe.self-action` | Quote (1) |
| `com.qiu7c.wcgesture.chat.reply-swipe.other-action` | Quote (1) |
| `com.qiu7c.wcgesture.chat.reply-swipe.right.self-action` | None (0) |
| `com.qiu7c.wcgesture.chat.reply-swipe.right.other-action` | None (0) |
| `com.qiu7c.wcgesture.chat.reply-swipe.trigger-distance` | 56.0 |
| `com.qiu7c.wcgesture.chat.message-gesture.double-tap.self/other-action` | None (0) |
| `com.qiu7c.wcgesture.chat.message-gesture.triple-tap.self/other-action` | None (0) |
| `com.qiu7c.wcgesture.chat.input-swipe-actions` | NO |

## License

See WCAtlas for upstream attribution. This extraction is derivative of WCAtlas by qiu7c.
