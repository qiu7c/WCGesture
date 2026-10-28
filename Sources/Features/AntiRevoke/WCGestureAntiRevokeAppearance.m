#import <math.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCRevokeLabelKey;
static char WCRevokeOriginalColorKey;
static char WCRevokeAppliedColorKey;

void WCGestureAntiRevokeStyleLabel(UILabel *label) {
    label.font = [UIFont systemFontOfSize:10.5];
    label.text = [NSUserDefaults.standardUserDefaults stringForKey:WCGestureAntiRevokeSideTextKey];
    if (!label.text.length) label.text = @"已拦截撤回";
    label.textColor = WCGestureDynamicColorForDefaultsKeys(WCGestureAntiRevokeSideLightTextColorKey,
        WCGestureAntiRevokeSideDarkTextColorKey, WCGestureAntiRevokeSideTextColorKey,
        UIColor.tertiaryLabelColor, UIColor.tertiaryLabelColor);
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    label.userInteractionEnabled = NO;
}

CGRect WCGestureAntiRevokeSideFrame(CGRect bounds, CGRect bubble, BOOL sender, CGSize size) {
    if (CGRectIsEmpty(bubble) || CGRectIsInfinite(bubble)) return CGRectZero;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    double offsetX = [defaults doubleForKey:WCGestureAntiRevokeSideOffsetXKey];
    double offsetY = [defaults doubleForKey:WCGestureAntiRevokeSideOffsetYKey];
    if (!isfinite(offsetX)) offsetX = 0;
    if (!isfinite(offsetY)) offsetY = 10;
    CGFloat gap = 7;
    CGFloat available = sender ? CGRectGetMinX(bubble) - gap - 4 : CGRectGetWidth(bounds) - CGRectGetMaxX(bubble) - gap - 4;
    if (available < 36) return CGRectZero;
    CGFloat width = MIN(MIN(160, MAX(36, size.width + 8)), available);
    CGFloat height = 18;
    CGFloat x = sender ? CGRectGetMinX(bubble) - width - gap + offsetX : CGRectGetMaxX(bubble) + gap - offsetX;
    CGFloat minimumX = sender ? 4 : CGRectGetMaxX(bubble) + gap;
    CGFloat maximumX = sender ? CGRectGetMinX(bubble) - gap - width : CGRectGetWidth(bounds) - width - 4;
    x = MIN(MAX(minimumX, x), MAX(minimumX, maximumX));
    CGFloat y = CGRectGetMidY(bubble) - height / 2 + offsetY;
    y = MIN(MAX(0, y), MAX(0, CGRectGetHeight(bounds) - height));
    return CGRectIntegral(CGRectMake(x, y, width, height));
}

void WCGestureAntiRevokeHide(UIView *cell) {
    UILabel *label = objc_getAssociatedObject(cell, &WCRevokeLabelKey);
    label.hidden = YES;
    label.text = nil;
}

