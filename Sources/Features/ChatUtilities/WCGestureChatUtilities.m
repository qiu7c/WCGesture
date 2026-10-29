#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

static char WCChatSearchItemKey;
static NSHashTable<UIViewController *> *WCChatSearchControllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}

static char WCChatSearchActiveKey;
static char WCChatSearchCleanupKey;
static char WCChatSearchEdgePanKey;
static char WCChatSearchOriginalPopKey;
static char WCChatSearchSessionKey;

static id WCChatSearchExactIvarValue(id object, NSString *name) {
    if (!object) return nil;
    Ivar ivar = class_getInstanceVariable([object class], name.UTF8String);
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    return type && type[0] == '@' ? object_getIvar(object, ivar) : nil;
}

static BOOL WCChatSearchMethodArgumentMatches(Method method, unsigned int index, const char *types) {
    if (!method || index >= method_getNumberOfArguments(method)) return NO;
    char type[32] = {0};
    method_getArgumentType(method, index, type, sizeof(type));
    const char *value = type;
    while (*value && strchr("rnNoORV", *value)) value++;
    return *value && strchr(types, *value) != NULL;
}
static BOOL WCChatSearchMethodArgumentIsIntegerScalar(Method method, unsigned int index) {
    return WCChatSearchMethodArgumentMatches(method, index, "cCsSiIlLqQB");
}
static BOOL WCChatSearchMethodArgumentIsObject(Method method, unsigned int index) {
    return WCChatSearchMethodArgumentMatches(method, index, "@");
}
static BOOL WCChatSearchMethodArgumentIsSelector(Method method, unsigned int index) {
    return WCChatSearchMethodArgumentMatches(method, index, ":");
}
static BOOL WCChatSearchMethodReturnsObject(Method method) {
    if (!method) return NO;
    char type[32] = {0};
    method_getReturnType(method, type, sizeof(type));
    return type[0] == '@';
}

static id WCChatSearchOfficialHost(BaseMsgContentViewController *controller) {
    if (!controller) return nil;
    UINavigationController *navigationController = controller.navigationController;
    return (!navigationController || navigationController.topViewController == controller)
        ? controller : nil;
}

static id WCChatSearchNativeHelper(BaseMsgContentViewController *controller,
                                 BOOL createIfMissing) {
    if (!controller) return nil;
    id helper = WCTweakSafeValue(controller, @"m_oMsgSearchHelper");
    if (!helper) helper = WCChatSearchExactIvarValue(controller, @"m_oMsgSearchHelper");
    if (helper || !createIfMissing) return helper;

    SEL selector = NSSelectorFromString(@"initMsgSearchHelper:");
    Method method = class_getInstanceMethod([controller class], selector);
    if (!method || ![controller respondsToSelector:selector] ||
        method_getNumberOfArguments(method) != 3 ||
        !WCChatSearchMethodArgumentIsIntegerScalar(method, 2)) return nil;
    @try {
        ((void (*)(id, SEL, int))objc_msgSend)(controller, selector, 0);
    } @catch (__unused NSException *exception) {
        return nil;
    }
    helper = WCTweakSafeValue(controller, @"m_oMsgSearchHelper");
    return helper ?: WCChatSearchExactIvarValue(controller, @"m_oMsgSearchHelper");
}

static id WCChatSearchNativeSearcher(id helper) {
    if (!helper) return nil;
    id searcher = WCTweakSafeValue(helper, @"searcher");
    if (!searcher) {
        SEL selector = NSSelectorFromString(@"getSearcher");
        if ([helper respondsToSelector:selector]) {
            searcher = ((id (*)(id, SEL))objc_msgSend)(helper, selector);
        }
    }
    return searcher ?: WCChatSearchExactIvarValue(helper, @"_searcher");
}

static UISearchController *WCChatSearchNativeController(id searcher) {
    id controller=WCTweakSafeValue(searcher,@"searchController");
    return [controller isKindOfClass:UISearchController.class]?controller:nil;
}

