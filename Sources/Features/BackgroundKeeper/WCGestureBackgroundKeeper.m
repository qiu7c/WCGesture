#import "Sources/API/WCGestureInternal.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface WCGestureBackgroundKeeper : NSObject
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskIdentifier;
@property (nonatomic, strong, nullable) NSTimer *renewalTimer;
@property (nonatomic, strong, nullable) AVAudioPlayer *silentPlayer;
@property (nonatomic, assign) BOOL audioSessionActivated;
@property (nonatomic, copy) NSString *previousCategory;
@property (nonatomic, copy) NSString *previousMode;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousOptions;
+ (instancetype)sharedKeeper;
- (void)enterBackground;
- (void)leaveBackground;
- (void)stopSilentAudio;
@end

@implementation WCGestureBackgroundKeeper

+ (instancetype)sharedKeeper {
    static WCGestureBackgroundKeeper *keeper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keeper = [WCGestureBackgroundKeeper new];
        keeper.taskIdentifier = UIBackgroundTaskInvalid;
    });
    return keeper;
}

- (BOOL)enabled {
    return WCGestureEnabled(WCGestureBackgroundKeepAliveEnabledKey);
}

- (void)endCurrentTask {
    UIBackgroundTaskIdentifier identifier = self.taskIdentifier;
    if (identifier == UIBackgroundTaskInvalid) return;
    self.taskIdentifier = UIBackgroundTaskInvalid;
    [UIApplication.sharedApplication endBackgroundTask:identifier];
}

- (void)beginFreshTask {
    [self endCurrentTask];
    UIApplication *application = UIApplication.sharedApplication;
    __weak typeof(self) weakSelf = self;
    __block UIBackgroundTaskIdentifier identifier = UIBackgroundTaskInvalid;
    identifier = [application beginBackgroundTaskWithExpirationHandler:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.taskIdentifier == identifier) self.taskIdentifier = UIBackgroundTaskInvalid;
        if (identifier != UIBackgroundTaskInvalid) [application endBackgroundTask:identifier];
    }];
    self.taskIdentifier = identifier;
}

static void WCGestureAppendLittleEndian16(NSMutableData *data, uint16_t value) {
    uint16_t encoded = CFSwapInt16HostToLittle(value);
    [data appendBytes:&encoded length:sizeof(encoded)];
}

static void WCGestureAppendLittleEndian32(NSMutableData *data, uint32_t value) {
    uint32_t encoded = CFSwapInt32HostToLittle(value);
    [data appendBytes:&encoded length:sizeof(encoded)];
}

- (NSURL *)silentAudioURL {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *supportURL = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                            inDomains:NSUserDomainMask].firstObject;
    NSURL *directoryURL = [supportURL URLByAppendingPathComponent:@"OneWx/Background" isDirectory:YES];
    NSURL *audioURL = [directoryURL URLByAppendingPathComponent:@"silence.wav" isDirectory:NO];
    if ([fileManager fileExistsAtPath:audioURL.path]) return audioURL;

    NSError *directoryError = nil;
    if (![fileManager createDirectoryAtURL:directoryURL
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&directoryError]) {
        NSLog(@"[One Wx] 创建后台静音音频目录失败：%@", directoryError.localizedDescription ?: @"未知错误");
        return nil;
    }

    const uint32_t sampleRate = 8000;
    const uint16_t channels = 1;
    const uint16_t bitsPerSample = 16;
    const uint32_t dataSize = sampleRate * channels * (bitsPerSample / 8);
    NSMutableData *wave = [NSMutableData dataWithCapacity:44 + dataSize];
    [wave appendBytes:"RIFF" length:4];
    WCGestureAppendLittleEndian32(wave, 36 + dataSize);
    [wave appendBytes:"WAVEfmt " length:8];
    WCGestureAppendLittleEndian32(wave, 16);
    WCGestureAppendLittleEndian16(wave, 1);
    WCGestureAppendLittleEndian16(wave, channels);
    WCGestureAppendLittleEndian32(wave, sampleRate);
    WCGestureAppendLittleEndian32(wave, sampleRate * channels * (bitsPerSample / 8));
    WCGestureAppendLittleEndian16(wave, channels * (bitsPerSample / 8));
    WCGestureAppendLittleEndian16(wave, bitsPerSample);
    [wave appendBytes:"data" length:4];
    WCGestureAppendLittleEndian32(wave, dataSize);
    [wave increaseLengthBy:dataSize];

    NSError *writeError = nil;
    if (![wave writeToURL:audioURL options:NSDataWritingAtomic error:&writeError]) {
        NSLog(@"[One Wx] 写入后台静音音频失败：%@", writeError.localizedDescription ?: @"未知错误");
        return nil;
    }
    return audioURL;
}

