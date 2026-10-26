#import <objc/runtime.h>
#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"

static char WCTopBarStateKey;
static char WCTopBarPendingKey;

@interface WCTopBackgroundState : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) BOOL clips;
@property (nonatomic, assign) CGFloat border;
@property (nonatomic, assign) CGFloat corner;
@property (nonatomic, strong) UIVisualEffect *effect;
@property (nonatomic, assign) NSUInteger changed;
@end
@implementation WCTopBackgroundState
@end

@interface WCTopBarState : NSObject
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *left;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *right;
@property (nonatomic, strong) UIView *title;
@property (nonatomic, assign) BOOL supplement;
@property (nonatomic, copy) NSArray *appearances;
@property (nonatomic, weak) UINavigationBar *navigationBar;
@property (nonatomic, copy) NSArray *navigationAppearances;
@property (nonatomic, assign) BOOL translucent;
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

static NSMapTable *WCTopBarOwners(void) {
    static NSMapTable *owners;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ owners = [NSMapTable weakToWeakObjectsMapTable]; });
    return owners;
}
static BOOL WCTopIsOurs(UIView *view) {
    return [view isKindOfClass:WCGestureChatTopCapsuleView.class]
        || [NSStringFromClass(view.class) isEqualToString:@"WCGestureGlassCapsuleView"];
}
static WCTopBackgroundState *WCTopSnapshot(WCTopBarState *state, UIView *view) {
    WCTopBackgroundState *saved = [state.backgrounds objectForKey:view];
    if (!saved) {
        saved = [WCTopBackgroundState new]; saved.view = view;
        saved.hidden = view.hidden; saved.alpha = view.alpha; saved.color = view.backgroundColor;
        saved.clips = view.clipsToBounds; saved.border = view.layer.borderWidth; saved.corner = view.layer.cornerRadius;
        if ([view isKindOfClass:UIVisualEffectView.class]) saved.effect = ((UIVisualEffectView *)view).effect;
        [state.backgrounds setObject:saved forKey:view];
    }
    return saved;
}
static void WCTopClearHost(WCTopBarState *state, UIView *view, BOOL geometry) {
    if (!view || WCTopIsOurs(view)) return;
    WCTopBackgroundState *saved = WCTopSnapshot(state, view); saved.changed |= 2;
    if (![view.backgroundColor isEqual:UIColor.clearColor]) view.backgroundColor = UIColor.clearColor;
    if (geometry) {
        saved.changed |= 4;
        view.clipsToBounds = NO; view.layer.borderWidth = 0; view.layer.cornerRadius = 0;
    }
}
static BOOL WCTopHasContent(UIView *view, NSUInteger depth) {
    if (WCTopIsOurs(view) || [view isKindOfClass:UIControl.class] || [view isKindOfClass:UILabel.class]) return YES;
    if (depth > 6) return NO;
    NSString *name = NSStringFromClass(view.class);
    if ([name containsString:@"BarContent"] || [name containsString:@"NavigationBarContent"]) return YES;
    for (UIView *child in view.subviews) if (WCTopHasContent(child, depth + 1)) return YES;
    return NO;
}
static BOOL WCTopIsBackground(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    return [view isKindOfClass:UIVisualEffectView.class] || [name containsString:@"Background"]
        || [name containsString:@"Backdrop"] || [name containsString:@"Material"];
}
static void WCTopRemoveBackground(WCTopBarState *state, UIView *view) {
    if (!view || WCTopIsOurs(view)) return;
    WCTopClearHost(state, view, NO);
    WCTopBackgroundState *saved = WCTopSnapshot(state, view);
    if ([view isKindOfClass:UIVisualEffectView.class]) {
        saved.changed |= 8;
        if (((UIVisualEffectView *)view).effect) ((UIVisualEffectView *)view).effect = nil;
    }
    if (!WCTopHasContent(view, 0)) {
        saved.changed |= 1; view.hidden = YES; view.alpha = 0;
    }
}
static void WCTopScopeBackgrounds(WCTopBarState *state, UIView *view, NSUInteger depth) {
    if (!view || depth > 6 || WCTopIsOurs(view)) return;
    if (WCTopIsBackground(view)) WCTopRemoveBackground(state, view);
    for (UIView *child in view.subviews) WCTopScopeBackgrounds(state, child, depth + 1);
}
static void WCTopClearPrivateLayers(WCTopBarState *state, UIView *view, NSUInteger depth) {
    if (!view || depth > 5 || [NSStringFromClass(view.class) containsString:@"Expand"] || WCTopIsOurs(view) || [view isKindOfClass:UIControl.class] || [view isKindOfClass:UILabel.class]) return;
    WCTopClearHost(state, view, NO);
    if (WCTopIsBackground(view)) WCTopRemoveBackground(state, view);
    for (UIView *child in view.subviews) WCTopClearPrivateLayers(state, child, depth + 1);
}
static void WCTopPrivateBackgrounds(WCTopBarState *state, UIView *view, NSUInteger depth, NSUInteger *budget) {
    if (!view || depth > 8 || !*budget) return;
    (*budget)--;
    NSString *name = NSStringFromClass(view.class);
    if ([name isEqualToString:@"MMNewMsgContentNavBar"] || [name isEqualToString:@"MMMsgContentNavBar"]) {
        WCTopClearHost(state, view, YES);
        WCTopClearPrivateLayers(state, view, 0);
        return;
    }
    for (UIView *child in view.subviews) WCTopPrivateBackgrounds(state, child, depth + 1, budget);
}
static void WCTopApplyBackgrounds(WCTopBarState *state, UIViewController *controller) {
    UINavigationBar *bar = controller.navigationController.navigationBar;
    if (!bar) return;
    UIViewController *previous = [WCTopBarOwners() objectForKey:bar];
    if (previous && previous != controller) WCGestureChatTopBarRestore(previous);
    if (!state.navigationAppearances) {
        state.navigationBar = bar;
        NSMutableArray *saved = [NSMutableArray arrayWithArray:@[bar.standardAppearance, bar.scrollEdgeAppearance ?: NSNull.null,
            bar.compactAppearance ?: NSNull.null]];
        if (@available(iOS 15.0, *)) [saved addObject:bar.compactScrollEdgeAppearance ?: NSNull.null];
        state.navigationAppearances = saved; state.translucent = bar.translucent;
    }
    [WCTopBarOwners() setObject:controller forKey:bar];
    if (bar.standardAppearance.backgroundEffect || ![bar.standardAppearance.backgroundColor isEqual:UIColor.clearColor]
        || (bar.scrollEdgeAppearance && (bar.scrollEdgeAppearance.backgroundEffect || ![bar.scrollEdgeAppearance.backgroundColor isEqual:UIColor.clearColor]))
        || (bar.compactAppearance && (bar.compactAppearance.backgroundEffect || ![bar.compactAppearance.backgroundColor isEqual:UIColor.clearColor]))) {
        bar.standardAppearance = controller.navigationItem.standardAppearance;
        bar.scrollEdgeAppearance = controller.navigationItem.scrollEdgeAppearance;
        bar.compactAppearance = controller.navigationItem.compactAppearance;
        if (@available(iOS 15.0, *)) bar.compactScrollEdgeAppearance = controller.navigationItem.compactScrollEdgeAppearance;
    }
    if (!bar.translucent) bar.translucent = YES;
    WCTopClearHost(state, bar, YES); WCTopClearHost(state, bar.superview, YES);
    WCTopScopeBackgrounds(state, bar, 0);
    for (UIView *child in bar.subviews) if (!WCTopHasContent(child, 0)) WCTopRemoveBackground(state, child);
    UIView *navigationRoot = controller.navigationController.view;
    UIView *host = bar;
    for (NSUInteger depth = 0; host && depth < 4; depth++, host = host.superview) {
        WCTopClearHost(state, host, NO);
        if (host == navigationRoot) break;
        for (UIView *sibling in host.superview.subviews)
            if (sibling != host && WCTopIsBackground(sibling)) WCTopRemoveBackground(state, sibling);
    }
    NSUInteger budget = 400;
    WCTopPrivateBackgrounds(state, controller.view, 0, &budget);
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
    UINavigationBar *bar = state.navigationBar;
    if (bar && [WCTopBarOwners() objectForKey:bar] == controller) {
        NSArray *savedBar = state.navigationAppearances;
        bar.standardAppearance = savedBar[0];
        bar.scrollEdgeAppearance = savedBar[1] == NSNull.null ? nil : savedBar[1];
        bar.compactAppearance = savedBar[2] == NSNull.null ? nil : savedBar[2];
        if (@available(iOS 15.0, *)) bar.compactScrollEdgeAppearance = savedBar[3] == NSNull.null ? nil : savedBar[3];
        bar.translucent = state.translucent;
        [WCTopBarOwners() removeObjectForKey:bar];
        for (WCTopBackgroundState *background in state.backgrounds.objectEnumerator) {
            UIView *view = background.view;
            if (background.changed & 1) { view.hidden = background.hidden; view.alpha = background.alpha; }
            if (background.changed & 2) view.backgroundColor = background.color;
            if (background.changed & 4) { view.clipsToBounds = background.clips; view.layer.borderWidth = background.border; view.layer.cornerRadius = background.corner; }
            if ((background.changed & 8) && [view isKindOfClass:UIVisualEffectView.class]) ((UIVisualEffectView *)view).effect = background.effect;
        }
    }
    objc_setAssociatedObject(controller, &WCTopBarStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCTopUpdate(UIViewController *controller, BOOL preparing) {
    [WCTopControllers() addObject:controller];
    if (!WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey) || WCGestureChatSearchIsActive(controller)) {
        WCGestureChatTopBarRestore(controller); return;
    }
    BOOL multiSelect = [WCTweakSafeValue(controller, @"isMultiSelectMode") boolValue]
        || [WCTweakSafeValue(controller, @"isInMultiSelectMsg") boolValue];
    if (multiSelect) {
        WCGestureChatTopBarRestore(controller); return;
    }
    if (!controller.isViewLoaded) return;
    // WCAtlas installs the item before the view enters a window. Only later repairs require visibility.
    if (!preparing && (!controller.view.window || controller.navigationController.topViewController != controller)) return;
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
        [state.profile setAvatarView:userName.length ? WCGestureContactUncroppedAvatarView(userName) : [UIView new]];
    }
    NSString *fallback = item.title ?: controller.title ?: @"聊天";
    if ([fallback containsString:@"正在输入"]) fallback = state.stableName ?: @"聊天";
    NSString *name = WCGesturePrivateContactDisplayName(contact, fallback);
    state.stableName = name;
    BOOL search = WCGestureEnabled(WCGestureChatSearchEnabledKey);
    CGFloat totalWidth = CGRectGetWidth(controller.navigationController.navigationBar.bounds);
    if (totalWidth < 1) totalWidth = CGRectGetWidth(controller.view.bounds);
    NSUInteger extras = (state.left.count > 1 ? state.left.count - 1 : 0) + (state.right.count > 1 ? state.right.count - 1 : 0);
    CGFloat scale = WCGestureChatTopBarScale();
    CGFloat shell = WCGestureChatTopBarShellFactor();
    CGFloat maxLeft = MIN(205 * scale * shell, MAX(0, totalWidth - WCGestureChatTopBarActionsWidth(search) - 48 - 44 * extras));
    CGSize leftSize = [state.profile configureWithName:name typing:state.typing search:NO moreImage:nil menu:nil maximumWidth:maxLeft];
    UIBarButtonItem *more = state.right.firstObject;
    CGSize rightSize = [state.actions configureWithName:@"" typing:NO search:search moreImage:more.image menu:more.menu maximumWidth:WCGestureChatTopBarActionsWidth(search)];
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
    // A preloaded chat may prepare its own item, but must not change another screen's shared bar.
    if (controller.navigationController.topViewController == controller) WCTopApplyBackgrounds(state, controller);
    [state.profile layoutIfNeeded];
    [state.actions layoutIfNeeded];
    state.updating = NO;
}

