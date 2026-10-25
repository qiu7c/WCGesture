#import "Sources/API/WCGestureInternal.h"

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

// Chat layout: font level override and Moments cell-height compensation.
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
        NSDictionary *defaults = @{
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
