#import "Sources/API/WCGestureInternal.h"

unsigned int WCChatLayoutResolvedFontLevel(unsigned int originalLevel) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:WCChatLayoutEnabledKey]) return originalLevel;
    NSInteger level = [defaults integerForKey:WCChatLayoutFontLevelKey];
    if (level < 1) level = 1;
    if (level > 8) level = 8;
    return (unsigned int)level;
}

double WCMomentsLayoutAdjustedHeight(double originalHeight) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:WCMomentsLayoutEnabledKey]) return originalHeight;
    double percent = [defaults doubleForKey:WCMomentsHeightScaleKey];
    if (percent < 100.0) percent = 100.0;
    if (percent > 160.0) percent = 160.0;
    return originalHeight * percent / 100.0;
}
