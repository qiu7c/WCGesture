#import <objc/runtime.h>
#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"

static char WCTopBarStateKey;

@interface WCTopBackgroundState : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, assign) BOOL hidden;
@end
@implementation WCTopBackgroundState
@end

@interface WCTopBarState : NSObject
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *left;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *right;
@property (nonatomic, strong) UIView *title;
@property (nonatomic, assign) BOOL supplement;
@property (nonatomic, copy) NSArray *appearances;
@property (nonatomic, assign) UIRectEdge edges;
@property (nonatomic, assign) BOOL opaqueBars;
@property (nonatomic, strong) UIBarButtonItem *profileItem;
@property (nonatomic, strong) UIBarButtonItem *actionsItem;
@property (nonatomic, strong) WCGestureChatTopCapsuleView *profile;
@property (nonatomic, strong) WCGestureChatTopCapsuleView *actions;
@property (nonatomic, strong) UIView *placeholder;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *stableName;
@property (nonatomic, assign) BOOL typing;
@property (nonatomic, assign) BOOL updating;
@property (nonatomic, strong) NSMapTable<UIView *, WCTopBackgroundState *> *backgrounds;
@end
@implementation WCTopBarState
@end

static NSHashTable<UIViewController *> *WCTopControllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}

static NSArray *WCTopNativeItems(NSArray<UIBarButtonItem *> *items) {
    NSMutableArray *native = [NSMutableArray array];
    for (UIBarButtonItem *item in items) {
        if (![item.customView isKindOfClass:WCGestureChatTopCapsuleView.class]) [native addObject:item];
    }
    return native;
}

static BOOL WCTopTyping(UIView *view, NSUInteger depth) {
    if (![view isKindOfClass:UIView.class] || depth > 6) return NO;
    if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text containsString:@"正在输入"]) return YES;
    for (UIView *child in view.subviews) if (WCTopTyping(child, depth + 1)) return YES;
    return NO;
}

static UIControl *WCTopControl(UIView *view, NSUInteger depth) {
    if ([view isKindOfClass:UIControl.class]) return (UIControl *)view;
    if (depth >= 6) return nil;
    for (UIView *child in view.subviews) {
        UIControl *control = WCTopControl(child, depth + 1);
        if (control) return control;
    }
    return nil;
}