void WCGestureAntiRevokeLayout(UIView *cell) {
    if (!NSThread.isMainThread) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id model = WCTweakSafeValue(cell, @"viewModel") ?: WCTweakSafeValue(cell, @"m_viewModel");
    if (!cell.window || !WCGestureEnabled(WCGestureAntiRevokeEnabledKey) ||
        [defaults integerForKey:WCGestureAntiRevokePromptStyleKey] != 1 ||
        !WCGestureShouldShowSplitMessageMetadata(model, NO)) {
        WCGestureAntiRevokeHide(cell);
        return;
    }
    NSString *prompt = WCGestureAntiRevokeSidePromptForMessage(WCGestureMessageWrapForCell(cell));
    UIView *anchor = WCGestureMessageSideAnchorView(cell);
    if (!prompt.length || !anchor) { WCGestureAntiRevokeHide(cell); return; }
    CGRect frame = [anchor convertRect:anchor.bounds toView:cell];
    if (CGRectIsEmpty(frame) || CGRectIsInfinite(frame) ||
        !CGRectIntersectsRect(frame, CGRectInset(cell.bounds, -80, -80))) {
        WCGestureAntiRevokeHide(cell);
        return;
    }
    UILabel *label = objc_getAssociatedObject(cell, &WCRevokeLabelKey);
    if (!label) {
        label = [UILabel new];
        label.accessibilityIdentifier = @"com.qiu7c.onewx.anti-revoke.side-label";
        objc_setAssociatedObject(cell, &WCRevokeLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (label.superview != cell) [cell addSubview:label];
    WCGestureAntiRevokeStyleLabel(label);
    label.text = prompt;
    BOOL sender = [WCTweakSafeValue(model, @"isSender") boolValue];
    CGRect target = WCGestureAntiRevokeSideFrame(cell.bounds, frame, sender, [label sizeThatFits:CGSizeMake(160, 18)]);
    UILabel *time = WCGestureVisibleMessageTimeSideLabel(cell);
    if (time && !CGRectIsEmpty(target) && CGRectIntersectsRect(CGRectInset(target, -2, -2), time.frame)) {
        CGFloat below = CGRectGetMaxY(time.frame) + 2;
        CGFloat above = CGRectGetMinY(time.frame) - target.size.height - 2;
        if (below + target.size.height <= CGRectGetHeight(cell.bounds)) target.origin.y = below;
        else if (above >= 0) target.origin.y = above;
        else target = CGRectZero;
    }
    label.frame = target;
    label.hidden = CGRectIsEmpty(target);
    [cell bringSubviewToFront:label];
}

void WCGestureAntiRevokeSystemCellLayout(UIView *cell) {
    id richText = WCTweakSafeValue(cell, @"m_richTextView");
    if (!richText) return;
    BOOL apply = WCGestureEnabled(WCGestureAntiRevokeEnabledKey) &&
        WCGestureAntiRevokeIsLocalPromptMessage(WCGestureMessageWrapForCell(cell));
    NSDictionary *original = objc_getAssociatedObject(richText, &WCRevokeOriginalColorKey);
    UIColor *applied = objc_getAssociatedObject(richText, &WCRevokeAppliedColorKey);
    // Ordinary native tips are untouched unless this label still holds a color
    // previously applied by us. textColor and oTextColor have separate baselines.
    if (!apply) {
        if (!original) return;
        for (NSString *key in @[@"textColor", @"oTextColor"]) {
            id saved=original[key];
            if (saved && [WCTweakSafeValue(richText,key) isEqual:applied])
                WCTweakSetValue(richText,key,saved==NSNull.null?nil:saved);
        }
        objc_setAssociatedObject(richText,&WCRevokeOriginalColorKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(richText,&WCRevokeAppliedColorKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    NSMutableDictionary *baseline=[original mutableCopy] ?: [NSMutableDictionary dictionary];
    for (NSString *key in @[@"textColor", @"oTextColor"]) {
        id current=WCTweakSafeValue(richText,key);
        if (!original || ![current isEqual:applied]) baseline[key]=current ?: NSNull.null;
    }
    UIColor *color=WCGestureDynamicColorForDefaultsKeys(WCGestureAntiRevokeLocalLightTextColorKey,
        WCGestureAntiRevokeLocalDarkTextColorKey, WCGestureAntiRevokeLocalTextColorKey,
        UIColor.secondaryLabelColor, UIColor.secondaryLabelColor);
    objc_setAssociatedObject(richText,&WCRevokeOriginalColorKey,baseline,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(richText,&WCRevokeAppliedColorKey,color,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCTweakSetValue(richText,@"textColor",color);
    WCTweakSetValue(richText,@"oTextColor",color);
}

void WCGestureAntiRevokeSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.chat.anti-revoke."]) return;
    if (!key || [key isEqualToString:WCGestureAntiRevokePersistRecordsKey]) {
        WCGestureAntiRevokeSetPersistenceEnabled([NSUserDefaults.standardUserDefaults boolForKey:WCGestureAntiRevokePersistRecordsKey]);
    }
    UIWindow *window = WCActiveWindow();
    if (!window) return;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
    Class common = NSClassFromString(@"CommonMessageCellView");
    Class system = NSClassFromString(@"SystemMessageCellView");
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (common && [view isKindOfClass:common]) {
            WCGestureMessageTimeLayout(view);
            WCGestureAntiRevokeLayout(view);
        }
        if (system && [view isKindOfClass:system]) WCGestureAntiRevokeSystemCellLayout(view);
        [stack addObjectsFromArray:view.subviews];
    }
}
