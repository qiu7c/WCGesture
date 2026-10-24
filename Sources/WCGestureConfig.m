#import "WCGestureConfig.h"

NSString *const WCGestureEnabledKey = @"com.qiu7c.wcgesture.enabled";
NSString *const WCPluginNameKey = @"com.qiu7c.wcgesture.plugin-name";

NSString *const WCReplySwipeEnabledKey = @"com.qiu7c.wcgesture.chat.reply-swipe";
NSString *const WCReplySwipeSelfActionKey = @"com.qiu7c.wcgesture.chat.reply-swipe.self-action";
NSString *const WCReplySwipeOtherActionKey = @"com.qiu7c.wcgesture.chat.reply-swipe.other-action";
NSString *const WCReplySwipeRightSelfActionKey = @"com.qiu7c.wcgesture.chat.reply-swipe.right.self-action";
NSString *const WCReplySwipeRightOtherActionKey = @"com.qiu7c.wcgesture.chat.reply-swipe.right.other-action";
NSString *const WCReplySwipeTriggerDistanceKey = @"com.qiu7c.wcgesture.chat.reply-swipe.trigger-distance";
NSString *const WCMessageDoubleTapSelfActionKey = @"com.qiu7c.wcgesture.chat.message-gesture.double-tap.self-action";
NSString *const WCMessageDoubleTapOtherActionKey = @"com.qiu7c.wcgesture.chat.message-gesture.double-tap.other-action";
NSString *const WCMessageTripleTapSelfActionKey = @"com.qiu7c.wcgesture.chat.message-gesture.triple-tap.self-action";
NSString *const WCMessageTripleTapOtherActionKey = @"com.qiu7c.wcgesture.chat.message-gesture.triple-tap.other-action";

NSString *const WCInputGestureEnabledKey = @"com.qiu7c.wcgesture.chat.input-gesture";
NSString *const WCInputSwipeLeftActionKey = @"com.qiu7c.wcgesture.chat.input-gesture.swipe.left";
NSString *const WCInputSwipeRightActionKey = @"com.qiu7c.wcgesture.chat.input-gesture.swipe.right";
NSString *const WCInputDoubleTapActionKey = @"com.qiu7c.wcgesture.chat.input-gesture.double-tap";
NSString *const WCInputTripleTapActionKey = @"com.qiu7c.wcgesture.chat.input-gesture.triple-tap";
NSString *const WCKeyboardEnhanceEnabledKey = @"com.qiu7c.wcgesture.input.keyboard-enhance";
NSString *const WCKeyboardSwipeLeftActionKey = @"com.qiu7c.wcgesture.input.keyboard.swipe-left";
NSString *const WCKeyboardSwipeRightActionKey = @"com.qiu7c.wcgesture.input.keyboard.swipe-right";
NSString *const WCKeyboardDoubleTapActionKey = @"com.qiu7c.wcgesture.input.keyboard.double-tap";
NSString *const WCKeyboardTripleTapActionKey = @"com.qiu7c.wcgesture.input.keyboard.triple-tap";
NSString *const WCKeyboardDebugFrameKey = @"com.qiu7c.wcgesture.input.keyboard.debug-frame";
NSString *const WCKeyboardStripWidthKey = @"com.qiu7c.wcgesture.input.keyboard.strip-width";
NSString *const WCKeyboardStripHeightKey = @"com.qiu7c.wcgesture.input.keyboard.strip-height";
NSString *const WCKeyboardStripOffsetXKey = @"com.qiu7c.wcgesture.input.keyboard.strip-offset-x";
NSString *const WCKeyboardStripOffsetYKey = @"com.qiu7c.wcgesture.input.keyboard.strip-offset-y";
NSString *const WCTranslateEngineKey = @"com.qiu7c.wcgesture.translate.engine";
NSString *const WCTranslateCustomURLKey = @"com.qiu7c.wcgesture.translate.custom-url";
NSString *const WCTranslateCustomKeyKey = @"com.qiu7c.wcgesture.translate.custom-key";
NSString *const WCTranslateCustomModelKey = @"com.qiu7c.wcgesture.translate.custom-model";

NSString *const WCMomentsDoubleTapLikeKey = @"com.qiu7c.wcgesture.moments.double-tap-like";
NSString *const WCMomentsLikeHapticKey = @"com.qiu7c.wcgesture.moments.like-haptic";

NSString *const WCMessageGestureHapticKey = @"com.qiu7c.wcgesture.chat.message-gesture.haptic";
NSString *const WCInputGestureHapticKey = @"com.qiu7c.wcgesture.chat.input-gesture.haptic";
NSString *const WCKeyboardHapticKey = @"com.qiu7c.wcgesture.keyboard.haptic";

NSString *const WCGlobalGestureEnabledKey = @"com.qiu7c.wcgesture.global.enabled";
NSString *const WCGlobalTwoFingerActionKey = @"com.qiu7c.wcgesture.global.two-finger-action";
NSString *const WCGlobalThreeFingerActionKey = @"com.qiu7c.wcgesture.global.three-finger-action";
NSString *const WCGlobalGestureHapticKey = @"com.qiu7c.wcgesture.global.haptic";
NSString *const WCGestureHapticStyleKey = @"com.qiu7c.wcgesture.haptic-style";
NSString *const WCCustomPagesKey = @"com.qiu7c.wcgesture.custom-pages";
NSString *const WCHideSeparatorLinesKey = @"com.qiu7c.wcgesture.interface.hide-separator-lines";

NSString *const WCGestureDidChangeNotification = @"WCGestureDidChangeNotification";

void WCGestureRegisterDefaults(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *defaults = @{
            WCGestureEnabledKey: @YES,
            WCPluginNameKey: @"微信手势",
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
            WCKeyboardSwipeLeftActionKey: @(WCInputActionTranslateToEnglish),
            WCKeyboardSwipeRightActionKey: @(WCInputActionTranslateToChinese),
            WCKeyboardDoubleTapActionKey: @(WCInputActionNone),
            WCKeyboardTripleTapActionKey: @(WCInputActionNone),
            WCKeyboardDebugFrameKey: @YES,
            WCKeyboardStripWidthKey: @0.0,
            WCKeyboardStripHeightKey: @50.0,
            WCKeyboardStripOffsetXKey: @0.0,
            WCKeyboardStripOffsetYKey: @0.0,
            WCTranslateEngineKey: @(WCTranslateEngineEdge),
            WCTranslateCustomURLKey: @"",
            WCTranslateCustomKeyKey: @"",
            WCTranslateCustomModelKey: @"",
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
