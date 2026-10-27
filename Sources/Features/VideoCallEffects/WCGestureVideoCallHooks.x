#import "Sources/API/WCGestureInternal.h"

%hook AVVideoDevice
- (void)captureOutput:(id)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(id)connection {
    CMSampleBufferRef processed = WCGestureVideoCallCreateFrame(self, sample, connection);
    CMSampleBufferRef outgoing = processed ? processed : sample;
    @try {
        %orig(output, outgoing, connection);
    } @finally {
        if (processed) CFRelease(processed);
    }
}
- (void)stopSession {
    WCGestureVideoCallDeviceStopped(self);
    %orig;
}
%end

%hook VoIPViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureVideoCallViewChanged((UIViewController *)self, YES);
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *controller = (UIViewController *)self;
    if (controller.view.window) WCGestureVideoCallViewChanged(controller, YES);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    WCGestureVideoCallViewChanged((UIViewController *)self, NO);
}
- (void)switchToTalkingView {
    %orig;
    WCGestureVideoCallConnected((UIViewController *)self);
}
- (void)layoutTalkingView {
    %orig;
    WCGestureVideoCallViewChanged((UIViewController *)self, YES);
}
- (void)forceEndCall {
    WCGestureVideoCallEnded((UIViewController *)self);
    %orig;
}
- (void)onVideoVoipTalkingViewEndCall {
    WCGestureVideoCallEnded((UIViewController *)self);
    %orig;
}
- (void)onVideoVoipTalkingViewHangUp {
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
