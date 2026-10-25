#import "Sources/API/WCGestureInternal.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

static const void *WCGestureMessageTimeAvatarLabelKey = &WCGestureMessageTimeAvatarLabelKey;
static const void *WCGestureMessageTimeBubbleLabelKey = &WCGestureMessageTimeBubbleLabelKey;
static const void *WCGestureMessageTimeRefreshPendingKey = &WCGestureMessageTimeRefreshPendingKey;
static const void *WCGestureMessageTimeRefreshGenerationKey = &WCGestureMessageTimeRefreshGenerationKey;
static NSString *const WCGestureMessageTimeAvatarLabelIdentifier = @"com.qiu7c.onewx.message-time.avatar";
static NSString *const WCGestureMessageTimeBubbleLabelIdentifier = @"com.qiu7c.onewx.message-time.bubble";

static id WCGestureMessageTimeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id WCGestureMessageTimeFirstValue(id object, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = WCGestureMessageTimeValue(object, key);
        if (value) return value;
    }
    return nil;
}

static id WCGestureMessageTimeViewModel(UIView *cell) {
    return WCGestureMessageTimeFirstValue(cell, @[@"viewModel", @"m_viewModel"]);
}

static id WCGestureMessageTimeMessage(id viewModel) {
    id message = WCGestureMessageTimeFirstValue(viewModel, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
    if (message) return message;
    id parent = WCGestureMessageTimeValue(viewModel, @"parentModel");
    return WCGestureMessageTimeFirstValue(parent, @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
}

static NSString *WCGestureMessageTimeObjectString(id object, NSArray<NSString *> *keys) {
    id value = WCGestureMessageTimeFirstValue(object, keys);
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

/// Cell reuse can leave delayed layout work targeting a different message.
/// Use the same stable fields WeChatX validates (local/server ID, create time,
/// sender and recipient), with object identity only as a last-resort fallback.
static NSString *WCGestureMessageTimeIdentity(UIView *cell) {
    id viewModel = WCGestureMessageTimeViewModel(cell);
    id message = WCGestureMessageTimeMessage(viewModel);
    if (!viewModel || !message) return nil;
    NSString *localID = WCGestureMessageTimeObjectString(message, @[@"m_uiMesLocalID", @"localID"]);
    NSString *serverID = WCGestureMessageTimeObjectString(message, @[@"m_n64MesSvrID", @"svrID"]);
    NSString *createTime = WCGestureMessageTimeObjectString(message, @[@"m_uiCreateTime", @"createTime"]);
    NSString *fromUser = WCGestureMessageTimeObjectString(message, @[@"m_nsFromUsr", @"fromUsr"]);
    NSString *toUser = WCGestureMessageTimeObjectString(message, @[@"m_nsToUsr", @"toUsr"]);
    if (localID.length == 0 && serverID.length == 0 && createTime.length == 0) {
        return [NSString stringWithFormat:@"vm:%p|msg:%p",
                (__bridge void *)viewModel, (__bridge void *)message];
    }
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
            localID ?: @"", serverID ?: @"", createTime ?: @"",
            fromUser ?: @"", toUser ?: @""];
}

static BOOL WCGestureMessageTimeIdentityMatches(UIView *cell, NSString *expectedIdentity) {
    NSString *currentIdentity = WCGestureMessageTimeIdentity(cell);
    return currentIdentity == expectedIdentity || [currentIdentity isEqualToString:expectedIdentity];
}

static NSTimeInterval WCGestureMessageTimeCreateTime(id message, id viewModel) {
    for (id object in @[message ?: NSNull.null, viewModel ?: NSNull.null]) {
        if (object == NSNull.null) continue;
        id value = WCGestureMessageTimeFirstValue(object, @[@"m_uiCreateTime", @"createTime"]);
        NSTimeInterval time = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
        if (isfinite(time) && time > 0) return time;
    }
    return 0;
}

static UIView *WCGestureMessageTimeDescendant(UIView *root, BOOL (^matches)(UIView *view)) {
    if (!root || !matches) return nil;
    for (UIView *subview in root.subviews) {
        if (matches(subview)) return subview;
        UIView *nested = WCGestureMessageTimeDescendant(subview, matches);
        if (nested) return nested;
    }
    return nil;
}

static UIView *WCGestureMessageTimeAvatarView(UIView *cell) {
    SEL selector = NSSelectorFromString(@"getHeadImageView");
    if ([cell respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(cell, selector);
        if ([value isKindOfClass:UIView.class] && ![value isHidden]) return value;
    }
    UIView *avatar = WCGestureMessageTimeDescendant(cell, ^BOOL(UIView *candidate) {
        return [NSStringFromClass(candidate.class) containsString:@"MMHeadImageView"];
    });
    return avatar.hidden ? nil : avatar;
}

static BOOL WCGestureMessageTimeAnchorIsUsable(id value) {
    if (![value isKindOfClass:UIView.class]) return NO;
    UIView *view = value;
    return !view.hidden && view.alpha > 0.01 && CGRectGetWidth(view.bounds) > 1.0 && CGRectGetHeight(view.bounds) > 1.0;
}

static BOOL WCGestureMessageTimeFrameIsUsable(CGRect frame, CGRect cellBounds) {
    if (CGRectIsNull(frame) || CGRectIsInfinite(frame) || CGRectIsEmpty(frame)) return NO;
    if (!isfinite(CGRectGetMinX(frame)) || !isfinite(CGRectGetMinY(frame)) ||
        !isfinite(CGRectGetWidth(frame)) || !isfinite(CGRectGetHeight(frame))) return NO;
    return CGRectIntersectsRect(frame, CGRectInset(cellBounds, -80.0, -80.0));
}

BOOL WCGestureShouldShowSplitMessageMetadata(id viewModel, BOOL preferHeadPart) {
    if (!viewModel) return NO;
    Class splitClass = NSClassFromString(@"TextMessageSubViewModel");
    BOOL isSplitModel = splitClass ? [viewModel isKindOfClass:splitClass]
                                   : [NSStringFromClass([viewModel class]) isEqualToString:@"TextMessageSubViewModel"];
    if (!isSplitModel) return YES;

    id parentModel = WCGestureMessageTimeValue(viewModel, @"parentModel");
    id value = WCGestureMessageTimeValue(parentModel, @"subViewModels");
    if ([value isKindOfClass:NSArray.class]) {
        NSArray *subViewModels = value;
        if (subViewModels.count > 1) {
            NSUInteger index = [subViewModels indexOfObjectIdenticalTo:viewModel];
            if (index != NSNotFound) {
                return preferHeadPart ? index == 0 : index == subViewModels.count - 1;
            }
        }
    }

    // Version fallback used by WeChat's long-split models when the parent
    // collection is unavailable during an intermediate layout pass.
    NSString *partKey = preferHeadPart ? @"isHeadPart" : @"isTailPart";
    id partValue = WCGestureMessageTimeValue(viewModel, partKey);
    return partValue ? [partValue boolValue] : YES;
}

static void WCGestureMessageTimeRemoveDuplicateLabels(UIView *cell,
                                                     NSString *identifier,
                                                     UILabel *preferred) {
    if (!cell || identifier.length == 0) return;
    // WCGesture owns these labels and always attaches them directly to the cell.
    // A direct scan keeps this safe to run from every layoutSubviews pass.
    for (UIView *subview in cell.subviews.copy) {
        if (subview != preferred && [subview isKindOfClass:UILabel.class] &&
            [subview.accessibilityIdentifier isEqualToString:identifier]) {
            [subview removeFromSuperview];
        }
    }
}

UIView *WCGestureMessageSideAnchorView(UIView *cell) {
    if (!cell) return nil;
    SEL selector = NSSelectorFromString(@"getBgImageView");
    if ([cell respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(cell, selector);
        if (WCGestureMessageTimeAnchorIsUsable(value)) return value;
    }
    id content = WCGestureMessageTimeFirstValue(cell, @[@"m_contentView", @"contentView", @"m_msgContentView",
                                                    @"msgContentView", @"m_messageView", @"messageView",
                                                    @"m_nodeView", @"nodeView"]);
    if ([content isKindOfClass:UIView.class]) {
        if ([content respondsToSelector:selector]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(content, selector);
            if (WCGestureMessageTimeAnchorIsUsable(value)) return value;
        }
        id value = WCGestureMessageTimeFirstValue(content, @[@"m_bgImageView", @"bgImageView"]);
        if (WCGestureMessageTimeAnchorIsUsable(value)) return value;
        if (WCGestureMessageTimeAnchorIsUsable(content)) return content;
    }
    for (NSString *selectorName in @[@"getContentView", @"getMessageContentView", @"getMsgContentView", @"getNodeView"]) {
        SEL contentSelector = NSSelectorFromString(selectorName);
        if (![cell respondsToSelector:contentSelector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(cell, contentSelector);
        if (![value isKindOfClass:UIView.class]) continue;
        if (WCGestureMessageTimeAnchorIsUsable(value)) return value;
    }
    return nil;
}

static UILabel *WCGestureMessageTimeLabel(UIView *cell, const void *key, NSString *identifier) {
    UILabel *label = objc_getAssociatedObject(cell, key);
    if (label) {
        if (label.superview != cell) [cell addSubview:label];
        label.accessibilityIdentifier = identifier;
        WCGestureMessageTimeRemoveDuplicateLabels(cell, identifier, label);
        return label;
    }
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.numberOfLines = 1;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    label.userInteractionEnabled = NO;
    label.layer.zPosition = 900.0;
    label.accessibilityIdentifier = identifier;
    [cell addSubview:label];
    objc_setAssociatedObject(cell, key, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCGestureMessageTimeRemoveDuplicateLabels(cell, identifier, label);
    return label;
}

static void WCGestureSetMessageTimeLabelsHidden(UIView *cell) {
    UILabel *avatar = objc_getAssociatedObject(cell, WCGestureMessageTimeAvatarLabelKey);
    UILabel *bubble = objc_getAssociatedObject(cell, WCGestureMessageTimeBubbleLabelKey);
    WCGestureMessageTimeRemoveDuplicateLabels(cell, WCGestureMessageTimeAvatarLabelIdentifier, avatar);
    WCGestureMessageTimeRemoveDuplicateLabels(cell, WCGestureMessageTimeBubbleLabelIdentifier, bubble);
    avatar.hidden = YES;
    bubble.hidden = YES;
}

UILabel *WCGestureVisibleMessageTimeSideLabel(UIView *cell) {
    UILabel *label = objc_getAssociatedObject(cell, WCGestureMessageTimeBubbleLabelKey);
    if (!label || label.hidden || label.alpha <= 0.01 || label.superview == nil) return nil;
    return label;
}

void WCGestureMessageTimeHide(UIView *cell) {
    WCGestureSetMessageTimeLabelsHidden(cell);
    NSUInteger generation = [objc_getAssociatedObject(cell, WCGestureMessageTimeRefreshGenerationKey) unsignedIntegerValue];
    objc_setAssociatedObject(cell, WCGestureMessageTimeRefreshGenerationKey,
                             @(generation + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, WCGestureMessageTimeRefreshPendingKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *WCGestureMessageTimeText(NSTimeInterval time, NSString *format) {
    static NSCache<NSString *, NSDateFormatter *> *formatters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ formatters = [NSCache new]; });
    NSDateFormatter *formatter = [formatters objectForKey:format];
    if (!formatter) {
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = [format stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
        [formatters setObject:formatter forKey:format];
    }
    formatter.timeZone = NSTimeZone.localTimeZone;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
}

static void WCGestureRefreshMessageTimeLabels(UIView *cell) {
    UILabel *existingAvatar = objc_getAssociatedObject(cell, WCGestureMessageTimeAvatarLabelKey);
    UILabel *existingBubble = objc_getAssociatedObject(cell, WCGestureMessageTimeBubbleLabelKey);
    WCGestureMessageTimeRemoveDuplicateLabels(cell, WCGestureMessageTimeAvatarLabelIdentifier, existingAvatar);
    WCGestureMessageTimeRemoveDuplicateLabels(cell, WCGestureMessageTimeBubbleLabelIdentifier, existingBubble);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = WCGestureEnabled(WCGestureMessageTimeEnabledKey);
    BOOL bubbleSide = [defaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    // Bubble mode wins if legacy settings ever contain both booleans. When
    // neither is set, fall back to the default below-avatar mode.
    BOOL belowAvatar = !bubbleSide;
    if (!enabled || !cell.window) {
        WCGestureMessageTimeHide(cell);
        return;
    }

    id viewModel = WCGestureMessageTimeViewModel(cell);
    if (!viewModel) {
        WCGestureMessageTimeHide(cell);
        return;
    }
    if (!WCGestureShouldShowSplitMessageMetadata(viewModel, belowAvatar)) {
        WCGestureSetMessageTimeLabelsHidden(cell);
        return;
    }
    id message = WCGestureMessageTimeMessage(viewModel);
    NSTimeInterval time = WCGestureMessageTimeCreateTime(message, viewModel);
    if (time <= 0) {
        WCGestureMessageTimeHide(cell);
        return;
    }

    NSString *format = [defaults stringForKey:WCGestureMessageTimeFormatKey];
    if (format.length == 0) format = @"MM-dd HH:mm:ss";
    NSString *text = WCGestureMessageTimeText(time, format);
    CGFloat configuredSize = [defaults doubleForKey:WCGestureMessageTimeFontSizeKey];
    CGFloat fontSize = MIN(18.0, MAX(8.0, configuredSize > 0 ? configuredSize : 10.0));
    UIFontWeight fontWeight = [defaults boolForKey:WCGestureMessageTimeBoldKey] ? UIFontWeightSemibold : UIFontWeightRegular;
    UIFont *font = [UIFont systemFontOfSize:fontSize weight:fontWeight];
    CGFloat labelHeight = MAX(12.0, ceil(fontSize * 1.5));
    CGFloat measuredWidth = ceil([text sizeWithAttributes:@{NSFontAttributeName: font}].width) + 4.0;
    CGFloat labelWidth = MIN(118.0, MAX(50.0, measuredWidth));
    BOOL isSender = [WCGestureMessageTimeValue(viewModel, @"isSender") boolValue];

    UILabel *avatarLabel = objc_getAssociatedObject(cell, WCGestureMessageTimeAvatarLabelKey);
    if (belowAvatar) {
        UIView *avatar = WCGestureMessageTimeAvatarView(cell);
        if (avatar) {
            avatarLabel = WCGestureMessageTimeLabel(cell, WCGestureMessageTimeAvatarLabelKey,
                                                  WCGestureMessageTimeAvatarLabelIdentifier);
            CGRect frame = [avatar convertRect:avatar.bounds toView:cell];
            if (!WCGestureMessageTimeFrameIsUsable(frame, cell.bounds)) {
                avatarLabel.hidden = YES;
                frame = CGRectNull;
            }
            if (!CGRectIsNull(frame)) {
                WCGestureMessageTimeStyleLabel(avatarLabel, [NSDate dateWithTimeIntervalSince1970:time]);
                avatarLabel.frame = WCGestureMessageTimeAvatarFrame(cell.bounds, frame,
                    CGSizeMake(labelWidth, labelHeight));
                avatarLabel.hidden = NO;
            }
        } else {
            avatarLabel.hidden = YES;
        }
    } else {
        avatarLabel.hidden = YES;
    }

    UILabel *bubbleLabel = objc_getAssociatedObject(cell, WCGestureMessageTimeBubbleLabelKey);
    if (bubbleSide) {
        UIView *bubble = WCGestureMessageSideAnchorView(cell);
        if (bubble) {
            CGRect frame = [bubble convertRect:bubble.bounds toView:cell];
            if (!WCGestureMessageTimeFrameIsUsable(frame, cell.bounds)) {
                bubbleLabel.hidden = YES;
                frame = CGRectNull;
            }
            if (!CGRectIsNull(frame)) {
                CGFloat gap = 5.0;
                CGFloat cellWidth = CGRectGetWidth(cell.bounds);
                CGFloat availableWidth = isSender ? CGRectGetMinX(frame) - gap - 2.0
                                                  : cellWidth - CGRectGetMaxX(frame) - gap - 2.0;
                if (availableWidth >= 40.0) {
                    bubbleLabel = WCGestureMessageTimeLabel(cell, WCGestureMessageTimeBubbleLabelKey,
                        WCGestureMessageTimeBubbleLabelIdentifier);
                    WCGestureMessageTimeStyleLabel(bubbleLabel, [NSDate dateWithTimeIntervalSince1970:time]);
                    bubbleLabel.frame = WCGestureMessageTimeSideFrame(cell.bounds, frame, isSender,
                        CGSizeMake(labelWidth, labelHeight));
                    bubbleLabel.hidden = CGRectIsEmpty(bubbleLabel.frame);
                } else {
                    bubbleLabel.hidden = YES;
                }
            }
        } else {
            bubbleLabel.hidden = YES;
        }
    } else {
        bubbleLabel.hidden = YES;
    }

}

void WCGestureMessageTimeLayout(UIView *cell) {
    if (!cell) return;
    if (!cell.window || !WCGestureEnabled(WCGestureMessageTimeEnabledKey)) {
        WCGestureSetMessageTimeLabelsHidden(cell);
        return;
    }
    [UIView performWithoutAnimation:^{
        WCGestureRefreshMessageTimeLabels(cell);
    }];
}

void WCGestureMessageTimeSchedule(UIView *cell) {
    if (!cell) return;
    if (!WCGestureEnabled(WCGestureMessageTimeEnabledKey)) {
        WCGestureMessageTimeHide(cell);
        return;
    }
    if ([objc_getAssociatedObject(cell, WCGestureMessageTimeRefreshPendingKey) boolValue]) return;
    objc_setAssociatedObject(cell, WCGestureMessageTimeRefreshPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSUInteger generation = [objc_getAssociatedObject(cell, WCGestureMessageTimeRefreshGenerationKey) unsignedIntegerValue];
    NSString *messageIdentity = WCGestureMessageTimeIdentity(cell);
    __weak UIView *weakCell = cell;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongCell = weakCell;
        if (!strongCell ||
            [objc_getAssociatedObject(strongCell, WCGestureMessageTimeRefreshGenerationKey) unsignedIntegerValue] != generation) return;
        if (WCGestureMessageTimeIdentityMatches(strongCell, messageIdentity)) {
            WCGestureRefreshMessageTimeLabels(strongCell);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *delayedCell = weakCell;
            if (!delayedCell ||
                [objc_getAssociatedObject(delayedCell, WCGestureMessageTimeRefreshGenerationKey) unsignedIntegerValue] != generation) return;
            objc_setAssociatedObject(delayedCell, WCGestureMessageTimeRefreshPendingKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (WCGestureMessageTimeIdentityMatches(delayedCell, messageIdentity)) {
                WCGestureRefreshMessageTimeLabels(delayedCell);
            }
        });
    });
}

void WCGestureMessageTimeStyleLabel(UILabel *label, NSDate *date) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *format = [defaults stringForKey:WCGestureMessageTimeFormatKey];
    format = WCGestureNormalizedDateFormat(format ?: @"") ?: @"MM-dd HH:mm:ss";
    double size = [defaults doubleForKey:WCGestureMessageTimeFontSizeKey];
    if (!isfinite(size) || size <= 0) size = 10.0;
    CGFloat weight = [defaults boolForKey:WCGestureMessageTimeBoldKey] ? UIFontWeightSemibold : UIFontWeightRegular;
    label.font = [UIFont systemFontOfSize:MIN(18.0, MAX(8.0, size)) weight:weight];
    label.textColor = WCGestureDynamicColorForDefaultsKeys(WCGestureMessageTimeLightColorKey,
        WCGestureMessageTimeDarkColorKey, WCGestureMessageTimeColorKey,
        UIColor.secondaryLabelColor, UIColor.secondaryLabelColor);
    label.text = WCGestureMessageTimeText(date.timeIntervalSince1970, format);
    label.numberOfLines = 1;
    label.textAlignment = NSTextAlignmentCenter;
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
    CGFloat width = MIN(size.width, available);
    CGFloat x = sender ? CGRectGetMinX(bubble) - width - gap : CGRectGetMaxX(bubble) + gap;
    NSInteger position = [NSUserDefaults.standardUserDefaults integerForKey:WCGestureMessageTimePositionKey];
    CGFloat y = CGRectGetMaxY(bubble) - size.height;
    if (position == 0) y = CGRectGetMinY(bubble);
    else if (position == 1) y = CGRectGetMidY(bubble) - size.height / 2.0;
    double offsetX = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMessageTimeOffsetXKey];
    double offsetY = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMessageTimeOffsetYKey];
    if (!isfinite(offsetX)) offsetX = 0;
    if (!isfinite(offsetY)) offsetY = 0;
    x += sender ? MIN(80, MAX(-80, offsetX)) : -MIN(80, MAX(-80, offsetX));
    CGFloat minimumX = sender ? CGRectGetMinX(bounds) + 2 : CGRectGetMaxX(bubble) + gap;
    CGFloat maximumX = sender ? CGRectGetMinX(bubble) - width - gap : CGRectGetMaxX(bounds) - width - 2;
    x = MIN(MAX(minimumX, x), MAX(minimumX, maximumX));
    y += MIN(80, MAX(-80, offsetY));
    y = MIN(MAX(CGRectGetMinY(bounds), y), CGRectGetMaxY(bounds) - size.height);
    return CGRectMake(x, y, width, size.height);
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
        if (cellClass && [view isKindOfClass:cellClass]) {
            WCGestureMessageTimeLayout(view);
            WCGestureAntiRevokeLayout(view);
        }
        [stack addObjectsFromArray:view.subviews];
    }
}

CGRect WCGestureMessageTimeAvatarFrame(CGRect bounds, CGRect avatar, CGSize size) {
    CGFloat width = MIN(size.width, MAX(0, CGRectGetWidth(bounds) - 4));
    double spacing = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMessageTimeAvatarSpacingKey];
    if (!isfinite(spacing)) spacing = -2;
    CGFloat x = CGRectGetMidX(avatar) - width / 2;
    CGFloat y = CGRectGetMaxY(avatar) + MIN(8, MAX(-6, spacing));
    x = MIN(MAX(2, x), MAX(2, CGRectGetWidth(bounds) - width - 2));
    y = MIN(MAX(0, y), MAX(0, CGRectGetHeight(bounds) - size.height));
    return CGRectMake(x, y, width, size.height);
}