static void WCChatSearchSetInteractivePop(BaseMsgContentViewController *controller,
                                          BOOL enabled) {
    SEL selector = NSSelectorFromString(@"setM_bInteractivePopEnabled:");
    Method method = class_getInstanceMethod([controller class], selector);
    if (!method || ![controller respondsToSelector:selector] ||
        method_getNumberOfArguments(method) != 3 ||
        !WCChatSearchMethodArgumentIsIntegerScalar(method, 2)) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, selector, enabled);
}

static void WCChatSearchRemoveEdgePan(BaseMsgContentViewController *controller) {
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(controller, &WCChatSearchEdgePanKey);
    if (recognizer.view) [recognizer.view removeGestureRecognizer:recognizer];
    objc_setAssociatedObject(controller, &WCChatSearchEdgePanKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSArray<UIView *> *WCChatSearchOfficialChromeViews(id searcher) {
    if (!searcher) return @[];
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (NSString *key in @[@"searchBar", @"searchBarNotInSearcher", @"searchContainerView"]) {
        id value = WCTweakSafeValue(searcher, key);
        if ([value isKindOfClass:UIView.class] && ![views containsObject:value]) {
            [views addObject:value];
        }
    }
    UIView *root=WCChatSearchNativeController(searcher).viewIfLoaded;
    if (root && ![views containsObject:root]) [views addObject:root];
    return views;
}

static void WCChatSearchSetChromeHidden(id searcher, BOOL hidden) {
    for (UIView *view in WCChatSearchOfficialChromeViews(searcher)) {
        if (hidden) [view endEditing:YES];
        view.hidden = hidden;
        view.alpha = hidden ? 0.0 : 1.0;
        view.userInteractionEnabled = !hidden;
    }
}

static void WCChatSearchHideChrome(BaseMsgContentViewController *controller,
                                   id searcher) {
    if (!controller || !searcher) return;
    WCChatSearchSetChromeHidden(searcher, YES);
    UISearchController *native=WCChatSearchNativeController(searcher);
    // Only detach the searcher's own orphaned root, never a transition view
    // or shared navigation bar. Active presentation/pop remains UIKit-owned.
    if (!native.isActive && !native.presentingViewController
        && ![native.navigationController.viewControllers containsObject:native])
        [native.viewIfLoaded removeFromSuperview];
}

static void WCChatSearchCleanup(BaseMsgContentViewController *controller) {
    if (!controller || !objc_getAssociatedObject(controller, &WCChatSearchSessionKey) ||
        [objc_getAssociatedObject(controller, &WCChatSearchCleanupKey) boolValue]) return;
    id helper = WCChatSearchNativeHelper(controller, NO);
    id searcher = WCChatSearchNativeSearcher(helper);
    // viewWillAppear may run before the native pop animation finishes. The
    // final disappearance callback must still remove chrome restored by it.
    if (![objc_getAssociatedObject(controller, &WCChatSearchActiveKey) boolValue]) {
        UISearchController *native=WCChatSearchNativeController(searcher);
        if (native.isActive) native.active=NO;
        WCChatSearchHideChrome(controller,searcher);
        return;
    }
    objc_setAssociatedObject(controller, &WCChatSearchCleanupKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCChatSearchRemoveEdgePan(controller);

    WCChatSearchHideChrome(controller, searcher);
    SEL activeSelector = NSSelectorFromString(@"setActive:animated:completion:");
    SEL searchActiveSelector = NSSelectorFromString(@"isSeachActive");
    BOOL closedThroughSearcher = NO;
    if ([searcher respondsToSelector:activeSelector]) {
        // Presence of WCSearcher's active-state API means it owns dismissal.
        // If it already reports inactive, do not call MsgSearchHelper's
        // finishSearch a second time from viewWillAppear.
        closedThroughSearcher = YES;
        BOOL searchActive = YES;
        if ([searcher respondsToSelector:searchActiveSelector]) {
            searchActive = ((BOOL (*)(id, SEL))objc_msgSend)(searcher, searchActiveSelector);
        }
        if (searchActive) {
            @try {
                ((void (*)(id, SEL, BOOL, BOOL, id))objc_msgSend)(searcher, activeSelector,
                                                                 NO, NO, nil);
            } @catch (__unused NSException *exception) {
                closedThroughSearcher = NO;
            }
        }
    }
    SEL finishSelector = NSSelectorFromString(@"finishSearch");
    if (!closedThroughSearcher && [helper respondsToSelector:finishSelector]) {
        @try {
            ((void (*)(id, SEL))objc_msgSend)(helper, finishSelector);
        } @catch (__unused NSException *exception) {
        }
    }
    UISearchController *native=WCChatSearchNativeController(searcher);
    if (native.isActive) native.active=NO;
    WCChatSearchHideChrome(controller,searcher);
    NSNumber *originalPop = objc_getAssociatedObject(controller, &WCChatSearchOriginalPopKey);
    if (originalPop) WCChatSearchSetInteractivePop(controller, originalPop.boolValue);
    objc_setAssociatedObject(controller, &WCChatSearchOriginalPopKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCChatSearchActiveKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCChatSearchCleanupKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL WCChatSearchOpenNative(BaseMsgContentViewController *controller, id sender) {
    (void)sender;
    if ([objc_getAssociatedObject(controller, &WCChatSearchActiveKey) boolValue]) return YES;
    id searchHost = WCChatSearchOfficialHost(controller);
    if (!searchHost) return NO;

    // Reuse the current chat's helper so its session, search delegates and dismissal stay together.
    id helper = WCChatSearchNativeHelper(searchHost, YES);
    if (!helper) return NO;
    SEL panCancelSelector = NSSelectorFromString(@"setBUsePanCancelGesture:");
    if ([helper respondsToSelector:panCancelSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(helper, panCancelSelector, YES);
    }
    id searcher = WCChatSearchNativeSearcher(helper);

    WCChatSearchSetChromeHidden(searcher, NO);

    SEL pushSelector = NSSelectorFromString(@"pushSearchControllerWithCompletion:");
    SEL activeSelector = NSSelectorFromString(@"setActive:animated:completion:");
    if (![searcher respondsToSelector:pushSelector] &&
        ![searcher respondsToSelector:activeSelector]) return NO;
    NSNumber *originalPop = WCTweakSafeValue(controller, @"m_bInteractivePopEnabled");
    objc_setAssociatedObject(controller, &WCChatSearchOriginalPopKey, originalPop, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &WCChatSearchSessionKey, [NSObject new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCChatSearchSetInteractivePop(controller, NO);
    objc_setAssociatedObject(controller, &WCChatSearchActiveKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc]
        initWithTarget:controller action:NSSelectorFromString(@"wc_handleChatSearchEdgePan:")];
    edgePan.edges = UIRectEdgeLeft;
    [controller.view addGestureRecognizer:edgePan];
    objc_setAssociatedObject(controller, &WCChatSearchEdgePanKey, edgePan,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        if ([searcher respondsToSelector:pushSelector]) {
            ((void (*)(id, SEL, id))objc_msgSend)(searcher, pushSelector, nil);
        } else {
            ((void (*)(id, SEL, BOOL, BOOL, id))objc_msgSend)(searcher, activeSelector,
                                                             YES, NO, nil);
        }
    } @catch (__unused NSException *exception) {
        WCChatSearchCleanup(controller);
        return NO;
    }
    return YES;
}

static UIImage *WCChatSearchImage(void) {
    UIImage *image = [UIImage imageNamed:@"icons_outlined_search"];
    if (image) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(18, 18)];
        return [[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            [image drawInRect:CGRectMake(0, 0, 18, 18)];
        }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular]];
}

static UIBarButtonItem *WCChatSearchOfficialBarButton(BaseMsgContentViewController *controller) {
    Class utilityClass = NSClassFromString(@"MMUICommonUtil");
    SEL factorySelector = NSSelectorFromString(@"getBarButtonWithImageName:target:action:style:accessibility:");
    Method factoryMethod = utilityClass ? class_getClassMethod(utilityClass, factorySelector) : NULL;
    if (factoryMethod && method_getNumberOfArguments(factoryMethod) == 7 &&
        WCChatSearchMethodReturnsObject(factoryMethod) &&
        WCChatSearchMethodArgumentIsObject(factoryMethod, 2) &&
        WCChatSearchMethodArgumentIsObject(factoryMethod, 3) &&
        WCChatSearchMethodArgumentIsSelector(factoryMethod, 4) &&
        WCChatSearchMethodArgumentIsIntegerScalar(factoryMethod, 5) &&
        WCChatSearchMethodArgumentIsObject(factoryMethod, 6)) {
        id item = ((id (*)(id, SEL, id, id, SEL, NSUInteger, id))objc_msgSend)(
            utilityClass, factorySelector, @"icons_outlined_search", controller,
            NSSelectorFromString(@"wc_openChatSearch:"), 2, @"search");
        if ([item isKindOfClass:[UIBarButtonItem class]]) return item;
    }
    return [[UIBarButtonItem alloc] initWithImage:WCChatSearchImage()
                                            style:UIBarButtonItemStylePlain
                                           target:controller
                                           action:NSSelectorFromString(@"wc_openChatSearch:")];
}

BOOL WCGestureChatSearchIsActive(UIViewController *controller) {
    return [objc_getAssociatedObject(controller, &WCChatSearchActiveKey) boolValue];
}

void WCGestureChatSearchUpdate(UIViewController *controller) {
    [WCChatSearchControllers() addObject:controller];
    if (WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey)) {
        UIBarButtonItem *standalone = objc_getAssociatedObject(controller, &WCChatSearchItemKey);
        if (standalone) {
            NSMutableArray *native = [controller.navigationItem.rightBarButtonItems mutableCopy];
            [native removeObjectIdenticalTo:standalone];
            controller.navigationItem.rightBarButtonItems = native;
            objc_setAssociatedObject(controller, &WCChatSearchItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        WCGestureChatTopBarUpdate(controller);
        return;
    }
    WCGestureChatTopBarRestore(controller);
    UIBarButtonItem *installed = objc_getAssociatedObject(controller, &WCChatSearchItemKey);
    NSMutableArray *items = [controller.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
    BOOL enabled = WCGestureEnabled(WCGestureChatSearchEnabledKey) && !WCGestureChatSearchIsActive(controller);
    if (!enabled) {
        if (!installed) return;
        [items removeObjectIdenticalTo:installed];
        controller.navigationItem.rightBarButtonItems = items;
        objc_setAssociatedObject(controller, &WCChatSearchItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (installed) {
        installed.tintColor = UIColor.labelColor;
        installed.customView.tintColor = UIColor.labelColor;
    }
    if (installed && [items containsObject:installed]) return;
    if (!installed) {
        installed = WCChatSearchOfficialBarButton((BaseMsgContentViewController *)controller);
        if (!installed) return;
        installed.accessibilityLabel = @"搜索聊天记录";
        objc_setAssociatedObject(controller, &WCChatSearchItemKey, installed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    installed.tintColor = UIColor.labelColor;
    installed.customView.tintColor = UIColor.labelColor;
    [items addObject:installed]; controller.navigationItem.rightBarButtonItems = items;
}

void WCGestureChatSearchOpen(UIViewController *controller, id sender) {
    if (!WCGestureEnabled(WCGestureChatSearchEnabledKey)) return;
    WCGestureChatTopBarRestore(controller);
    if (!WCChatSearchOpenNative((BaseMsgContentViewController *)controller, sender)) {
        WCGestureChatSearchUpdate(controller);
        WCShowToast(@"当前微信版本暂不支持聊天记录搜索");
    }
}

void WCGestureChatSearchWillAppear(UIViewController *controller) {
    WCChatSearchCleanup((BaseMsgContentViewController *)controller);
    WCGestureChatSearchUpdate(controller);
}

void WCGestureChatSearchHandleEdgePan(UIViewController *controller, UIScreenEdgePanGestureRecognizer *recognizer) {
    if (recognizer.state != UIGestureRecognizerStateEnded
        || ![objc_getAssociatedObject(controller, &WCChatSearchActiveKey) boolValue]) return;
    UIView *view = recognizer.view ?: controller.view;
    if ([recognizer translationInView:view].x > 44 || [recognizer velocityInView:view].x > 260) {
        WCChatSearchCleanup((BaseMsgContentViewController *)controller);
    }
}

void WCGestureChatSearchDidDismiss(id owner) {
    for (BaseMsgContentViewController *controller in WCChatSearchControllers().allObjects) {
        id helper=WCChatSearchNativeHelper(controller, NO);
        if (helper!=owner && WCChatSearchNativeSearcher(helper)!=owner) continue;
        id session = objc_getAssociatedObject(controller, &WCChatSearchSessionKey);
        __weak BaseMsgContentViewController *weakController = controller;
        // Let the native dismissal finish before querying the searcher's active state.
        dispatch_async(dispatch_get_main_queue(), ^{
            BaseMsgContentViewController *target = weakController;
            if (target && objc_getAssociatedObject(target, &WCChatSearchSessionKey) == session) {
                UISearchController *native=WCChatSearchNativeController(WCChatSearchNativeSearcher(WCChatSearchNativeHelper(target,NO)));
                // Keep a cancelled return or an active results page intact.
                if ((native.presentingViewController && !native.isBeingDismissed)
                    || [native.navigationController.viewControllers containsObject:native]) return;
                WCChatSearchCleanup(target);
                WCGestureChatSearchUpdate(target);
            }
        });
    }
}

BOOL WCGestureJumpToReferencedMessage(UIView *cell) {
    if (!WCGestureEnabled(WCGestureQuoteJumpEnabledKey)) return NO;
    id message = WCGestureMessageWrapForCell(cell);
    id model = WCTweakValueForSelectorNames(cell, @[@"viewModel", @"_viewModel"]);
    id referenced = nil;
    for (id object in @[message ?: NSNull.null, model ?: NSNull.null, cell]) {
        if (object == NSNull.null) continue;
        for (NSString *key in @[@"referHostMsg", @"referingMessageWrap", @"replyingMessageWrap"]) {
            referenced = WCTweakSafeValue(object, key);
            if (referenced) break;
        }
        if (referenced) break;
    }
    if (!referenced) return NO;
    NSInteger type = [WCTweakSafeValue(referenced, @"m_uiMessageType") integerValue];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (type == 3 && ![defaults boolForKey:WCGestureQuoteJumpImageKey]) return NO;
    if ((type == 43 || type == 62) && ![defaults boolForKey:WCGestureQuoteJumpVideoKey]) return NO;
    UIViewController *controller = WCViewControllerForResponder(cell);
    // Use the owning chat only; never jump in a different visible conversation.
    while (controller && ![controller isKindOfClass:NSClassFromString(@"BaseMsgContentViewController")]) controller = controller.parentViewController;
    for (NSString *name in @[@"returnToOriginalMsg:", @"locateToMsg:"]) {
        SEL selector = NSSelectorFromString(name);
        if ([controller respondsToSelector:selector]) { ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, referenced); return YES; }
    }
    SEL fallback = NSSelectorFromString(@"onReturnToOriginalMsg");
    if ([cell respondsToSelector:fallback]) { ((void (*)(id, SEL))objc_msgSend)(cell, fallback); return YES; }
    return NO;
}

void WCGestureChatUtilitiesSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureChatSearchEnabledKey]) return;
    for (BaseMsgContentViewController *controller in WCChatSearchControllers().allObjects) {
        if (!WCGestureEnabled(WCGestureChatSearchEnabledKey)) WCChatSearchCleanup(controller);
        WCGestureChatSearchUpdate(controller);
    }
}
