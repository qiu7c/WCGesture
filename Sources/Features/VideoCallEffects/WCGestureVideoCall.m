#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import <string.h>
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
@protocol WCVideoStickerEditor <NSObject>
- (instancetype)initWithLiveTaskId:(id)task stickerItem:(id)item configuration:(id)config reporter:(id)reporter;
@end
@protocol WCVideoStickerItem <NSObject>
- (instancetype)initWithInstanceId:(NSString *)identifier;
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

@interface WCVideoStickerContext : NSObject
@property (nonatomic) NSUInteger generation;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, weak) UIViewController *presenter;
@end
static char WCVideoStickerContextKey;
static char WCVideoRendererRequestedMirrorKey;
static __thread BOOL WCVideoMirrorScope;
static NSHashTable *WCVideoRenderers(void) {
    static NSHashTable *renderers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ renderers = [NSHashTable weakObjectsHashTable]; });
    return renderers;
}
static void WCVideoRefreshRenderers(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSHashTable *table = WCVideoRenderers();
        NSArray *renderers;
        @synchronized (table) { renderers = table.allObjects; }
        for (id renderer in renderers) {
            NSNumber *requested = objc_getAssociatedObject(renderer, &WCVideoRendererRequestedMirrorKey);
            if (requested && WCVideoHas(renderer, @"setMirror:", 1)) {
                @try { ((void (*)(id, SEL, BOOL))objc_msgSend)(renderer, NSSelectorFromString(@"setMirror:"), requested.boolValue); }
                @catch (__unused NSException *exception) {}
            }
        }
    });
}

@interface WCVideoCallCoordinator : NSObject {
    CVPixelBufferPoolRef _pool;
    size_t _width;
    size_t _height;
    OSType _format;
}
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) dispatch_queue_t controlQueue;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic, strong) WCVideoBeautySession *beauty;
@property (atomic, weak) UIViewController *host;
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