void WCGestureChatTopBarUpdate(UIViewController *controller) {
    WCTopUpdate(controller, NO);
}

void WCGestureChatTopBarPrepareAppearance(UIViewController *controller) {
    [UIView performWithoutAnimation:^{ WCTopUpdate(controller, YES); }];
}

void WCGestureChatTopBarWillDisappear(UIViewController *controller) {
    // Keep the capsule through the outgoing animation, as WCAtlas does. Search restores it before opening.
    if (!objc_getAssociatedObject(controller, &WCTopBarStateKey)) return;
    __weak UIViewController *weakController = controller;
    [controller.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        UIViewController *target = weakController;
        if (!target) return;
        if (context.isCancelled) WCGestureChatTopBarPrepareAppearance(target);
        else WCGestureChatTopBarRestore(target);
    }];
}

void WCGestureChatTopBarTitleChanged(UIViewController *controller, id titleView) {
    WCGestureGroupTitleLayout(controller);
    WCTopBarState *state = objc_getAssociatedObject(controller, &WCTopBarStateKey);
    if (state && [titleView isKindOfClass:UIView.class] && titleView != state.placeholder) {
        state.title = titleView;
        state.typing = WCTopTyping(titleView, 0);
    }
    WCGestureChatTopBarUpdate(controller);
}

