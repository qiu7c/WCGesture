#import "WCGestureConfig.h"

NSString *const WCGestureEnabledKey = @"com.qiu7c.wcgesture.enabled";

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

NSString *const WCInputSwipeActionsEnabledKey = @"com.qiu7c.wcgesture.chat.input-swipe-actions";

NSString *const WCGestureDidChangeNotification = @"WCGestureDidChangeNotification";

void WCGestureRegisterDefaults(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *defaults = @{
            WCGestureEnabledKey: @YES,
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
            WCInputSwipeActionsEnabledKey: @NO,
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    });
}

BOOL WCGestureEnabled(NSString *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL masterEnabled = [defaults boolForKey:WCGestureEnabledKey];
    if (!masterEnabled) return NO;
    if (key.length == 0) return YES;
    return [defaults boolForKey:key];
}
