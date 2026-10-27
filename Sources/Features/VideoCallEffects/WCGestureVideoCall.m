#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import <string.h>
#import <stdlib.h>
#import "Sources/API/WCGestureInternal.h"

NSString *const WCGestureVideoCallStateDidChangeNotification = @"WCGestureVideoCallStateDidChangeNotification";

// Protocols describe only the checked WeChat 8.0.79 ABI; no private class is linked.
@protocol WCVideoEffectEngine <NSObject>
- (instancetype)initWithSceneType:(long long)scene roleType:(long long)role energyController:(id)energy
              dataReportCallback:(id)report isAllowFp16:(BOOL)fp16 enableRci:(BOOL)rci beautyAssetsDirectory:(id)path;
- (void)runSyncOnWeEffectThread:(void (^)(void))block;
- (id)renderEffectImp:(id)frame pixelBufferFlipX:(BOOL)flip;
- (void)stopProcess;
@end
@protocol WCVideoEffectFrame <NSObject>
@property (nonatomic) CMSampleBufferRef sampleBuffer;
@property (nonatomic) CVPixelBufferRef pixelBuffer;
@property (nonatomic) BOOL isFront;
@property (nonatomic) BOOL mirror;
@property (nonatomic) long long renderRotation;
@end
static BOOL WCVideoOnEffectThread(id<WCVideoEffectEngine> engine, void (^work)(void)) {
    __block BOOL completed = NO;
    @try {
        [engine runSyncOnWeEffectThread:^{
            // An exception on the effect queue cannot be caught by the dispatching queue.
            @try { work(); completed = YES; }
            @catch (__unused NSException *exception) {}
        }];
    } @catch (__unused NSException *exception) {}
    return completed;
}

static BOOL WCVideoHas(id object, NSString *name, NSUInteger arguments) {
    if (!object || ![object respondsToSelector:NSSelectorFromString(name)]) return NO;
    NSMethodSignature *signature = [object methodSignatureForSelector:NSSelectorFromString(name)];
    return signature && signature.numberOfArguments == arguments + 2;
}
static id WCVideoGet(id object, NSString *name) {
    if (!WCVideoHas(object, name, 0)) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:NSSelectorFromString(name)];
    if (signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
}
static void WCVideoCall(id object, NSString *name) {
    if (WCVideoHas(object, name, 0)) ((void (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
}
static void WCVideoSetObject(id object, NSString *name, id value) {
    if (WCVideoHas(object, name, 1)) ((void (*)(id, SEL, id))objc_msgSend)(object, NSSelectorFromString(name), value);
}
static void WCVideoNotify(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:WCGestureVideoCallStateDidChangeNotification object:nil];
    });
}
static NSString *WCVideoString(id object, NSString *key) {
    id value = WCTweakSafeValue(object, key);
    return [value isKindOfClass:NSString.class] ? value : @"";
}

@interface WCVideoBeautySession : NSObject
@property (nonatomic, strong) id<WCVideoEffectEngine> engine;
@property (nonatomic, strong) id logic;
@property (nonatomic, strong) id package;
@property (nonatomic, strong) id suite;
@property (nonatomic, copy) NSString *account;
@property (nonatomic) NSUInteger generation;
@end
@implementation WCVideoBeautySession
@end

static void WCVideoStopBeauty(WCVideoBeautySession *session) {
    if (!session) return;
    @try {
        WCVideoOnEffectThread(session.engine, ^{
            @try { WCVideoCall(session.logic, @"saveAllEffectBeautyValues"); }
            @catch (__unused NSException *exception) {}
            WCVideoCall(session.engine, @"stopProcess");
        });
    } @catch (__unused NSException *exception) {}
}

static NSArray<NSDictionary *> *WCVideoDescribeBeauty(WCVideoBeautySession *session) {
    NSMutableArray *result = [NSMutableArray array];
    id items = WCVideoGet(session.suite, @"items");
    if (![items isKindOfClass:NSArray.class]) return result;
    for (id item in items) {
        NSString *identifier = WCVideoString(item, @"itemId"), *title = WCVideoString(item, @"displayName");
        NSNumber *minimum = WCTweakSafeValue(item, @"minimumValue"), *maximum = WCTweakSafeValue(item, @"maximumValue");
        NSNumber *value = WCTweakSafeValue(item, @"value");
        if (!identifier.length || !title.length || ![minimum isKindOfClass:NSNumber.class] ||
            ![maximum isKindOfClass:NSNumber.class] || ![value isKindOfClass:NSNumber.class] ||
            !isfinite(minimum.doubleValue) || !isfinite(maximum.doubleValue) ||
            !isfinite(value.doubleValue) || maximum.doubleValue <= minimum.doubleValue) continue;
        [result addObject:@{@"id":identifier, @"title":title, @"min":minimum, @"max":maximum, @"value":value}];
    }
    return result;
}

static BOOL WCVideoApplySavedValues(id logic, id suite, NSDictionary *values) {
    BOOL changed = NO;
    id items = WCVideoGet(suite, @"items");
    if (![items isKindOfClass:NSArray.class]) return NO;
    for (id item in items) {
        NSNumber *value = values[WCVideoString(item, @"itemId")];
        double minimum = [WCTweakSafeValue(item, @"minimumValue") doubleValue];
        double maximum = [WCTweakSafeValue(item, @"maximumValue") doubleValue];
        if (![value isKindOfClass:NSNumber.class] || !isfinite(value.doubleValue) ||
            !isfinite(minimum) || !isfinite(maximum) || maximum <= minimum) continue;
        double clamped = MIN(maximum, MAX(minimum, value.doubleValue));
        if ([WCTweakSafeValue(item, @"value") doubleValue] == clamped) continue;
        WCTweakSetValue(item, @"value", @(clamped));
        WCVideoSetObject(logic, @"applyBeautyItem:", item); changed = YES;
    }
    return changed;
}

static char WCVideoEndedKey;
static char WCVideoCaptureMirrorKey;
@interface WCVideoCaptureMirrorState : NSObject
@property (nonatomic, weak) id device;
@property (nonatomic) BOOL originalMirror;
@property (nonatomic) BOOL originalAutomatic;
@property (nonatomic) BOOL captured;
@property (nonatomic) BOOL applied;
@property (nonatomic) BOOL pending;
@property (nonatomic) BOOL forceRestore;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, copy) NSString *account;
@end
@implementation WCVideoCaptureMirrorState
@end
static NSHashTable *WCVideoCaptureConnections(void) {
    static NSHashTable *connections;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ connections = [NSHashTable weakObjectsHashTable]; });
    return connections;
}
static void WCVideoRefreshCaptureMirroring(void);
static void WCVideoCaptureMirrorUpdate(id device, id value, BOOL forceRestore);

