#import "Sources/API/WCGestureInternal.h"

%hook AVVideoDevice
- (void)captureOutput:(id)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(id)connection {
    CMSampleBufferRef substituted = WCGestureVirtualVideoCreateSample(output, sample, connection);
    CMSampleBufferRef processed = WCGestureVideoCallCreateFrame(self, substituted ? substituted : sample, connection);
    CMSampleBufferRef outgoing = processed ? processed : (substituted ? substituted : sample);
    @try {
        %orig(output, outgoing, connection);
    } @finally {
        if (processed) CFRelease(processed);
        if (substituted) CFRelease(substituted);
    }
}
- (void)stopSession {
    WCGestureVirtualVideoStop();
    WCGestureVideoCallDeviceStopped(self);
    %orig;
}
%end

%hook VoIPViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureVideoCallViewChanged((UIViewController *)self, YES);
    WCGestureVirtualVideoContextChanged();
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *controller = (UIViewController *)self;
    if (controller.view.window) WCGestureVideoCallViewChanged(controller, YES);
    WCGestureVirtualVideoContextChanged();
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    WCGestureVideoCallViewChanged((UIViewController *)self, NO);
    WCGestureVirtualVideoContextChanged();
}
- (void)switchToTalkingView {
    %orig;
    WCGestureVideoCallConnected((UIViewController *)self);
    WCGestureVirtualVideoContextChanged();
}
- (void)layoutTalkingView {
    %orig;
    WCGestureVideoCallViewChanged((UIViewController *)self, YES);
    WCGestureVirtualVideoContextChanged();
}
- (void)forceEndCall {
    WCGestureVirtualVideoStop();
    WCGestureVideoCallEnded((UIViewController *)self);
    %orig;
}
- (void)onVideoVoipTalkingViewEndCall {
    WCGestureVirtualVideoStop();
    WCGestureVideoCallEnded((UIViewController *)self);
    %orig;
}
- (void)onVideoVoipTalkingViewHangUp {
    WCGestureVirtualVideoStop();
    WCGestureVideoCallEnded((UIViewController *)self);
    %orig;
}
%end

%hook VoIPTalkingView
- (void)layoutSubviews {
    %orig;
    WCGestureVideoCallTalkingViewChanged((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureVideoCallTalkingViewChanged((UIView *)self);
}
%end

%hook VideoVoipCSTalkingView
- (void)layoutSubviews {
    %orig;
    WCGestureVideoCallTalkingViewChanged((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureVideoCallTalkingViewChanged((UIView *)self);
}
%end

%hook MMLiveResUpdateMgr
- (void)onResUpdateFinish:(long long)version resType:(unsigned int)type subResType:(unsigned int)subtype {
    %orig(version, type, subtype);
    if (type == 184 && subtype == 3) WCGestureVideoCallResourcesChanged();
}
%end

%ctor {
    %init;
    WCGestureVideoCallStart();
}
