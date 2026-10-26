#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

static char WCInfoCardGroupKey;
static char WCInfoCardCellKey;
static char WCInfoCardReloadKey;

static NSHashTable *WCInfoOwners(void) {
    static NSHashTable *owners;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ owners = [NSHashTable weakObjectsHashTable]; });
    return owners;
}
static id WCInfoValue(id object, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = WCTweakSafeValue(object, key);
        if (value && value != NSNull.null) return value;
    }
    return nil;
}
static NSString *WCInfoText(id object, NSArray<NSString *> *keys) {
    id value = WCInfoValue(object, keys);
    return [value isKindOfClass:NSString.class] ? value : @"";
}
static void WCInfoAdd(NSMutableArray *rows, NSString *title, id value) {
    if (![value isKindOfClass:NSString.class]) return;
    NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length) [rows addObject:@{@"title":title, @"value":text}];
}
static NSArray<NSString *> *WCInfoList(id value) {
    NSArray *parts = [value isKindOfClass:NSString.class] ? [value componentsSeparatedByCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@";,|"]] : ([value isKindOfClass:NSArray.class] ? value : @[]);
    NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSet];
    for (id part in parts) {
        NSString *name = [part isKindOfClass:NSString.class] ? part : WCPrivateContactUserName(part);
        name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length) [names addObject:name];
    }
    return names.array;
}
static id WCInfoContact(id owner, BOOL group) {
    return WCInfoValue(owner, group ? @[@"m_chatRoomContact", @"chatRoomContact", @"m_contact", @"contact"]
        : @[@"m_contact", @"contact", @"contactInfo", @"m_contactInfo"]);
}
static NSArray *WCInfoRows(id contact, BOOL group, NSString *roomName) {
    NSMutableArray *rows = [NSMutableArray array];
    NSString *userName = WCPrivateContactUserName(contact);
    WCInfoAdd(rows, group ? @"原始群号码" : @"原始号码", userName);
    WCInfoAdd(rows, group ? @"群聊名称" : @"昵称", WCInfoText(contact, @[@"m_nsNickName", @"getNickName"]));
    WCInfoAdd(rows, @"备注", WCInfoText(contact, @[@"m_nsRemark", @"getRemark"]));
    WCInfoAdd(rows, @"微信号", WCInfoText(contact, @[@"m_nsAliasName", @"m_nsAlias"]));
    id room = group ? contact : ([roomName hasSuffix:@"@chatroom"] ? WCPrivateContact(roomName) : nil);
    if (!group) {
        WCInfoAdd(rows, @"个性签名", WCInfoText(contact, @[@"m_nsSignature"]));
        NSMutableArray *region = [NSMutableArray array];
        for (NSString *key in @[@"m_nsCountry", @"m_nsProvince", @"m_nsCity"]) {
            NSString *value = WCInfoText(contact, @[key]);
            if (value.length && ![region containsObject:value]) [region addObject:value];
        }
        WCInfoAdd(rows, @"地区", [region componentsJoinedByString:@" · "]);
        NSInteger sex = [WCTweakSafeValue(contact, @"m_uiSex") integerValue];
        if (sex == 1 || sex == 2) WCInfoAdd(rows, @"性别", sex == 1 ? @"男" : @"女");
        NSTimeInterval timestamp = [WCTweakSafeValue(contact, @"m_uiAddCreateTime") doubleValue];
        if (timestamp > 0 && timestamp <= NSDate.date.timeIntervalSince1970) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
            NSDateFormatter *formatter = [NSDateFormatter new]; formatter.dateFormat = @"yyyy-MM-dd HH:mm";
            WCInfoAdd(rows, @"添加时间", [formatter stringFromDate:date]);
            NSInteger days = [NSCalendar.currentCalendar components:NSCalendarUnitDay fromDate:date toDate:NSDate.date options:0].day;
            WCInfoAdd(rows, @"添加天数", [NSString stringWithFormat:@"%ld 天", (long)days]);
        }
    }
    if (room) {
        if (!group) WCInfoAdd(rows, @"所在群聊", roomName);
        NSString *owner = WCInfoText(room, @[@"m_nsChatRoomOwner", @"m_nsOwner", @"ownerUserName"]);
        NSArray *admins = WCInfoList(WCInfoValue(room, @[@"m_nsChatRoomAdminList", @"m_nsAdminList", @"adminList"]));
        if (group) {
            WCInfoAdd(rows, @"群主", owner);
            WCInfoAdd(rows, @"管理员", [admins componentsJoinedByString:@"、"]);
            id rawMembers = WCInfoValue(room, @[@"m_nsChatRoomMemList"]);
            if (!rawMembers) rawMembers = WCInfoValue(WCInfoValue(room, @[@"m_ChatRoomData"]), @[@"m_nsChatRoomMemList"]);
            // XML member lists are parsed below rather than counted as delimited usernames.
            NSArray *members = WCInfoList(rawMembers);
            if ([rawMembers isKindOfClass:NSString.class] && [rawMembers containsString:@"<"]) {
                NSMutableSet *xmlMembers = [NSMutableSet set];
                NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"(?is)<(?:userId|username)>\\s*(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?\\s*</(?:userId|username)>" options:0 error:nil];
                for (NSTextCheckingResult *match in [expression matchesInString:rawMembers options:0 range:NSMakeRange(0, [rawMembers length])]) {
                    NSString *member = [rawMembers substringWithRange:[match rangeAtIndex:1]];
                    if (member.length) [xmlMembers addObject:member];
                }
                members = xmlMembers.allObjects;
            }
            if (members.count) WCInfoAdd(rows, @"群成员", [NSString stringWithFormat:@"%lu 人", (unsigned long)members.count]);
            WCInfoAdd(rows, @"群简介", WCInfoText(room, @[@"groupSummary"]));
            WCInfoAdd(rows, @"群链接", WCInfoText(room, @[@"groupURL"]));
        } else {
            SEL display = NSSelectorFromString(@"getChatRoomMemberDisplayName:");
            NSMethodSignature *signature = [room methodSignatureForSelector:display];
            if (signature.numberOfArguments == 3 && signature.methodReturnType[0] == '@' && [signature getArgumentTypeAtIndex:2][0] == '@') {
                WCInfoAdd(rows, @"群昵称", ((id (*)(id, SEL, id))objc_msgSend)(room, display, contact));
            }
            if (owner.length || admins.count) WCInfoAdd(rows, @"群身份", [owner isEqualToString:userName] ? @"群主" : ([admins containsObject:userName] ? @"管理员" : @"群成员"));
        }
    }
    return rows;
}

