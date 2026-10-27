#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Master switch key. When OFF, every gesture feature is disabled.
FOUNDATION_EXPORT NSString *const WCGestureEnabledKey;

/// User-customizable plugin display name shown in WeChat's plugin manager.
FOUNDATION_EXPORT NSString *const WCPluginNameKey;

/// Message-gesture feature keys (left/right swipe, double/triple tap on bubbles).
FOUNDATION_EXPORT NSString *const WCReplySwipeEnabledKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeSelfActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeOtherActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeRightSelfActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeRightOtherActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeTriggerDistanceKey;
FOUNDATION_EXPORT NSString *const WCMessageDoubleTapSelfActionKey;
FOUNDATION_EXPORT NSString *const WCMessageDoubleTapOtherActionKey;
FOUNDATION_EXPORT NSString *const WCMessageTripleTapSelfActionKey;
FOUNDATION_EXPORT NSString *const WCMessageTripleTapOtherActionKey;

/// Input-box gesture keys (swipe + multi-tap on the chat input).
FOUNDATION_EXPORT NSString *const WCInputGestureEnabledKey;
FOUNDATION_EXPORT NSString *const WCInputSwipeLeftActionKey;
FOUNDATION_EXPORT NSString *const WCInputSwipeRightActionKey;
FOUNDATION_EXPORT NSString *const WCInputDoubleTapActionKey;
FOUNDATION_EXPORT NSString *const WCInputTripleTapActionKey;

/// Keyboard enhancement: a transparent gesture strip in the blank area below
/// the keyboard's bottom row (between the globe and mic keys), above the home
/// indicator. It has its own action configuration, independent of the input
/// box gestures.
FOUNDATION_EXPORT NSString *const WCKeyboardEnhanceEnabledKey;
FOUNDATION_EXPORT NSString *const WCKeyboardSwipeLeftActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardSwipeRightActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardDoubleTapActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardTripleTapActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardLongPressActionKey;

/// Debug aid: paints the keyboard gesture strip red and shows its live size at
/// the top of the screen so the touchable band is visible while tuning.
FOUNDATION_EXPORT NSString *const WCKeyboardDebugFrameKey;

/// Geometry of the keyboard gesture strip, all in points. Width 0 means the
/// full keyboard width; the offsets move the strip from its default spot
/// (positive X = right, positive Y = up).
FOUNDATION_EXPORT NSString *const WCKeyboardStripWidthKey;
FOUNDATION_EXPORT NSString *const WCKeyboardStripHeightKey;
FOUNDATION_EXPORT NSString *const WCKeyboardStripOffsetXKey;
FOUNDATION_EXPORT NSString *const WCKeyboardStripOffsetYKey;

/// Same geometry for third-party keyboards (搜狗/百度/讯飞…), which lay their
/// keys out differently. Chosen automatically: when no system key view can be
/// found in the keyboard, these values are used instead of the ones above.
FOUNDATION_EXPORT NSString *const WCKeyboardStripWidthKeyThirdParty;
FOUNDATION_EXPORT NSString *const WCKeyboardStripHeightKeyThirdParty;
FOUNDATION_EXPORT NSString *const WCKeyboardStripOffsetXKeyThirdParty;
FOUNDATION_EXPORT NSString *const WCKeyboardStripOffsetYKeyThirdParty;

/// When OFF (default), both keyboard types share the system set above, and the
/// third-party strip's vertical offset is derived from it automatically. When
/// ON, the four third-party values are used on their own.
FOUNDATION_EXPORT NSString *const WCKeyboardStripSeparateAdjustKey;

/// Optional small caption drawn in the middle of the gesture strip, e.g. a
/// nickname or a short signature. Empty text turns it off.
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureTextKey;
/// Font size of that caption in points (scaled with the keyboard width).
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureSizeKey;
/// Typeface of that caption. Uses the Chinese faces built into iOS and falls
/// back to the system font when a face is missing on the device.
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureFontKey;
/// Ornament wrapped around the caption ("— 文字 —", "◇ 文字 ◇"…) plus the
/// spaced/outlined variants.
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureDecorationKey;
/// Caption color as "#RRGGBB"; empty follows the system label color.
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureColorKey;
/// Fine position offsets of the caption in points (positive X = right,
/// positive Y = up); both are limited to a small range for nudging.
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureOffsetXKey;
FOUNDATION_EXPORT NSString *const WCKeyboardSignatureOffsetYKey;

