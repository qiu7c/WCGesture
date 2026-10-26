#import "Sources/API/WCGestureInternal.h"

NSString *const WCGestureSettingsEntryLocationKey = @"com.qiu7c.onewx.plugin.entry-location";

NSString *const WCGestureEmoticonCornerEnabledKey = @"com.qiu7c.onewx.interface.emoticon-corner.enabled";
NSString *const WCGestureEmoticonCornerRadiusKey = @"com.qiu7c.onewx.interface.emoticon-corner.radius";
NSString *const WCGestureChatImageCornerEnabledKey = @"com.qiu7c.onewx.interface.chat-image-corner.enabled";
NSString *const WCGestureChatImageCornerRadiusKey = @"com.qiu7c.onewx.interface.chat-image-corner.radius";
NSString *const WCGestureChatGlassTransparencyKey = @"com.qiu7c.onewx.chat.top-bar-capsule.glass-transparency";
NSString *const WCGestureChatTopBarShellScaleKey = @"com.qiu7c.onewx.chat.top-bar-capsule.shell-percent";
NSString *const WCGestureChatTopBarIconSizeKey = @"com.qiu7c.onewx.chat.top-bar-capsule.icon-size";
NSString *const WCGestureCallConfirmEnabledKey = @"com.qiu7c.onewx.chat.call-bubble-confirm.enabled";
NSString *const WCGestureContactInfoCardEnabledKey = @"com.qiu7c.onewx.interface.contact-info-card.enabled";
NSString *const WCGestureAutoCombineSendEnabledKey = @"com.qiu7c.onewx.chat.auto-combine-send.enabled";
NSString *const WCGestureChatTopBarCapsuleEnabledKey = @"com.qiu7c.onewx.chat.top-bar-capsule.enabled";
NSString *const WCGestureChatGlassStyleKey = @"com.qiu7c.onewx.chat.top-bar-capsule.glass-style";
NSString *const WCGestureChatGlassBlurIntensityKey = @"com.qiu7c.onewx.chat.top-bar-capsule.blur-intensity";
NSString *const WCGestureChatTopBarAvatarSizeKey = @"com.qiu7c.onewx.chat.top-bar-capsule.avatar-size";
NSString *const WCGestureChatTopBarNicknameSizeKey = @"com.qiu7c.onewx.chat.top-bar-capsule.nickname-size";
NSString *const WCGestureHideGroupTitleTailKey = @"com.qiu7c.onewx.interface.hide-group-title-tail";
NSString *const WCGestureHideScreenshotForwardKey = @"com.qiu7c.onewx.interface.hide-screenshot-forward";
NSString *const WCGestureHideMeFinderKey = @"com.qiu7c.onewx.interface.me.hide-finder";
NSString *const WCGestureHideMeCardsKey = @"com.qiu7c.onewx.interface.me.hide-cards";
NSString *const WCGestureHideMeEmoticonsKey = @"com.qiu7c.onewx.interface.me.hide-emoticons";
NSString *const WCGestureMomentsImageCornerEnabledKey = @"com.qiu7c.onewx.moments.image-corner.enabled";
NSString *const WCGestureMomentsImageCornerRadiusKey = @"com.qiu7c.onewx.moments.image-corner.radius";
NSString *const WCGestureChatSearchEnabledKey = @"com.qiu7c.onewx.chat.search-button.enabled";
NSString *const WCGestureQuoteJumpEnabledKey = @"com.qiu7c.onewx.chat.quote-jump.enabled";
NSString *const WCGestureQuoteJumpImageKey = @"com.qiu7c.onewx.chat.quote-jump.image";
NSString *const WCGestureQuoteJumpVideoKey = @"com.qiu7c.onewx.chat.quote-jump.video";
NSString *const WCGestureMessageRepeatMenuEnabledKey = @"com.qiu7c.onewx.chat.repeat-menu.enabled";
NSString *const WCGestureMomentsTimeEnabledKey = @"com.qiu7c.onewx.moments.precise-time.enabled";
NSString *const WCGestureMomentsTimeFormatKey = @"com.qiu7c.onewx.moments.precise-time.format";
NSString *const WCGestureAutoOriginalEnabledKey = @"com.qiu7c.onewx.chat.auto-original.enabled";
NSString *const WCGestureBackgroundKeepAliveEnabledKey = @"com.qiu7c.onewx.background.keep-alive";
NSString *const WCGestureAdBlockerEnabledKey = @"com.qiu7c.onewx.interface.ad-blocker.enabled";
NSString *const WCGestureMomentsInteractionReminderEnabledKey = @"com.qiu7c.onewx.moments.interaction-reminder";
NSString *const WCGestureMomentsInteractionReminderDetailsEnabledKey = @"com.qiu7c.onewx.moments.interaction-reminder.details";
NSString *const WCGestureMomentsReminderEnabledKey = @"com.qiu7c.onewx.moments.reminder";
NSString *const WCGestureMomentsReminderUsersKey = @"com.qiu7c.onewx.moments.reminder.users";
NSString *const WCGestureMomentsReminderIntervalKey = @"com.qiu7c.onewx.moments.reminder.interval";
NSString *const WCGestureMomentsReminderForwardEnabledKey = @"com.qiu7c.onewx.moments.reminder.forward";
NSString *const WCGestureMomentsReminderForwardTargetKey = @"com.qiu7c.onewx.moments.reminder.forward-target";
NSString *const WCGestureMomentsReminderForwardImagesKey = @"com.qiu7c.onewx.moments.reminder.forward-images";
NSString *const WCGestureMomentsReminderForwardVideosKey = @"com.qiu7c.onewx.moments.reminder.forward-videos";
NSString *const WCGestureMomentsReminderSeenItemsKey = @"com.qiu7c.onewx.moments.reminder.seen-items";
NSString *const WCGestureMomentsInteractionStateKey = @"com.qiu7c.onewx.moments.interaction-reminder.state";
NSString *const WCGestureNotificationDirectChatEnabledKey = @"com.qiu7c.onewx.chat.notification-direct-chat.enabled";
NSString *const WCGestureAutoStatusEnabledKey = @"com.qiu7c.onewx.automation.auto-status.enabled";
NSString *const WCGestureAutoStatusHourKey = @"com.qiu7c.onewx.automation.auto-status.hour";
NSString *const WCGestureAutoStatusIconTypeKey = @"com.qiu7c.onewx.automation.auto-status.icon-type";
NSString *const WCGestureAutoStatusIconIDKey = @"com.qiu7c.onewx.automation.auto-status.icon-id";
NSString *const WCGestureAutoStatusIconDescriptionKey = @"com.qiu7c.onewx.automation.auto-status.icon-description";
NSString *const WCGestureAutoStatusTextModeKey = @"com.qiu7c.onewx.automation.auto-status.text-mode";
NSString *const WCGestureAutoStatusTextKey = @"com.qiu7c.onewx.automation.auto-status.text";
NSString *const WCGestureAutoStatusTextURLKey = @"com.qiu7c.onewx.automation.auto-status.text-url";
NSString *const WCGestureAutoStatusMediaModeKey = @"com.qiu7c.onewx.automation.auto-status.media-mode";
NSString *const WCGestureAutoStatusImageURLKey = @"com.qiu7c.onewx.automation.auto-status.image-url";
NSString *const WCGestureAutoStatusVideoURLKey = @"com.qiu7c.onewx.automation.auto-status.video-url";
NSString *const WCGestureAutoStatusLastAttemptKey = @"com.qiu7c.onewx.automation.auto-status.last-attempt";
NSString *const WCGestureAutoDeviceLoginEnabledKey = @"com.qiu7c.onewx.automation.device-login.enabled";
NSString *const WCGestureVoiceTranscriptionEnabledKey = @"com.qiu7c.onewx.chat.voice-transcription.enabled";
NSString *const WCGestureVoiceTranscriptionIgnoreGroupKey = @"com.qiu7c.onewx.chat.voice-transcription.ignore-group";
NSString *const WCGestureVoiceTranscriptionIgnorePrivateKey = @"com.qiu7c.onewx.chat.voice-transcription.ignore-private";
NSString *const WCGestureVoiceTranscriptionIgnoreSelfKey = @"com.qiu7c.onewx.chat.voice-transcription.ignore-self";

