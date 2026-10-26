#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCAutoCombineState : NSObject
@property (nonatomic, assign) BOOL pending;
@property (nonatomic, weak) UIView *appliedView;
@property (nonatomic, weak) id appliedCenter;
@end
@implementation WCAutoCombineState
@end
static char WCAutoCombineStateKey;

static BOOL WCAutoCombineEnabled(void) {
    return WCGestureEnabled(WCGestureAutoOriginalEnabledKey) && WCGestureEnabled(WCGestureAutoCombineSendEnabledKey);
}
static BOOL WCAutoCombineSignature(id object, SEL selector, BOOL setter) {
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (signature.numberOfArguments != (setter ? 3 : 2)) return NO;
    return setter ? signature.methodReturnType[0] == 'v' && strcmp([signature getArgumentTypeAtIndex:2], @encode(BOOL)) == 0
        : strcmp(signature.methodReturnType, @encode(BOOL)) == 0;
}
void WCGestureAutoCombineSendApply(id controller) {
    WCAutoCombineState *state = objc_getAssociatedObject(controller, &WCAutoCombineStateKey);
    if (!WCAutoCombineEnabled()) {
        state.appliedView = nil; state.appliedCenter = nil;
        return;
    }
    if (!state) {
        state = [WCAutoCombineState new];
        objc_setAssociatedObject(controller, &WCAutoCombineStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (state.pending) return;
    state.pending = YES;
    __weak id weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        id target = weakController;
        state.pending = NO;
        if (!target || !WCAutoCombineEnabled()) return;
        if ([target isKindOfClass:UIViewController.class]) {
            UIViewController *viewController = target;
            if (!viewController.isViewLoaded || !viewController.view.window || viewController.isBeingDismissed || viewController.isMovingFromParentViewController) return;
        }
        @try {
            UIView *view = WCTweakSafeValue(target, @"combineSendView");
            SEL hidden = NSSelectorFromString(@"isCombineSendHidden");
            if (![view isKindOfClass:UIView.class] || !WCAutoCombineSignature(target, hidden, NO)) return;
            if (((BOOL (*)(id, SEL))objc_msgSend)(target, hidden) || view.hidden || !view.window) {
                state.appliedView = nil; state.appliedCenter = nil;
                return;
            }
            id center = WCTweakSafeValue(target, @"controlCenter");
            if (state.appliedView == view && state.appliedCenter == center) return;
            SEL setter = NSSelectorFromString(@"setIsCombineSend:");
            SEL update = NSSelectorFromString(@"updateSelected:");
            if (!WCAutoCombineSignature(center, setter, YES) || !WCAutoCombineSignature(view, update, YES)) return;
            // One attempt per eligibility period: a user's later deselection is respected.
            state.appliedView = view; state.appliedCenter = center;
            ((void (*)(id, SEL, BOOL))objc_msgSend)(center, setter, YES);
            ((void (*)(id, SEL, BOOL))objc_msgSend)(view, update, YES);
        } @catch (__unused NSException *exception) {
            state.appliedView = nil; state.appliedCenter = nil;
        }
    });
}
