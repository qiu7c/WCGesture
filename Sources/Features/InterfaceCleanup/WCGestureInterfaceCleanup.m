#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCGroupLabelHiddenKey;
static NSHashTable<UILabel *> *WCGroupLabels(void) {
    static NSHashTable *labels;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ labels = [NSHashTable weakObjectsHashTable]; });
    return labels;
}

BOOL WCGestureShouldHideMeEntry(NSString *title) {
    NSDictionary *keys = @{ @"作品": WCGestureHideMeFinderKey, @"小店与卡包": WCGestureHideMeCardsKey,
                            @"表情": WCGestureHideMeEmoticonsKey };
    NSString *key = keys[title];
    return key && WCGestureEnabled(key);
}

id WCGestureGroupMemberLabel(id label) {
    if (![label isKindOfClass:UILabel.class]) return label;
    UILabel *view = label;
    NSNumber *original = objc_getAssociatedObject(view, &WCGroupLabelHiddenKey);
    if (WCGestureEnabled(WCGestureHideGroupTitleTailKey)) {
        if (!original) objc_setAssociatedObject(view, &WCGroupLabelHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [WCGroupLabels() addObject:view];
        view.hidden = YES;
    } else if (original) {
        view.hidden = original.boolValue;
        objc_setAssociatedObject(view, &WCGroupLabelHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return label;
}

void WCGestureInterfaceCleanupSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureHideGroupTitleTailKey]) return;
    for (UILabel *label in WCGroupLabels().allObjects) WCGestureGroupMemberLabel(label);
    // WeChat rebuilds title-tail and Me-page sections when those pages reopen.
}
