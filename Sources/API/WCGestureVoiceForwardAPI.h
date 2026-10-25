#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
NSArray * _Nullable WCGestureVoiceForwardMenuItems(UIView *cell, NSArray * _Nullable items);
BOOL WCGestureVoiceForwardAllowsAction(SEL action);
/// Consumes voice messages sent to every selected contact; returns the rest
/// for WeChat's original forwarding path. Origin indexes stay aligned.
NSArray * _Nullable WCGestureVoiceForwardMessages(NSArray * _Nullable messages, NSArray * _Nullable contacts,
    NSIndexSet * _Nullable * _Nullable handledIndexes);
NSArray * _Nullable WCGestureVoiceForwardFilteredOrigins(NSArray * _Nullable origins, NSIndexSet * _Nullable handledIndexes);
NS_ASSUME_NONNULL_END
