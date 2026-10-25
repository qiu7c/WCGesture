#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"

NSArray *WCGestureVoiceForwardMenuItems(UIView *cell, NSArray *items) {
    if (!WCGestureEnabled(WCGestureVoiceForwardEnabledKey) || ![items isKindOfClass:NSArray.class]) return items;
    for (id item in items) {
        NSString *title = [WCTweakSafeValue(item, @"title") description];
        if ([title containsString:@"转发"] || [title localizedCaseInsensitiveContainsString:@"forward"]) return items;
    }
    SEL selector = NSSelectorFromString(@"forwardMenuItem");
    if (![cell respondsToSelector:selector]) return items;
    id item = ((id (*)(id, SEL))objc_msgSend)(cell, selector);
    return item ? [items arrayByAddingObject:item] : items;
}

BOOL WCGestureVoiceForwardAllowsAction(SEL action) {
    return WCGestureEnabled(WCGestureVoiceForwardEnabledKey) &&
        (action == NSSelectorFromString(@"onForward:") || action == NSSelectorFromString(@"doForward") ||
         action == NSSelectorFromString(@"onClickForwardMenu:"));
}

static NSString *WCVoiceForwardSession(id contact) {
    if ([contact isKindOfClass:NSString.class] && [contact length]) return contact;
    return contact ? WCPrivateContactUserName(contact) : nil;
}

NSArray *WCGestureVoiceForwardMessages(NSArray *messages, NSArray *contacts, NSIndexSet **handledIndexes) {
    if (handledIndexes) *handledIndexes = nil;
    if (!WCGestureEnabled(WCGestureVoiceForwardEnabledKey) ||
        ![messages isKindOfClass:NSArray.class] || !messages.count ||
        ![contacts isKindOfClass:NSArray.class] || !contacts.count) return messages;
    NSMutableArray *remaining = [NSMutableArray arrayWithCapacity:messages.count];
    NSMutableIndexSet *handled = [NSMutableIndexSet indexSet];
    [messages enumerateObjectsUsingBlock:^(id message, NSUInteger index, BOOL *stop) {
        if ([WCTweakSafeValue(message, @"m_uiMessageType") integerValue] != 34) {
            [remaining addObject:message]; return;
        }
        BOOL sentToEveryContact = YES;
        for (id contact in contacts) {
            NSString *session = WCVoiceForwardSession(contact);
            if (!session.length || !WCGestureResendVoiceMessage(message, session)) {
                sentToEveryContact = NO; break;
            }
        }
        if (sentToEveryContact) [handled addIndex:index];
        else [remaining addObject:message];
    }];
    if (handledIndexes && handled.count) *handledIndexes = [handled copy];
    return remaining;
}

NSArray *WCGestureVoiceForwardFilteredOrigins(NSArray *origins, NSIndexSet *handledIndexes) {
    if (![origins isKindOfClass:NSArray.class] || !handledIndexes.count) return origins;
    NSMutableArray *remaining = [origins mutableCopy];
    [handledIndexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger index, BOOL *stop) {
        if (index < remaining.count) [remaining removeObjectAtIndex:index];
    }];
    return remaining;
}