@interface WCVideoCallCoordinator : NSObject {
    CVPixelBufferPoolRef _pool;
    size_t _width;
    size_t _height;
    OSType _format;
}
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) dispatch_queue_t controlQueue;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic) BOOL renderOrientationReady;
@property (nonatomic) BOOL renderFlipped;
@property (nonatomic, strong) WCVideoBeautySession *beauty;
@property (atomic, weak) UIViewController *host;
@property (nonatomic, weak) UIView *talkingView;
@property (atomic, weak) id device;
@property (atomic, weak) UIViewController *editor;
@property (nonatomic, weak) UIButton *button;
@property (atomic) BOOL active;
@property (atomic) BOOL suspended;
@property (atomic) BOOL beautyEnabled;
@property (atomic) BOOL stickerEnabled;
@property (atomic) BOOL mirrorEnabled;
@property (atomic) BOOL frameFailed;
@property (atomic) NSUInteger generation;
@property (atomic, copy) NSString *account;
@property (atomic, copy) NSString *status;
@property (atomic, copy) NSArray<NSDictionary *> *beautyItems;
@property (nonatomic) BOOL preparing;
@property (nonatomic) BOOL attempted;
@property (atomic, strong) CIImage *sticker;
@property (atomic, strong) UIImage *stickerSource;
@property (atomic, copy) NSDictionary *stickerPlacement;
- (void)refresh;
- (void)prepare;
- (void)retire;
- (void)layoutButton;
- (CVPixelBufferRef)newPixelsLike:(CVPixelBufferRef)pixels CF_RETURNS_RETAINED;
@end

static WCVideoCallCoordinator *WCVideoCoordinator(void) {
    static WCVideoCallCoordinator *coordinator;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ coordinator = [WCVideoCallCoordinator new]; });
    return coordinator;
}

static void WCVideoCaptureMirrorUpdate(id device, id value, BOOL forceRestore) {
    if (![value isKindOfClass:AVCaptureConnection.class]) return;
    AVCaptureConnection *connection = value;
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    BOOL wanted = device && !forceRestore && coordinator.active && coordinator.host && coordinator.mirrorEnabled &&
        (!coordinator.device || coordinator.device == device) &&
        !coordinator.suspended && !coordinator.frameFailed && ![WCTweakSafeValue(device, @"m_usingBackCamera") boolValue];
    @synchronized (connection) {
        WCVideoCaptureMirrorState *state = objc_getAssociatedObject(connection, &WCVideoCaptureMirrorKey);
        if (!state && (!wanted || !connection.isVideoMirroringSupported)) return;
        if (!state) {
            state = [WCVideoCaptureMirrorState new]; state.device = device;
            state.generation = coordinator.generation; state.account = coordinator.account;
            objc_setAssociatedObject(connection, &WCVideoCaptureMirrorKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSHashTable *connections = WCVideoCaptureConnections();
            @synchronized (connections) { [connections addObject:connection]; }
        }
        state.forceRestore = state.forceRestore || forceRestore;
        if (state.pending || (wanted && state.applied && !state.forceRestore &&
            connection.videoMirrored == !state.originalMirror && !connection.automaticallyAdjustsVideoMirroring)) return;
        state.pending = YES;
        dispatch_async(coordinator.controlQueue, ^{
            @synchronized (connection) {
                if (objc_getAssociatedObject(connection, &WCVideoCaptureMirrorKey) != state) return;
                BOOL enabled = device && !state.forceRestore && coordinator.active && coordinator.host && coordinator.mirrorEnabled &&
                    (!coordinator.device || coordinator.device == device) &&
                    state.generation == coordinator.generation && [state.account isEqualToString:coordinator.account] &&
                    !coordinator.suspended && !coordinator.frameFailed && state.device == device &&
                    ![WCTweakSafeValue(device, @"m_usingBackCamera") boolValue];
                @try {
                    if (enabled && connection.isVideoMirroringSupported) {
                        if (!state.captured) {
                            state.originalMirror = connection.videoMirrored;
                            state.originalAutomatic = connection.automaticallyAdjustsVideoMirroring;
                            state.captured = YES;
                        }
                        connection.automaticallyAdjustsVideoMirroring = NO;
                        connection.videoMirrored = !state.originalMirror;
                        state.applied = YES;
                    } else {
                        if (state.captured) {
                            if (connection.isVideoMirroringSupported) connection.videoMirrored = state.originalMirror;
                            connection.automaticallyAdjustsVideoMirroring = state.originalAutomatic;
                        }
                        objc_setAssociatedObject(connection, &WCVideoCaptureMirrorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        NSHashTable *connections = WCVideoCaptureConnections();
                        @synchronized (connections) { [connections removeObject:connection]; }
                    }
                } @catch (__unused NSException *exception) {
                    coordinator.status = @"相机镜像暂不可用"; WCVideoNotify();
                } @finally { state.pending = NO; }
            }
        });
    }
}
static void WCVideoRefreshCaptureMirroring(void) {
    NSHashTable *table = WCVideoCaptureConnections(); NSArray *connections;
    @synchronized (table) { connections = table.allObjects; }
    for (AVCaptureConnection *connection in connections) {
        WCVideoCaptureMirrorState *state = objc_getAssociatedObject(connection, &WCVideoCaptureMirrorKey);
        WCVideoCaptureMirrorUpdate(state.device, connection, NO);
    }
}

static WCVideoBeautySession *WCVideoBuildBeauty(NSString *account, id service, NSString **failure) {
    Class managerClass = NSClassFromString(@"MMWeEffectManager");
    Class packageClass = NSClassFromString(@"MMLiveBeautyPackage");
    Class logicClass = NSClassFromString(@"MMLiveBeautyLogic");
    Class pathClass = NSClassFromString(@"MMLivePathUtil");
    if (!service) {
        *failure = @"微信美颜资源服务尚未就绪，请接通后重试";
        return nil;
    }
    NSString *initializer = @"initWithSceneType:roleType:energyController:dataReportCallback:isAllowFp16:enableRci:beautyAssetsDirectory:";
    NSArray<NSDictionary *> *requirements = @[
        @{@"class":@"MMWeEffectManager", @"selector":initializer, @"message":@"美颜引擎初始化接口不可用"},
        @{@"class":@"MMWeEffectManager", @"selector":@"runSyncOnWeEffectThread:", @"message":@"美颜效果线程接口不可用"},
        @{@"class":@"MMWeEffectManager", @"selector":@"renderEffectImp:pixelBufferFlipX:", @"message":@"美颜帧渲染接口不可用"}];
    for (NSDictionary *requirement in requirements) {
        Class cls = NSClassFromString(requirement[@"class"]);
        if (!class_getInstanceMethod(cls, NSSelectorFromString(requirement[@"selector"]))) {
            NSLog(@"[One Wx] Beauty missing instance method %@ %@", requirement[@"class"], requirement[@"selector"]);
            *failure = requirement[@"message"]; return nil;
        }
    }
    if (!WCVideoHas(service, @"latestReadyResVersion:subResType:", 2)) {
        *failure = @"微信美颜资源版本查询不可用";
        return nil;
    }
    if (!WCVideoHas(pathClass, @"liveStaticResourcesPathWithType:subType:version:", 3)) {
        *failure = @"微信美颜资源目录查询不可用";
        return nil;
    }
    if (!WCVideoHas(packageClass, @"beautyPackageInLocalDirectory:withConfigurationPath:capabilities:", 3)) {
        *failure = @"微信美颜资源包加载接口不可用";
        return nil;
    }
    unsigned int version = ((unsigned int (*)(id, SEL, unsigned int, unsigned int))objc_msgSend)(
        service, NSSelectorFromString(@"latestReadyResVersion:subResType:"), 184, 3);
    NSString *directory = ((id (*)(id, SEL, unsigned int, unsigned int, unsigned int))objc_msgSend)(
        pathClass, NSSelectorFromString(@"liveStaticResourcesPathWithType:subType:version:"), 184, 3, version);
    if (![directory isKindOfClass:NSString.class] || !directory.length ||
        ![NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:@"contents.json"]]) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCVideoCall(service, @"checkResourcesOnInitialization"); });
        *failure = @"微信美颜资源尚未就绪，可稍后重新检查";
        return nil;
    }
    id capabilities = [NSClassFromString(@"MMLiveBeautyCapabilities") new];
    id package = ((id (*)(id, SEL, id, id, id))objc_msgSend)(packageClass,
        NSSelectorFromString(@"beautyPackageInLocalDirectory:withConfigurationPath:capabilities:"),
        directory, [directory stringByAppendingPathComponent:@"contents.json"], capabilities);
    NSString *assets = WCVideoString(package, @"opaqueResourcesPath");
    id suite = WCVideoGet(package, @"defaultSuite");
    if (!package || !suite || !assets.length || !logicClass) {
        *failure = @"微信美颜资源包不可用";
        return nil;
    }
    long long scene = 0;
    SEL generationSelector = NSSelectorFromString(@"isNewerThaniPhoneGeneration:subGeneration:");
    if (WCVideoHas(UIDevice.currentDevice, NSStringFromSelector(generationSelector), 2) &&
        ((BOOL (*)(id, SEL, long long, long long))objc_msgSend)(UIDevice.currentDevice, generationSelector, 12, 0)) scene = 7;
    BOOL rci = class_getInstanceMethod(managerClass, NSSelectorFromString(@"isRCIEnableForRole:")) &&
        class_getInstanceMethod(managerClass, NSSelectorFromString(@"renderEffectRciImp:flipX:"));
    id<WCVideoEffectEngine> engine = [(id<WCVideoEffectEngine>)[managerClass alloc]
        initWithSceneType:scene roleType:0 energyController:nil dataReportCallback:nil
        isAllowFp16:NO enableRci:rci beautyAssetsDirectory:assets];
    if (!engine) { *failure = @"微信美颜引擎初始化失败"; return nil; }
    @try {
    id logic = [logicClass new];
    id mappedKV = nil;
    Class kvClass = NSClassFromString(@"MemoryMappedKV");
    if (WCVideoHas(kvClass, @"memoryMappedKVWithID:", 1))
        mappedKV = ((id (*)(id, SEL, id))objc_msgSend)(kvClass, NSSelectorFromString(@"memoryMappedKVWithID:"),
            [@"com.qiu7c.onewx.video-call.beauty." stringByAppendingString:account]);
    if (!logic || !mappedKV || !WCVideoHas(logic, @"applyBeautyItem:", 1) ||
        !WCVideoHas(logic, @"activateBeautySuite:", 1)) {
        WCVideoOnEffectThread(engine, ^{ WCVideoCall(engine, @"stopProcess"); });
        *failure = @"当前微信版本不支持美颜参数配置";
        return nil;
    }
    WCVideoSetObject(logic, @"setMappedKV:", mappedKV);
    WCVideoSetObject(logic, @"setBeautyPackage:", package);
    WCVideoSetObject(logic, @"setEffectManager:", engine);
    NSDictionary *values = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureVideoCallBeautyValuesKey];
    BOOL initialized = WCVideoOnEffectThread(engine, ^{
        WCVideoCall(logic, @"initSkinSeg");
        WCVideoCall(logic, @"initBeauty");
        WCVideoSetObject(logic, @"activateBeautySuite:", suite);
        WCVideoApplySavedValues(logic, suite, values);
    });
    if (!initialized) {
        WCVideoOnEffectThread(engine, ^{ WCVideoCall(engine, @"stopProcess"); });
        *failure = @"微信美颜参数初始化失败";
        return nil;
    }
    WCVideoBeautySession *session = [WCVideoBeautySession new];
    session.engine = engine; session.logic = logic; session.package = package;
    session.suite = suite; session.account = account;
    return session;
    } @catch (__unused NSException *exception) {
        @try { WCVideoOnEffectThread(engine, ^{ WCVideoCall(engine, @"stopProcess"); }); }
        @catch (__unused NSException *cleanupException) {}
        *failure = @"微信美颜初始化未完成";
        return nil;
    }
}

