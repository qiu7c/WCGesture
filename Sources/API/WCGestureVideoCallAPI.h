#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
@class CIImage;

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
BOOL WCGestureVideoCallCancelSticker(id editor);
void WCGestureVideoCallEditTextSticker(UIViewController *presenter);
void WCGestureVideoCallEditSticker(UIViewController *presenter, UIImage *image);
void WCGestureVideoCallRepositionSticker(UIViewController *presenter);
UIViewController *WCGestureCreateVideoStickerEditor(UIImage *image, NSDictionary * _Nullable placement,
    void (^completion)(UIImage * _Nullable canvas, NSDictionary * _Nullable placement));
BOOL WCGestureVideoStickerEditorCancel(UIViewController *controller);
void WCGestureVideoCallClearSticker(void);
BOOL WCGestureVideoCallHasSticker(void);
NSArray<NSDictionary *> *WCGestureVideoCallBeautyItems(void);
void WCGestureVideoCallSetBeautyValue(NSString *identifier, double value);
void WCGestureVideoCallPreviewBeautyValue(NSString *identifier, double value);
void WCGestureVideoCallResetBeauty(void);
NSString *WCGestureVideoCallStatus(void);
NSString *WCGestureVideoCallContextToken(void);
UIViewController *WCGestureCreateVideoCallSettingsController(void);
void WCGesturePresentVideoCallSettings(UIViewController *presenter);
BOOL WCGestureVideoCallRenderToPixels(CIImage *image,CVPixelBufferRef output);
NS_ASSUME_NONNULL_END
