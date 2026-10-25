#import <objc/message.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

NSArray *WCGesturePrivateContactList(void) {
    id manager = WCServiceForClass(NSClassFromString(@"CContactMgr"));
    SEL selector = NSSelectorFromString(@"getContactList:contactType:");
    NSMethodSignature *signature = [manager methodSignatureForSelector:selector];
    if (![manager respondsToSelector:selector] || signature.numberOfArguments != 4
        || signature.methodReturnType[0] != '@'
        || strcmp([signature getArgumentTypeAtIndex:2], @encode(unsigned int)) != 0
        || strcmp([signature getArgumentTypeAtIndex:3], @encode(unsigned int)) != 0) return @[];
    @try {
        id value = ((id (*)(id, SEL, unsigned int, unsigned int))objc_msgSend)(manager, selector, 1, 0);
        if (![value conformsToProtocol:@protocol(NSFastEnumeration)] || [value isKindOfClass:NSString.class]) return @[];
        NSMutableArray *contacts = [NSMutableArray array];
        for (id contact in value) if (contact) [contacts addObject:contact];
        return contacts;
    } @catch (__unused NSException *exception) { return @[]; }
}

static NSString *WCContactsName(id contact, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = WCTweakSafeValue(contact, key);
        if (![value isKindOfClass:NSString.class]) continue;
        NSString *name = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length) return name;
    }
    return nil;
}

NSString *WCGesturePrivateContactDisplayName(id contact, NSString *fallback) {
    return WCContactsName(contact, @[@"m_nsRemark", @"getRemark", @"remark", @"remarkName",
        @"getContactDisplayName", @"getDisplayName", @"m_nsNickName", @"getNickName", @"nickName", @"nickname"])
        ?: (fallback ?: @"");
}

NSString *WCGesturePrivateNotificationDisplayName(NSString *username, NSString *fallback) {
    id contact = username.length ? WCPrivateContact(username) : nil;
    NSArray *remarkKeys = @[@"m_nsRemark", @"getRemark", @"remark", @"remarkName"];
    NSString *remark = WCContactsName(contact, remarkKeys);
    if (remark.length) return remark;
    id listContact = nil;
    if (username.length) for (id candidate in WCGesturePrivateContactList()) {
        if ([candidate isKindOfClass:NSString.class]) continue;
        NSString *alias = WCContactsName(candidate, @[@"m_nsAliasName", @"m_nsAlias", @"getAlias", @"alias", @"aliasName"]);
        if ([WCPrivateContactUserName(candidate) isEqualToString:username] || [alias isEqualToString:username]) {
            listContact = candidate;
            break;
        }
    }
    remark = WCContactsName(listContact, remarkKeys);
    if (remark.length) return remark;
    NSString *name = WCGesturePrivateContactDisplayName(contact, nil);
    if (!name.length) name = WCGesturePrivateContactDisplayName(listContact, nil);
    return name.length ? name : (fallback.length ? fallback : (username ?: @""));
}

UIView *WCGestureContactAvatarView(NSString *username) {
    id contact = WCPrivateContact(username);
    NSString *url = WCContactsName(contact, @[@"m_nsHeadHDImgUrl", @"m_nsHeadImgUrlHD", @"m_nsHeadImgUrl"]) ?: @"";
    Class helper = NSClassFromString(@"MMHeadImageHelper");
    for (NSString *name in @[@"getContactHeadImageViewWithUsrName:headImgUrl:bAutoUpdate:bRoundCorner:",
                            @"getMainFrameHeadImageViewWithUsrName:headImgUrl:bAutoUpdate:bRoundCorner:"]) {
        SEL selector = NSSelectorFromString(name);
        NSMethodSignature *signature = [helper methodSignatureForSelector:selector];
        if (![helper respondsToSelector:selector] || signature.numberOfArguments != 6
            || signature.methodReturnType[0] != '@' || [signature getArgumentTypeAtIndex:2][0] != '@'
            || [signature getArgumentTypeAtIndex:3][0] != '@'
            || !strchr("BcCsSiIlLqQ", [signature getArgumentTypeAtIndex:4][0])
            || !strchr("BcCsSiIlLqQ", [signature getArgumentTypeAtIndex:5][0])) continue;
        @try {
            id view = ((id (*)(id, SEL, id, id, BOOL, BOOL))objc_msgSend)(helper, selector, username, url, YES, YES);
            if ([view isKindOfClass:UIView.class]) return view;
        } @catch (__unused NSException *exception) {}
    }
    UIView *view = [UIView new];
    view.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    return view;
}
