#import "Sources/API/WCGestureInternal.h"
%hook NSURL
+ (instancetype)URLWithString:(NSString *)URLString {
    NSString *rewritten=WCGestureAdBlockerRewrittenURLString(URLString);
    return %orig(rewritten);
}
%end
%ctor {
    %init;
    WCGestureAdBlockerInstallOptionalHooks();
}
