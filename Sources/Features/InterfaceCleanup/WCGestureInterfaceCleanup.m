#import <objc/runtime.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

static char WCGroupLabelHiddenKey;
static NSHashTable<UILabel *> *WCGroupLabels(void) {
    static NSHashTable *labels;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ labels = [NSHashTable weakObjectsHashTable]; });
    return labels;
}

BOOL WCGestureShouldHideMeEntry(NSString *title) {
    NSDictionary *keys = @{ @"作品": WCGestureHideMeFinderKey, @"小店与卡包": WCGestureHideMeCardsKey,
                            @"表情": WCGestureHideMeEmoticonsKey };
    NSString *key = keys[title];
    return key && WCGestureEnabled(key);
}

id WCGestureGroupMemberLabel(id label) {
    if (![label isKindOfClass:UILabel.class]) return label;
    UILabel *view = label;
    NSNumber *original = objc_getAssociatedObject(view, &WCGroupLabelHiddenKey);
    if (WCGestureEnabled(WCGestureHideGroupTitleTailKey)) {
        if (!original) objc_setAssociatedObject(view, &WCGroupLabelHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [WCGroupLabels() addObject:view];
        view.hidden = YES;
    } else if (original) {
        view.hidden = original.boolValue;
        objc_setAssociatedObject(view, &WCGroupLabelHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return label;
}


@interface WCGroupTitleState : NSObject
@property (nonatomic, weak) UIView *title;
@property (nonatomic, weak) UILabel *label;
@property (nonatomic, assign) CGRect originalTitleFrame;
@property (nonatomic, assign) CGRect appliedTitleFrame;
@property (nonatomic, assign) CGRect originalLabelFrame;
@property (nonatomic, assign) CGRect appliedLabelFrame;
@property (nonatomic, assign) NSTextAlignment alignment;
@end
@implementation WCGroupTitleState
@end
static char WCGroupTitleStateKey;
static NSHashTable *WCGroupTitleControllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}
static UILabel *WCGroupMainTitle(UIView *view, NSUInteger depth) {
    if (!view || depth > 6 || view.hidden) return nil;
    if ([view isKindOfClass:UILabel.class]) return ((UILabel *)view).text.length ? (UILabel *)view : nil;
    UILabel *best = nil;
    for (UIView *child in view.subviews) {
        UILabel *label = WCGroupMainTitle(child, depth + 1);
        if (label && (!best || label.font.pointSize > best.font.pointSize)) best = label;
    }
    return best;
}
void WCGestureGroupTitleRestore(UIViewController *controller) {
    WCGroupTitleState *state = objc_getAssociatedObject(controller, &WCGroupTitleStateKey);
    if (!state) return;
    if (state.title && CGRectEqualToRect(state.title.frame, state.appliedTitleFrame)) state.title.frame = state.originalTitleFrame;
    if (state.label && state.label != state.title && CGRectEqualToRect(state.label.frame, state.appliedLabelFrame)) state.label.frame = state.originalLabelFrame;
    state.label.textAlignment = state.alignment;
    objc_setAssociatedObject(controller, &WCGroupTitleStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void WCGestureGroupTitleLayout(UIViewController *controller) {
    [WCGroupTitleControllers() addObject:controller];
    id contact = WCTweakSafeValue(controller, @"GetCContact");
    UIView *title = controller.navigationItem.titleView;
    UINavigationBar *bar = controller.navigationController.navigationBar;
    BOOL enabled = WCGestureEnabled(WCGestureHideGroupTitleTailKey) && !WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey)
        && [WCPrivateContactUserName(contact) hasSuffix:@"@chatroom"] && !WCGestureChatSearchIsActive(controller)
        && ![WCTweakSafeValue(controller, @"isMultiSelectMode") boolValue];
    if (!enabled || !title.superview || !bar.window || controller.navigationController.topViewController != controller) { WCGestureGroupTitleRestore(controller); return; }
    UILabel *label = WCGroupMainTitle(title, 0);
    if (!label) return;
    WCGroupTitleState *state = objc_getAssociatedObject(controller, &WCGroupTitleStateKey);
    if (state && (state.title != title || state.label != label)) { WCGestureGroupTitleRestore(controller); state = nil; }
    if (!state) {
        state = [WCGroupTitleState new]; state.title = title; state.label = label;
        state.originalTitleFrame = title.frame; state.originalLabelFrame = label.frame; state.alignment = label.textAlignment;
        objc_setAssociatedObject(controller, &WCGroupTitleStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        if (!CGRectEqualToRect(title.frame, state.appliedTitleFrame)) state.originalTitleFrame = title.frame;
        if (!CGRectEqualToRect(label.frame, state.appliedLabelFrame)) state.originalLabelFrame = label.frame;
    }
    CGPoint center = [bar convertPoint:CGPointMake(CGRectGetMidX(bar.bounds), CGRectGetMidY(bar.bounds)) toView:title.superview];
    title.center = CGPointMake(center.x, title.center.y);
    if (label != title) {
        CGPoint labelCenter = [title convertPoint:CGPointMake(CGRectGetMidX(title.bounds), CGRectGetMidY(title.bounds)) toView:label.superview];
        label.center = CGPointMake(labelCenter.x, label.center.y);
    }
    label.textAlignment = NSTextAlignmentCenter;
    state.appliedTitleFrame = title.frame; state.appliedLabelFrame = label.frame;
}
static IMP WCGroupOffsetOriginal;
static CGFloat WCGroupTitleOffset(id object, SEL selector) {
    if (WCGestureEnabled(WCGestureHideGroupTitleTailKey)) return 0;
    return ((CGFloat (*)(id, SEL))WCGroupOffsetOriginal)(object, selector);
}
void WCGestureInterfaceCleanupInstallOptionalHooks(void) {
    if (WCGroupOffsetOriginal) return;
    // WCAtlas's offset selector is absent from 8.0.79 headers; install only if its runtime ABI matches.
    Class cls = NSClassFromString(@"RoomContentLogicController");
    SEL selector = NSSelectorFromString(@"GetTitleLabelOffset");
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return;
    char result[16] = {0}; method_getReturnType(method, result, sizeof(result));
    if (strcmp(result, @encode(CGFloat)) != 0) return;
    WCGroupOffsetOriginal = method_getImplementation(method);
    if (!class_addMethod(cls, selector, (IMP)WCGroupTitleOffset, method_getTypeEncoding(method)))
        method_setImplementation(class_getInstanceMethod(cls, selector), (IMP)WCGroupTitleOffset);
}

void WCGestureInterfaceCleanupSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureHideGroupTitleTailKey]) return;
    for (UILabel *label in WCGroupLabels().allObjects) WCGestureGroupMemberLabel(label);
    for (UIViewController *controller in WCGroupTitleControllers().allObjects) {
        WCGestureGroupTitleLayout(controller);
        [controller.navigationItem.titleView.superview setNeedsLayout];
    }
}
