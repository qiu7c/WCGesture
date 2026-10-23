#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A real UITableViewController subclass registered with WeChat's WCPluginsMgr.
/// WeChat instantiates it by class name when the user taps the plugin entry.
@interface WCGestureSettingsController : UITableViewController
@end

/// Presents the WCGesture settings sheet (ActionSheet style) from the given
/// view controller. Used by the Me-page fallback entry.
void WCGesturePresentSettings(UIViewController *presenter);

/// Registers WCGestureSettingsController with WeChat's plugin manager
/// (WCPluginsMgr) using the real registerControllerWithTitle:version:controller:
/// API. Falls back silently when the API is unavailable.
void WCGestureRegisterEntry(void);

NS_ASSUME_NONNULL_END
