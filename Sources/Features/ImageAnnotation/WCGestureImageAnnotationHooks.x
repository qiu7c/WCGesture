#import "Sources/API/WCGestureInternal.h"
%hook WCEditImageLayoutView
- (void)layoutSubviews {
    %orig;
    WCGestureImageAnnotationLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureImageAnnotationLayout((UIView *)self);
}
- (void)reloadBottomEditImageBar {
    %orig;
    WCGestureImageAnnotationLayout((UIView *)self);
}
- (void)onPenEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onMosaicEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onTextEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onCropEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onEmotionEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onAiEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onClickDoneBtn:(id)completion {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(completion);
}
%end
%hook EditImageIntialView
- (void)layoutSubviews {
    %orig;
    WCGestureImageAnnotationLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureImageAnnotationLayout((UIView *)self);
}
- (void)reloadBottomEditImageBar {
    %orig;
    WCGestureImageAnnotationLayout((UIView *)self);
}
- (void)onPenEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onMosaicEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onTextEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onCropEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onEmotionEditImage:(id)sender {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(sender);
}
- (void)onClickDoneBtn:(id)completion {
    WCGestureImageAnnotationStop((UIView *)self);
    %orig(completion);
}
%end
%hook WCEditImageScrollView
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if(WCGestureImageAnnotationBlocksGesture((UIScrollView *)self,gesture))return NO;
    return %orig(gesture);
}
%end
%hook EditImageScrollView
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if(WCGestureImageAnnotationBlocksGesture((UIScrollView *)self,gesture))return NO;
    return %orig(gesture);
}
%end
%hook EditImageEmotionTool
- (void)didSelectEmotion:(id)emotion withCenterPoint:(CGPoint)center md5:(id)md5 {
    WCGestureImageAnnotationWidgetCapture((UIView *)self);
    %orig(emotion,center,md5);
    WCGestureImageAnnotationWidgetRestore((UIView *)self);
}
%end
%ctor {
    %init;
}