typedef NS_ENUM(NSInteger, WCKeyboardSignatureFontFace) {
    WCKeyboardSignatureFontSystem = 0,    // 系统字
    WCKeyboardSignatureFontKaiti = 1,     // 楷体
    WCKeyboardSignatureFontXingkai = 2,   // 行楷
    WCKeyboardSignatureFontSongti = 3,    // 宋体
    WCKeyboardSignatureFontYuanti = 4,    // 圆体
    WCKeyboardSignatureFontHannotate = 5, // 手写体
    WCKeyboardSignatureFontWawati = 6,    // 娃娃体
};

typedef NS_ENUM(NSInteger, WCKeyboardSignatureDecoration) {
    WCKeyboardSignatureDecorationNone = 0,    // 无装饰
    WCKeyboardSignatureDecorationSpaced = 1,  // 拉开字距
    WCKeyboardSignatureDecorationOutline = 2, // 描边空心
    WCKeyboardSignatureDecorationDivider = 3, // — 文字 —
    WCKeyboardSignatureDecorationDiamond = 4, // ◇ 文字 ◇
    WCKeyboardSignatureDecorationDot = 5,     // · 文字 ·
    WCKeyboardSignatureDecorationStar = 6,    // ✦ 文字 ✦
    WCKeyboardSignatureDecorationQuote = 7,   // 「文字」
};

/// Translation engine selection.
typedef NS_ENUM(NSInteger, WCTranslateEngine) {
    WCTranslateEngineEdge = 0,     // 微软 Edge(免费,无需 key)
    WCTranslateEngineMyMemory = 1, // MyMemory(免费,无需 key)
    WCTranslateEngineAI = 2,       // 已配置的 AI(预设翻译提示词)
};

FOUNDATION_EXPORT NSString *const WCTranslateEngineKey;
/// Language code of the other side of the translation pair, e.g. "en" means
/// 中文 ↔ English: one action translates into it, the other one into Chinese.
FOUNDATION_EXPORT NSString *const WCTranslatePairTargetKey;

/// AI assistant (OpenAI-compatible chat completions). The provider picks a
/// template for endpoint and model; both can be overridden by the user.
typedef NS_ENUM(NSInteger, WCGestureAIProvider) {
    WCGestureAIProviderDeepSeek = 0,
    WCGestureAIProviderQwen = 1,        // 千问 (DashScope compatible-mode)
    WCGestureAIProviderBailian = 2,     // 百炼
    WCGestureAIProviderSiliconFlow = 3, // 硅基流动
    WCGestureAIProviderCustom = 4,
};

FOUNDATION_EXPORT NSString *const WCGestureAIProviderKey;
/// Empty means "use the provider template".
FOUNDATION_EXPORT NSString *const WCGestureAIBaseURLKey;
FOUNDATION_EXPORT NSString *const WCGestureAIModelKey;
FOUNDATION_EXPORT NSString *const WCGestureAIAPIKeyKey;
/// Master switch for the AI assistant. When off, AI actions report "AI 未开启"
/// and the settings section only shows this switch.
FOUNDATION_EXPORT NSString *const WCGestureAIEnabledKey;
/// Master switch for translation. When off, translation actions show a toast
/// and the settings section only shows this switch.
FOUNDATION_EXPORT NSString *const WCTranslateEnabledKey;

/// Editable prompt presets: an array of { @"name": NSString,
/// @"prompt": NSString }. A non-empty prompt replaces the built-in system
/// prompt for the task; an empty one keeps the built-in prompt. When the
/// array is empty the built-in three (方案 1/2/3) are used, migrated from the
/// legacy keys below.
FOUNDATION_EXPORT NSString *const WCGestureAIPresetsKey;

/// Legacy fixed presets (kept for migration only).
FOUNDATION_EXPORT NSString *const WCGestureAIPresetPrompt1Key;
FOUNDATION_EXPORT NSString *const WCGestureAIPresetPrompt2Key;
FOUNDATION_EXPORT NSString *const WCGestureAIPresetPrompt3Key;
/// Which preset (0/1/2) each AI action uses.
FOUNDATION_EXPORT NSString *const WCGestureAIReplyPresetKey;
FOUNDATION_EXPORT NSString *const WCGestureAIAnswerPresetKey;
FOUNDATION_EXPORT NSString *const WCGestureAIPolishPresetKey;