static WCVideoBeautySession *WCVideoBuildBeauty(NSString *account, NSString **failure) {
    Class managerClass = NSClassFromString(@"MMWeEffectManager");
    Class packageClass = NSClassFromString(@"MMLiveBeautyPackage");
    Class logicClass = NSClassFromString(@"MMLiveBeautyLogic");
    Class pathClass = NSClassFromString(@"MMLivePathUtil");
    id service = WCServiceForClass(NSClassFromString(@"MMLiveResUpdateMgr"));
    NSString *initializer = @"initWithSceneType:roleType:energyController:dataReportCallback:isAllowFp16:enableRci:beautyAssetsDirectory:";
    if (!class_getInstanceMethod(managerClass, NSSelectorFromString(initializer)) ||
        !class_getInstanceMethod(managerClass, @selector(runSyncOnWeEffectThread:)) ||
        !class_getInstanceMethod(managerClass, @selector(renderEffectImp:pixelBufferFlipX:)) ||
        !WCVideoHas(service, @"latestReadyResVersion:subResType:", 2) ||
        !WCVideoHas(pathClass, @"liveStaticResourcesPathWithType:subType:version:", 3) ||
        !WCVideoHas(packageClass, @"beautyPackageInLocalDirectory:withConfigurationPath:capabilities:", 3)) {
        *failure = @"当前微信版本缺少美颜接口";
        return nil;
    }
    unsigned int version = ((unsigned int (*)(id, SEL, unsigned int, unsigned int))objc_msgSend)(
        service, NSSelectorFromString(@"latestReadyResVersion:subResType:"), 184, 3);
    NSString *directory = ((id (*)(id, SEL, unsigned int, unsigned int, unsigned int))objc_msgSend)(
        pathClass, NSSelectorFromString(@"liveStaticResourcesPathWithType:subType:version:"), 184, 3, version);
    if (![directory isKindOfClass:NSString.class] || !directory.length ||
        ![NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:@"contents.json"]]) {
        WCVideoCall(service, @"checkResourcesOnInitialization");
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
    WCVideoRefreshRenderers();
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
    dispatch_async(self.controlQueue, ^{
        if (!self.active || !self.host || self.suspended || !self.beautyEnabled || self.preparing || self.attempted) return;
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
        @try { candidate = WCVideoBuildBeauty(account, &failure); }
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
    self.device = nil; self.sticker = nil;
    WCVideoRefreshRenderers();
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
        if (self.generation != retirement) return;
        [self.button removeFromSuperview]; self.button = nil;
        UIViewController *editor = self.editor;
        if (editor && objc_getAssociatedObject(editor, &WCVideoStickerContextKey)) {
            objc_setAssociatedObject(editor, &WCVideoStickerContextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [editor dismissViewControllerAnimated:NO completion:nil];
        }
        self.editor = nil;
    });
}
- (void)layoutButton {
    UIViewController *host = self.host;
    BOOL enabled = self.beautyEnabled || self.stickerEnabled || self.mirrorEnabled;
    BOOL video = [WCTweakSafeValue(host, @"isVideoMode") boolValue];
    if (!enabled || !host.isViewLoaded || !host.view.window || !video || !self.active) {
        [self.button removeFromSuperview]; self.button = nil; return;
    }
    UIButton *button = self.button;
    if (button && button.superview != host.view) {
        [button removeFromSuperview]; self.button = nil; button = nil;
    }
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:@"通话调节" forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        button.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:.9];
        button.layer.cornerRadius = 18;
        __weak WCVideoCallCoordinator *weakSelf = self;
        [button addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
            WCVideoCallCoordinator *strongSelf = weakSelf;
            UIViewController *presenter = strongSelf.host;
            if (!presenter || presenter.presentedViewController) return;
            UIViewController *settings = WCGestureCreateVideoCallSettingsController();
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
            navigation.modalPresentationStyle = UIModalPresentationPageSheet;
            if (@available(iOS 15.0, *)) {
                navigation.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent],
                    [UISheetPresentationControllerDetent largeDetent]];
                navigation.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                navigation.sheetPresentationController.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                navigation.sheetPresentationController.prefersGrabberVisible = YES;
            }
            [presenter presentViewController:navigation animated:YES completion:nil];
        }] forControlEvents:UIControlEventTouchUpInside];
        [host.view addSubview:button]; self.button = button;
    }
    UIEdgeInsets safe = host.view.safeAreaInsets;
    button.frame = CGRectMake(MAX(safe.left + 12, CGRectGetWidth(host.view.bounds) - safe.right - 104), safe.top + 12, 92, 36);
    [host.view bringSubviewToFront:button];
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