// Resolve native control geometry on each layout; the waiting and connected views differ.
static CGRect WCVideoCallControlsRect(UIView *container, id owner) {
    CGRect result = CGRectNull;
    for (NSString *key in @[@"m_micButton", @"m_speakerButton", @"m_videoModeButton",
        @"m_flipCameraView", @"m_flipCameraButton", @"m_hangupBtn", @"m_hangupButton"]) {
        id value = WCTweakSafeValue(owner, key);
        if (![value isKindOfClass:UIView.class]) continue;
        UIView *control = value;
        if (![control isDescendantOfView:container] || !control.window) continue;
        BOOL visible = YES;
        for (UIView *parent = control; parent && parent != container; parent = parent.superview) {
            if (parent.hidden || parent.alpha < .01) { visible = NO; break; }
        }
        if (!visible || CGRectIsEmpty(control.bounds)) continue;
        CGRect rect = [control convertRect:control.bounds toView:container];
        if (!isfinite(rect.origin.x) || !isfinite(rect.origin.y) || !isfinite(rect.size.width) ||
            !isfinite(rect.size.height) || CGRectIsEmpty(rect) ||
            !CGRectIntersectsRect(container.bounds, rect) || CGRectGetMidY(rect) < CGRectGetMidY(container.bounds)) continue;
        result = CGRectIsNull(result) ? rect : CGRectUnion(result, rect);
    }
    return result;
}