- (void)playSilentAudioIfNeeded {
    NSError *sessionError = nil;
    AVAudioSession *session = AVAudioSession.sharedInstance;
    // Do not replace a recording/call session; retry after the native session ends.
    if ([session.category isEqualToString:AVAudioSessionCategoryRecord]
        || [session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        [self.silentPlayer stop];
        self.silentPlayer = nil;
        self.audioSessionActivated = NO;
        return;
    }
    if (self.silentPlayer.isPlaying) return;
    if (!self.audioSessionActivated) {
        self.previousCategory = session.category;
        self.previousMode = session.mode;
        self.previousOptions = session.categoryOptions;
    }
    if (![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault
                      options:AVAudioSessionCategoryOptionMixWithOthers
                        error:&sessionError] ||
        ![session setActive:YES error:&sessionError]) {
        NSLog(@"[One Wx] 启动后台静音音频会话失败：%@", sessionError.localizedDescription ?: @"未知错误");
        self.audioSessionActivated = YES;
        [self stopSilentAudio];
        return;
    }
    self.audioSessionActivated = YES;
    NSURL *audioURL = [self silentAudioURL];
    if (!audioURL) { [self stopSilentAudio]; return; }
    NSError *playerError = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL error:&playerError];
    if (!player) {
        NSLog(@"[One Wx] 创建后台静音播放器失败：%@", playerError.localizedDescription ?: @"未知错误");
        [self stopSilentAudio];
        return;
    }
    player.numberOfLoops = -1;
    [player prepareToPlay];
    self.silentPlayer = player;
    if (![player play]) {
        NSLog(@"[One Wx] 后台静音音频未能开始播放");
        [self stopSilentAudio];
    }
}

- (void)stopSilentAudio {
    [self.silentPlayer stop];
    self.silentPlayer = nil;
    AVAudioSession *session = AVAudioSession.sharedInstance;
    if (self.audioSessionActivated && [session.category isEqualToString:AVAudioSessionCategoryPlayback]
        && [session.mode isEqualToString:AVAudioSessionModeDefault]
        && session.categoryOptions == AVAudioSessionCategoryOptionMixWithOthers) {
        [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        if (self.previousCategory.length && self.previousMode.length) {
            [session setCategory:self.previousCategory mode:self.previousMode options:self.previousOptions error:nil];
        }
    }
    self.audioSessionActivated = NO;
    self.previousCategory = nil;
    self.previousMode = nil;
}

- (void)requestMoreTime:(NSTimer *)timer {
    (void)timer;
    if (![self enabled]) {
        [self leaveBackground];
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if (application.applicationState != UIApplicationStateBackground) return;
    if (application.backgroundTimeRemaining < 30.0) {
        [self playSilentAudioIfNeeded];
        [self beginFreshTask];
    }
}

- (void)enterBackground {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self enterBackground]; });
        return;
    }
    if (![self enabled]) return;
    [self.renewalTimer invalidate];
    [self beginFreshTask];
    self.renewalTimer = [NSTimer timerWithTimeInterval:25.0
                                               target:self
                                             selector:@selector(requestMoreTime:)
                                             userInfo:nil
                                              repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.renewalTimer forMode:NSRunLoopCommonModes];
    [self.renewalTimer fire];
    NSLog(@"[One Wx] 后台保持已启动");
}

- (void)leaveBackground {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self leaveBackground]; });
        return;
    }
    [self.renewalTimer invalidate];
    self.renewalTimer = nil;
    [self endCurrentTask];
    [self stopSilentAudio];
}

@end

void WCGestureBackgroundKeeperEnterBackground(void) {
    [[WCGestureBackgroundKeeper sharedKeeper] enterBackground];
}

void WCGestureBackgroundKeeperWillEnterForeground(void) {
    [[WCGestureBackgroundKeeper sharedKeeper] leaveBackground];
}

void WCGestureBackgroundKeeperSettingsDidChange(void) {
    WCGestureBackgroundKeeper *keeper = [WCGestureBackgroundKeeper sharedKeeper];
    if (![keeper enabled]) {
        [keeper leaveBackground];
    } else if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
        [keeper enterBackground];
    }
}
