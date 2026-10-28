#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureVirtualVideoStart(void);
void WCGestureVirtualVideoContextChanged(void);
void WCGestureVirtualVideoStop(void);
void WCGestureVirtualVideoSettingsChanged(NSString * _Nullable key);
void WCGestureVirtualVideoInstallAudioDelegate(id _Nullable delegate);
CMSampleBufferRef _Nullable WCGestureVirtualVideoCreateSample(id output,CMSampleBufferRef incoming,id connection) CF_RETURNS_RETAINED;
void WCGestureVirtualVideoImport(NSURL *url,void (^completion)(BOOL success));
void WCGestureVirtualVideoClear(void);
NSString *WCGestureVirtualVideoSourceName(void);
NS_ASSUME_NONNULL_END
