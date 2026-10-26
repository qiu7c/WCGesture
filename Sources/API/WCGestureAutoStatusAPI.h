#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Called from WeChat's careEnoughForTheLiving callback. Publishes at most once
/// per local calendar day after the configured hour.
void WCGestureAutoStatusCheck(void);
/// Receives the setting key changed by the settings notification observer.
void WCGestureAutoStatusSettingsChanged(NSString * _Nullable key);
/// Starts a publication immediately, bypassing the daily schedule gate.
void WCGestureAutoStatusPublishNow(void);
/// Returns dictionaries containing the native status icon title and value.
NSArray<NSDictionary<NSString *, NSString *> *> *WCGestureAutoStatusIconOptions(void);
/// Imports a user-selected local background. Importing one media type removes
/// the previous other type so mode 0 has a deterministic local media choice.
BOOL WCGestureAutoStatusImportMedia(NSURL *url, BOOL video, NSError * _Nullable * _Nullable error);
/// Returns the managed local background path for the requested media type.
NSString *WCGestureAutoStatusMediaPath(BOOL video);

NS_ASSUME_NONNULL_END
