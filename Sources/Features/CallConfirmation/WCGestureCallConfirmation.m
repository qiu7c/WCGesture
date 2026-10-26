#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCCallBypassKey;
static __weak UIAlertController *WCCallPendingAlert;

BOOL WCGestureCallConfirmationIntercept(UIView *cell, BOOL video) {
    NSNumber *bypass = objc_getAssociatedObject(cell, &WCCallBypassKey);
    if (bypass && bypass.boolValue == video) {
        objc_setAssociatedObject(cell, &WCCallBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return NO;
    }
    if (!WCGestureEnabled(WCGestureCallConfirmEnabledKey)) return NO;
    // A missing presenter must not silently bypass the enabled confirmation.
    if (WCCallPendingAlert || !cell.window) return YES;
    UIViewController *presenter = WCRootTopController();
    if (!presenter.view.window || presenter.isBeingDismissed || presenter.presentedViewController
        || [presenter isKindOfClass:UIAlertController.class]) return YES;
    id message = WCGestureMessageWrapForCell(cell);
    if (!message) return YES;
    NSString *serverID = [WCTweakSafeValue(message, @"m_n64MesSvrID") description];
    NSString *localID = [WCTweakSafeValue(message, @"m_uiMesLocalID") description];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:video ? @"发起视频通话？" : @"发起语音通话？"
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak UIView *weakCell = cell;
    [alert addAction:[UIAlertAction actionWithTitle:@"呼叫" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIView *target = weakCell;
        id current = target ? WCGestureMessageWrapForCell(target) : nil;
        if (!target.window || current != message || !WCGestureEnabled(WCGestureCallConfirmEnabledKey)) return;
        NSString *currentServerID = [WCTweakSafeValue(current, @"m_n64MesSvrID") description] ?: @"";
        NSString *currentLocalID = [WCTweakSafeValue(current, @"m_uiMesLocalID") description] ?: @"";
        if (![currentServerID isEqualToString:serverID ?: @""] || ![currentLocalID isEqualToString:localID ?: @""]) return;
        SEL selector = NSSelectorFromString(video ? @"startVideoVoip" : @"startVoiceVoip");
        objc_setAssociatedObject(target, &WCCallBypassKey, @(video), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        @try { ((void (*)(id, SEL))objc_msgSend)(target, selector); }
        @finally { objc_setAssociatedObject(target, &WCCallBypassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    }]];
    WCCallPendingAlert = alert;
    [presenter presentViewController:alert animated:YES completion:nil];
    return YES;
}
