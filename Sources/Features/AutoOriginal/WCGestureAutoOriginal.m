#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
static char WCAutoOriginalPendingKey;
void WCGestureAutoOriginalApply(id controller, NSString *checkboxKey) {
    if (!WCGestureEnabled(WCGestureAutoOriginalEnabledKey) || [objc_getAssociatedObject(controller, &WCAutoOriginalPendingKey) boolValue]) return;
    objc_setAssociatedObject(controller, &WCAutoOriginalPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak id weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        id target = weakController; if (!target) return;
        objc_setAssociatedObject(target, &WCAutoOriginalPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!WCGestureEnabled(WCGestureAutoOriginalEnabledKey)) return;
        if ([target isKindOfClass:UIViewController.class] && ([target isBeingDismissed] || [target isMovingFromParentViewController])) return;
        SEL selected = NSSelectorFromString(@"isOriginSelected");
        if (![target respondsToSelector:selected]) return;
        if (((BOOL (*)(id, SEL))objc_msgSend)(target, selected)) return;
        id checkbox = WCTweakSafeValue(target, checkboxKey);
        SEL action = NSSelectorFromString(@"onOriginImageCheck:");
        if (checkbox && [target respondsToSelector:action]) {
            ((void (*)(id, SEL, id))objc_msgSend)(target, action, checkbox);
        } else {
            SEL setter = NSSelectorFromString(@"setIsOriginSelected:");
            if ([target respondsToSelector:setter]) ((void (*)(id, SEL, BOOL))objc_msgSend)(target, setter, YES);
        }
    });
}
