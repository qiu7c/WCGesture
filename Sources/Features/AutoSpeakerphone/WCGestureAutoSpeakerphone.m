#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCAutoSpeakerHandledKey;
static char WCAutoSpeakerReadyKey;
static void WCAutoSpeakerApplyReady(id manager) {
    if (!manager || !WCGestureEnabled(WCGestureAutoSpeakerphoneEnabledKey)) return;
    if (![WCTweakSafeValue(manager, @"m_hasBeganTalk") boolValue] ||
        ![WCTweakSafeValue(manager, @"isAudioMode") boolValue]) return;
    NSNumber *stamp = WCTweakSafeValue(manager, @"startTalkTimestamp");
    if (![stamp isKindOfClass:NSNumber.class] || stamp.doubleValue <= 0) return;
    if ([objc_getAssociatedObject(manager, &WCAutoSpeakerHandledKey) isEqual:stamp]) return;
    // Mark even an external route as handled: unplugging it must not change the user's route mid-call.
    objc_setAssociatedObject(manager, &WCAutoSpeakerHandledKey, stamp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    AVAudioSessionRouteDescription *route = AVAudioSession.sharedInstance.currentRoute;
    if (!route.outputs.count) return;
    BOOL alreadySpeaker = NO;
    for (AVAudioSessionPortDescription *port in route.outputs) {
        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) alreadySpeaker = YES;
        else if (![port.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) return;
    }
    for (AVAudioSessionPortDescription *port in route.inputs) {
        if (![port.portType isEqualToString:AVAudioSessionPortBuiltInMic]) return;
    }
    SEL selector = NSSelectorFromString(@"SetSpeakerPhone:");
    if (!alreadySpeaker && [manager respondsToSelector:selector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, selector, YES);
    }
}
void WCGestureAutoSpeakerphoneApply(id manager) {
    // The audio callback can arrive before the talk-state setter; handle either order.
    dispatch_async(dispatch_get_main_queue(), ^{
        objc_setAssociatedObject(manager, &WCAutoSpeakerReadyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCAutoSpeakerApplyReady(manager);
    });
}
void WCGestureAutoSpeakerphoneTalkChanged(id manager, BOOL began) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!began) {
            objc_setAssociatedObject(manager, &WCAutoSpeakerHandledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(manager, &WCAutoSpeakerReadyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else if ([objc_getAssociatedObject(manager, &WCAutoSpeakerReadyKey) boolValue]) {
            WCAutoSpeakerApplyReady(manager);
        }
    });
}
