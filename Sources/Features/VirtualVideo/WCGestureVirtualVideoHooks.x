#import <AVFoundation/AVFoundation.h>
#import "Sources/API/WCGestureInternal.h"
%hook AVCaptureAudioDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    WCGestureVirtualVideoInstallAudioDelegate(delegate);
    %orig(delegate,queue);
}
%end
%ctor {
    %init;
    WCGestureVirtualVideoStart();
}