@implementation WCVideoCallCoordinator
- (instancetype)init {
    if ((self = [super init])) {
        _lock = [NSLock new];
        _controlQueue = dispatch_queue_create("com.qiu7c.onewx.video-call.control", DISPATCH_QUEUE_SERIAL);
        _status = @"请在视频通话中调节";
        _account = @"";
    }
    return self;
}
- (void)refresh {
    self.frameFailed = NO;
    self.beautyEnabled = WCGestureEnabled(WCGestureVideoCallBeautyEnabledKey);
    self.stickerEnabled = WCGestureEnabled(WCGestureVideoCallStickerEnabledKey);
    self.mirrorEnabled = WCGestureEnabled(WCGestureVideoCallMirrorEnabledKey);
    WCVideoRefreshCaptureMirroring();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self layoutButton];
        if (!self.stickerEnabled && self.editor) WCGestureVideoCallCancelSticker(self.editor);
    });
    if (!self.beautyEnabled) {
        dispatch_async(self.controlQueue, ^{
            [self.lock lock];
            @try {
                WCVideoBeautySession *old = self.beauty;
                self.beauty = nil; self.beautyItems = @[]; self.attempted = NO;
                WCVideoStopBeauty(old);
                if (!self.stickerEnabled && !self.mirrorEnabled) {
                    if (self->_pool) { CVPixelBufferPoolRelease(self->_pool); self->_pool = NULL; }
                    self.context = nil;
                }
            } @catch (__unused NSException *exception) {} @finally { [self.lock unlock]; }
            WCVideoNotify();
        });
    } else {
        dispatch_async(self.controlQueue, ^{
            [self.lock lock];
            @try {
                WCVideoBeautySession *session = self.beauty;
                if (session && self.active && self.beautyEnabled && session.generation == self.generation) {
                    __block BOOL changed = NO;
                    NSDictionary *values = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureVideoCallBeautyValuesKey];
                    WCVideoOnEffectThread(session.engine, ^{
                        changed = WCVideoApplySavedValues(session.logic, session.suite, values);
                        if (changed) WCVideoCall(session.logic, @"saveAllEffectBeautyValues");
                    });
                    if (changed) { self.beautyItems = WCVideoDescribeBeauty(session); WCVideoNotify(); }
                }
            } @catch (__unused NSException *exception) {} @finally { [self.lock unlock]; }
        });
        [self prepare];
    }
}
- (void)prepare {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self prepare]; }); return;
    }
    // MMContext/service resolution follows the UI/account context. Resolve here,
    // then retain that service for the asynchronous resource work below.
    if (!self.active || !self.host || self.suspended || !self.beautyEnabled) return;
    id service = nil;
    @try { service = WCServiceForClass(NSClassFromString(@"MMLiveResUpdateMgr")); }
    @catch (__unused NSException *exception) {}
    NSUInteger requestedGeneration = self.generation;
    dispatch_async(self.controlQueue, ^{
        if (requestedGeneration != self.generation || !self.active || !self.host || self.suspended ||
            !self.beautyEnabled || self.preparing || self.attempted) return;
        self.preparing = YES; self.attempted = YES;
        NSUInteger generation = self.generation;
        NSString *account = self.account;
        if (!account.length) {
            self.preparing = NO; self.status = @"尚未获取当前微信账号"; WCVideoNotify(); return;
        }
        self.status = @"正在准备微信美颜资源";
        WCVideoNotify();
        WCVideoBeautySession *candidate = nil;
        NSString *failure = nil;
        @try { candidate = WCVideoBuildBeauty(account, service, &failure); }
        @catch (__unused NSException *exception) { failure = @"微信美颜接口暂不可用"; }
        [self.lock lock];
        @try {
            BOOL current = self.active && self.beautyEnabled && generation == self.generation &&
                [account isEqualToString:self.account];
            if (current && candidate) {
                candidate.generation = generation;
                self.beauty = candidate;
                self.beautyItems = WCVideoDescribeBeauty(candidate);
                self.status = @"微信美颜已就绪";
            } else {
                WCVideoStopBeauty(candidate);
                if (current) self.status = failure ?: @"微信美颜暂不可用";
            }
        } @catch (__unused NSException *exception) {
            self.status = @"微信美颜初始化未完成";
        } @finally { self.preparing = NO; [self.lock unlock]; }
        WCVideoNotify();
    });
}
- (void)retire {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self retire]; }); return;
    }
    self.active = NO; self.generation++;
    self.beautyItems = @[];
    self.frameFailed = NO;
    NSUInteger retirement = self.generation;
    UIViewController *retiringEditor = self.editor; self.editor = nil;
    self.device = nil; self.sticker = nil; self.stickerSource = nil; self.stickerPlacement = nil;
    self.talkingView = nil;
    WCVideoRefreshCaptureMirroring();
    self.status = @"请在视频通话中调节";
    dispatch_async(self.controlQueue, ^{
        [self.lock lock];
        @try {
            WCVideoBeautySession *old = self.beauty;
            self.beauty = nil; self.attempted = NO;
            WCVideoStopBeauty(old);
        } @catch (__unused NSException *exception) {} @finally {
            if (self->_pool) { CVPixelBufferPoolRelease(self->_pool); self->_pool = NULL; }
            self.context = nil;
            [self.lock unlock];
        }
        WCVideoNotify();
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        if (retiringEditor) WCGestureVideoCallCancelSticker(retiringEditor);
        if (self.generation != retirement) return;
        [self.button removeFromSuperview]; self.button = nil;
    });
}
- (void)layoutButton {
    UIViewController *host = self.host;
    BOOL enabled = self.beautyEnabled || self.stickerEnabled || self.mirrorEnabled;
    UIView *talking = self.talkingView;
    BOOL talkingVisible = talking.window && !talking.hidden && ![WCTweakSafeValue(talking, @"isEnding") boolValue];
    BOOL video = talkingVisible ? [WCTweakSafeValue(talking, @"isAllowVideo") boolValue] :
        [WCTweakSafeValue(host, @"isVideoMode") boolValue];
    UIView *container = talkingVisible ? talking : (host.isViewLoaded ? host.view : nil);
    if (!enabled || !container.window || !video || !self.active ||
        CGRectGetWidth(container.bounds) < 180 || CGRectGetHeight(container.bounds) < 180) {
        [self.button removeFromSuperview]; self.button = nil; return;
    }
    UIButton *button = self.button;
    if (button && button.superview != container) {
        [button removeFromSuperview]; self.button = nil; button = nil;
    }
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:@"通话调节" forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        button.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:.35];
        button.layer.cornerRadius = 17;
        __weak WCVideoCallCoordinator *weakSelf = self;
        [button addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
            WCVideoCallCoordinator *strongSelf = weakSelf;
            UIViewController *presenter = strongSelf.host;
            if (!presenter || presenter.presentedViewController) return;
            WCGesturePresentVideoCallSettings(presenter);
        }] forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:button]; self.button = button;
    }
    UIEdgeInsets safe = container.safeAreaInsets;
    CGRect controls = WCVideoCallControlsRect(container, talkingVisible ? (id)talking : (id)host);
    if (CGRectIsNull(controls) && talkingVisible) controls = WCVideoCallControlsRect(container, host);
    CGFloat right = CGRectIsNull(controls) ? CGRectGetWidth(container.bounds) - safe.right - 16 : CGRectGetMaxX(controls);
    CGFloat top = CGRectIsNull(controls) ? CGRectGetHeight(container.bounds) - safe.bottom - 190 : CGRectGetMinY(controls) - 46;
    CGFloat x = MAX(safe.left + 12, MIN(right - 88, CGRectGetWidth(container.bounds) - safe.right - 100));
    CGFloat y = MAX(safe.top + 12, MIN(top, CGRectGetHeight(container.bounds) - safe.bottom - 46));
    CGRect frame = CGRectMake(x, y, 88, 34);
    if (!CGRectEqualToRect(button.frame, frame)) button.frame = frame;
    if (container.subviews.lastObject != button) [container bringSubviewToFront:button];
}
- (CVPixelBufferRef)newPixelsLike:(CVPixelBufferRef)pixels {
    size_t width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels);
    OSType format = CVPixelBufferGetPixelFormatType(pixels);
    if (!width || !height || width > 4096 || height > 4096) return NULL;
    if (!_pool || _width != width || _height != height || _format != format) {
        if (_pool) { CVPixelBufferPoolRelease(_pool); _pool = NULL; }
        NSDictionary *attributes = @{(id)kCVPixelBufferWidthKey:@(width), (id)kCVPixelBufferHeightKey:@(height),
            (id)kCVPixelBufferPixelFormatTypeKey:@(format), (id)kCVPixelBufferIOSurfacePropertiesKey:@{}};
        if (CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attributes, &_pool) != kCVReturnSuccess)
            return NULL;
        _width = width; _height = height; _format = format;
    }
    CVPixelBufferRef result = NULL;
    NSDictionary *limit = @{(id)kCVPixelBufferPoolAllocationThresholdKey:@6};
    if (CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _pool,
        (__bridge CFDictionaryRef)limit, &result) != kCVReturnSuccess) return NULL;
    return result;
}
@end

