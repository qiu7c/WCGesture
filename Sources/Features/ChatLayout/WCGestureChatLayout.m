#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>
#import "Sources/API/WCGestureInternal.h"

static __thread NSUInteger WCLayoutThemeLookupDepth;
static char WCLayoutOriginalWebZoomKey;

BOOL WCGestureLayoutScaleEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:WCGesturePageScaleEnabledKey];
}

double WCGestureLayoutScaleFactor(void) {
    if (!WCGestureLayoutScaleEnabled()) return 1.0;
    double percent = [[NSUserDefaults standardUserDefaults] doubleForKey:WCGesturePageScalePercentKey];
    if (!isfinite(percent)) percent = 90.0;
    return MIN(100.0, MAX(70.0, percent)) / 100.0;
}

void WCGestureLayoutBeginThemeLookup(void) {
    WCLayoutThemeLookupDepth++;
}

id WCGestureLayoutEndThemeLookup(id value, id property, id ruleSet) {
    if (WCLayoutThemeLookupDepth == 0) return value;
    WCLayoutThemeLookupDepth--;
    if (WCLayoutThemeLookupDepth != 0 || !WCGestureLayoutScaleEnabled()) return value;
    if (![ruleSet isKindOfClass:NSString.class] || ![ruleSet isEqualToString:@"#font_set"] ||
        ![property isKindOfClass:NSString.class] ||
        (![property isEqualToString:@"alllevel"] && ![property isEqualToString:@"chatLevel"]) ||
        ![value isKindOfClass:NSArray.class] || [value count] == 0) return value;

    // Same theme contract as WCAtlas. Copy rather than mutate WeChat's cache.
    id first = [value firstObject];
    double number = 0.0;
    if ([first isKindOfClass:NSNumber.class]) {
        number = [first doubleValue];
    } else if ([first isKindOfClass:NSString.class]) {
        NSScanner *scanner = [NSScanner scannerWithString:first];
        if (![scanner scanDouble:&number] || !scanner.isAtEnd) return value;
    } else {
        return value;
    }
    if (!isfinite(number)) return value;
    double scaled = number * WCGestureLayoutScaleFactor();
    if (!isfinite(scaled)) return value;
    id replacement = @(scaled);
    if ([first isKindOfClass:NSString.class]) {
        NSDecimalNumber *decimal = [NSDecimalNumber decimalNumberWithString:first];
        NSDecimalNumber *factor = [NSDecimalNumber decimalNumberWithString:
            [NSString stringWithFormat:@"%.4f", WCGestureLayoutScaleFactor()]];
        NSDecimalNumber *result = [decimal decimalNumberByMultiplyingBy:factor];
        if ([result isEqualToNumber:NSDecimalNumber.notANumber]) return value;
        replacement = result.stringValue;
    }
    NSMutableArray *copy = [value mutableCopy];
    copy[0] = replacement;
    return copy;
}

double WCGestureLayoutWebViewZoom(id webView, double requestedFactor) {
    objc_setAssociatedObject(webView, &WCLayoutOriginalWebZoomKey, @(requestedFactor), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return WCGestureLayoutScaleEnabled() ? WCGestureLayoutScaleFactor() : requestedFactor;
}

void WCGestureLayoutApplyWebView(id webView) {
    SEL selector = NSSelectorFromString(@"_setTextZoomFactor:");
    if (![webView respondsToSelector:selector]) return;
    NSNumber *original = objc_getAssociatedObject(webView, &WCLayoutOriginalWebZoomKey);
    if (!original && !WCGestureLayoutScaleEnabled()) return;
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(webView, selector, original ? original.doubleValue : 1.0);
}

void WCGestureLayoutSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGesturePageScaleEnabledKey] &&
        ![key isEqualToString:WCGesturePageScalePercentKey]) return;
    UIWindow *window = WCActiveWindow();
    if (!window) return;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:WKWebView.class]) WCGestureLayoutApplyWebView(view);
        [view setNeedsLayout];
        [stack addObjectsFromArray:view.subviews];
    }
}

unsigned int WCChatLayoutResolvedFontLevel(unsigned int originalLevel) {
    if (WCGestureLayoutScaleEnabled()) return 1;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:WCChatLayoutEnabledKey]) return originalLevel;
    NSInteger level = [defaults integerForKey:WCChatLayoutFontLevelKey];
    if (level < 1) level = 1;
    if (level > 8) level = 8;
    return (unsigned int)level;
}

double WCMomentsLayoutAdjustedHeight(double originalHeight) {
    // Theme scaling lets WeChat measure smaller content itself. Do not also
    // multiply a whole Moments cell (photos and fixed spacing would clip).
    if (WCGestureLayoutScaleEnabled()) return originalHeight;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:WCMomentsLayoutEnabledKey]) return originalHeight;
    double percent = [defaults doubleForKey:WCMomentsHeightScaleKey];
    if (!isfinite(percent) || !isfinite(originalHeight) || originalHeight <= 0.0) return originalHeight;
    if (percent < 100.0) percent = 100.0;
    if (percent > 160.0) percent = 160.0;
    return originalHeight * percent / 100.0;
}
