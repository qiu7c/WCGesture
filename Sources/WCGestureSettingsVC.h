#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Presents the WCGesture settings sheet from the given view controller.
/// Uses UIAlertController action sheets and inline number prompts; no
/// dependency on WCAtlas's full settings framework.
void WCGesturePresentSettings(UIViewController *presenter);

/// Pushes a WCGesture settings entry into WeChat's plugin/settings page when
/// the WCPluginsMgr registration API is available. Otherwise registers a
/// standalone entry through the "Me" page hook.
void WCGestureRegisterEntry(void);

NS_ASSUME_NONNULL_END
