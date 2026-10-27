#import "Sources/API/WCGestureInternal.h"

%hook AVVideoDevice
- (void)captureOutput:(id)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(id)connection {
    CMSampleBufferRef processed = WCGestureVideoCallCreateFrame(self, sample, connection);
    CMSampleBufferRef outgoing = processed ? processed : sample;
    BOOL previous = WCGestureVideoCallBeginMirrorScope(self);
    @try {
        %orig(output, outgoing, connection);
    } @finally {
        WCGestureVideoCallEndMirrorScope(previous);
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

%hook WCVideoSampleBufferRender
- (void)setMirror:(BOOL)mirror {
    BOOL value = WCGestureVideoCallRendererMirrorValue(self, mirror);
    %orig(value);
}
- (id)initWithFrame:(CGRect)frame isMirror:(BOOL)mirror {
    BOOL value = WCGestureVideoCallRendererMirrorEnabled() ? NO : mirror;
    id result = %orig(frame, value);
    if (result) WCGestureVideoCallRendererMirrorValue(result, mirror);
    return result;
}
%end

%hook XImageViewRenderer
- (BOOL)flipX {
    BOOL original = %orig;
    return WCGestureVideoCallRendererFlipX(self, original);
}
%end

%hook MMFinderLiveStickerEditingViewController
- (void)onConfirmTapped {
    if (WCGestureVideoCallConfirmSticker(self)) return;
    %orig;
}
- (void)onCancelTapped {
    if (WCGestureVideoCallCancelSticker(self)) return;
    %orig;
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