/// Chat tools: other-user revoke protection and bubble-side message times.
FOUNDATION_EXPORT NSString *const WCGestureVoiceForwardEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureLongPressMenuEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureLongPressMenuHiddenTitlesKey;
FOUNDATION_EXPORT NSString *const WCGestureLongPressMenuPreferredOrderKey;
FOUNDATION_EXPORT NSString *const WCGestureLongPressMenuTitleMapKey;
FOUNDATION_EXPORT NSString *const WCGestureLongPressMenuKnownTitlesKey;
FOUNDATION_EXPORT NSString *const WCGestureLongPressMenuManualTitlesKey;

/// Chat tools: other-user revoke protection and bubble-side message times.
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeFormatKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeFontSizeKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeBoldKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimePositionKey;

FOUNDATION_EXPORT NSString *const WCGestureMessageTimeBelowAvatarKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeBubbleSideKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeColorKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeLightColorKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeDarkColorKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeAvatarSpacingKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeNotifySenderKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeLocalTemplateKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeReplyTemplateKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeTimeFilterKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokePromptStyleKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeSideTextKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeSideOffsetXKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeSideOffsetYKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeLocalTextColorKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeSideTextColorKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeLocalLightTextColorKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeLocalDarkTextColorKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeSideLightTextColorKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokeSideDarkTextColorKey;
FOUNDATION_EXPORT NSString *const WCGestureAntiRevokePersistRecordsKey;
FOUNDATION_EXPORT NSString *const WCGesturePageScalePluginUIKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeOffsetXKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageTimeOffsetYKey;


/// WCAtlas chat input/toolbar rounding, with independent inner and outer radii.
FOUNDATION_EXPORT NSString *const WCGestureChatInputRoundingEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureChatInputInnerRoundingKey;
FOUNDATION_EXPORT NSString *const WCGestureChatInputOuterRoundingKey;
FOUNDATION_EXPORT NSString *const WCGestureChatInputInnerRadiusKey;
FOUNDATION_EXPORT NSString *const WCGestureChatInputOuterRadiusKey;

/// Interface size, based on WCAtlas theme scaling (70–100%, default 90%).
FOUNDATION_EXPORT NSString *const WCGesturePageScaleEnabledKey;
FOUNDATION_EXPORT NSString *const WCGesturePageScalePercentKey;

/// Legacy chat layout: when enabled, CLocalInfo reports this font level instead of
/// the system one, so WeChat reflows chat text at the chosen size.
FOUNDATION_EXPORT NSString *const WCChatLayoutEnabledKey;
FOUNDATION_EXPORT NSString *const WCChatLayoutFontLevelKey;

/// Moments cell-height compensation. The two height class methods in
/// WCListBaseCellView / WCTimeLineCommentCellView are scaled by this
/// percentage while the switch is on.
FOUNDATION_EXPORT NSString *const WCMomentsLayoutEnabledKey;
FOUNDATION_EXPORT NSString *const WCMomentsHeightScaleKey;

/// Moments (朋友圈) double-tap like.
FOUNDATION_EXPORT NSString *const WCMomentsDoubleTapLikeKey;
FOUNDATION_EXPORT NSString *const WCMomentsLikeHapticKey;

/// Per-gesture vibration switches. Intensity is shared via WCGestureHapticStyleKey.
FOUNDATION_EXPORT NSString *const WCMessageGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCInputGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCKeyboardHapticKey;

/// Global multi-finger long-press (any WeChat page).
FOUNDATION_EXPORT NSString *const WCGlobalGestureEnabledKey;
FOUNDATION_EXPORT NSString *const WCGlobalTwoFingerActionKey;
FOUNDATION_EXPORT NSString *const WCGlobalThreeFingerActionKey;
FOUNDATION_EXPORT NSString *const WCGlobalGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCGestureHapticStyleKey;

/// Custom pages used by the "custom page" global action. An array of
/// dictionaries: { @"name": 备注, @"class": UIViewController 类名 }.
FOUNDATION_EXPORT NSString *const WCCustomPagesKey;

/// Enhancement switches (拓展设置).
FOUNDATION_EXPORT NSString *const WCHideSeparatorLinesKey;

