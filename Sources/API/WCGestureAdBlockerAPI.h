#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
BOOL WCGestureAdBlockerEnabled(void);
void WCGestureAdBlockerInstallOptionalHooks(void);
NSString * _Nullable WCGestureAdBlockerRewrittenURLString(NSString * _Nullable value);
NS_ASSUME_NONNULL_END