NSString *const WCGestureEnabledKey = @"com.qiu7c.onewx.enabled";
NSString *const WCPluginNameKey = @"com.qiu7c.onewx.plugin-name";

NSString *const WCReplySwipeEnabledKey = @"com.qiu7c.onewx.chat.reply-swipe";
NSString *const WCReplySwipeSelfActionKey = @"com.qiu7c.onewx.chat.reply-swipe.self-action";
NSString *const WCReplySwipeOtherActionKey = @"com.qiu7c.onewx.chat.reply-swipe.other-action";
NSString *const WCReplySwipeRightSelfActionKey = @"com.qiu7c.onewx.chat.reply-swipe.right.self-action";
NSString *const WCReplySwipeRightOtherActionKey = @"com.qiu7c.onewx.chat.reply-swipe.right.other-action";
NSString *const WCReplySwipeTriggerDistanceKey = @"com.qiu7c.onewx.chat.reply-swipe.trigger-distance";
NSString *const WCMessageDoubleTapSelfActionKey = @"com.qiu7c.onewx.chat.message-gesture.double-tap.self-action";
NSString *const WCMessageDoubleTapOtherActionKey = @"com.qiu7c.onewx.chat.message-gesture.double-tap.other-action";
NSString *const WCMessageTripleTapSelfActionKey = @"com.qiu7c.onewx.chat.message-gesture.triple-tap.self-action";
NSString *const WCMessageTripleTapOtherActionKey = @"com.qiu7c.onewx.chat.message-gesture.triple-tap.other-action";