static void WCTopInvoke(UIBarButtonItem *item, UIViewController *controller, BOOL back) {
    if (item && !item.enabled) return;
    UIControl *control = WCTopControl(item.customView, 0);
    if (control) {
        if (control.enabled) [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        return;
    }
    if (item.action && [UIApplication.sharedApplication sendAction:item.action to:item.target from:item forEvent:nil]) return;
    if (back) [controller.navigationController popViewControllerAnimated:YES];
}

static void WCTopHideBackground(WCTopBarState *state, UIView *view) {
    if (!view) return;
    if (![state.backgrounds objectForKey:view]) {
        WCTopBackgroundState *snapshot = [WCTopBackgroundState new];
        snapshot.view = view; snapshot.hidden = view.hidden;
        [state.backgrounds setObject:snapshot forKey:view];
    }
    view.hidden = YES;
}

static void WCTopScopeBackgrounds(WCTopBarState *state, UIView *view, NSUInteger depth) {
    if (!view || depth > 4 || [view isKindOfClass:WCGestureChatTopCapsuleView.class]) return;
    NSString *name = NSStringFromClass(view.class);
    // Only known navigation backgrounds; never hide content/control containers.
    if ([name isEqualToString:@"_UIBarBackground"] || [name isEqualToString:@"_UINavigationBarBackground"]) {
        WCTopHideBackground(state, view); return;
    }
    for (UIView *child in view.subviews) WCTopScopeBackgrounds(state, child, depth + 1);
}

static void WCTopPrivateBackgrounds(WCTopBarState *state, UIView *view, NSUInteger depth, NSUInteger *budget) {
    if (!view || depth > 8 || !*budget) return;
    (*budget)--;
    NSString *name = NSStringFromClass(view.class);
    if ([name isEqualToString:@"MMNewMsgContentNavBar"] || [name isEqualToString:@"MMMsgContentNavBar"]) {
        for (UIView *child in view.subviews) {
            NSString *childName = NSStringFromClass(child.class);
            BOOL background = [child isKindOfClass:UIVisualEffectView.class] || [childName containsString:@"Background"];
            if (background && CGRectGetWidth(child.bounds) >= CGRectGetWidth(view.bounds) - 1)
                WCTopHideBackground(state, child);
        }
        return;
    }
    for (UIView *child in view.subviews) WCTopPrivateBackgrounds(state, child, depth + 1, budget);
}

void WCGestureChatTopBarRestore(UIViewController *controller) {
    WCTopBarState *state = objc_getAssociatedObject(controller, &WCTopBarStateKey);
    if (!state || state.updating) return;
    state.updating = YES;
    UINavigationItem *item = controller.navigationItem;
    if ([item.leftBarButtonItems containsObject:state.profileItem]) item.leftBarButtonItems = state.left;
    if ([item.rightBarButtonItems containsObject:state.actionsItem]) item.rightBarButtonItems = state.right;
    if (item.titleView == state.placeholder) item.titleView = state.title;
    item.leftItemsSupplementBackButton = state.supplement;
    NSArray *saved = state.appearances;
    item.standardAppearance = saved[0] == NSNull.null ? nil : saved[0];
    item.scrollEdgeAppearance = saved[1] == NSNull.null ? nil : saved[1];
    item.compactAppearance = saved[2] == NSNull.null ? nil : saved[2];
    if (@available(iOS 15.0, *)) item.compactScrollEdgeAppearance = saved[3] == NSNull.null ? nil : saved[3];
    controller.edgesForExtendedLayout = state.edges;
    controller.extendedLayoutIncludesOpaqueBars = state.opaqueBars;
    for (WCTopBackgroundState *background in state.backgrounds.objectEnumerator) background.view.hidden = background.hidden;
    objc_setAssociatedObject(controller, &WCTopBarStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void WCGestureChatTopBarUpdate(UIViewController *controller) {
    [WCTopControllers() addObject:controller];
    if (!WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey) || WCGestureChatSearchIsActive(controller)) {
        WCGestureChatTopBarRestore(controller); return;
    }
    BOOL multiSelect = [WCTweakSafeValue(controller, @"isMultiSelectMode") boolValue]
        || [WCTweakSafeValue(controller, @"isInMultiSelectMsg") boolValue];
    if (multiSelect) {
        WCGestureChatTopBarRestore(controller); return;
    }
    if (!controller.isViewLoaded || !controller.view.window || controller.navigationController.topViewController != controller) return;
    WCTopBarState *state = objc_getAssociatedObject(controller, &WCTopBarStateKey);
    if (state.updating) return;
    UINavigationItem *item = controller.navigationItem;
    if (!state) {
        state = [WCTopBarState new];
        state.left = WCTopNativeItems(item.leftBarButtonItems ?: @[]);
        state.right = WCTopNativeItems(item.rightBarButtonItems ?: @[]);
        state.title = item.titleView; state.supplement = item.leftItemsSupplementBackButton;
        NSMutableArray *appearances = [NSMutableArray arrayWithArray:@[item.standardAppearance ?: NSNull.null,
            item.scrollEdgeAppearance ?: NSNull.null, item.compactAppearance ?: NSNull.null]];
        if (@available(iOS 15.0, *)) [appearances addObject:item.compactScrollEdgeAppearance ?: NSNull.null];
        state.appearances = appearances;
        state.edges = controller.edgesForExtendedLayout; state.opaqueBars = controller.extendedLayoutIncludesOpaqueBars;
        state.backgrounds = [NSMapTable weakToStrongObjectsMapTable];
        state.profile = [[WCGestureChatTopCapsuleView alloc] initWithProfile:YES];
        state.actions = [[WCGestureChatTopCapsuleView alloc] initWithProfile:NO];
        state.profileItem = [[UIBarButtonItem alloc] initWithCustomView:state.profile];
        state.actionsItem = [[UIBarButtonItem alloc] initWithCustomView:state.actions];
        state.placeholder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
        objc_setAssociatedObject(controller, &WCTopBarStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIViewController *weakController = controller;
        __weak WCTopBarState *weakState = state;
        state.profile.backAction = ^{ WCTopInvoke(weakState.left.firstObject, weakController, YES); };
        state.actions.moreAction = ^{ WCTopInvoke(weakState.right.firstObject, weakController, NO); };
        state.actions.searchAction = ^{ WCGestureChatSearchOpen(weakController, nil); };
    }
    state.updating = YES;
    // Keep replacements made by WeChat (including menus) as the latest native baseline.
    if (![item.leftBarButtonItems containsObject:state.profileItem]) state.left = WCTopNativeItems(item.leftBarButtonItems ?: @[]);
    if (![item.rightBarButtonItems containsObject:state.actionsItem]) state.right = WCTopNativeItems(item.rightBarButtonItems ?: @[]);
    if (!state.right.count) {
        id nativeMore = WCTweakSafeValue(controller, @"getRightBarButton");
        if ([nativeMore isKindOfClass:UIBarButtonItem.class] && nativeMore != state.actionsItem) state.right = @[nativeMore];
    }
    if (item.titleView != state.placeholder) {
        state.title = item.titleView;
        state.typing = WCTopTyping(state.title, 0);
    }
    id contact = WCTweakSafeValue(controller, @"GetCContact");
    NSString *userName = WCPrivateContactUserName(contact) ?: @"";
    if (![state.userName isEqualToString:userName]) {
        state.userName = userName;
        [state.profile setAvatarView:userName.length ? WCGestureContactAvatarView(userName) : [UIView new]];
    }
    NSString *fallback = item.title ?: controller.title ?: @"聊天";
    if ([fallback containsString:@"正在输入"]) fallback = state.stableName ?: @"聊天";
    NSString *name = WCGesturePrivateContactDisplayName(contact, fallback);
    state.stableName = name;
    BOOL search = WCGestureEnabled(WCGestureChatSearchEnabledKey);
    CGFloat totalWidth = CGRectGetWidth(controller.navigationController.navigationBar.bounds);
    if (totalWidth < 1) totalWidth = CGRectGetWidth(controller.view.bounds);
    NSUInteger extras = (state.left.count > 1 ? state.left.count - 1 : 0) + (state.right.count > 1 ? state.right.count - 1 : 0);
    CGFloat maxLeft = MAX(90, MIN(260, totalWidth - (search ? 88 : 44) - 48 - 44 * extras));
    CGSize leftSize = [state.profile configureWithName:name typing:state.typing search:NO moreImage:nil menu:nil maximumWidth:maxLeft];
    UIBarButtonItem *more = state.right.firstObject;
    CGSize rightSize = [state.actions configureWithName:@"" typing:NO search:search moreImage:more.image menu:more.menu maximumWidth:88];
    state.profile.frame = (CGRect){CGPointZero, leftSize};
    state.actions.frame = (CGRect){CGPointZero, rightSize};
    if (![item.leftBarButtonItems containsObject:state.profileItem]) {
        NSMutableArray *left = [NSMutableArray arrayWithObject:state.profileItem];
        if (state.left.count > 1) [left addObjectsFromArray:[state.left subarrayWithRange:NSMakeRange(1, state.left.count - 1)]];
        item.leftBarButtonItems = left;
    }
    if (![item.rightBarButtonItems containsObject:state.actionsItem]) {
        NSMutableArray *right = [NSMutableArray arrayWithObject:state.actionsItem];
        if (state.right.count > 1) [right addObjectsFromArray:[state.right subarrayWithRange:NSMakeRange(1, state.right.count - 1)]];
        item.rightBarButtonItems = right;
    }
    item.leftItemsSupplementBackButton = NO;
    if (item.titleView != state.placeholder) item.titleView = state.placeholder;
    // Per-item appearances avoid leaking transparent styles into other screens.
    if (!item.standardAppearance || item.standardAppearance.backgroundEffect || ![item.standardAppearance.backgroundColor isEqual:UIColor.clearColor]) {
        UINavigationBarAppearance *clear = [UINavigationBarAppearance new];
        [clear configureWithTransparentBackground];
        clear.backgroundColor = UIColor.clearColor; clear.backgroundEffect = nil; clear.shadowColor = UIColor.clearColor;
        item.standardAppearance = clear; item.scrollEdgeAppearance = clear; item.compactAppearance = clear;
        if (@available(iOS 15.0, *)) item.compactScrollEdgeAppearance = clear;
    }
    controller.edgesForExtendedLayout |= UIRectEdgeTop;
    controller.extendedLayoutIncludesOpaqueBars = YES;
    WCTopScopeBackgrounds(state, controller.navigationController.navigationBar, 0);
    NSUInteger budget = 150;
    WCTopPrivateBackgrounds(state, controller.view, 0, &budget);
    state.updating = NO;
}

void WCGestureChatTopBarTitleChanged(UIViewController *controller, id titleView) {
    WCTopBarState *state = objc_getAssociatedObject(controller, &WCTopBarStateKey);
    if (state && [titleView isKindOfClass:UIView.class] && titleView != state.placeholder) {
        state.title = titleView;
        state.typing = WCTopTyping(titleView, 0);
    }
    WCGestureChatTopBarUpdate(controller);
}

void WCGestureChatTopBarSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureChatSearchEnabledKey]
        && ![key hasPrefix:@"com.qiu7c.onewx.chat.top-bar-capsule."]) return;
    for (UIViewController *controller in WCTopControllers().allObjects) {
        if (controller.isViewLoaded && controller.view.window) WCGestureChatSearchUpdate(controller);
        else WCGestureChatTopBarRestore(controller);
    }
}