static BOOL WCVideoCopyPixels(CVPixelBufferRef source, CVPixelBufferRef destination) {
    if (CVPixelBufferGetWidth(source) != CVPixelBufferGetWidth(destination) ||
        CVPixelBufferGetHeight(source) != CVPixelBufferGetHeight(destination) ||
        CVPixelBufferGetPixelFormatType(source) != CVPixelBufferGetPixelFormatType(destination)) return NO;
    size_t planes = CVPixelBufferGetPlaneCount(source);
    if (planes != CVPixelBufferGetPlaneCount(destination) || planes > 3) return NO;
    if (CVPixelBufferLockBaseAddress(source, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) return NO;
    if (CVPixelBufferLockBaseAddress(destination, 0) != kCVReturnSuccess) {
        CVPixelBufferUnlockBaseAddress(source, kCVPixelBufferLock_ReadOnly); return NO;
    }
    BOOL valid = YES;
    for (size_t i = 0; i < MAX((size_t)1, planes); i++) {
        size_t rows = planes ? CVPixelBufferGetHeightOfPlane(source, i) : CVPixelBufferGetHeight(source);
        size_t destinationRows = planes ? CVPixelBufferGetHeightOfPlane(destination, i) : CVPixelBufferGetHeight(destination);
        size_t fromStride = planes ? CVPixelBufferGetBytesPerRowOfPlane(source, i) : CVPixelBufferGetBytesPerRow(source);
        size_t toStride = planes ? CVPixelBufferGetBytesPerRowOfPlane(destination, i) : CVPixelBufferGetBytesPerRow(destination);
        void *from = planes ? CVPixelBufferGetBaseAddressOfPlane(source, i) : CVPixelBufferGetBaseAddress(source);
        void *to = planes ? CVPixelBufferGetBaseAddressOfPlane(destination, i) : CVPixelBufferGetBaseAddress(destination);
        if (!from || !to || !rows || rows != destinationRows || !fromStride || !toStride) { valid = NO; break; }
        for (size_t row = 0; row < rows; row++)
            memcpy((uint8_t *)to + row * toStride, (uint8_t *)from + row * fromStride, MIN(fromStride, toStride));
    }
    CVPixelBufferUnlockBaseAddress(destination, 0);
    CVPixelBufferUnlockBaseAddress(source, kCVPixelBufferLock_ReadOnly);
    return valid;
}

static CMSampleBufferRef WCVideoNewSample(CVPixelBufferRef pixels, CMSampleBufferRef original) CF_RETURNS_RETAINED;
static void WCVideoCopySampleAttachment(const void *key, const void *value, void *context) {
    CFDictionarySetValue((CFMutableDictionaryRef)context, key, value);
}
static CMSampleBufferRef WCVideoNewSample(CVPixelBufferRef pixels, CMSampleBufferRef original) {
    CMVideoFormatDescriptionRef format = NULL;
    CMSampleBufferRef result = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixels, &format) != noErr) return NULL;
    CMSampleTimingInfo timing = {CMSampleBufferGetDuration(original), CMSampleBufferGetPresentationTimeStamp(original),
        CMSampleBufferGetDecodeTimeStamp(original)};
    OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixels, format, &timing, &result);
    CFRelease(format);
    if (status != noErr) return NULL;
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, original, kCMAttachmentMode_ShouldPropagate);
    if (attachments) { CMSetAttachments(result, attachments, kCMAttachmentMode_ShouldPropagate); CFRelease(attachments); }
    CFArrayRef source = CMSampleBufferGetSampleAttachmentsArray(original, false);
    CFArrayRef target = CMSampleBufferGetSampleAttachmentsArray(result, true);
    if (source && target && CFArrayGetCount(source) && CFArrayGetCount(target))
        CFDictionaryApplyFunction((CFDictionaryRef)CFArrayGetValueAtIndex(source, 0),
            WCVideoCopySampleAttachment, (void *)CFArrayGetValueAtIndex(target, 0));
    return result;
}

static BOOL WCVideoCalibrateRenderOrientation(CIContext *context, BOOL *flipped) {
    CVPixelBufferRef source = NULL, output = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) return NO;
    BOOL matched = NO;
    const uint8_t corners[2][8] = {{0, 0, 255, 255, 0, 255, 0, 255}, {255, 0, 0, 255, 255, 255, 255, 255}};
    @try {
        NSDictionary *attributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey:@{}};
        if (CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA,
            (__bridge CFDictionaryRef)attributes, &source) != kCVReturnSuccess ||
            CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA,
            (__bridge CFDictionaryRef)attributes, &output) != kCVReturnSuccess) return NO;
        if (CVPixelBufferLockBaseAddress(source, 0) != kCVReturnSuccess) return NO;
        for (NSUInteger row = 0; row < 2; row++)
            memcpy((uint8_t *)CVPixelBufferGetBaseAddress(source) + row * CVPixelBufferGetBytesPerRow(source), corners[row], 8);
        CVPixelBufferUnlockBaseAddress(source, 0);
        CIImage *probe = [CIImage imageWithCVPixelBuffer:source];
        for (NSUInteger attempt = 0; attempt < 2 && !matched; attempt++) {
            CIRenderDestination *destination = [[CIRenderDestination alloc] initWithPixelBuffer:output];
            destination.colorSpace = colorSpace; destination.flipped = attempt != 0;
            NSError *error = nil;
            CIRenderTask *task = [context startTaskToRender:probe fromRect:CGRectMake(0, 0, 2, 2)
                toDestination:destination atPoint:CGPointZero error:&error];
            if (!task || error || ![task waitUntilCompletedAndReturnError:&error] || error) continue;
            if (CVPixelBufferLockBaseAddress(output, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) continue;
            matched = YES;
            for (NSUInteger row = 0; row < 2; row++) {
                uint8_t *bytes = (uint8_t *)CVPixelBufferGetBaseAddress(output) + row * CVPixelBufferGetBytesPerRow(output);
                for (NSUInteger i = 0; i < 8; i++)
                    if (abs((int)bytes[i] - (int)corners[row][i]) > 12) matched = NO;
            }
            CVPixelBufferUnlockBaseAddress(output, kCVPixelBufferLock_ReadOnly);
            if (matched) *flipped = attempt != 0;
        }
    } @catch (__unused NSException *exception) { matched = NO; }
    @finally {
        if (source) CVPixelBufferRelease(source);
        if (output) CVPixelBufferRelease(output);
        CGColorSpaceRelease(colorSpace);
    }
    return matched;
}