NSString *const WCInputGestureEnabledKey = @"com.qiu7c.onewx.chat.input-gesture";
NSString *const WCInputSwipeLeftActionKey = @"com.qiu7c.onewx.chat.input-gesture.swipe.left";
NSString *const WCInputSwipeRightActionKey = @"com.qiu7c.onewx.chat.input-gesture.swipe.right";
NSString *const WCInputDoubleTapActionKey = @"com.qiu7c.onewx.chat.input-gesture.double-tap";
NSString *const WCInputTripleTapActionKey = @"com.qiu7c.onewx.chat.input-gesture.triple-tap";
NSString *const WCKeyboardEnhanceEnabledKey = @"com.qiu7c.onewx.input.keyboard-enhance";
NSString *const WCKeyboardSwipeLeftActionKey = @"com.qiu7c.onewx.input.keyboard.swipe-left";
NSString *const WCKeyboardSwipeRightActionKey = @"com.qiu7c.onewx.input.keyboard.swipe-right";
NSString *const WCKeyboardDoubleTapActionKey = @"com.qiu7c.onewx.input.keyboard.double-tap";
NSString *const WCKeyboardTripleTapActionKey = @"com.qiu7c.onewx.input.keyboard.triple-tap";
NSString *const WCKeyboardLongPressActionKey = @"com.qiu7c.onewx.input.keyboard.long-press";
NSString *const WCKeyboardDebugFrameKey = @"com.qiu7c.onewx.input.keyboard.debug-frame";
NSString *const WCKeyboardStripWidthKey = @"com.qiu7c.onewx.input.keyboard.strip-width-sys";
NSString *const WCKeyboardStripHeightKey = @"com.qiu7c.onewx.input.keyboard.strip-height-sys";
NSString *const WCKeyboardStripOffsetXKey = @"com.qiu7c.onewx.input.keyboard.strip-offset-x-sys";
NSString *const WCKeyboardStripOffsetYKey = @"com.qiu7c.onewx.input.keyboard.strip-offset-y-sys";
NSString *const WCKeyboardStripWidthKeyThirdParty = @"com.qiu7c.onewx.input.keyboard.strip-width-3p";
NSString *const WCKeyboardStripHeightKeyThirdParty = @"com.qiu7c.onewx.input.keyboard.strip-height-3p";
NSString *const WCKeyboardStripOffsetXKeyThirdParty = @"com.qiu7c.onewx.input.keyboard.strip-offset-x-3p";
NSString *const WCKeyboardStripOffsetYKeyThirdParty = @"com.qiu7c.onewx.input.keyboard.strip-offset-y-3p";
NSString *const WCKeyboardStripSeparateAdjustKey = @"com.qiu7c.onewx.input.keyboard.strip-separate";
NSString *const WCKeyboardSignatureTextKey = @"com.qiu7c.onewx.input.keyboard.signature-text";
NSString *const WCKeyboardSignatureSizeKey = @"com.qiu7c.onewx.input.keyboard.signature-size";
NSString *const WCKeyboardSignatureFontKey = @"com.qiu7c.onewx.input.keyboard.signature-font";
NSString *const WCKeyboardSignatureDecorationKey = @"com.qiu7c.onewx.input.keyboard.signature-decoration";
NSString *const WCKeyboardSignatureColorKey = @"com.qiu7c.onewx.input.keyboard.signature-color";
NSString *const WCKeyboardSignatureOffsetXKey = @"com.qiu7c.onewx.input.keyboard.signature-offset-x";
NSString *const WCKeyboardSignatureOffsetYKey = @"com.qiu7c.onewx.input.keyboard.signature-offset-y";
NSString *const WCTranslateEngineKey = @"com.qiu7c.onewx.translate.engine";
NSString *const WCTranslatePairTargetKey = @"com.qiu7c.onewx.translate.pair-target";
NSString *const WCTranslateEnabledKey = @"com.qiu7c.onewx.translate.enabled";

NSString *const WCGestureAIEnabledKey = @"com.qiu7c.onewx.ai.enabled";
NSString *const WCGestureAIProviderKey = @"com.qiu7c.onewx.ai.provider";
NSString *const WCGestureAIBaseURLKey = @"com.qiu7c.onewx.ai.base-url";
NSString *const WCGestureAIModelKey = @"com.qiu7c.onewx.ai.model";
NSString *const WCGestureAIAPIKeyKey = @"com.qiu7c.onewx.ai.api-key";
NSString *const WCGestureAIPresetsKey = @"com.qiu7c.onewx.ai.presets";
NSString *const WCGestureAIPresetPrompt1Key = @"com.qiu7c.onewx.ai.preset1-prompt";
NSString *const WCGestureAIPresetPrompt2Key = @"com.qiu7c.onewx.ai.preset2-prompt";
NSString *const WCGestureAIPresetPrompt3Key = @"com.qiu7c.onewx.ai.preset3-prompt";
NSString *const WCGestureAIReplyPresetKey = @"com.qiu7c.onewx.ai.reply-preset";
NSString *const WCGestureAIAnswerPresetKey = @"com.qiu7c.onewx.ai.answer-preset";
NSString *const WCGestureAIPolishPresetKey = @"com.qiu7c.onewx.ai.polish-preset";

