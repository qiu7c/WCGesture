#import <math.h>
#import "Sources/API/WCGestureInternal.h"

NSString *WCGestureNormalizedDateFormat(NSString *format) {
    if (![format isKindOfClass:[NSString class]]) return nil;
    NSString *normalized = [format stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    if (normalized.length == 0 || normalized.length > 64) return nil;

    static NSArray<NSString *> *tokens;
    static NSCharacterSet *letters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tokens = @[@"yyyy", @"MM", @"dd", @"E", @"HH", @"mm", @"ss"];
        letters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"];
    });

    NSUInteger index = 0;
    while (index < normalized.length) {
        if ([normalized characterAtIndex:index] == '\\' &&
            index + 1 < normalized.length &&
            [normalized characterAtIndex:index + 1] == 'n') {
            index += 2;
            continue;
        }
        NSRange characterRange = [normalized rangeOfComposedCharacterSequenceAtIndex:index];
        NSString *character = [normalized substringWithRange:characterRange];
        if ([character rangeOfCharacterFromSet:letters].location == NSNotFound) {
            index = NSMaxRange(characterRange);
            continue;
        }
        BOOL matched = NO;
        for (NSString *token in tokens) {
            if (index + token.length <= normalized.length &&
                [[normalized substringWithRange:NSMakeRange(index, token.length)] isEqualToString:token]) {
                index += token.length;
                matched = YES;
                break;
            }
        }
        if (!matched) return nil;
    }
    return normalized;
}

UIColor *WCGestureColorForDefaultsKey(NSString *key, UIColor *fallbackColor) {
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (![hex isKindOfClass:[NSString class]]) return fallbackColor;
    NSString *value = [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if (value.length != 6 && value.length != 8) return fallbackColor;
    unsigned long long rgba = 0;
    if (![[NSScanner scannerWithString:value] scanHexLongLong:&rgba]) return fallbackColor;
    CGFloat red = ((rgba >> (value.length == 8 ? 24 : 16)) & 0xFF) / 255.0;
    CGFloat green = ((rgba >> (value.length == 8 ? 16 : 8)) & 0xFF) / 255.0;
    CGFloat blue = ((rgba >> (value.length == 8 ? 8 : 0)) & 0xFF) / 255.0;
    CGFloat alpha = value.length == 8 ? (rgba & 0xFF) / 255.0 : 1.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

NSString *WCGestureHexStringFromColor(UIColor *color) {
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) return @"#8E8E93FF";
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (int)lround(red * 255.0), (int)lround(green * 255.0),
            (int)lround(blue * 255.0), (int)lround(alpha * 255.0)];
}

UIColor *WCGestureDynamicColorForDefaultsKeys(NSString *lightKey,
                                          NSString *darkKey,
                                          NSString *legacyKey,
                                          UIColor *lightFallbackColor,
                                          UIColor *darkFallbackColor) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *legacyHex = legacyKey.length > 0 ? [defaults stringForKey:legacyKey] : nil;
    UIColor *legacyFallback = legacyHex.length > 0
        ? WCGestureColorForDefaultsKey(legacyKey, lightFallbackColor)
        : nil;
    UIColor *lightColor = WCGestureColorForDefaultsKey(lightKey, legacyFallback ?: lightFallbackColor);
    UIColor *darkColor = WCGestureColorForDefaultsKey(darkKey, legacyFallback ?: darkFallbackColor);
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
}
