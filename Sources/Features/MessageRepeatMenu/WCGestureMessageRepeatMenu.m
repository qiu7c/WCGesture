#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCRepeatMenuItemKey;

BOOL WCGestureMessageCanRepeat(UIView *cell) {
    if (!WCGestureEnabled(WCGestureMessageRepeatMenuEnabledKey)) return NO;
    id message = WCGestureMessageWrapForCell(cell);
    if (!message) return NO;
    NSInteger type = [WCTweakSafeValue(message, @"m_uiMessageType") integerValue];
    if (type == 34) {
        id path = WCTweakValueForSelectorNames(message, @[@"getVoicePath"]);
        return [path isKindOfClass:NSString.class] && [path length] && [NSFileManager.defaultManager fileExistsAtPath:path];
    }
    Class utility = NSClassFromString(@"ForwardMsgUtil");
    SEL selector = NSSelectorFromString(@"canBeForwardWithMsg:");
    if ([utility respondsToSelector:selector]) return ((BOOL (*)(id, SEL, id))objc_msgSend)(utility, selector, message);
    return type == 1 && [WCTweakSafeValue(message, @"m_nsContent") length] > 0;
}

NSArray *WCGestureRepeatMenuItems(UIView *cell, NSArray *items) {
    if (![items isKindOfClass:NSArray.class] || !WCGestureMessageCanRepeat(cell)) return items;
    for (id item in items) if ([objc_getAssociatedObject(item, &WCRepeatMenuItemKey) boolValue] || [WCTweakSafeValue(item, @"title") isEqualToString:@"+1"]) return items;
    Class cls = NSClassFromString(@"MMMenuItem");
    if (![cls instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) return items;
    UIImage *icon = [[UIImage systemImageNamed:@"plus.message"] imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    id item = [[cls alloc] initWithTitle:@"+1" icon:icon target:cell action:NSSelectorFromString(@"wc_repeatMenuMessage:")];
    if (!item) return items;
    objc_setAssociatedObject(item, &WCRepeatMenuItemKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *result = [items mutableCopy]; [result insertObject:item atIndex:0]; return result;
}

void WCGestureRepeatMenuPerform(UIView *cell) {
    if (!cell.window || !WCGestureMessageCanRepeat(cell)) return;
    if (!WCGestureRepeatMessage((CommonMessageCellView *)cell)) WCShowToast(@"这条消息暂时无法复读");
}