NSString *const WCGestureMessageTimeBelowAvatarKey = @"com.qiu7c.onewx.chat.message-time.below-avatar";
NSString *const WCGestureMessageTimeBubbleSideKey = @"com.qiu7c.onewx.chat.message-time.bubble-side";
NSString *const WCGestureMessageTimeColorKey = @"com.qiu7c.onewx.chat.message-time.color";
NSString *const WCGestureMessageTimeLightColorKey = @"com.qiu7c.onewx.chat.message-time.color.light";
NSString *const WCGestureMessageTimeDarkColorKey = @"com.qiu7c.onewx.chat.message-time.color.dark";
NSString *const WCGestureMessageTimeAvatarSpacingKey = @"com.qiu7c.onewx.chat.message-time.avatar-spacing";
NSString *const WCGestureAntiRevokeNotifySenderKey = @"com.qiu7c.onewx.chat.anti-revoke.notify-sender";
NSString *const WCGestureAntiRevokeLocalTemplateKey = @"com.qiu7c.onewx.chat.anti-revoke.local-template";
NSString *const WCGestureAntiRevokeReplyTemplateKey = @"com.qiu7c.onewx.chat.anti-revoke.reply-template";
NSString *const WCGestureAntiRevokeTimeFilterKey = @"com.qiu7c.onewx.chat.anti-revoke.time-filter";
NSString *const WCGestureAntiRevokePromptStyleKey = @"com.qiu7c.onewx.chat.anti-revoke.prompt-style";
NSString *const WCGestureAntiRevokeSideTextKey = @"com.qiu7c.onewx.chat.anti-revoke.side-text";
NSString *const WCGestureAntiRevokeSideOffsetXKey = @"com.qiu7c.onewx.chat.anti-revoke.side-offset-x";
NSString *const WCGestureAntiRevokeSideOffsetYKey = @"com.qiu7c.onewx.chat.anti-revoke.side-offset-y";
NSString *const WCGestureAntiRevokeLocalTextColorKey = @"com.qiu7c.onewx.chat.anti-revoke.local-text-color";
NSString *const WCGestureAntiRevokeSideTextColorKey = @"com.qiu7c.onewx.chat.anti-revoke.side-text-color";
NSString *const WCGestureAntiRevokeLocalLightTextColorKey = @"com.qiu7c.onewx.chat.anti-revoke.local-text-color.light";
NSString *const WCGestureAntiRevokeLocalDarkTextColorKey = @"com.qiu7c.onewx.chat.anti-revoke.local-text-color.dark";
NSString *const WCGestureAntiRevokeSideLightTextColorKey = @"com.qiu7c.onewx.chat.anti-revoke.side-text-color.light";
NSString *const WCGestureAntiRevokeSideDarkTextColorKey = @"com.qiu7c.onewx.chat.anti-revoke.side-text-color.dark";
NSString *const WCGestureAntiRevokePersistRecordsKey = @"com.qiu7c.onewx.chat.anti-revoke.persist-records";
NSString *const WCGesturePageScalePluginUIKey = @"com.qiu7c.onewx.interface.page-scale.plugin-ui";
NSString *const WCGestureMessageTimeOffsetXKey = @"com.qiu7c.onewx.chat.message-time.offset-x";
NSString *const WCGestureMessageTimeOffsetYKey = @"com.qiu7c.onewx.chat.message-time.offset-y";

NSString *const WCGesturePageScaleEnabledKey = @"com.qiu7c.onewx.interface.page-scale.enabled";
NSString *const WCGestureGlobalAvatarRoundingEnabledKey = @"com.qiu7c.onewx.interface.global-avatar-rounding";
NSString *const WCGestureGlobalAvatarCornerPercentKey = @"com.qiu7c.onewx.interface.global-avatar-corner-percent";

NSString *const WCGestureChatInputRoundingEnabledKey = @"com.qiu7c.onewx.interface.chat-input-rounding.enabled";
NSString *const WCGestureChatInputInnerRoundingKey = @"com.qiu7c.onewx.interface.chat-input-rounding.inner";
NSString *const WCGestureChatInputOuterRoundingKey = @"com.qiu7c.onewx.interface.chat-input-rounding.outer";
NSString *const WCGestureChatInputInnerRadiusKey = @"com.qiu7c.onewx.interface.chat-input-rounding.inner-radius";
NSString *const WCGestureChatInputOuterRadiusKey = @"com.qiu7c.onewx.interface.chat-input-rounding.outer-radius";
NSString *const WCGestureAntiRevokeEnabledKey = @"com.qiu7c.onewx.chat.anti-revoke.enabled";
NSString *const WCGestureVoiceForwardEnabledKey = @"com.qiu7c.onewx.chat.voice-forward.enabled";
NSString *const WCGestureLongPressMenuEnabledKey = @"com.qiu7c.onewx.chat.long-press-menu.enabled";
NSString *const WCGestureLongPressMenuHiddenTitlesKey = @"com.qiu7c.onewx.chat.long-press-menu.hidden";
NSString *const WCGestureLongPressMenuPreferredOrderKey = @"com.qiu7c.onewx.chat.long-press-menu.order";
NSString *const WCGestureLongPressMenuTitleMapKey = @"com.qiu7c.onewx.chat.long-press-menu.rename";
NSString *const WCGestureLongPressMenuKnownTitlesKey = @"com.qiu7c.onewx.chat.long-press-menu.known";
NSString *const WCGestureLongPressMenuManualTitlesKey = @"com.qiu7c.onewx.chat.long-press-menu.manual";
NSString *const WCGestureMessageTimeEnabledKey = @"com.qiu7c.onewx.chat.message-time.enabled";
NSString *const WCGestureMessageTimeFormatKey = @"com.qiu7c.onewx.chat.message-time.format";
NSString *const WCGestureMessageTimeFontSizeKey = @"com.qiu7c.onewx.chat.message-time.font-size";
NSString *const WCGestureMessageTimeBoldKey = @"com.qiu7c.onewx.chat.message-time.bold";
NSString *const WCGestureMessageTimePositionKey = @"com.qiu7c.onewx.chat.message-time.position";
NSString *const WCGesturePageScalePercentKey = @"com.qiu7c.onewx.interface.page-scale.percent";

