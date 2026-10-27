#import <objc/runtime.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCMomentsTimeState : NSObject
@property (nonatomic, weak) UILabel *label;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSAttributedString *attributedText;
@property (nonatomic, assign) NSInteger lines;
@end
@implementation WCMomentsTimeState
@end

static char WCMomentsTimeStateKey;
static NSHashTable<UIView *> *WCMomentsTimeCells(void) {
    static NSHashTable *cells; static dispatch_once_t once;
    dispatch_once(&once, ^{ cells = [NSHashTable weakObjectsHashTable]; }); return cells;
}

void WCGestureMomentsTimeReset(UIView *cell) {
    WCMomentsTimeState *state = objc_getAssociatedObject(cell, &WCMomentsTimeStateKey);
    if (!state) return;
    if (state.attributedText) state.label.attributedText = state.attributedText;
    else state.label.text = state.text;
    state.label.numberOfLines = state.lines;
    objc_setAssociatedObject(cell, &WCMomentsTimeStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

NSString *WCGestureMomentsTimeText(id item) {
    NSTimeInterval timestamp = [WCTweakSafeValue(item, @"createtime") doubleValue];
    if (!WCGestureEnabled(WCGestureMomentsTimeEnabledKey) || !isfinite(timestamp) || timestamp <= 0) return nil;
    static NSDateFormatter *formatter; static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new]; formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    });
    NSString *format = WCGestureNormalizedDateFormat([NSUserDefaults.standardUserDefaults stringForKey:WCGestureMomentsTimeFormatKey]) ?: @"yyyy-MM-dd HH:mm:ss";
    @synchronized (formatter) {
        formatter.timeZone = NSTimeZone.localTimeZone;
        formatter.dateFormat = [format stringByReplacingOccurrencesOfString:@"\\n" withString:@" "];
        return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
    }
}

void WCGestureMomentsTimeApply(UIView *cell, BOOL nativeRefreshed) {
    [WCMomentsTimeCells() addObject:cell];
    id value = WCTweakSafeValue(cell, @"m_timeLabel");
    if (![value isKindOfClass:UILabel.class]) { WCGestureMomentsTimeReset(cell); return; }
    UILabel *label = value;
    WCMomentsTimeState *state = objc_getAssociatedObject(cell, &WCMomentsTimeStateKey);
    if (state && (state.label != label || nativeRefreshed)) {
        // Native setters are restored before %orig by the hooks, so this is
        // chiefly a replacement-label guard rather than a repeated snapshot.
        WCGestureMomentsTimeReset(cell); state = nil;
    }
    id item = WCTweakSafeValue(cell, @"m_dataItem");
    NSString *text = WCGestureMomentsTimeText(item);
    if (!text) { WCGestureMomentsTimeReset(cell); return; }
    if (!state) {
        state = [WCMomentsTimeState new]; state.label = label; state.text = label.text;
        state.attributedText = label.attributedText; state.lines = label.numberOfLines;
        objc_setAssociatedObject(cell, &WCMomentsTimeStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (![label.text isEqualToString:text]) label.text = text;
    label.numberOfLines = 1;
}

void WCGestureMomentsTimeSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.moments.precise-time."]) return;
    for (UIView *cell in WCMomentsTimeCells().allObjects) {
        if (cell.window) { WCGestureMomentsTimeApply(cell, NO); [cell setNeedsLayout]; }
        else WCGestureMomentsTimeReset(cell);
    }
}