/// Haptic intensity levels (maps to UIImpactFeedbackStyle).
typedef NS_ENUM(NSInteger, WCHapticStyle) {
    WCHapticStyleLight = 0,
    WCHapticStyleMedium = 1,
    WCHapticStyleHeavy = 2,
    WCHapticStyleSoft = 3,
    WCHapticStyleRigid = 4,
};

/// Input-box gesture action enum (shared by swipe and multi-tap).
typedef NS_ENUM(NSInteger, WCInputAction) {
    WCInputActionNone = 0,
    WCInputActionClear = 1,   // 清空输入框
    WCInputActionPaste = 2,   // 粘贴剪贴板
    WCInputActionCopy = 3,    // 复制输入框内容
    WCInputActionCut = 4,     // 剪切输入框内容
    WCInputActionTranslate = 5,       // 翻译:自动判断方向(中文→互译语言,其它→中文)
    WCInputActionTranslateLegacy = 6, // 旧版「译成中文」;行为同互译,仅兼容已保存设置
    WCInputActionUppercase = 7,          // 转大写
    WCInputActionLowercase = 8,          // 转小写
    WCInputActionTrim = 9,               // 去空格/换行
    WCInputActionAIAnswer = 10,          // AI 回答输入框里的问题
    WCInputActionAIPolish = 11,          // AI 润色输入框文字
};

/// Notification posted when an enhancement key changes, so gesture recognizers
/// can be re-synchronized on the next view appearance. Object carries the key.
FOUNDATION_EXPORT NSString *const WCGestureDidChangeNotification;

typedef NS_ENUM(NSInteger, WCReplySwipeAction) {
    WCReplySwipeActionNone = 0,
    WCReplySwipeActionQuote = 1,
    WCReplySwipeActionRevoke = 2,
    WCReplySwipeActionCopy = 3,
    WCReplySwipeActionDelete = 4,
    WCReplySwipeActionRepeat = 5,
    WCReplySwipeActionForward = 6,
    WCReplySwipeActionFavorite = 7,
    WCReplySwipeActionSpeak = 8,
    WCReplySwipeActionTranslate = 9,
    WCReplySwipeActionAIReply = 10, // AI 根据这条消息生成回复并填入输入框
};

/// Global multi-finger long-press action.
typedef NS_ENUM(NSInteger, WCGlobalAction) {
    WCGlobalActionNone = 0,
    WCGlobalActionScreenshot = 1,   // 截图当前页面
    WCGlobalActionBack = 2,         // 返回上一页
    WCGlobalActionLockScreen = 3,   // 回到首页
    WCGlobalActionScanQR = 4,       // 扫一扫
    WCGlobalActionMenu = 5,         // 弹快捷菜单
    WCGlobalActionJump = 6,         // 跳转设置页
    WCGlobalActionMoments = 7,      // 朋友圈
    WCGlobalActionAddFriend = 8,    // 添加朋友
    WCGlobalActionCustomPage = 9,   // 前往自定义页面
    WCGlobalActionMyQRCode = 10,    // 我的二维码
    WCGlobalActionReserved11 = 11, // Retired payment-code action. Keep this value unused.
};

/// Copies settings stored under the legacy WCGesture key namespace into the
/// One Wx namespace. Call once at startup, before registering defaults.
void WCGestureMigrateLegacyDefaults(void);

/// Registers the default values for all keys once per process.
void WCGestureRegisterDefaults(void);

/// Returns YES only when the master switch is on and the given feature key is on.
BOOL WCGestureEnabled(NSString *key);

FOUNDATION_EXPORT NSString *const WCGestureGlobalAvatarRoundingEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureGlobalAvatarCornerPercentKey;


// WCAtlas utility migrations.
FOUNDATION_EXPORT NSString *const WCGestureHideGroupTitleTailKey;
FOUNDATION_EXPORT NSString *const WCGestureHideScreenshotForwardKey;
FOUNDATION_EXPORT NSString *const WCGestureHideMeFinderKey;
FOUNDATION_EXPORT NSString *const WCGestureHideMeCardsKey;
FOUNDATION_EXPORT NSString *const WCGestureHideMeEmoticonsKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsImageCornerEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsImageCornerRadiusKey;
FOUNDATION_EXPORT NSString *const WCGestureChatSearchEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureQuoteJumpEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureQuoteJumpImageKey;
FOUNDATION_EXPORT NSString *const WCGestureQuoteJumpVideoKey;
FOUNDATION_EXPORT NSString *const WCGestureMessageRepeatMenuEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsTimeEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsTimeFormatKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoOriginalEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoDeviceLoginEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureNotificationDirectChatEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVoiceTranscriptionEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVoiceTranscriptionIgnoreGroupKey;
FOUNDATION_EXPORT NSString *const WCGestureVoiceTranscriptionIgnorePrivateKey;
FOUNDATION_EXPORT NSString *const WCGestureVoiceTranscriptionIgnoreSelfKey;