void WCGestureChatTopBarNavigationLayout(UINavigationBar *bar) {
    UIViewController *controller = [WCTopBarOwners() objectForKey:bar];
    if (!controller) return;
    WCTopBarState *state = objc_getAssociatedObject(controller, &WCTopBarStateKey);
    // Clear native background replacements during this layout, before the frame is rendered.
    if (state && !state.updating && controller.navigationController.topViewController == controller
        && WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey) && !WCGestureChatSearchIsActive(controller)) {
        state.updating = YES;
        WCTopApplyBackgrounds(state, controller);
        state.updating = NO;
    }
    if ([objc_getAssociatedObject(bar, &WCTopBarPendingKey) boolValue]) return;
    objc_setAssociatedObject(bar, &WCTopBarPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UINavigationBar *weakBar = bar;
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationBar *target = weakBar;
        if (!target) return;
        objc_setAssociatedObject(target, &WCTopBarPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIViewController *owner = weakController;
        if (owner && [WCTopBarOwners() objectForKey:target] == owner) WCGestureChatTopBarUpdate(owner);
    });
}

void WCGestureChatTopBarSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureChatSearchEnabledKey]
        && ![key hasPrefix:@"com.qiu7c.onewx.chat.top-bar-capsule."]
        && ![key isEqualToString:WCGesturePageScaleEnabledKey] && ![key isEqualToString:WCGesturePageScalePercentKey]) return;
    WCGestureChatPinnedRefresh();
    for (UIViewController *controller in WCTopControllers().allObjects) {
        if (controller.isViewLoaded && controller.view.window) WCGestureChatSearchUpdate(controller);
        else WCGestureChatTopBarRestore(controller);
    }
}
