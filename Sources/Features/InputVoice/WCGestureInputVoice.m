#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#include <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCInputVoiceSession : NSObject <AVAudioRecorderDelegate>
@property (nonatomic, weak) UIView *source;
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *peer;
@property (nonatomic, strong) NSURL *directory;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) UILabel *hud;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *previousCategory;
@property (nonatomic, copy) NSString *previousMode;
@property (nonatomic) AVAudioSessionCategoryOptions previousOptions;
@property (nonatomic) CGPoint origin;
@property (nonatomic) BOOL pressed;
@property (nonatomic) BOOL cancelOnRelease;
@property (nonatomic) BOOL ownsAudioSession;
@property (nonatomic) BOOL limitReached;
@property (nonatomic) BOOL encoding;
@end

static WCInputVoiceSession *WCInputVoiceActive;
static BOOL WCInputVoiceAllowed(void) {
    return WCGestureEnabled(WCInputGestureEnabledKey) &&
        [NSUserDefaults.standardUserDefaults integerForKey:WCInputLongPressActionKey] == WCInputActionRecordVoice;
}
static BOOL WCInputVoiceValid(WCInputVoiceSession *session) {
    return WCInputVoiceActive == session && WCInputVoiceAllowed() && session.source.window && session.controller &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        WCVisibleChatControllerGet() == session.controller &&
        [session.account isEqualToString:WCCurrentUserWXID() ?: @""] &&
        [session.peer isEqualToString:WCGestureLocalChatSession(session.controller)];
}
static void WCInputVoiceRestoreAudio(WCInputVoiceSession *session) {
    if (!session.ownsAudioSession) return;
    session.ownsAudioSession = NO;
    AVAudioSession *audio = AVAudioSession.sharedInstance;
    // Only restore our category; leave a newly started call/audio owner alone.
    if ([audio.category isEqualToString:AVAudioSessionCategoryRecord] && [audio.mode isEqualToString:AVAudioSessionModeDefault]) {
        [audio setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        [audio setCategory:session.previousCategory mode:session.previousMode options:session.previousOptions error:nil];
    }
}
static void WCInputVoiceCleanup(WCInputVoiceSession *session) {
    [session.timer invalidate]; session.timer = nil;
    [session.recorder stop];
    [session.hud removeFromSuperview];
    WCInputVoiceRestoreAudio(session);
    if (session.directory) [NSFileManager.defaultManager removeItemAtURL:session.directory error:nil];
    if (WCInputVoiceActive == session) WCInputVoiceActive = nil;
}
void WCGestureInputVoiceCancel(void) {
    WCInputVoiceSession *session = WCInputVoiceActive;
    session.pressed = NO;
    // Encoding owns its files until its completion returns to the main queue.
    if (session.encoding) {
        [session.hud removeFromSuperview];
        WCInputVoiceActive = nil;
    } else if (session) WCInputVoiceCleanup(session);
}
void WCGestureInputVoiceSettingsChanged(void) {
    if (WCInputVoiceActive && !WCInputVoiceValid(WCInputVoiceActive)) WCGestureInputVoiceCancel();
}
static void WCInputVoiceUpdateHUD(WCInputVoiceSession *session) {
    if (!WCInputVoiceValid(session)) { WCGestureInputVoiceCancel(); return; }
    NSTimeInterval elapsed = session.limitReached ? 60 : session.recorder.currentTime;
    if (!session.limitReached && elapsed >= 59.9) {
        session.limitReached = YES;
        [session.recorder stop];
        WCInputVoiceRestoreAudio(session);
    }
    session.hud.text = session.cancelOnRelease ? @"松开取消" :
        [NSString stringWithFormat:@"%.0f 秒\n%@", ceil(elapsed), session.limitReached ? @"已达 60 秒，松开发送" : @"松开发送，上滑取消"];
    session.hud.backgroundColor = session.cancelOnRelease ? [UIColor.systemRedColor colorWithAlphaComponent:.88] : [UIColor.blackColor colorWithAlphaComponent:.76];
}
static void WCInputVoiceStart(WCInputVoiceSession *session) {
    if (!session.pressed || !WCInputVoiceValid(session)) { if (WCInputVoiceActive == session) WCInputVoiceCleanup(session); return; }
    AVAudioSession *audio = AVAudioSession.sharedInstance;
    session.previousCategory = audio.category;
    session.previousMode = audio.mode;
    session.previousOptions = audio.categoryOptions;
    NSError *error = nil;
    if (![audio setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeDefault options:0 error:&error]) {
        WCShowToast(error.localizedDescription ?: @"无法开启麦克风"); WCInputVoiceCleanup(session); return;
    }
    session.ownsAudioSession = YES;
    if (![audio setActive:YES error:&error]) { WCShowToast(@"麦克风正忙"); WCInputVoiceCleanup(session); return; }
    session.directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"OneWxVoice-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    if (![NSFileManager.defaultManager createDirectoryAtURL:session.directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        WCShowToast(@"无法创建录音文件"); WCInputVoiceCleanup(session); return;
    }
    NSDictionary *settings = @{AVFormatIDKey:@(kAudioFormatLinearPCM), AVSampleRateKey:@16000,
        AVNumberOfChannelsKey:@1, AVLinearPCMBitDepthKey:@16, AVLinearPCMIsFloatKey:@NO, AVLinearPCMIsBigEndianKey:@NO};
    session.recorder = [[AVAudioRecorder alloc] initWithURL:[session.directory URLByAppendingPathComponent:@"recording.wav"] settings:settings error:&error];
    session.recorder.delegate = session;
    if (!session.recorder || ![session.recorder recordForDuration:60]) {
        WCShowToast(error.localizedDescription ?: @"录音启动失败"); WCInputVoiceCleanup(session); return;
    }
    UILabel *hud = [UILabel new];
    hud.textColor = UIColor.whiteColor; hud.numberOfLines = 2; hud.textAlignment = NSTextAlignmentCenter;
    hud.font = [UIFont systemFontOfSize:16]; hud.layer.cornerRadius = 18; hud.clipsToBounds = YES;
    hud.userInteractionEnabled = NO;
    UIView *host = session.source.window;
    hud.frame = CGRectMake((host.bounds.size.width-240)/2, MAX(host.safeAreaInsets.top+60,host.bounds.size.height*.32),240,100);
    hud.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    session.hud = hud; [host addSubview:hud]; WCInputVoiceUpdateHUD(session);
    __weak WCInputVoiceSession *weak = session;
    session.timer = [NSTimer timerWithTimeInterval:.1 repeats:YES block:^(__unused NSTimer *timer) { WCInputVoiceSession *live=weak; if(live)WCInputVoiceUpdateHUD(live); }];
    [NSRunLoop.mainRunLoop addTimer:session.timer forMode:NSRunLoopCommonModes];
    if ([NSUserDefaults.standardUserDefaults boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
}
static void WCInputVoiceInstallObservers(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *name in @[UIApplicationWillResignActiveNotification,AVAudioSessionInterruptionNotification]) {
            [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { WCGestureInputVoiceCancel(); }];
        }
        [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if ([note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue]==AVAudioSessionRouteChangeReasonOldDeviceUnavailable) WCGestureInputVoiceCancel();
        }];
    });
}
static void WCInputVoiceBegin(UIView *source, UILongPressGestureRecognizer *gesture) {
    WCGestureInputVoiceCancel();
    UIViewController *controller = WCViewControllerForResponder(source);
    NSString *account = WCCurrentUserWXID(), *peer = WCGestureLocalChatSession(controller);
    if (!WCInputVoiceAllowed() || !source.window || !peer.length || !account.length || controller != WCVisibleChatControllerGet()) return;
    WCInputVoiceInstallObservers();
    WCInputVoiceSession *session = [WCInputVoiceSession new];
    session.source=source;session.controller=controller;session.account=account;session.peer=peer;
    session.pressed=YES;session.origin=[gesture locationInView:source.window]; WCInputVoiceActive=session;
    // Public selectors invoked dynamically avoid deprecated SDK declarations on iOS 17+.
    void (^permission)(BOOL) = ^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!session.pressed || WCInputVoiceActive!=session) return;
            if (!granted) { WCShowToast(@"请在系统设置允许微信使用麦克风"); WCInputVoiceCleanup(session); return; }
            WCInputVoiceStart(session);
        });
    };
    Class application=NSClassFromString(@"AVAudioApplication");
    SEL modern=NSSelectorFromString(@"requestRecordPermissionWithCompletionHandler:");
    if ([application respondsToSelector:modern]) ((void (*)(id,SEL,id))objc_msgSend)(application,modern,permission);
    else {
        SEL legacy=NSSelectorFromString(@"requestRecordPermission:");
        if ([AVAudioSession.sharedInstance respondsToSelector:legacy]) ((void (*)(id,SEL,id))objc_msgSend)(AVAudioSession.sharedInstance,legacy,permission);
        else { WCShowToast(@"无法请求麦克风权限"); WCInputVoiceCleanup(session); }
    }
}
static void WCInputVoiceFinish(WCInputVoiceSession *session) {
    session.pressed=NO;
    if (!WCInputVoiceValid(session) || session.cancelOnRelease || !session.recorder) { WCInputVoiceCleanup(session); return; }
    NSTimeInterval seconds=session.limitReached?60:session.recorder.currentTime;
    [session.timer invalidate];session.timer=nil;[session.recorder stop];WCInputVoiceRestoreAudio(session);
    if (seconds<.5) { WCShowToast(@"录音时间太短");WCInputVoiceCleanup(session);return; }
    session.encoding=YES;session.hud.text=@"正在发送语音…";
    NSURL *source=session.recorder.url,*destination=[session.directory URLByAppendingPathComponent:@"voice.silk"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        NSUInteger duration=0;BOOL encoded=WCGestureEncodeRecordedVoice(source,destination,&duration);
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL valid=WCInputVoiceValid(session);
            if (valid && (!encoded || !WCGestureSendRecordedVoiceFile(destination.path,duration,session.peer))) WCShowToast(@"语音发送失败");
            session.encoding=NO;WCInputVoiceCleanup(session);
        });
    });
}
void WCGestureInputVoiceHandle(UIView *source, UILongPressGestureRecognizer *gesture) {
    if (gesture.state==UIGestureRecognizerStateBegan) { WCInputVoiceBegin(source,gesture); return; }
    WCInputVoiceSession *session=WCInputVoiceActive;
    if (!session || session.source!=source || session.encoding) return;
    if (gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateEnded) {
        session.cancelOnRelease=[gesture locationInView:source.window].y < session.origin.y-60;
        if (gesture.state==UIGestureRecognizerStateEnded) WCInputVoiceFinish(session);
        else if (session.recorder) WCInputVoiceUpdateHUD(session);
    } else if (gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) WCGestureInputVoiceCancel();
}
@implementation WCInputVoiceSession
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    if (WCInputVoiceActive==self) { WCShowToast(@"录音中断");WCGestureInputVoiceCancel(); }
}
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (WCInputVoiceActive!=self || !self.pressed) return;
    if (!flag) { WCShowToast(@"录音中断");WCGestureInputVoiceCancel();return; }
    self.limitReached=YES;WCInputVoiceRestoreAudio(self);WCInputVoiceUpdateHUD(self);
}
@end