// Moments monitoring settings and account-scoped runtime state.
FOUNDATION_EXPORT NSString *const WCGestureBackgroundKeepAliveEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureAdBlockerEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsInteractionReminderEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsInteractionReminderDetailsEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderUsersKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderIntervalKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderForwardEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderForwardTargetKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderForwardImagesKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderForwardVideosKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsReminderSeenItemsKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsInteractionStateKey;

FOUNDATION_EXPORT NSString *const WCGestureChatTopBarCapsuleEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureChatGlassStyleKey;
FOUNDATION_EXPORT NSString *const WCGestureChatGlassBlurIntensityKey;
FOUNDATION_EXPORT NSString *const WCGestureChatTopBarAvatarSizeKey;
FOUNDATION_EXPORT NSString *const WCGestureChatTopBarNicknameSizeKey;

FOUNDATION_EXPORT NSString *const WCGestureCallConfirmEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureContactInfoCardEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoCombineSendEnabledKey;

FOUNDATION_EXPORT NSString *const WCGestureChatGlassTransparencyKey;
FOUNDATION_EXPORT NSString *const WCGestureChatTopBarShellScaleKey;
FOUNDATION_EXPORT NSString *const WCGestureChatTopBarIconSizeKey;

FOUNDATION_EXPORT NSString *const WCGestureEmoticonCornerEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureEmoticonCornerRadiusKey;
FOUNDATION_EXPORT NSString *const WCGestureChatImageCornerEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureChatImageCornerRadiusKey;

// Automatic personal status publishing. LastAttempt is runtime state, excluded from share codes.
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusHourKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusIconTypeKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusIconIDKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusIconDescriptionKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusTextModeKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusTextKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusTextURLKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusMediaModeKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusImageURLKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusVideoURLKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoStatusLastAttemptKey;

FOUNDATION_EXPORT NSString *const WCGestureSettingsEntryLocationKey;

FOUNDATION_EXPORT NSString *const WCGestureImageEditQuickSendEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureAutoSpeakerphoneEnabledKey;

FOUNDATION_EXPORT NSString *const WCGestureSendConfirmationEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureSendConfirmationUsersKey;
FOUNDATION_EXPORT NSString *const WCGestureSendConfirmationPauseSecondsKey;
FOUNDATION_EXPORT NSString *const WCGestureSendConfirmationProfileSwitchEnabledKey;


// Video-call native effects. Sticker pixels are call-scoped and are never exported.
FOUNDATION_EXPORT NSString *const WCGestureVideoCallBeautyEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVideoCallStickerEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVideoCallMirrorEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVideoCallBeautyValuesKey;


// Me-page entry privacy authentication.
FOUNDATION_EXPORT NSString *const WCGestureServicePageLockEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureFavoritesPageLockEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsAlbumPageLockEnabledKey;

// Native Moments feed rows and direct actions.
FOUNDATION_EXPORT NSString *const WCGestureMomentsForwardEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsFeedEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsFeedSpacingKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsFeedLocationKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsFeedActionsKey;
FOUNDATION_EXPORT NSString *const WCGestureMomentsFeedHideActionTextKey;

// Virtual location.
FOUNDATION_EXPORT NSString *const WCGestureVirtualLocationEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVirtualLocationMomentsEnabledKey;
FOUNDATION_EXPORT NSString *const WCGestureVirtualLocationLatitudeKey;
FOUNDATION_EXPORT NSString *const WCGestureVirtualLocationLongitudeKey;
FOUNDATION_EXPORT NSString *const WCGestureVirtualLocationNameKey;
FOUNDATION_EXPORT NSString *const WCGestureVirtualLocationPresetsKey;

NS_ASSUME_NONNULL_END
