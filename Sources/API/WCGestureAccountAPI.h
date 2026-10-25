#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/// A new native avatar view for the logged-in account, using WeChat's loader.
/// Returns an empty neutral view if the account service is not ready.
UIView *WCGestureCurrentUserAvatarView(void);
NS_ASSUME_NONNULL_END
