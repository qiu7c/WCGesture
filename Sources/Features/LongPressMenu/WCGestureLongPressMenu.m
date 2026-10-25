#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCLongPressOriginalTitleKey;

static NSArray<NSString *> *WCLongPressStringList(NSString *key) {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
    if (![stored isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:stored.count];
    for (id item in stored) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *value = [(NSString *)item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length > 0) [values addObject:value];
    }
    return values;
}

static NSString *WCLongPressSourceTitle(id item) {
    NSString *stored = objc_getAssociatedObject(item, &WCLongPressOriginalTitleKey);
    if (stored.length > 0) return stored;
    SEL titleSelector = sel_registerName("title");
    id value = nil;
    if ([item respondsToSelector:titleSelector]) {
        value = ((id (*)(id, SEL))objc_msgSend)(item, titleSelector);
    } else {
        value = WCTweakSafeValue(item, @"title");
    }
    if (![value isKindOfClass:[NSString class]] || [value length] == 0) return nil;
    stored = [value copy];
    objc_setAssociatedObject(item, &WCLongPressOriginalTitleKey, stored, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return stored;
}

static void WCLongPressSetTitle(id item, NSString *title) {
    if (!item || title.length == 0) return;
    SEL selector = sel_registerName("setTitle:");
    if ([item respondsToSelector:selector]) {
        ((void (*)(id, SEL, NSString *))objc_msgSend)(item, selector, title);
    } else {
        WCTweakSetValue(item, @"title", title);
    }
}

NSArray *WCGestureManagedLongPressMenuItems(NSArray *items) {
    if (![items isKindOfClass:[NSArray class]]) return items;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *knownTitles = [[defaults arrayForKey:WCGestureLongPressMenuKnownTitlesKey] mutableCopy] ?: [NSMutableArray array];
    BOOL discoveredNewTitle = NO;
    for (id item in items) {
        NSString *sourceTitle = WCLongPressSourceTitle(item);
        if (sourceTitle.length > 0 && ![knownTitles containsObject:sourceTitle]) {
            [knownTitles addObject:sourceTitle];
            discoveredNewTitle = YES;
        }
    }
    if (discoveredNewTitle) {
        [defaults setObject:knownTitles forKey:WCGestureLongPressMenuKnownTitlesKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCGestureDidChangeNotification
                                                            object:WCGestureLongPressMenuKnownTitlesKey];
    }
    BOOL enabled = WCGestureEnabled(WCGestureLongPressMenuEnabledKey);
    for (id item in items) {
        NSString *sourceTitle = WCLongPressSourceTitle(item);
        if (!enabled && sourceTitle.length > 0) WCLongPressSetTitle(item, sourceTitle);
    }
    if (!enabled) return items;

    NSSet *hiddenTitles = [NSSet setWithArray:WCLongPressStringList(WCGestureLongPressMenuHiddenTitlesKey)];
    NSMutableArray *remaining = [NSMutableArray array];
    for (id item in items) {
        NSString *sourceTitle = WCLongPressSourceTitle(item);
        if (sourceTitle.length == 0 || ![hiddenTitles containsObject:sourceTitle]) [remaining addObject:item];
    }

    NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:remaining.count];
    for (NSString *preferredTitle in WCLongPressStringList(WCGestureLongPressMenuPreferredOrderKey)) {
        for (id item in [remaining copy]) {
            if ([WCLongPressSourceTitle(item) isEqualToString:preferredTitle]) {
                [ordered addObject:item];
                [remaining removeObjectIdenticalTo:item];
            }
        }
    }
    [ordered addObjectsFromArray:remaining];

    NSDictionary *mapping = [defaults dictionaryForKey:WCGestureLongPressMenuTitleMapKey];
    for (id item in ordered) {
        NSString *sourceTitle = WCLongPressSourceTitle(item);
        id renamedTitle = sourceTitle.length > 0 ? mapping[sourceTitle] : nil;
        WCLongPressSetTitle(item,
                          [renamedTitle isKindOfClass:[NSString class]] && [renamedTitle length] > 0
                              ? renamedTitle
                              : sourceTitle);
    }
    return ordered;
}


NSArray<NSString *> *WCGestureLongPressMenuTitles(void) {
    NSArray *known = WCLongPressStringList(WCGestureLongPressMenuKnownTitlesKey);
    NSArray *manual = WCLongPressStringList(WCGestureLongPressMenuManualTitlesKey);
    NSMutableArray *all = [NSMutableArray arrayWithArray:known];
    for (NSString *title in manual) if (![all containsObject:title]) [all addObject:title];
    NSMutableArray *ordered = [NSMutableArray array];
    for (NSString *title in WCLongPressStringList(WCGestureLongPressMenuPreferredOrderKey)) {
        if ([all containsObject:title] && ![ordered containsObject:title]) [ordered addObject:title];
    }
    for (NSString *title in all) if (![ordered containsObject:title]) [ordered addObject:title];
    return ordered;
}
