#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Hides thin table separators across WeChat when the option is on. Called
/// from the app-wide UIView layoutSubviews hook after the original ran.
void WCSeparatorHandleLayoutSubviews(UIView *view);

NS_ASSUME_NONNULL_END