CMSampleBufferRef WCGestureVideoCallCreateFrame(id device, CMSampleBufferRef sample, __unused id connection) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
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
        if (!beauty && !(coordinator.stickerEnabled && coordinator.sticker) && !(front && coordinator.mirrorEnabled)) return NULL;
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
            frame.renderRotation = [WCTweakSafeValue(device, @"rotation") intValue];
            BOOL effectCompleted = WCVideoOnEffectThread(beauty.engine, ^{
                id manager = WCVideoGet(beauty.engine, @"wevisEffectMgr");
                if (WCVideoHas(manager, @"setRotationForTrackFace:", 1))
                    ((void (*)(id, SEL, int))objc_msgSend)(manager, NSSelectorFromString(@"setRotationForTrackFace:"),
                        [WCTweakSafeValue(device, @"rotation") intValue]);
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
                WCVideoRefreshRenderers(); WCVideoNotify();
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
            WCVideoRefreshRenderers(); WCVideoNotify(); return NULL;
        }
        image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-extent.origin.x, -extent.origin.y)];
        image = [image imageByApplyingTransform:CGAffineTransformMakeScale(target.size.width / extent.size.width,
                                                                         target.size.height / extent.size.height)];
        // Mirror the camera before compositing: the sticker stays where it was edited,
        // including readable text inside the selected image.
        if (front && coordinator.mirrorEnabled) {
            image = [image imageByApplyingTransform:CGAffineTransformMake(-1, 0, 0, 1, target.size.width, 0)];
            changed = YES;
        }
        CIImage *sticker = coordinator.stickerEnabled ? coordinator.sticker : nil;
        if (sticker) {
            CGRect size = sticker.extent;
            if (size.size.width > 0 && size.size.height > 0) {
                CGFloat scale = MAX(target.size.width / size.size.width, target.size.height / size.size.height);
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
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        if (!coordinator.context) coordinator.context = [CIContext contextWithOptions:@{kCIContextCacheIntermediates:@NO}];
        BOOL completed = NO;
        @try {
            CIRenderDestination *destination = [[CIRenderDestination alloc] initWithPixelBuffer:output];
            destination.colorSpace = colorSpace;
            NSError *error = nil;
            CIRenderTask *task = [coordinator.context startTaskToRender:[image imageByCroppingToRect:target]
                fromRect:target toDestination:destination atPoint:CGPointZero error:&error];
            completed = task && !error && [task waitUntilCompletedAndReturnError:&error] != nil && !error;
        }
        @finally { CGColorSpaceRelease(colorSpace); }
        if (!completed) {
            coordinator.frameFailed = YES;
            coordinator.status = @"视频帧合成失败，已恢复原生画面";
            WCVideoRefreshRenderers(); WCVideoNotify(); return NULL;
        }
        if (!coordinator.active || coordinator.suspended || coordinator.generation != generation) return NULL;
        result = WCVideoNewSample(output, sample);
    } @catch (__unused NSException *exception) {
        if (result) { CFRelease(result); result = NULL; }
        coordinator.frameFailed = YES;
        coordinator.status = @"视频处理暂不可用，已恢复原生画面";
        WCVideoRefreshRenderers(); WCVideoNotify();
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
                    WCVideoRefreshRenderers();
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
    if (!visible) {
        if (coordinator.host == controller && (controller.isBeingDismissed || controller.isMovingFromParentViewController ||
            (!controller.presentedViewController && !controller.view.window)))
            [coordinator retire];
        return;
    }
    if (!controller.isViewLoaded) return;
    BOOL video = [WCTweakSafeValue(controller, @"isVideoMode") boolValue];
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
void WCGestureVideoCallDeviceStopped(id device) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    NSUInteger generation = coordinator.generation;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (coordinator.generation == generation && coordinator.device == device) [coordinator retire];
    });
}
void WCGestureVideoCallResourcesChanged(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    dispatch_async(coordinator.controlQueue, ^{
        coordinator.frameFailed = NO;
        WCVideoRefreshRenderers();
        if (coordinator.beauty) return;
        coordinator.attempted = NO; [coordinator prepare];
    });
}
BOOL WCGestureVideoCallRendererMirrorEnabled(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    return coordinator.active && coordinator.mirrorEnabled && !coordinator.suspended && !coordinator.frameFailed;
}
BOOL WCGestureVideoCallRendererMirrorValue(id renderer, BOOL requested) {
    if (renderer) {
        objc_setAssociatedObject(renderer, &WCVideoRendererRequestedMirrorKey, @(requested), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSHashTable *table = WCVideoRenderers();
        @synchronized (table) { [table addObject:renderer]; }
    }
    return WCGestureVideoCallRendererMirrorEnabled() ? NO : requested;
}
BOOL WCGestureVideoCallBeginMirrorScope(id device) {
    BOOL previous = WCVideoMirrorScope;
    WCVideoMirrorScope = WCGestureVideoCallRendererMirrorEnabled() && WCVideoCoordinator().device == device &&
        ![WCTweakSafeValue(device, @"m_usingBackCamera") boolValue];
    return previous;
}
void WCGestureVideoCallEndMirrorScope(BOOL previous) { WCVideoMirrorScope = previous; }
BOOL WCGestureVideoCallRendererFlipX(id renderer, BOOL original) {
    if (!WCVideoMirrorScope || !WCGestureVideoCallRendererMirrorEnabled()) return original;
    NSString *name = WCVideoString(renderer, @"name");
    if ([name containsString:@"Local"] || [name containsString:@"CallerView"] ||
        [name isEqualToString:@"ReceiveView"] || [name containsString:@"ReceiverView"]) return NO;
    return original;
}

void WCGestureVideoCallEditSticker(UIViewController *presenter, UIImage *image) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (!coordinator.active || !coordinator.stickerEnabled || coordinator.suspended ||
        ![coordinator.account isEqualToString:WCCurrentUserWXID() ?: @""]) {
        WCShowToast(@"请先开启图片贴纸并进入视频通话"); return;
    }
    Class editorClass = NSClassFromString(@"MMFinderLiveStickerEditingViewController");
    Class itemClass = NSClassFromString(@"MMFinderLiveImageStickerItem");
    SEL initializer = NSSelectorFromString(@"initWithLiveTaskId:stickerItem:configuration:reporter:");
    if (!image || !class_getInstanceMethod(editorClass, initializer) ||
        !class_getInstanceMethod(itemClass, @selector(initWithInstanceId:))) {
        WCShowToast(@"当前微信版本缺少贴纸编辑接口"); return;
    }
    @try {
        id item = [(id<WCVideoStickerItem>)[itemClass alloc] initWithInstanceId:NSUUID.UUID.UUIDString];
        WCVideoSetObject(item, @"setStickerImage:", image);
        if (WCVideoHas(item, @"setNativeSize:", 1))
            ((void (*)(id, SEL, CGSize))objc_msgSend)(item, NSSelectorFromString(@"setNativeSize:"), image.size);
        if (WCVideoHas(item, @"setCanvasSize:", 1))
            ((void (*)(id, SEL, CGSize))objc_msgSend)(item, NSSelectorFromString(@"setCanvasSize:"), coordinator.host.view.bounds.size);
        id config = [NSClassFromString(@"MMFinderLiveStickerEditingViewControllerConfiguration") new];
        WCTweakSetValue(config, @"forceResetTransformation", @YES);
        if (!item || !config) { WCShowToast(@"贴纸编辑器不可用"); return; }
        UIViewController *editor = [(id<WCVideoStickerEditor>)[editorClass alloc]
            initWithLiveTaskId:nil stickerItem:item configuration:config reporter:nil];
        if (![editor isKindOfClass:UIViewController.class]) return;
        WCVideoStickerContext *context = [WCVideoStickerContext new];
        context.generation = coordinator.generation; context.account = coordinator.account; context.presenter = presenter;
        objc_setAssociatedObject(editor, &WCVideoStickerContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        coordinator.editor = editor;
        editor.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:editor animated:YES completion:nil];
    } @catch (__unused NSException *exception) { WCShowToast(@"微信贴纸编辑器暂不可用"); }
}
BOOL WCGestureVideoCallConfirmSticker(id object) {
    WCVideoStickerContext *context = objc_getAssociatedObject(object, &WCVideoStickerContextKey);
    if (!context) return NO;
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    if (!coordinator.active || !coordinator.stickerEnabled || context.generation != coordinator.generation ||
        ![context.account isEqualToString:WCCurrentUserWXID() ?: @""]) {
        WCGestureVideoCallCancelSticker(object); return YES;
    }
    @try {
        UIView *canvas = WCVideoGet(object, @"editingCanvasView");
        UIView *manipulation = WCVideoGet(object, @"manipulationView");
        id item = WCVideoGet(manipulation, @"stickerItem") ?: WCVideoGet(object, @"stickerItem");
        UIImage *image = WCVideoGet(item, @"stickerImage");
        if (![canvas isKindOfClass:UIView.class] || ![manipulation isKindOfClass:UIView.class] ||
            ![image isKindOfClass:UIImage.class] || image.size.width <= 0 || image.size.height <= 0 ||
            CGRectIsEmpty(canvas.bounds)) { WCShowToast(@"贴纸图片尚未准备好"); return YES; }
        CGRect bounds = manipulation.bounds;
        CGPoint p0 = [manipulation convertPoint:CGPointMake(CGRectGetMinX(bounds), CGRectGetMinY(bounds)) toView:canvas];
        CGPoint p1 = [manipulation convertPoint:CGPointMake(CGRectGetMaxX(bounds), CGRectGetMinY(bounds)) toView:canvas];
        CGPoint p3 = [manipulation convertPoint:CGPointMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds)) toView:canvas];
        CGSize size = canvas.bounds.size;
        CGFloat scale = MIN(1, 1536 / MAX(size.width, size.height));
        CGSize output = CGSizeMake(ceil(size.width * scale), ceil(size.height * scale));
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.scale = 1; format.opaque = NO;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:output format:format];
        UIImage *baked = [renderer imageWithActions:^(UIGraphicsImageRendererContext *drawing) {
            CGContextRef cg = drawing.CGContext;
            CGContextScaleCTM(cg, output.width / size.width, output.height / size.height);
            CGContextTranslateCTM(cg, -canvas.bounds.origin.x, -canvas.bounds.origin.y);
            CGContextConcatCTM(cg, CGAffineTransformMake((p1.x-p0.x)/image.size.width, (p1.y-p0.y)/image.size.width,
                (p3.x-p0.x)/image.size.height, (p3.y-p0.y)/image.size.height, p0.x, p0.y));
            [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
        }];
        if (!baked.CGImage) { WCShowToast(@"贴纸生成失败"); return YES; }
        coordinator.sticker = [CIImage imageWithCGImage:baked.CGImage];
        WCGestureVideoCallCancelSticker(object);
        WCVideoNotify();
    } @catch (__unused NSException *exception) { WCShowToast(@"微信贴纸接口暂不可用"); }
    return YES;
}
BOOL WCGestureVideoCallCancelSticker(id editor) {
    if (!objc_getAssociatedObject(editor, &WCVideoStickerContextKey)) return NO;
    WCVideoCall(editor, @"cancelAutomaticConfirm");
    objc_setAssociatedObject(editor, &WCVideoStickerContextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCVideoCoordinator().editor = nil;
    [(UIViewController *)editor dismissViewControllerAnimated:YES completion:nil];
    return YES;
}
void WCGestureVideoCallClearSticker(void) { WCVideoCoordinator().sticker = nil; WCVideoNotify(); }
BOOL WCGestureVideoCallHasSticker(void) { return WCVideoCoordinator().sticker != nil; }

NSArray<NSDictionary *> *WCGestureVideoCallBeautyItems(void) {
    WCVideoCallCoordinator *coordinator = WCVideoCoordinator();
    return coordinator.active && coordinator.beautyEnabled ? (coordinator.beautyItems ?: @[]) : @[];
}
void WCGestureVideoCallSetBeautyValue(NSString *identifier, double value) {
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
                    WCVideoCall(session.logic, @"saveAllEffectBeautyValues");
                });
                if (!applied) { coordinator.status = @"美颜参数应用失败"; WCVideoNotify(); return; }
                NSMutableDictionary *values = [[NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureVideoCallBeautyValuesKey] mutableCopy]
                    ?: [NSMutableDictionary dictionary];
                values[identifier] = @(clamped);
                [NSUserDefaults.standardUserDefaults setObject:values forKey:WCGestureVideoCallBeautyValuesKey];
                coordinator.beautyItems = WCVideoDescribeBeauty(session);
                WCVideoNotify();
                break;
            }
        } @catch (__unused NSException *exception) {} @finally { [coordinator.lock unlock]; }
    });
}
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