static id WCInfoTable(id owner) {
    return WCInfoValue(owner, @[@"m_tableViewInfo", @"tableViewInfo", @"m_tableViewMgr", @"tableViewMgr"]);
}
static NSArray *WCInfoArray(id object, NSString *key) {
    id value = WCTweakSafeValue(object, key);
    return [value isKindOfClass:NSArray.class] ? value : @[];
}
static BOOL WCInfoCompatible(id object, SEL selector, char result, const char *arguments) {
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    NSUInteger count = strlen(arguments);
    if (signature.numberOfArguments != count + 2 || signature.methodReturnType[0] != result) return NO;
    for (NSUInteger index = 0; index < count; index++)
        if ([signature getArgumentTypeAtIndex:index + 2][0] != arguments[index]) return NO;
    return YES;
}
static void WCInfoReload(id table) {
    if ([objc_getAssociatedObject(table, &WCInfoCardReloadKey) boolValue]) return;
    objc_setAssociatedObject(table, &WCInfoCardReloadKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak id weakTable = table;
    dispatch_async(dispatch_get_main_queue(), ^{
        id target = weakTable;
        objc_setAssociatedObject(target, &WCInfoCardReloadKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id view = WCInfoValue(target, @[@"getTableView", @"tableView", @"m_tableView"]);
        if ([view isKindOfClass:UITableView.class]) [view reloadData];
    });
}

void WCGestureContactInfoCardApply(id owner, BOOL group) {
    [WCInfoOwners() addObject:owner];
    objc_setAssociatedObject(owner, &WCInfoCardGroupKey, @(group), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id table = WCInfoTable(owner);
    NSArray *sections = WCInfoArray(table, @"getAllSections");
    BOOL enabled = WCGestureEnabled(WCGestureContactInfoCardEnabledKey);
    BOOL found = NO, changed = NO;
    id preferred = sections.firstObject;
    unsigned int insertIndex = 0;
    for (id section in sections) {
        NSArray *cells = [WCInfoArray(section, @"getAllCells") copy];
        for (NSUInteger i = cells.count; i > 0; i--) {
            id cell = cells[i - 1];
            if ([objc_getAssociatedObject(cell, &WCInfoCardCellKey) boolValue]) {
                if (enabled && !found) { found = YES; continue; }
                SEL remove = NSSelectorFromString(@"removeCellAt:");
                if (WCInfoCompatible(section, remove, 'v', "Q")) {
                    ((void (*)(id, SEL, unsigned long long))objc_msgSend)(section, remove, (unsigned long long)(i - 1)); changed = YES;
                }
            } else {
                NSString *title = WCInfoText(cell, @[@"title", @"m_title"]);
                if ([title containsString:@"微信号"] || [title containsString:@"群聊名称"]) { preferred = section; insertIndex = (unsigned int)i; }
            }
        }
    }
    if (enabled && !found && preferred && WCPrivateContactUserName(WCInfoContact(owner, group)).length) {
        Class factoryClass = NSClassFromString(@"WCTableViewCellManager");
        SEL factory = NSSelectorFromString(@"normalCellForSel:target:title:rightValue:");
        if (WCInfoCompatible(factoryClass, factory, '@', ":@@@") && WCInfoCompatible(preferred, NSSelectorFromString(@"insertCell:At:"), 'v', "@I")) {
            id cell = ((id (*)(id, SEL, SEL, id, id, id))objc_msgSend)(factoryClass, factory,
                NSSelectorFromString(@"wc_openContactInfoCard"), owner, @"资料信息", @"查看");
            if (cell) {
                objc_setAssociatedObject(cell, &WCInfoCardCellKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                ((void (*)(id, SEL, id, unsigned int))objc_msgSend)(preferred, NSSelectorFromString(@"insertCell:At:"), cell, insertIndex);
                changed = YES;
            }
        }
    }
    if (changed) WCInfoReload(table);
}

void WCGestureContactInfoCardOpen(id owner) {
    if (!WCGestureEnabled(WCGestureContactInfoCardEnabledKey)) return;
    BOOL group = [objc_getAssociatedObject(owner, &WCInfoCardGroupKey) boolValue];
    id contact = WCInfoContact(owner, group);
    NSString *userName = WCPrivateContactUserName(contact);
    if (!userName.length) return;
    NSString *room = WCInfoText(owner, @[@"m_nsChatRoomUserName", @"sessionUserName"]);
    if (!room.length) room = WCInfoText(contact, @[@"m_nsChatRoomUserName", @"sessionUserName"]);
    if (!room.length) {
        NSString *candidateRoom = WCPrivateContactUserName(WCInfoValue(owner, @[@"m_chatContact", @"m_chatRoomContact"]));
        if ([candidateRoom hasSuffix:@"@chatroom"]) room = candidateRoom;
    }
    UIViewController *presenter = [owner isKindOfClass:UIViewController.class] ? owner : nil;
    id candidate = WCInfoValue(owner, @[@"m_contactInfoViewController", @"contactInfoViewController", @"m_viewController", @"viewController", @"m_delegate", @"delegate"]);
    if (!presenter && [candidate isKindOfClass:UIViewController.class]) presenter = candidate;
    if (!presenter) presenter = WCRootTopController();
    if (!presenter.view.window || presenter.presentedViewController || presenter.isBeingDismissed) return;
    NSMutableArray *rows = [WCInfoRows(contact, group, room) mutableCopy];
    if (!group) {
        id related = WCInfoValue(owner, @[@"m_relatedGroupLogic"]);
        id groups = WCInfoValue(related, @[@"_arrRelatedGroup"]);
        if ([groups isKindOfClass:NSArray.class] && ([groups count] || [WCTweakSafeValue(related, @"_bSearchDone") boolValue]))
            WCInfoAdd(rows, @"共同群聊", [NSString stringWithFormat:@"%lu 个", (unsigned long)[groups count]]);
    }
    UIViewController *card = WCGestureCreateContactInfoCard(group ? @"群聊资料" : ([room hasSuffix:@"@chatroom"] ? @"群成员资料" : @"好友资料"),
        WCGesturePrivateContactDisplayName(contact, userName), userName, rows);
    [presenter presentViewController:card animated:YES completion:nil];
}
void WCGestureContactInfoCardSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureContactInfoCardEnabledKey]) return;
    for (id owner in WCInfoOwners().allObjects)
        WCGestureContactInfoCardApply(owner, [objc_getAssociatedObject(owner, &WCInfoCardGroupKey) boolValue]);
}