// Legacy settings retained for compatibility; page scaling takes priority.
NSString *const WCChatLayoutEnabledKey = @"com.qiu7c.onewx.chat.layout.enabled";
NSString *const WCChatLayoutFontLevelKey = @"com.qiu7c.onewx.chat.layout.font-level";
NSString *const WCMomentsLayoutEnabledKey = @"com.qiu7c.onewx.chat.layout.moments-enabled";
NSString *const WCMomentsHeightScaleKey = @"com.qiu7c.onewx.chat.layout.moments-scale";

NSString *const WCMomentsDoubleTapLikeKey = @"com.qiu7c.onewx.moments.double-tap-like";
NSString *const WCMomentsLikeHapticKey = @"com.qiu7c.onewx.moments.like-haptic";

NSString *const WCMessageGestureHapticKey = @"com.qiu7c.onewx.chat.message-gesture.haptic";
NSString *const WCInputGestureHapticKey = @"com.qiu7c.onewx.chat.input-gesture.haptic";
NSString *const WCKeyboardHapticKey = @"com.qiu7c.onewx.keyboard.haptic";

NSString *const WCGlobalGestureEnabledKey = @"com.qiu7c.onewx.global.enabled";
NSString *const WCGlobalTwoFingerActionKey = @"com.qiu7c.onewx.global.two-finger-action";
NSString *const WCGlobalThreeFingerActionKey = @"com.qiu7c.onewx.global.three-finger-action";
NSString *const WCGlobalGestureHapticKey = @"com.qiu7c.onewx.global.haptic";
NSString *const WCGestureHapticStyleKey = @"com.qiu7c.onewx.haptic-style";
NSString *const WCCustomPagesKey = @"com.qiu7c.onewx.custom-pages";
NSString *const WCHideSeparatorLinesKey = @"com.qiu7c.onewx.interface.hide-separator-lines";

NSString *const WCGestureDidChangeNotification = @"WCGestureDidChangeNotification";


// One Wx was previously distributed as WCGesture (com.qiu7c.wcgesture).
// Copy the old values into the new namespace once so upgrading users keep
// their configuration. Runs before the defaults are registered, otherwise
// the registered values would hide whether the user had already set a key.
static NSString *const WCLegacyDefaultsPrefix = @"com.qiu7c.wcgesture";
static NSString *const WCDefaultsPrefix = @"com.qiu7c.onewx";
static NSString *const WCLegacyDefaultsMigratedKey = @"com.qiu7c.onewx.migrated-from-wcgesture";

static NSArray<NSString *> *WCGestureAllSettingKeys(void) {
    return @[
        WCGestureEnabledKey,
        WCPluginNameKey,
        WCReplySwipeEnabledKey,
        WCReplySwipeSelfActionKey,
        WCReplySwipeOtherActionKey,
        WCReplySwipeRightSelfActionKey,
        WCReplySwipeRightOtherActionKey,
        WCReplySwipeTriggerDistanceKey,
        WCMessageDoubleTapSelfActionKey,
        WCMessageDoubleTapOtherActionKey,
        WCMessageTripleTapSelfActionKey,
        WCMessageTripleTapOtherActionKey,
        WCInputGestureEnabledKey,
        WCInputSwipeLeftActionKey,
        WCInputSwipeRightActionKey,
        WCInputDoubleTapActionKey,
        WCInputTripleTapActionKey,
        WCKeyboardEnhanceEnabledKey,
        WCKeyboardSwipeLeftActionKey,
        WCKeyboardSwipeRightActionKey,
        WCKeyboardDoubleTapActionKey,
        WCKeyboardTripleTapActionKey,
        WCKeyboardLongPressActionKey,
        WCKeyboardDebugFrameKey,
        WCKeyboardStripWidthKey,
        WCKeyboardStripHeightKey,
        WCKeyboardStripOffsetXKey,
        WCKeyboardStripOffsetYKey,
        WCKeyboardStripWidthKeyThirdParty,
        WCKeyboardStripHeightKeyThirdParty,
        WCKeyboardStripOffsetXKeyThirdParty,
        WCKeyboardStripOffsetYKeyThirdParty,
        WCKeyboardStripSeparateAdjustKey,
        WCKeyboardSignatureTextKey,
        WCKeyboardSignatureSizeKey,
        WCKeyboardSignatureFontKey,
        WCKeyboardSignatureDecorationKey,
        WCKeyboardSignatureColorKey,
        WCKeyboardSignatureOffsetXKey,
        WCKeyboardSignatureOffsetYKey,
        WCTranslateEngineKey,
        WCTranslatePairTargetKey,
        WCTranslateEnabledKey,
        WCGestureAIEnabledKey,
        WCGestureAIProviderKey,
        WCGestureAIBaseURLKey,
        WCGestureAIModelKey,
        WCGestureAIAPIKeyKey,
        WCGestureAIPresetsKey,
        WCGestureAIPresetPrompt1Key,
        WCGestureAIPresetPrompt2Key,
        WCGestureAIPresetPrompt3Key,
        WCGestureAIReplyPresetKey,
        WCGestureAIAnswerPresetKey,
        WCGestureAIPolishPresetKey,
        WCMomentsDoubleTapLikeKey,
        WCMomentsLikeHapticKey,
        WCMessageGestureHapticKey,
        WCInputGestureHapticKey,
        WCKeyboardHapticKey,
        WCGlobalGestureEnabledKey,
        WCGlobalTwoFingerActionKey,
        WCGlobalThreeFingerActionKey,
        WCGlobalGestureHapticKey,
        WCGestureHapticStyleKey,
        WCCustomPagesKey,
        WCHideSeparatorLinesKey,
    ];
}

void WCGestureMigrateLegacyDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:WCLegacyDefaultsMigratedKey]) return;
    for (NSString *key in WCGestureAllSettingKeys()) {
        if (![key hasPrefix:WCDefaultsPrefix]) continue;
        NSString *legacyKey = [WCLegacyDefaultsPrefix stringByAppendingString:
            [key substringFromIndex:WCDefaultsPrefix.length]];
        id legacyValue = [defaults objectForKey:legacyKey];
        if (legacyValue && [defaults objectForKey:key] == nil) {
            [defaults setObject:legacyValue forKey:key];
        }
    }
    [defaults setBool:YES forKey:WCLegacyDefaultsMigratedKey];
    [defaults synchronize];
}

void WCGestureRegisterDefaults(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Preserve the bubble-only mode published before the WCAtlas port.
        // New installations use WCAtlas's below-avatar default.
        NSUserDefaults *stored = NSUserDefaults.standardUserDefaults;
        if ([stored objectForKey:WCGestureMessageTimeEnabledKey] && ![stored objectForKey:WCGestureMessageTimeBubbleSideKey]) {
            [stored setBool:YES forKey:WCGestureMessageTimeBubbleSideKey];
            [stored setBool:NO forKey:WCGestureMessageTimeBelowAvatarKey];
        }
        NSDictionary *defaults = @{
            WCGestureHideGroupTitleTailKey: @NO,
            WCGestureHideScreenshotForwardKey: @NO,
            WCGestureHideMeFinderKey: @NO,
            WCGestureHideMeCardsKey: @NO,
            WCGestureHideMeEmoticonsKey: @NO,
            WCGestureMomentsImageCornerEnabledKey: @NO,
            WCGestureMomentsImageCornerRadiusKey: @8.0,
            WCGestureChatSearchEnabledKey: @NO,
            WCGestureQuoteJumpEnabledKey: @NO,
            WCGestureQuoteJumpImageKey: @YES,
            WCGestureQuoteJumpVideoKey: @YES,
            WCGestureMessageRepeatMenuEnabledKey: @NO,
            WCGestureMomentsTimeEnabledKey: @NO,
            WCGestureMomentsTimeFormatKey: @"yyyy-MM-dd HH:mm:ss",
            WCGestureAutoOriginalEnabledKey: @NO,
            WCGestureChatTopBarCapsuleEnabledKey: @NO,
            WCGestureChatGlassStyleKey: @0, // Legacy share-code compatibility; renderer is frosted only.
            WCGestureEmoticonCornerEnabledKey: @NO,
            WCGestureEmoticonCornerRadiusKey: @8.0,
            WCGestureChatImageCornerEnabledKey: @NO,
            WCGestureChatImageCornerRadiusKey: @8.0,

            WCGestureChatGlassTransparencyKey: @50.0,
            WCGestureChatTopBarShellScaleKey: @100.0,
            WCGestureChatTopBarIconSizeKey: @18.0,

            WCGestureChatGlassBlurIntensityKey: @20.0,
            WCGestureChatTopBarAvatarSizeKey: @30.0,
            WCGestureChatTopBarNicknameSizeKey: @15.0,
            WCGestureCallConfirmEnabledKey: @NO,
            WCGestureContactInfoCardEnabledKey: @NO,
            WCGestureAutoCombineSendEnabledKey: @NO,
            WCGestureSettingsEntryLocationKey: @-1, // Automatic: manager if available, otherwise Me.
            WCGestureAutoStatusEnabledKey: @NO,
            WCGestureAutoStatusHourKey: @8,
            WCGestureAutoStatusIconTypeKey: @"做好事",
            WCGestureAutoStatusIconIDKey: @"1074",
            WCGestureAutoStatusIconDescriptionKey: @"",
            WCGestureAutoStatusTextModeKey: @0,
            WCGestureAutoStatusTextKey: @"",
            WCGestureAutoStatusTextURLKey: @"",
            WCGestureAutoStatusMediaModeKey: @0,
            WCGestureAutoStatusImageURLKey: @"",
            WCGestureAutoStatusVideoURLKey: @"",
            WCGestureAutoStatusLastAttemptKey: @{},
            WCGestureAutoDeviceLoginEnabledKey: @NO,
            WCGestureNotificationDirectChatEnabledKey: @NO,
            WCGestureBackgroundKeepAliveEnabledKey: @NO,
            WCGestureAdBlockerEnabledKey: @NO,
            WCGestureMomentsInteractionReminderEnabledKey: @NO,
            WCGestureMomentsInteractionReminderDetailsEnabledKey: @YES,
            WCGestureMomentsReminderEnabledKey: @NO,
            WCGestureMomentsReminderUsersKey: @[],
            WCGestureMomentsReminderIntervalKey: @60,
            WCGestureMomentsReminderForwardEnabledKey: @NO,
            WCGestureMomentsReminderForwardTargetKey: @0,
            WCGestureMomentsReminderForwardImagesKey: @NO,
            WCGestureMomentsReminderForwardVideosKey: @NO,
            WCGestureMomentsReminderSeenItemsKey: @{},
            WCGestureMomentsInteractionStateKey: @{},
            WCGestureVoiceTranscriptionEnabledKey: @NO,
            WCGestureVoiceTranscriptionIgnoreGroupKey: @NO,
            WCGestureVoiceTranscriptionIgnorePrivateKey: @NO,
            WCGestureVoiceTranscriptionIgnoreSelfKey: @YES,
            WCGestureEnabledKey: @YES,
            WCPluginNameKey: @"One Wx",
            WCReplySwipeEnabledKey: @NO,
            WCReplySwipeSelfActionKey: @(WCReplySwipeActionQuote),
            WCReplySwipeOtherActionKey: @(WCReplySwipeActionQuote),
            WCReplySwipeRightSelfActionKey: @(WCReplySwipeActionNone),
            WCReplySwipeRightOtherActionKey: @(WCReplySwipeActionNone),
            WCReplySwipeTriggerDistanceKey: @56.0,
            WCMessageDoubleTapSelfActionKey: @(WCReplySwipeActionNone),
            WCMessageDoubleTapOtherActionKey: @(WCReplySwipeActionNone),
            WCMessageTripleTapSelfActionKey: @(WCReplySwipeActionNone),
            WCMessageTripleTapOtherActionKey: @(WCReplySwipeActionNone),
            WCInputGestureEnabledKey: @NO,
            WCInputSwipeLeftActionKey: @(WCInputActionClear),
            WCInputSwipeRightActionKey: @(WCInputActionPaste),
            WCInputDoubleTapActionKey: @(WCInputActionNone),
            WCInputTripleTapActionKey: @(WCInputActionNone),
            WCKeyboardEnhanceEnabledKey: @NO,
            WCKeyboardSwipeLeftActionKey: @(WCInputActionTranslate),
            // The former "译成中文" gesture is now folded into 互译, so the
            // right swipe starts empty instead of repeating the same action.
            WCKeyboardSwipeRightActionKey: @(WCInputActionNone),
            WCKeyboardDoubleTapActionKey: @(WCInputActionNone),
            WCKeyboardTripleTapActionKey: @(WCInputActionNone),
            WCKeyboardLongPressActionKey: @(WCInputActionNone),
            WCKeyboardDebugFrameKey: @YES,
            // Same baseline as the third-party set: the width scales with the
            // screen (250 at the 393pt reference), keeping the band between
            // the globe and mic keys instead of spanning the whole keyboard.
            WCKeyboardStripWidthKey: @250.0,
            WCKeyboardStripHeightKey: @50.0,
            WCKeyboardStripOffsetXKey: @0.0,
            WCKeyboardStripOffsetYKey: @(-25.0),
            WCKeyboardStripWidthKeyThirdParty: @250.0,
            WCKeyboardStripHeightKeyThirdParty: @50.0,
            WCKeyboardStripOffsetXKeyThirdParty: @0.0,
            WCKeyboardStripOffsetYKeyThirdParty: @65.0,
            WCKeyboardStripSeparateAdjustKey: @NO,
            WCKeyboardSignatureTextKey: @"",
            WCKeyboardSignatureSizeKey: @11.0,
            WCKeyboardSignatureFontKey: @(WCKeyboardSignatureFontSystem),
            WCKeyboardSignatureDecorationKey: @(WCKeyboardSignatureDecorationNone),
            WCKeyboardSignatureColorKey: @"",
            WCKeyboardSignatureOffsetXKey: @0.0,
            WCKeyboardSignatureOffsetYKey: @0.0,
            WCTranslateEnabledKey: @YES,
            WCTranslateEngineKey: @(WCTranslateEngineEdge),
            WCTranslatePairTargetKey: @"en",
            WCGestureAIEnabledKey: @YES,
            WCGestureAIProviderKey: @(WCGestureAIProviderDeepSeek),
            WCGestureAIBaseURLKey: @"",
            WCGestureAIModelKey: @"",
            WCGestureAIAPIKeyKey: @"",
            WCGestureAIPresetsKey: @[],
            WCGestureAIPresetPrompt1Key: @"",
            WCGestureAIPresetPrompt2Key: @"",
            WCGestureAIPresetPrompt3Key: @"",
            WCGestureAIReplyPresetKey: @0,
            WCGestureAIAnswerPresetKey: @0,
            WCGestureAIPolishPresetKey: @0,
            WCGestureAntiRevokeNotifySenderKey: @NO,
            WCGestureAntiRevokeTimeFilterKey: @300.0,
            WCGestureAntiRevokePromptStyleKey: @0,
            WCGestureAntiRevokeSideTextKey: @"已拦截撤回",
            WCGestureAntiRevokeSideOffsetXKey: @0.0,
            WCGestureAntiRevokeSideOffsetYKey: @10.0,
            WCGestureAntiRevokePersistRecordsKey: @NO,
            WCGestureMessageTimeBelowAvatarKey: @YES,
            WCGestureMessageTimeBubbleSideKey: @NO,
            WCGestureMessageTimeColorKey: @"#8E8E93FF",
            WCGestureMessageTimeAvatarSpacingKey: @-2.0,
            WCGestureMessageTimeLightColorKey: @"",
            WCGestureMessageTimeDarkColorKey: @"",
            WCGestureAntiRevokeLocalTemplateKey: @"拦截到一条{用户名}撤回的消息\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n内容：{内容}",
            WCGestureAntiRevokeReplyTemplateKey: @"【捕捉到一条撤回消息】\n操作用户：{用户名}\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n撤回内容：{内容}\n\n撤回无效，消息已保存",
            WCGestureAntiRevokeLocalTextColorKey: @"",
            WCGestureAntiRevokeSideTextColorKey: @"",
            WCGestureAntiRevokeLocalLightTextColorKey: @"",
            WCGestureAntiRevokeLocalDarkTextColorKey: @"",
            WCGestureAntiRevokeSideLightTextColorKey: @"",
            WCGestureAntiRevokeSideDarkTextColorKey: @"",
            WCGesturePageScalePluginUIKey: @NO,
            WCGestureMessageTimeOffsetXKey: @0.0,
            WCGestureMessageTimeOffsetYKey: @0.0,
            WCGesturePageScaleEnabledKey: @NO,
            WCGestureGlobalAvatarRoundingEnabledKey: @NO,
            WCGestureGlobalAvatarCornerPercentKey: @100.0,
            WCGestureChatInputRoundingEnabledKey: @NO,
            WCGestureChatInputInnerRoundingKey: @YES,
            WCGestureChatInputOuterRoundingKey: @YES,
            WCGestureChatInputInnerRadiusKey: @18.0,
            WCGestureChatInputOuterRadiusKey: @22.0,
            WCGestureAntiRevokeEnabledKey: @NO,
            WCGestureVoiceForwardEnabledKey: @NO,
            WCGestureLongPressMenuEnabledKey: @NO,
            WCGestureLongPressMenuHiddenTitlesKey: @[],
            WCGestureLongPressMenuPreferredOrderKey: @[],
            WCGestureLongPressMenuTitleMapKey: @{},
            WCGestureLongPressMenuKnownTitlesKey: @[],
            WCGestureLongPressMenuManualTitlesKey: @[],
            WCGestureMessageTimeEnabledKey: @NO,
            WCGestureMessageTimeFormatKey: @"MM-dd HH:mm:ss",
            WCGestureMessageTimeFontSizeKey: @10.0,
            WCGestureMessageTimeBoldKey: @NO,
            WCGestureMessageTimePositionKey: @2,
            WCGesturePageScalePercentKey: @90.0,
            WCChatLayoutEnabledKey: @NO,
            WCChatLayoutFontLevelKey: @2,
            WCMomentsLayoutEnabledKey: @NO,
            WCMomentsHeightScaleKey: @115.0,
            WCMomentsDoubleTapLikeKey: @NO,
            WCMomentsLikeHapticKey: @YES,
            WCMessageGestureHapticKey: @YES,
            WCInputGestureHapticKey: @YES,
            WCKeyboardHapticKey: @YES,
            WCGlobalGestureEnabledKey: @NO,
            WCGlobalTwoFingerActionKey: @(WCGlobalActionNone),
            WCGlobalThreeFingerActionKey: @(WCGlobalActionNone),
            WCGlobalGestureHapticKey: @YES,
            WCGestureHapticStyleKey: @(WCHapticStyleMedium),
            WCCustomPagesKey: @[],
            WCHideSeparatorLinesKey: @NO,
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    });
}

BOOL WCGestureEnabled(NSString *key) {
    // The per-feature switches gate everything; there is no separate master
    // switch in the UI, so each gesture is controlled by its own key.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (key.length == 0) return YES;
    return [defaults boolForKey:key];
}
