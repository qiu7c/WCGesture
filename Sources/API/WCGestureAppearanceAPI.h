#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
NSString * _Nullable WCGestureNormalizedDateFormat(NSString *format);
UIColor *WCGestureColorForDefaultsKey(NSString *key, UIColor *fallback);
NSString *WCGestureHexStringFromColor(UIColor *color);
UIColor *WCGestureDynamicColorForDefaultsKeys(NSString *lightKey, NSString *darkKey, NSString *legacyKey,
    UIColor *lightFallback, UIColor *darkFallback);
CGFloat WCGestureSettingsScaleFactor(void);
UIImage *WCGestureSettingsBackImage(void);
void WCGestureSettingsConfigureNavigation(UIViewController *controller);
void WCGestureSettingsPostChange(NSString * _Nullable key);
UIView *WCGestureSettingsSearchHeader(UITextField *field, CGFloat width);
NS_ASSUME_NONNULL_END
