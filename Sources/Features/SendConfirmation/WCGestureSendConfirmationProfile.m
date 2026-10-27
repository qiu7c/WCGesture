#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCSendProfileCellKey, WCSendProfileAccountKey, WCSendProfileTargetKey, WCSendProfileGroupKey, WCSendProfileReloadKey;
static NSHashTable *WCSendProfileOwners(void) {
    static NSHashTable *owners; static dispatch_once_t once;
    dispatch_once(&once, ^{ owners = [NSHashTable weakObjectsHashTable]; });
    return owners;
}
static id WCSendProfileValue(id object, NSArray *keys) {
    for (NSString *key in keys) { id value = WCTweakSafeValue(object, key); if (value && value != NSNull.null) return value; }
    return nil;
}
static NSArray *WCSendProfileArray(id object, NSString *key) {
    id value = WCTweakSafeValue(object, key);
    return [value isKindOfClass:NSArray.class] ? value : @[];
}
static NSString *WCSendProfileUsername(id owner, BOOL group) {
    return WCPrivateContactUserName(WCSendProfileValue(owner, group
        ? @[@"m_chatRoomContact", @"chatRoomContact", @"m_contact", @"contact"]
        : @[@"m_contact", @"contact", @"contactInfo", @"m_contactInfo"]));
}
void WCGestureSendConfirmationProfileApply(id owner, BOOL group) {
    if (!owner) return;
    [WCSendProfileOwners() addObject:owner];
    objc_setAssociatedObject(owner, &WCSendProfileGroupKey, @(group), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id table = WCSendProfileValue(owner, @[@"m_tableViewInfo", @"tableViewInfo", @"m_tableViewMgr", @"tableViewMgr"]);
    NSArray *sections = WCSendProfileArray(table, @"getAllSections");
    if (!sections.count) return;
    NSString *target = WCSendProfileUsername(owner, group);
    NSString *account = WCRefreshCachedCurrentUser() ? WCCurrentUserWXID() : nil;
    BOOL enabled = account.length && target.length && WCGestureEnabled(WCGestureSendConfirmationEnabledKey) &&
        WCGestureEnabled(WCGestureSendConfirmationProfileSwitchEnabledKey) &&
        !WCGestureEnabled(WCGestureContactInfoCardEnabledKey);
    BOOL selected = [WCGestureSendConfirmationProtectedConversations() containsObject:target ?: @""];
    NSString *fingerprint = [NSString stringWithFormat:@"%@\n%@\n%d", account ?: @"", target ?: @"", selected];
    objc_setAssociatedObject(owner, &WCSendProfileAccountKey, account, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(owner, &WCSendProfileTargetKey, target, OBJC_ASSOCIATION_COPY_NONATOMIC);
    BOOL found = NO, changed = NO;
    id memberSection = group ? WCTweakSafeValue(owner, @"memListSection") : nil;
    id preferred = nil;
    for (id section in sections) {
        BOOL validSection = !group || sections.count == 1 || (section != sections.firstObject && section != memberSection);
        if (!preferred && validSection) preferred = section;
        NSArray *cells = WCSendProfileArray(section, @"getAllCells");
        for (NSUInteger index = cells.count; index > 0; index--) {
            id cell = cells[index - 1];
            NSString *marker = objc_getAssociatedObject(cell, &WCSendProfileCellKey);
            if (!marker) continue;
            if (enabled && !found && validSection && [marker isEqualToString:fingerprint]) { found = YES; continue; }
            SEL remove = NSSelectorFromString(@"removeCellAt:");
            if ([section respondsToSelector:remove]) {
                ((void (*)(id, SEL, unsigned long long))objc_msgSend)(section, remove, (unsigned long long)(index - 1)); changed = YES;
            }
        }
    }
    if (enabled && !found && preferred) {
        Class factoryClass = NSClassFromString(@"WCTableViewCellManager");
        SEL factory = NSSelectorFromString(@"switchCellForSel:target:title:on:");
        SEL add = NSSelectorFromString(@"addCell:");
        if ([factoryClass respondsToSelector:factory] && [preferred respondsToSelector:add]) {
            id cell = ((id (*)(id, SEL, SEL, id, id, BOOL))objc_msgSend)(factoryClass, factory,
                NSSelectorFromString(@"wc_toggleConversationSendConfirmation:"), owner, group ? @"本群发送前确认" : @"对其发送前确认", selected);
            if (cell) {
                objc_setAssociatedObject(cell, &WCSendProfileCellKey, fingerprint, OBJC_ASSOCIATION_COPY_NONATOMIC);
                ((void (*)(id, SEL, id))objc_msgSend)(preferred, add, cell); changed = YES;
            }
        }
    }
    if (changed && ![objc_getAssociatedObject(table, &WCSendProfileReloadKey) boolValue]) {
        objc_setAssociatedObject(table, &WCSendProfileReloadKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak id weakTable = table;
        dispatch_async(dispatch_get_main_queue(), ^{
            id current = weakTable;
            objc_setAssociatedObject(current, &WCSendProfileReloadKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            id view = WCSendProfileValue(current, @[@"getTableView", @"tableView", @"m_tableView"]);
            if ([view isKindOfClass:UITableView.class]) [view reloadData];
        });
    }
}
void WCGestureSendConfirmationProfileToggle(id owner, UISwitch *sender) {
    NSString *account = objc_getAssociatedObject(owner, &WCSendProfileAccountKey);
    NSString *target = objc_getAssociatedObject(owner, &WCSendProfileTargetKey);
    BOOL group = [objc_getAssociatedObject(owner, &WCSendProfileGroupKey) boolValue];
    if (!WCRefreshCachedCurrentUser() || ![account isEqualToString:WCCurrentUserWXID()] ||
        ![target isEqualToString:WCSendProfileUsername(owner, group)]) {
        [sender setOn:!sender.on animated:YES]; WCShowToast(@"资料已变化，请重新进入后设置"); return;
    }
    WCGestureSendConfirmationSetProtected(target, sender.on);
}
void WCGestureSendConfirmationRefreshProfiles(void) {
    for (id owner in WCSendProfileOwners().allObjects)
        WCGestureSendConfirmationProfileApply(owner, [objc_getAssociatedObject(owner, &WCSendProfileGroupKey) boolValue]);
}
