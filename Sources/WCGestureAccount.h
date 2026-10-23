#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Cached current-user WeChat ID (wxid). Persists across launches via NSUserDefaults.
FOUNDATION_EXPORT NSString * _Nullable WCCurrentUserWXID(void);

/// Returns WeChat's shared service center, installing a compatibility shim on
/// versions that lack the `defaultCenter` class method. nil when unavailable.
FOUNDATION_EXPORT id _Nullable WCDefaultServiceCenter(void);

/// Resolves a WeChat service instance through the service center by class.
FOUNDATION_EXPORT id _Nullable WCServiceForClass(Class _Nullable serviceClass);

/// Installs the service-center compatibility shim. Safe to call multiple times.
FOUNDATION_EXPORT void WCInstallServiceCenterCompatibility(void);

NS_ASSUME_NONNULL_END
