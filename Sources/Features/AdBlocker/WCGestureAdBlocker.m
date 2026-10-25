#import <objc/runtime.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

BOOL WCGestureAdBlockerEnabled(void) {
    return WCGestureEnabled(WCGestureAdBlockerEnabledKey);
}

static __thread BOOL WCAdBlockerURLBusy;
NSString *WCGestureAdBlockerRewrittenURLString(NSString *value) {
    if (WCAdBlockerURLBusy || ![value isKindOfClass:NSString.class]) return value;
    WCAdBlockerURLBusy = YES;
    @try {
        if (!WCGestureAdBlockerEnabled()) return value;
        // Do not parse via NSURL inside its factory hook, and do not match generic "ad_data" text.
        NSString *lower = value.lowercaseString;
        BOOL blocked = [lower hasPrefix:@"wxfile://usr/ad/"];
        if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]) {
            NSUInteger start = [lower rangeOfString:@"://"].location + 3;
            NSString *rest = [lower substringFromIndex:start];
            NSRange separator = [rest rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
            NSString *authority = separator.location == NSNotFound ? rest : [rest substringToIndex:separator.location];
            NSString *host = [[[authority componentsSeparatedByString:@"@"] lastObject] componentsSeparatedByString:@":"].firstObject;
            static NSSet<NSString *> *hosts;
            static dispatch_once_t once;
            dispatch_once(&once, ^{ hosts = [NSSet setWithArray:@[@"wxsnsdy.wxs.qq.com", @"wxsnsdy.tc.qq.com",
                @"wxsnsdy.video.qq.com", @"wxsnsdythumb.wxs.qq.com", @"ad.wx.com"]]; });
            blocked = [hosts containsObject:host];
            NSString *path = separator.location == NSNotFound ? @"" : [rest substringFromIndex:separator.location];
            if ([host isEqualToString:@"mp.weixin.qq.com"] && ([path isEqualToString:@"/mp/getappmsgad"]
                || [path hasPrefix:@"/mp/getappmsgad?"] || [path hasPrefix:@"/mp/getappmsgad/"]
                || [path hasPrefix:@"/mp/getappmsgad#"])) blocked = YES;
        }
        if ([lower hasSuffix:@"/lib/wasplashadworker.js"] || [lower hasSuffix:@"/lib/waappad.js"]
            || [lower isEqualToString:@"lib/wasplashadworker.js"] || [lower isEqualToString:@"lib/waappad.js"]) blocked = YES;
        return blocked ? @"about:blank" : value;
    } @finally { WCAdBlockerURLBusy = NO; }
}

static IMP WCAdReportOriginalThree, WCAdReportOriginalFour;
static void WCAdReportThree(id object, SEL selector, id event, id facade, id extra) {
    if (!WCGestureAdBlockerEnabled() && WCAdReportOriginalThree) {
        ((void (*)(id, SEL, id, id, id))WCAdReportOriginalThree)(object, selector, event, facade, extra);
    }
}
static void WCAdReportFour(id object, SEL selector, id event, id facade, id extra, id controller) {
    if (!WCGestureAdBlockerEnabled() && WCAdReportOriginalFour) {
        ((void (*)(id, SEL, id, id, id, id))WCAdReportOriginalFour)(object, selector, event, facade, extra, controller);
    }
}
static void WCAdInstallReportMethod(Class cls, NSString *name, unsigned int count, IMP replacement, IMP *original) {
    SEL selector = NSSelectorFromString(name);
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != count) return;
    char type[32] = {0};
    method_getReturnType(method, type, sizeof(type));
    if (type[0] != 'v') return;
    for (unsigned int index = 2; index < count; index++) {
        method_getArgumentType(method, index, type, sizeof(type));
        if (type[0] != '@') return;
    }
    *original = method_getImplementation(method);
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
        method_setImplementation(class_getInstanceMethod(cls, selector), replacement);
    }
}
void WCGestureAdBlockerInstallOptionalHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = NSClassFromString(@"WebviewJSEventHandler_adDataReport");
        WCAdInstallReportMethod(cls, @"handleJSEvent:HandlerFacade:ExtraData:", 5, (IMP)WCAdReportThree, &WCAdReportOriginalThree);
        WCAdInstallReportMethod(cls, @"handleJSEvent:HandlerFacade:ExtraData:CurrentViewController:", 6, (IMP)WCAdReportFour, &WCAdReportOriginalFour);
    });
}
