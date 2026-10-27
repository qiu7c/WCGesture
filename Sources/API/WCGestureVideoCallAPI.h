#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const WCGestureVideoCallStateDidChangeNotification;
void WCGestureVideoCallStart(void);
void WCGestureVideoCallViewChanged(UIViewController *controller, BOOL visible);
void WCGestureVideoCallTalkingViewChanged(UIView *view);
void WCGestureVideoCallConnected(UIViewController *controller);
void WCGestureVideoCallEnded(UIViewController *controller);
void WCGestureVideoCallDeviceStopped(id device);
void WCGestureVideoCallResourcesChanged(void);
/// NULL means use the original frame. A returned sample is owned by the caller.
CMSampleBufferRef _Nullable WCGestureVideoCallCreateFrame(id device, CMSampleBufferRef sample,
                                                        id connection) CF_RETURNS_RETAINED;
BOOL WCGestureVideoCallBeginMirrorScope(id device);
void WCGestureVideoCallEndMirrorScope(BOOL previous);
BOOL WCGestureVideoCallRendererMirrorEnabled(void);
BOOL WCGestureVideoCallRendererMirrorValue(id renderer, BOOL requested);
BOOL WCGestureVideoCallRendererFlipX(id renderer, BOOL original);
/// Returns YES only for an editor owned by this feature, including invalid confirmation.
BOOL WCGestureVideoCallConfirmSticker(id editor);
BOOL WCGestureVideoCallCancelSticker(id editor);
void WCGestureVideoCallEditSticker(UIViewController *presenter, UIImage *image);
void WCGestureVideoCallClearSticker(void);
BOOL WCGestureVideoCallHasSticker(void);
NSArray<NSDictionary *> *WCGestureVideoCallBeautyItems(void);
void WCGestureVideoCallSetBeautyValue(NSString *identifier, double value);
void WCGestureVideoCallResetBeauty(void);
NSString *WCGestureVideoCallStatus(void);
NSString *WCGestureVideoCallContextToken(void);
UIViewController *WCGestureCreateVideoCallSettingsController(void);
NS_ASSUME_NONNULL_END
