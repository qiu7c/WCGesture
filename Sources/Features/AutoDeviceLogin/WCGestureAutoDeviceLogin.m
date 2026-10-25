#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCAutoDeviceLoginPendingInfoKey;
static char WCAutoDeviceLoginConfirmedInfoKey;

static BOOL WCAutoDeviceLoginCanConfirm(MultiDeviceCardLoginContentView *view) {
    UIButton *button = view.confirmButton;
    return WCGestureEnabled(WCGestureAutoDeviceLoginEnabledKey)
        && view.window && !view.hidden && view.alpha > 0.01
        && view.errorType == 0 && button && button.enabled
        && !button.hidden && button.alpha > 0.01;
}

void WCGestureAutoDeviceLoginApply(UIView *view) {
    Class loginClass = NSClassFromString(@"MultiDeviceCardLoginContentView");
    if (!loginClass || ![view isKindOfClass:loginClass]) return;
    MultiDeviceCardLoginContentView *card = (MultiDeviceCardLoginContentView *)view;
    if (![card respondsToSelector:@selector(onTapConfirmButton)] || !WCAutoDeviceLoginCanConfirm(card)) return;
    id info = card.deviceLoginInfo;
    if (!info || objc_getAssociatedObject(card, &WCAutoDeviceLoginConfirmedInfoKey) == info
        || objc_getAssociatedObject(card, &WCAutoDeviceLoginPendingInfoKey) == info) return;
    objc_setAssociatedObject(card, &WCAutoDeviceLoginPendingInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak MultiDeviceCardLoginContentView *weakCard = card;
    dispatch_async(dispatch_get_main_queue(), ^{
        MultiDeviceCardLoginContentView *target = weakCard;
        if (!target || objc_getAssociatedObject(target, &WCAutoDeviceLoginPendingInfoKey) != info) return;
        objc_setAssociatedObject(target, &WCAutoDeviceLoginPendingInfoKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // A reused card must never confirm the request captured before reuse.
        if (target.deviceLoginInfo != info || !WCAutoDeviceLoginCanConfirm(target)
            || objc_getAssociatedObject(target, &WCAutoDeviceLoginConfirmedInfoKey) == info) return;
        objc_setAssociatedObject(target, &WCAutoDeviceLoginConfirmedInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [target onTapConfirmButton];
        WCShowToast(@"已自动确认设备登录");
    });
}
