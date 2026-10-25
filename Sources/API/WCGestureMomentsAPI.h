#import <UIKit/UIKit.h>
#import "Sources/WeChat/WCGestureWeChatClasses.h"

NS_ASSUME_NONNULL_BEGIN

/// Adds/removes the double-tap recognizer for the current settings. Called
/// from the cell's lifecycle hooks.
void WCSynchronizeMomentsDoubleTap(WCTimeLineCellView *cell);

/// Body of the double-tap recognizer.
void WCMomentsHandleDoubleTap(WCTimeLineCellView *cell);

NS_ASSUME_NONNULL_END
