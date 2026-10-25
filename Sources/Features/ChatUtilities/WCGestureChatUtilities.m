#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCChatSearchItemKey;
static NSHashTable<UIViewController *> *WCChatSearchControllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}

void WCGestureChatSearchUpdate(UIViewController *controller) {
    [WCChatSearchControllers() addObject:controller];
    UIBarButtonItem *installed = objc_getAssociatedObject(controller, &WCChatSearchItemKey);
    NSMutableArray *items = [controller.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
    BOOL enabled = WCGestureEnabled(WCGestureChatSearchEnabledKey) && [controller respondsToSelector:NSSelectorFromString(@"onSearchButton:")];
    if (!enabled) {
        if (!installed) return;
        [items removeObjectIdenticalTo:installed];
        controller.navigationItem.rightBarButtonItems = items;
        objc_setAssociatedObject(controller, &WCChatSearchItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (installed && [items containsObject:installed]) return;
    if (!installed) {
        installed = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"] style:UIBarButtonItemStylePlain
            target:controller action:NSSelectorFromString(@"wc_openChatSearch:")];
        installed.accessibilityLabel = @"搜索聊天记录";
        objc_setAssociatedObject(controller, &WCChatSearchItemKey, installed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [items addObject:installed]; controller.navigationItem.rightBarButtonItems = items;
}

void WCGestureChatSearchOpen(UIViewController *controller, id sender) {
    SEL selector = NSSelectorFromString(@"onSearchButton:");
    if (WCGestureEnabled(WCGestureChatSearchEnabledKey) && [controller respondsToSelector:selector])
        ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, sender);
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
    for (UIViewController *controller in WCChatSearchControllers().allObjects) WCGestureChatSearchUpdate(controller);
}
