#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"
NSString *WCGestureLocalChatSession(id controller) {
    id contact = WCTweakValueForSelectorNames(controller, @[@"GetContact", @"getContact"]);
    return contact ? (WCPrivateContactUserName(contact) ?: @"") : @"";
}
NSString *WCGestureLocalChatIdentity(UIView *cell) {
    id wrap = WCGestureMessageWrapForCell(cell); NSString *account = WCCurrentUserWXID();
    NSString *session = WCGestureLocalChatSession(WCViewControllerForResponder(cell));
    unsigned long long local = [WCTweakSafeValue(wrap,@"m_uiMesLocalID") unsignedLongLongValue];
    long long server = [WCTweakSafeValue(wrap,@"m_n64MesSvrID") longLongValue];
    if (!wrap || !account.length || !session.length || (!local && !server)) return @"";
    return [NSString stringWithFormat:@"%@|%@|%llu|%lld|%@",account,session,local,server,WCTweakSafeValue(wrap,@"m_uiMessageType") ?: @0];
}
id WCGestureLocalChatMenuItem(UIView *cell, NSString *title, NSString *symbol, SEL action) {
    Class cls = NSClassFromString(@"MMMenuItem"); SEL init = @selector(initWithTitle:icon:target:action:);
    if (![cls instancesRespondToSelector:init]) return nil;
    UIImage *icon = [[UIImage systemImageNamed:symbol] imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    return [[cls alloc] initWithTitle:title icon:icon target:cell action:action];
}
void WCGestureLocalChatRefreshCell(UIView *cell) {
    if (!cell) return;
    id model = WCTweakSafeValue(cell,@"viewModel");
    SEL reset = NSSelectorFromString(@"resetLayoutCache");
    Class textClass = NSClassFromString(@"TextMessageViewModel");
    BOOL textModel = textClass && [model isKindOfClass:textClass];
    if (textModel) {
        @try { if ([model respondsToSelector:reset]) ((void (*)(id,SEL))objc_msgSend)(model,reset); }
        @catch (__unused NSException *exception) {}
        for (NSString *key in @[@"m_contentText",@"m_contentPatternText",@"m_subViewModels"]) WCTweakSetValue(model,key,nil);
        WCTweakSetValue(model,@"m_isShouldLayout",@YES);
    }
    SEL update = NSSelectorFromString(@"updateLayouts");
    @try { if ([model respondsToSelector:update]) ((void (*)(id,SEL))objc_msgSend)(model,update); }
    @catch (__unused NSException *exception) {}
    @try { if (textModel && [cell respondsToSelector:reset]) ((void (*)(id,SEL))objc_msgSend)(cell,reset); }
    @catch (__unused NSException *exception) {}
    [cell setNeedsLayout];
    UITableView *table = nil;
    for (UIView *v=cell.superview;v;v=v.superview) if ([v isKindOfClass:UITableView.class]) { table=(UITableView *)v;break; }
    if (table && !table.hasUncommittedUpdates) [UIView performWithoutAnimation:^{ [table beginUpdates];[table endUpdates]; }];
    if (cell.window) [cell layoutIfNeeded];
}