CMSampleBufferRef WCGestureVideoCallCreateFrame(id device, CMSampleBufferRef sample, id connection) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    WCVideoCaptureMirrorUpdate(device, connection, NO);
    if (!coordinator.active || !coordinator.host || coordinator.suspended || coordinator.frameFailed ||
        (!coordinator.beautyEnabled && !coordinator.stickerEnabled && !coordinator.mirrorEnabled) ||
        !sample || !CMSampleBufferIsValid(sample) || !CMSampleBufferDataIsReady(sample)) return NULL;
    if (![coordinator.lock tryLock]) return NULL;
    CMSampleBufferRef result = NULL, scratchSample = NULL;
    CVPixelBufferRef scratch = NULL, output = NULL;
    __block CVPixelBufferRef rendered = NULL;
    id<WCVideoEffectFrame> frame = nil;
    @try {
        if (!coordinator.active || (coordinator.device && coordinator.device != device)) return NULL;
        coordinator.device = device;
        NSUInteger generation = coordinator.generation;
        CVPixelBufferRef input = CMSampleBufferGetImageBuffer(sample);
        if (!input) return NULL;
        CIImage *image = nil;
        BOOL changed = NO;
        WCVideoBeautySession *beauty = coordinator.beautyEnabled ? coordinator.beauty : nil;
        if (beauty.generation != generation || ![beauty.account isEqualToString:coordinator.account]) beauty = nil;
        BOOL front = ![WCTweakSafeValue(device, @"m_usingBackCamera") boolValue];
        // Pure mirroring belongs to AVCaptureConnection, so it never enters
        // Core Image or changes pixel rows using a private rotation value.
        if (!beauty && !(coordinator.stickerEnabled && coordinator.sticker)) return NULL;
        id rotationValue = WCTweakSafeValue(device, @"rotation");
        int rotation = [rotationValue intValue];
        image = [CIImage imageWithCVPixelBuffer:input];
        if (beauty) {
            scratch = [coordinator newPixelsLike:input];
            if (!scratch || !WCVideoCopyPixels(input, scratch)) return NULL;
            CVBufferPropagateAttachments(input, scratch);
            scratchSample = WCVideoNewSample(scratch, sample);
            Class frameClass = NSClassFromString(@"MMWeEffectFrame");
            frame = [frameClass new];
            if (!scratchSample || !WCVideoHas(frame, @"setSampleBuffer:", 1) ||
                !WCVideoHas(frame, @"setIsFront:", 1) || !WCVideoHas(frame, @"setRenderRotation:", 1)) return NULL;
            frame.sampleBuffer = scratchSample; frame.isFront = front;
            frame.renderRotation = rotation;
            BOOL effectCompleted = WCVideoOnEffectThread(beauty.engine, ^{
                id manager = WCVideoGet(beauty.engine, @"wevisEffectMgr");
                if (WCVideoHas(manager, @"setRotationForTrackFace:", 1))
                    ((void (*)(id, SEL, int))objc_msgSend)(manager, NSSelectorFromString(@"setRotationForTrackFace:"),
                        rotation);
                if (WCVideoHas(manager, @"setNeedMirror:", 1))
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, NSSelectorFromString(@"setNeedMirror:"), NO);
                id produced = [beauty.engine renderEffectImp:frame pixelBufferFlipX:NO];
                id candidate = [produced isKindOfClass:frameClass] ? produced : nil;
                if (!candidate) return;
                CVPixelBufferRef pixels = NULL;
                if (WCVideoHas(candidate, @"pixelBuffer", 0))
                    pixels = ((CVPixelBufferRef (*)(id, SEL))objc_msgSend)(candidate, NSSelectorFromString(@"pixelBuffer"));
                if (!pixels && WCVideoHas(candidate, @"sampleBuffer", 0)) {
                    CMSampleBufferRef buffer = ((CMSampleBufferRef (*)(id, SEL))objc_msgSend)(candidate, NSSelectorFromString(@"sampleBuffer"));
                    if (buffer && CMSampleBufferIsValid(buffer)) pixels = CMSampleBufferGetImageBuffer(buffer);
                }
                if (pixels) rendered = CVPixelBufferRetain(pixels);
            });
            if (!effectCompleted || !rendered) {
                coordinator.frameFailed = YES;
                coordinator.status = @"美颜帧输出不可用，已恢复原生画面";
                WCVideoRefreshCaptureMirroring(); WCVideoNotify();
                return NULL;
            }
            image = [CIImage imageWithCVPixelBuffer:rendered]; changed = YES;
        }
        CGRect target = CGRectMake(0, 0, CVPixelBufferGetWidth(input), CVPixelBufferGetHeight(input));
        CGRect extent = image.extent;
        if (CGRectIsEmpty(extent) || CGRectIsInfinite(extent) || !isfinite(extent.origin.x) ||
            !isfinite(extent.origin.y) || !isfinite(extent.size.width) || !isfinite(extent.size.height)) return NULL;
        // Do not guess a private engine's changed orientation or stretch a rotated output.
        double inputAspect = target.size.width / target.size.height;
        double outputAspect = extent.size.width / extent.size.height;
        if (fabs(inputAspect / outputAspect - 1) > .02) {
            coordinator.frameFailed = YES;
            coordinator.status = @"美颜输出方向不兼容，已恢复原生画面";
            WCVideoRefreshCaptureMirroring(); WCVideoNotify(); return NULL;
        }
        image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-extent.origin.x, -extent.origin.y)];
        image = [image imageByApplyingTransform:CGAffineTransformMakeScale(target.size.width / extent.size.width,
                                                                         target.size.height / extent.size.height)];
        // Capture mirroring has already happened before this callback. Stickers
        // are composited afterwards and their text is not mirrored.
        CIImage *sticker = coordinator.stickerEnabled ? coordinator.sticker : nil;
        if (sticker) {
            CGRect size = sticker.extent;
            if (size.size.width > 0 && size.size.height > 0) {
                // Inverse of the live view's aspect-fill: preserve the full
                // editable screen canvas inside the outgoing video, not crop it.
                CGFloat scale = MIN(target.size.width / size.size.width, target.size.height / size.size.height);
                CGAffineTransform transform = CGAffineTransformMake(scale, 0, 0, scale,
                    (target.size.width - size.size.width * scale) / 2,
                    (target.size.height - size.size.height * scale) / 2);
                CIImage *layer = [sticker imageByApplyingTransform:transform];
                image = [layer imageByCompositingOverImage:image]; changed = YES;
            }
        }
        if (!changed || generation != coordinator.generation || !coordinator.active || coordinator.suspended) return NULL;
        output = [coordinator newPixelsLike:input];
        if (!output) return NULL;
        CVBufferPropagateAttachments(input, output);
        if (!coordinator.context) {
            coordinator.context = [CIContext contextWithOptions:@{kCIContextCacheIntermediates:@NO}];
            coordinator.renderOrientationReady = NO;
        }
        if (!coordinator.renderOrientationReady) {
            BOOL flipped = NO;
            if (!WCVideoCalibrateRenderOrientation(coordinator.context, &flipped)) {
                coordinator.frameFailed = YES;
                coordinator.status = @"视频方向校验未通过，已恢复原生画面";
                WCVideoRefreshCaptureMirroring(); WCVideoNotify(); return NULL;
            }
            coordinator.renderFlipped = flipped; coordinator.renderOrientationReady = YES;
        }
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        if (!colorSpace) return NULL;
        BOOL completed = NO;
        @try {
            CIRenderDestination *destination = [[CIRenderDestination alloc] initWithPixelBuffer:output];
            destination.colorSpace = colorSpace;
            destination.flipped = coordinator.renderFlipped;
            NSError *error = nil;
            CIRenderTask *task = [coordinator.context startTaskToRender:[image imageByCroppingToRect:target]
                fromRect:target toDestination:destination atPoint:CGPointZero error:&error];
            completed = task && !error && [task waitUntilCompletedAndReturnError:&error] != nil && !error;
        }
        @finally { CGColorSpaceRelease(colorSpace); }
        if (!completed) {
            coordinator.frameFailed = YES;
            coordinator.status = @"视频帧合成失败，已恢复原生画面";
            WCVideoRefreshCaptureMirroring(); WCVideoNotify(); return NULL;
        }
        if (!coordinator.active || coordinator.suspended || coordinator.generation != generation) return NULL;
        result = WCVideoNewSample(output, sample);
    } @catch (__unused NSException *exception) {
        if (result) { CFRelease(result); result = NULL; }
        coordinator.frameFailed = YES;
        coordinator.status = @"视频处理暂不可用，已恢复原生画面";
        WCVideoRefreshCaptureMirroring(); WCVideoNotify();
    } @finally {
        // MMWeEffectFrame's CF properties are borrowed; clear before releasing our sample.
        @try {
            if (frame && WCVideoHas(frame, @"setSampleBuffer:", 1)) frame.sampleBuffer = NULL;
        } @catch (__unused NSException *exception) {}
        if (rendered) CVPixelBufferRelease(rendered);
        if (scratchSample) CFRelease(scratchSample);
        if (scratch) CVPixelBufferRelease(scratch);
        if (output) CVPixelBufferRelease(output);
        [coordinator.lock unlock];
    }
    return result;
}

