#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCMessageTimeLabelKey;

void WCGestureMessageTimeStyleLabel(UILabel *label, NSDate *date) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *format = [defaults stringForKey:WCGestureMessageTimeFormatKey];
    if (![@[@"HH:mm", @"HH:mm:ss", @"MM-dd HH:mm:ss"] containsObject:format]) format = @"HH:mm:ss";
    // All label updates run on the main thread, including the preview.
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    });
    formatter.timeZone = NSTimeZone.localTimeZone;
    formatter.dateFormat = format;
    double size = [defaults doubleForKey:WCGestureMessageTimeFontSizeKey];
    if (!isfinite(size)) size = 10.0;
    CGFloat weight = [defaults boolForKey:WCGestureMessageTimeBoldKey] ? UIFontWeightSemibold : UIFontWeightRegular;
    label.font = [UIFont systemFontOfSize:MIN(16.0, MAX(8.0, size)) weight:weight];
    label.textColor = UIColor.secondaryLabelColor;
    label.text = [formatter stringFromDate:date];
    label.numberOfLines = 1;
    label.userInteractionEnabled = NO;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
}

CGRect WCGestureMessageTimeSideFrame(CGRect bounds, CGRect bubble, BOOL sender, CGSize size) {
    if (CGRectIsEmpty(bounds) || CGRectIsEmpty(bubble) || CGRectIsInfinite(bubble) ||
        !isfinite(bubble.origin.x) || !isfinite(bubble.origin.y) ||
        !isfinite(bubble.size.width) || !isfinite(bubble.size.height)) return CGRectZero;
    CGFloat gap = 5.0;
    CGFloat available = sender ? CGRectGetMinX(bubble) - CGRectGetMinX(bounds) - gap - 2.0
        : CGRectGetMaxX(bounds) - CGRectGetMaxX(bubble) - gap - 2.0;
    // Long messages can fill the row. Hide rather than overlap the bubble.
    if (available < 40.0 || CGRectGetHeight(bounds) < size.height) return CGRectZero;
    CGFloat width = MIN(size.width + 4.0, available);
    CGFloat x = sender ? CGRectGetMinX(bubble) - width - gap : CGRectGetMaxX(bubble) + gap;
    NSInteger position = [NSUserDefaults.standardUserDefaults integerForKey:WCGestureMessageTimePositionKey];
    CGFloat y = CGRectGetMaxY(bubble) - size.height;
    if (position == 0) y = CGRectGetMinY(bubble);
    else if (position == 1) y = CGRectGetMidY(bubble) - size.height / 2.0;
    y = MIN(MAX(CGRectGetMinY(bounds), y), CGRectGetMaxY(bounds) - size.height);
    return CGRectMake(x, y, width, size.height);
}

static id WCMessageTimeModel(UIView *cell) {
    return WCTweakSafeValue(cell, @"viewModel") ?: WCTweakSafeValue(cell, @"m_viewModel");
}

static UIView *WCMessageTimeBubble(UIView *cell) {
    // Both getters exist in the supplied 8.0.79 headers. Some media cells
    // have no visible bubble background, so use their native content view.
    for (NSString *name in @[@"getBgImageView", @"getContentView"]) {
        SEL selector = NSSelectorFromString(name);
        if (![cell respondsToSelector:selector]) continue;
        id view = ((id (*)(id, SEL))objc_msgSend)(cell, selector);
        if (![view isKindOfClass:UIView.class]) continue;
        UIView *bubble = view;
        if (!bubble.hidden && bubble.alpha > 0.01 && !CGRectIsEmpty(bubble.bounds) &&
            [bubble isDescendantOfView:cell]) return bubble;
    }
    return nil;
}

void WCGestureMessageTimeHide(UIView *cell) {
    UILabel *label = objc_getAssociatedObject(cell, &WCMessageTimeLabelKey);
    label.hidden = YES;
    label.text = nil;
}

void WCGestureMessageTimeLayout(UIView *cell) {
    if (!NSThread.isMainThread) return;
    if (!cell.window || !WCGestureEnabled(WCGestureMessageTimeEnabledKey)) {
        WCGestureMessageTimeHide(cell);
        return;
    }
    id model = WCMessageTimeModel(cell);
    id parent = WCTweakSafeValue(model, @"parentModel");
    if ([NSStringFromClass([model class]) containsString:@"TextMessageSubViewModel"]) {
        NSArray *parts = WCTweakSafeValue(parent, @"subViewModels");
        id tail = WCTweakSafeValue(model, @"isTailPart");
        if (([parts isKindOfClass:NSArray.class] && parts.count > 1 && parts.lastObject != model) ||
            (tail && ![tail boolValue])) {
            WCGestureMessageTimeHide(cell);
            return;
        }
    }
    id message = WCGestureMessageWrapForCell(cell);
    id rawTime = WCTweakSafeValue(message, @"m_uiCreateTime");
    NSTimeInterval timestamp = [rawTime respondsToSelector:@selector(doubleValue)] ? [rawTime doubleValue] : 0;
    UIView *bubble = WCMessageTimeBubble(cell);
    if (!isfinite(timestamp) || timestamp <= 0 || !bubble) {
        WCGestureMessageTimeHide(cell);
        return;
    }
    UILabel *label = objc_getAssociatedObject(cell, &WCMessageTimeLabelKey);
    if (!label) {
        label = [UILabel new];
        label.accessibilityIdentifier = @"com.qiu7c.onewx.message-time";
        [cell addSubview:label];
        objc_setAssociatedObject(cell, &WCMessageTimeLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (label.superview != cell) [cell addSubview:label];
    WCGestureMessageTimeStyleLabel(label, [NSDate dateWithTimeIntervalSince1970:timestamp]);
    id senderValue = WCTweakSafeValue(model, @"isSender");
    NSString *from = WCTweakSafeValue(message, @"m_nsFromUsr");
    BOOL sender = senderValue ? [senderValue boolValue] : [from isEqualToString:WCCurrentUserWXID()];
    CGRect frame = [bubble convertRect:bubble.bounds toView:cell];
    label.frame = WCGestureMessageTimeSideFrame(cell.bounds, frame, sender, [label sizeThatFits:CGSizeMake(160, 24)]);
    label.hidden = CGRectIsEmpty(label.frame);
}

void WCGestureMessageTimeSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.chat.message-time."]) return;
    UIWindow *window = WCActiveWindow();
    if (!window) return;
    Class cellClass = NSClassFromString(@"CommonMessageCellView");
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (cellClass && [view isKindOfClass:cellClass]) WCGestureMessageTimeLayout(view);
        [stack addObjectsFromArray:view.subviews];
    }
}