void WCGestureVideoCallStart(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:WCGestureDidChangeNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *note) { [coordinator refresh]; }];
            [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *note) {
                    coordinator.suspended = YES;
                    WCVideoRefreshCaptureMirroring();
                    dispatch_async(coordinator.controlQueue, ^{
                        [coordinator.lock lock];
                        @try {
                            WCVideoBeautySession *session = coordinator.beauty;
                            if (session) WCVideoOnEffectThread(session.engine, ^{ WCVideoCall(session.logic, @"saveAllEffectBeautyValues"); });
                        } @catch (__unused NSException *exception) {} @finally { [coordinator.lock unlock]; }
                    });
                }];
            [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *note) {
                    if (coordinator.active && ![coordinator.account isEqualToString:WCCurrentUserWXID() ?: @""])
                        [coordinator retire];
                    coordinator.suspended = NO;
                    [coordinator refresh];
                }];
            [coordinator refresh];
        });
    });
}

void WCGestureVideoCallViewChanged(UIViewController *controller, BOOL visible) {
    if (!NSThread.isMainThread) return;
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if ([objc_getAssociatedObject(controller, &WCVideoEndedKey) boolValue]) return;
    if (!visible) {
        BOOL inCall = [WCTweakSafeValue(controller, @"isTalking") boolValue] ||
            [WCTweakSafeValue(controller, @"isCalling") boolValue];
        if (coordinator.host == controller && (controller.isBeingDismissed || controller.isMovingFromParentViewController ||
            (!controller.presentedViewController && !controller.view.window)) && !inCall)
            [coordinator retire];
        return;
    }
    if (!controller.isViewLoaded) return;
    id talking = WCTweakSafeValue(controller, @"m_talkingView");
    BOOL video = [talking isKindOfClass:UIView.class] && ((UIView *)talking).window && WCVideoHas(talking, @"isAllowVideo", 0)
        ? [WCTweakSafeValue(talking, @"isAllowVideo") boolValue] : [WCTweakSafeValue(controller, @"isVideoMode") boolValue];
    if (!video) {
        if (coordinator.host == controller && coordinator.active) [coordinator retire];
        return;
    }
    if (coordinator.host != controller || !coordinator.active) {
        if (coordinator.active) [coordinator retire];
        coordinator.host = controller; coordinator.active = YES;
        WCRefreshCachedCurrentUser();
        coordinator.account = WCCurrentUserWXID() ?: @"";
        coordinator.generation++;
        [coordinator refresh];
    }
    [coordinator layoutButton];
}
void WCGestureVideoCallTalkingViewChanged(UIView *view) {
    if (!NSThread.isMainThread) return;
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (!view.window) {
        if (coordinator.talkingView == view) { coordinator.talkingView = nil; [coordinator layoutButton]; }
        return;
    }
    Class hostClass = NSClassFromString(@"VoIPViewController");
    UIViewController *host = WCViewControllerForResponder(view);
    if (!hostClass || ![host isKindOfClass:hostClass]) {
        id delegate = WCTweakSafeValue(view, @"delegate");
        host = hostClass && [delegate isKindOfClass:hostClass] ? delegate : nil;
    }
    if (!host) return;
    if ([WCTweakSafeValue(view, @"isEnding") boolValue]) { WCGestureVideoCallEnded(host); return; }
    WCGestureVideoCallViewChanged(host, YES);
    if (coordinator.host != host || !coordinator.active) return;
    coordinator.talkingView = view;
    [coordinator layoutButton];
}
void WCGestureVideoCallConnected(UIViewController *controller) {
    WCGestureVideoCallViewChanged(controller, YES);
    id talking = WCTweakSafeValue(controller, @"m_talkingView");
    if ([talking isKindOfClass:UIView.class]) WCGestureVideoCallTalkingViewChanged(talking);
    if (WCVideoCoordinator().host == controller && WCVideoCoordinator().active)
        WCGestureVideoCallResourcesChanged();
}
void WCGestureVideoCallEnded(UIViewController *controller) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCGestureVideoCallEnded(controller); }); return;
    }
    objc_setAssociatedObject(controller, &WCVideoEndedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (coordinator.host == controller) [coordinator retire];
}
void WCGestureVideoCallDeviceStopped(id device) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    NSUInteger generation = coordinator.generation;
    NSHashTable *table = WCVideoCaptureConnections(); NSArray *connections;
    @synchronized (table) { connections = table.allObjects; }
    for (AVCaptureConnection *connection in connections) {
        WCVideoCaptureMirrorState *state = objc_getAssociatedObject(connection, &WCVideoCaptureMirrorKey);
        if (state.device == device) WCVideoCaptureMirrorUpdate(device, connection, YES);
    }
    // Camera recreation at connection/front-back switch is not call termination.
    dispatch_async(coordinator.controlQueue, ^{
        [coordinator.lock lock];
        @try {
            if (coordinator.generation == generation && coordinator.device == device) coordinator.device = nil;
        } @finally { [coordinator.lock unlock]; }
    });
}
void WCGestureVideoCallResourcesChanged(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCGestureVideoCallResourcesChanged(); }); return;
    }
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (coordinator.active && coordinator.beautyEnabled) {
        coordinator.status = coordinator.beauty ? @"微信美颜已就绪" : @"正在检查微信美颜资源";
        WCVideoNotify();
    }
    dispatch_async(coordinator.controlQueue, ^{
        coordinator.frameFailed = NO;
        WCVideoRefreshCaptureMirroring();
        if (coordinator.beauty) return;
        coordinator.attempted = NO; [coordinator prepare];
    });
}
void WCGestureVideoCallEditSticker(UIViewController *presenter, UIImage *image) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    NSString *token = WCGestureVideoCallContextToken();
    UIViewController *host = coordinator.host;
    if (!NSThread.isMainThread || !token.length || !coordinator.stickerEnabled || !image ||
        image.size.width <= 0 || image.size.height <= 0 || !host.view.window) {
        WCShowToast(@"请回到视频通话并开启图片贴纸"); return;
    }
    if (coordinator.editor) return;
    CIImage *previous = coordinator.sticker;
    UIImage *previousSource = coordinator.stickerSource;
    NSDictionary *previousPlacement = coordinator.stickerPlacement;
    NSDictionary *placement = image == previousSource ? previousPlacement : nil;
    void (^show)(void) = ^{
        if (![token isEqualToString:WCGestureVideoCallContextToken()] || coordinator.host != host ||
            !host.view.window || host.presentedViewController || !coordinator.stickerEnabled) return;
        __block __weak UIViewController *weakEditor = nil;
        UIViewController *editor = WCGestureCreateVideoStickerEditor(image, placement, ^(UIImage *canvas, NSDictionary *position) {
            if (coordinator.editor == weakEditor) coordinator.editor = nil;
            if (![token isEqualToString:WCGestureVideoCallContextToken()]) return;
            if (canvas.CGImage && coordinator.stickerEnabled) {
                coordinator.sticker = [CIImage imageWithCGImage:canvas.CGImage];
                coordinator.stickerSource = image; coordinator.stickerPlacement = position;
            } else {
                coordinator.sticker = previous;
                coordinator.stickerSource = previousSource; coordinator.stickerPlacement = previousPlacement;
            }
            WCVideoNotify();
        });
        weakEditor = editor;
        coordinator.editor = editor;
        coordinator.sticker = nil;
        [host presentViewController:editor animated:YES completion:nil];
    };
    UIViewController *sheet = host.presentedViewController;
    if (sheet && (sheet == presenter || sheet == presenter.navigationController))
        [sheet dismissViewControllerAnimated:YES completion:show];
    else if (!sheet) show();
    else WCShowToast(@"请先关闭当前弹窗后调整贴纸");
}
void WCGestureVideoCallRepositionSticker(UIViewController *presenter) {
    UIImage *source = WCVideoCoordinator().stickerSource;
    if (source) WCGestureVideoCallEditSticker(presenter, source);
}
BOOL WCGestureVideoCallCancelSticker(id editor) {
    return [editor isKindOfClass:UIViewController.class] && WCGestureVideoStickerEditorCancel(editor);
}
void WCGestureVideoCallClearSticker(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (coordinator.editor) WCGestureVideoCallCancelSticker(coordinator.editor);
    coordinator.sticker = nil; coordinator.stickerSource = nil; coordinator.stickerPlacement = nil;
    WCVideoNotify();
}
BOOL WCGestureVideoCallHasSticker(void) { return WCVideoCoordinator().stickerSource != nil; }

NSArray<NSDictionary *> *WCGestureVideoCallBeautyItems(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    return coordinator.active && coordinator.beautyEnabled ? (coordinator.beautyItems ?: @[]) : @[];
}
static void WCVideoApplyBeautyValue(NSString *identifier, double value, BOOL persist) {
    if (!identifier.length || !isfinite(value)) return;
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    NSUInteger generation = coordinator.generation;
    dispatch_async(coordinator.controlQueue, ^{
        [coordinator.lock lock];
        @try {
            WCVideoBeautySession *session = coordinator.beauty;
            if (!coordinator.active || !coordinator.beautyEnabled || !session || generation != coordinator.generation ||
                ![session.account isEqualToString:WCCurrentUserWXID() ?: @""]) return;
            id items = WCVideoGet(session.suite, @"items");
            if (![items isKindOfClass:NSArray.class]) return;
            for (id item in items) if ([WCVideoString(item, @"itemId") isEqualToString:identifier]) {
                double minimum = [WCTweakSafeValue(item, @"minimumValue") doubleValue];
                double maximum = [WCTweakSafeValue(item, @"maximumValue") doubleValue];
                double clamped = MIN(maximum, MAX(minimum, value));
                if (!isfinite(clamped) || maximum <= minimum) break;
                BOOL applied = WCVideoOnEffectThread(session.engine, ^{
                    WCTweakSetValue(item, @"value", @(clamped));
                    WCVideoSetObject(session.logic, @"applyBeautyItem:", item);
                    if (persist) WCVideoCall(session.logic, @"saveAllEffectBeautyValues");
                });
                if (!applied) { coordinator.status = @"美颜参数应用失败"; WCVideoNotify(); return; }
                if (persist) {
                    NSMutableDictionary *values = [[NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureVideoCallBeautyValuesKey] mutableCopy]
                        ?: [NSMutableDictionary dictionary];
                    values[identifier] = @(clamped);
                    [NSUserDefaults.standardUserDefaults setObject:values forKey:WCGestureVideoCallBeautyValuesKey];
                }
                coordinator.beautyItems = WCVideoDescribeBeauty(session);
                if (persist) WCVideoNotify();
                break;
            }
        } @catch (__unused NSException *exception) {} @finally { [coordinator.lock unlock]; }
    });
}
void WCGestureVideoCallSetBeautyValue(NSString *identifier, double value) { WCVideoApplyBeautyValue(identifier, value, YES); }
void WCGestureVideoCallPreviewBeautyValue(NSString *identifier, double value) { WCVideoApplyBeautyValue(identifier, value, NO); }
void WCGestureVideoCallResetBeauty(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    NSUInteger generation = coordinator.generation;
    dispatch_async(coordinator.controlQueue, ^{
        [coordinator.lock lock];
        @try {
            WCVideoBeautySession *session = coordinator.beauty;
            if (!session || !coordinator.active || !coordinator.beautyEnabled || generation != coordinator.generation ||
                ![session.account isEqualToString:WCCurrentUserWXID() ?: @""]) return;
            BOOL reset = WCVideoOnEffectThread(session.engine, ^{
                WCVideoCall(session.logic, @"resetDataItemsValueToDefault");
                for (NSDictionary *descriptor in WCVideoDescribeBeauty(session)) {
                    id items = WCVideoGet(session.suite, @"items");
                    for (id item in items) if ([WCVideoString(item, @"itemId") isEqualToString:descriptor[@"id"]]) {
                        NSNumber *value = WCTweakSafeValue(item, @"defaultValue");
                        if (![value isKindOfClass:NSNumber.class] || !isfinite(value.doubleValue)) continue;
                        double clamped = MIN([descriptor[@"max"] doubleValue], MAX([descriptor[@"min"] doubleValue], value.doubleValue));
                        WCTweakSetValue(item, @"value", @(clamped));
                        WCVideoSetObject(session.logic, @"applyBeautyItem:", item);
                    }
                }
                WCVideoCall(session.logic, @"saveAllEffectBeautyValues");
            });
            if (!reset) { coordinator.status = @"美颜参数重置失败"; WCVideoNotify(); return; }
            [NSUserDefaults.standardUserDefaults setObject:@{} forKey:WCGestureVideoCallBeautyValuesKey];
            coordinator.beautyItems = WCVideoDescribeBeauty(session);
        } @catch (__unused NSException *exception) {} @finally { [coordinator.lock unlock]; }
        WCVideoNotify();
    });
}
NSString *WCGestureVideoCallStatus(void) { return WCVideoCoordinator().status; }
NSString *WCGestureVideoCallContextToken(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (!coordinator.active || !coordinator.host || coordinator.suspended || !coordinator.account.length ||
        ![coordinator.account isEqualToString:WCCurrentUserWXID() ?: @""]) return @"";
    return [NSString stringWithFormat:@"%@:%lu", coordinator.account, (unsigned long)coordinator.generation];
}
