#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCForwardTaskKey;
static BOOL WCForwardHas(id object, NSString *name, NSUInteger arguments) {
    SEL selector = NSSelectorFromString(name);
    return [object respondsToSelector:selector] &&
        [object methodSignatureForSelector:selector].numberOfArguments == arguments + 2;
}
static NSString *WCForwardText(id value) { return [value isKindOfClass:NSString.class] ? value : @""; }
static id WCForwardContent(id item) { return WCTweakSafeValue(item, @"contentObj"); }
static NSArray *WCForwardMedia(id item) {
    id value = WCTweakSafeValue(WCForwardContent(item), @"mediaList");
    return [value isKindOfClass:NSArray.class] ? [value copy] : @[];
}
static BOOL WCForwardStructured(id content) {
    for (NSString *key in @[@"noteInfo", @"musicShareItem", @"musicInfo", @"finderLiveShareItem",
        @"finderThemeLiveShareItem", @"finderShareToMomentsItem", @"finderLongVideoShareItem",
        @"finderShareItem", @"weappInfo", @"snsWeAppInfo", @"tingListenItem", @"tingCategoryItem",
        @"tingChatRoomItem", @"tingLyricsItem"])
        if (WCTweakSafeValue(content, key)) return YES;
    return NO;
}
BOOL WCGestureMomentsForwardCanForward(id item) {
    if (!WCGestureEnabled(WCGestureMomentsForwardEnabledKey) || !item ||
        [WCTweakSafeValue(item, @"isAd") boolValue]) return NO;
    id content = WCForwardContent(item);
    if (!content) return NO;
    if (WCForwardStructured(content)) return YES;
    NSArray *media = WCForwardMedia(item);
    if (media.count && ([WCTweakSafeValue(content, @"isPhotoType") boolValue] ||
        [WCTweakSafeValue(content, @"isVideoType") boolValue])) return YES;
    return [WCTweakSafeValue(content, @"type") unsignedIntValue] == 2 && !media.count &&
        WCForwardText(WCTweakSafeValue(item, @"contentDesc")).length &&
        !WCForwardText(WCTweakSafeValue(content, @"linkUrl")).length;
}
static NSString *WCForwardPath(id media, BOOL video) {
    NSArray *keys = video ? @[@"pathForSightData"] : @[@"pathForUhdData", @"pathForHdData", @"pathForData", @"pathForExistData"];
    for (NSString *key in keys) {
        id value = WCTweakSafeValue(media, key);
        NSString *path = [value isKindOfClass:NSURL.class] && [value isFileURL] ? [value path] : WCForwardText(value);
        BOOL directory = NO;
        if (path.length && [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&directory] && !directory &&
            [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue]) return path;
    }
    return nil;
}

@interface WCMomentsForwardTask : NSObject
@property (nonatomic, strong) id item;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *tid;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, strong) NSMutableArray *paths;
@property (nonatomic, strong) NSMutableArray *downloaders;
@property (nonatomic, strong) NSMutableIndexSet *pending;
@property (nonatomic) BOOL video;
@property (nonatomic) BOOL finished;
- (void)start;
- (void)finish:(NSString *)message;
@end
static NSHashTable *WCForwardTasks(void) {
    static NSHashTable *tasks; static dispatch_once_t once;
    dispatch_once(&once, ^{ tasks = [NSHashTable weakObjectsHashTable]; }); return tasks;
}
@implementation WCMomentsForwardTask
- (BOOL)valid {
    UIViewController *presenter = self.presenter;
    return !self.finished && WCGestureMomentsForwardCanForward(self.item) &&
        [self.account isEqualToString:WCCurrentUserWXID() ?: @""] &&
        [self.tid isEqualToString:WCForwardText(WCTweakSafeValue(self.item, @"tid"))] &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive && presenter.view.window &&
        !presenter.presentedViewController && (!presenter.navigationController || presenter.navigationController.topViewController == presenter);
}
- (void)finish:(NSString *)message {
    if (self.finished) return;
    BOOL showMessage = message.length && self.presenter.view.window &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        [self.account isEqualToString:WCCurrentUserWXID() ?: @""];
    self.finished = YES;
    for (id downloader in [self.downloaders copy]) {
        @try {
            if (WCForwardHas(downloader, @"setCompletionHandler:", 1))
                ((void (*)(id, SEL, id))objc_msgSend)(downloader, NSSelectorFromString(@"setCompletionHandler:"), nil);
            if (WCForwardHas(downloader, @"clear", 0))
                ((void (*)(id, SEL))objc_msgSend)(downloader, NSSelectorFromString(@"clear"));
        } @catch (__unused NSException *exception) {}
    }
    [self.downloaders removeAllObjects]; [self.pending removeAllIndexes];
    if (objc_getAssociatedObject(self.presenter, &WCForwardTaskKey) == self)
        objc_setAssociatedObject(self.presenter, &WCForwardTaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (showMessage) WCShowToast(message);
}
- (void)applyBody:(UIViewController *)controller attempt:(NSUInteger)attempt {
    if (!self.body.length || ![self.account isEqualToString:WCCurrentUserWXID() ?: @""] || !controller.view.window) return;
    id textView = WCTweakSafeValue(controller, @"textView");
    if (!WCForwardHas(textView, @"setText:", 1)) {
        if (attempt < 3) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self applyBody:controller attempt:attempt + 1];
        });
        else WCShowToast(@"文案未能自动填入，可取消后重试");
        return;
    }
    // Never overwrite edits or a native draft populated after presentation.
    if (WCForwardText(WCTweakSafeValue(textView, @"text")).length) return;
    ((void (*)(id, SEL, id))objc_msgSend)(textView, NSSelectorFromString(@"setText:"), self.body);
    for (NSString *name in @[@"changeContentSize", @"adjustRect"])
        if (WCForwardHas(textView, name, 0)) ((void (*)(id, SEL))objc_msgSend)(textView, NSSelectorFromString(name));
    if (WCForwardHas(controller, @"textViewTextDidChange", 0))
        ((void (*)(id, SEL))objc_msgSend)(controller, NSSelectorFromString(@"textViewTextDidChange"));
    if (WCForwardHas(controller, @"MMGrowTextViewHeightDidChanged:", 1))
        ((void (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"MMGrowTextViewHeightDidChanged:"), textView);
}
- (void)present:(id)candidate body:(BOOL)body {
    if (![self valid] || ![candidate isKindOfClass:UIViewController.class]) { [self finish:@"朋友圈发布页暂不可用"]; return; }
    UIViewController *controller = (UIViewController *)candidate;
    if (WCForwardHas(controller, @"setDelegate:", 1))
        ((void (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"setDelegate:"), self.presenter);
    if (WCForwardHas(controller, @"setM_bFromWCList:", 1))
        ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, NSSelectorFromString(@"setM_bFromWCList:"), YES);
    Class cls = NSClassFromString(@"MMUINavigationController") ?: UINavigationController.class;
    id navigation = [[cls alloc] initWithRootViewController:controller];
    if (![navigation isKindOfClass:UINavigationController.class]) { [self finish:@"朋友圈发布页暂不可用"]; return; }
    ((UIViewController *)navigation).modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *presenter = self.presenter;
    // Finish download ownership before opening the native editor; completion
    // retains only this text snapshot until prefill has finished.
    [self finish:nil];
    [presenter presentViewController:navigation animated:YES completion:^{ if (body) [self applyBody:controller attempt:0]; }];
}
- (void)presentMedia {
    if (![self valid]) { [self finish:nil]; return; }
    @try {
        Class cls = NSClassFromString(@"WCNewCommitViewController");
        id controller = nil;
        if (self.video) {
            Class draftClass = NSClassFromString(@"SightDraft");
            if (![draftClass respondsToSelector:NSSelectorFromString(@"draftWithVideoURL:")] ||
                ![cls instancesRespondToSelector:NSSelectorFromString(@"initWithSightDraft:")]) {
                [self finish:@"当前微信的视频发布接口不可用"]; return;
            }
            id draft = ((id (*)(id, SEL, id))objc_msgSend)(draftClass, NSSelectorFromString(@"draftWithVideoURL:"),
                [NSURL fileURLWithPath:self.paths.firstObject]);
            if (draft) controller = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], NSSelectorFromString(@"initWithSightDraft:"), draft);
        } else {
            Class imageClass = NSClassFromString(@"MMImage");
            if (![imageClass instancesRespondToSelector:NSSelectorFromString(@"initWithImage:")] ||
                ![cls instancesRespondToSelector:NSSelectorFromString(@"initWithImages:contacts:")]) {
                [self finish:@"当前微信的图片发布接口不可用"]; return;
            }
            NSMutableArray *images = [NSMutableArray array];
            for (NSString *path in self.paths) {
                UIImage *image = [UIImage imageWithContentsOfFile:path];
                if (!image) { [self finish:@"朋友圈图片读取失败"]; return; }
                id wrapped = ((id (*)(id, SEL, id))objc_msgSend)([imageClass alloc], NSSelectorFromString(@"initWithImage:"), image);
                if (!wrapped) { [self finish:@"朋友圈图片读取失败"]; return; }
                if (WCForwardHas(wrapped, @"setDataPath:", 1))
                    ((void (*)(id, SEL, id))objc_msgSend)(wrapped, NSSelectorFromString(@"setDataPath:"), path);
                [images addObject:wrapped];
            }
            controller = ((id (*)(id, SEL, id, id))objc_msgSend)([cls alloc], NSSelectorFromString(@"initWithImages:contacts:"), images, nil);
        }
        [self present:controller body:YES];
    } @catch (__unused NSException *exception) { [self finish:@"朋友圈媒体发布页打开失败"]; }
}
- (void)resolved:(id)media index:(NSUInteger)index downloader:(id)downloader {
    if (self.finished || ![self.pending containsIndex:index]) return;
    if (![self valid]) { [self finish:nil]; return; }
    NSString *path = WCForwardPath(media, self.video);
    if (!path) { [self finish:@"朋友圈媒体下载失败，请稍后重试"]; return; }
    self.paths[index] = path; [self.pending removeIndex:index];
    if (downloader) [self.downloaders removeObjectIdenticalTo:downloader];
    if (!self.pending.count) [self presentMedia];
}
- (void)start {
    if (![self valid]) { [self finish:nil]; return; }
    @try {
        id content = WCForwardContent(self.item);
        if (WCForwardStructured(content)) {
            Class cls = NSClassFromString(@"WCForwardViewController");
            if (![cls instancesRespondToSelector:NSSelectorFromString(@"initWithDataItem:")]) {
                [self finish:@"当前微信不支持此类朋友圈转发"]; return;
            }
            id controller = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], NSSelectorFromString(@"initWithDataItem:"), self.item);
            [self present:controller body:NO]; return;
        }
        NSArray *media = WCForwardMedia(self.item);
        if (!media.count) {
            Class cls = NSClassFromString(@"WCNewCommitViewController");
            if (![cls instancesRespondToSelector:NSSelectorFromString(@"initWithTextType")]) {
                [self finish:@"当前微信的文字发布接口不可用"]; return;
            }
            id controller = ((id (*)(id, SEL))objc_msgSend)([cls alloc], NSSelectorFromString(@"initWithTextType"));
            [self present:controller body:YES]; return;
        }
        self.video = [WCTweakSafeValue(content, @"isVideoType") boolValue];
        NSUInteger count = self.video ? 1 : MIN((NSUInteger)9, media.count);
        self.paths = [NSMutableArray array]; self.downloaders = [NSMutableArray array];
        self.pending = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count)];
        for (NSUInteger i = 0; i < count; i++) [self.paths addObject:NSNull.null];
        for (NSUInteger i = 0; i < count && !self.finished; i++) {
            id item = media[i];
            if (WCForwardPath(item, self.video)) { [self resolved:item index:i downloader:nil]; continue; }
            Class cls = NSClassFromString(@"WCMediaDownloader");
            if (![cls instancesRespondToSelector:NSSelectorFromString(@"initWithDataItem:mediaItem:")]) {
                [self finish:@"微信朋友圈媒体下载组件不可用"]; return;
            }
            id downloader = ((id (*)(id, SEL, id, id))objc_msgSend)([cls alloc], NSSelectorFromString(@"initWithDataItem:mediaItem:"), self.item, item);
            if (!WCForwardHas(downloader, @"startDownloadWithCompletionHandler:", 1)) {
                [self finish:@"微信朋友圈媒体下载接口不可用"]; return;
            }
            [self.downloaders addObject:downloader];
            __weak WCMomentsForwardTask *weakSelf = self; __weak id weakDownloader = downloader;
            void (^completion)(BOOL, NSError *) = ^(__unused BOOL success, __unused NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    WCMomentsForwardTask *task = weakSelf;
                    @try { [task resolved:item index:i downloader:weakDownloader]; }
                    @catch (__unused NSException *exception) { [task finish:@"朋友圈媒体读取失败"]; }
                });
            };
            ((void (*)(id, SEL, id))objc_msgSend)(downloader, NSSelectorFromString(@"startDownloadWithCompletionHandler:"), completion);
        }
        if (!self.finished && self.pending.count) {
            WCShowToast(@"正在准备朋友圈媒体");
            __weak WCMomentsForwardTask *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                WCMomentsForwardTask *task = weakSelf;
                [task finish:[task valid] ? @"朋友圈媒体准备超时，请重试" : nil];
            });
        }
    } @catch (__unused NSException *exception) { [self finish:@"朋友圈转发暂不可用"]; }
}
@end

void WCGestureMomentsForwardPresent(id item, UIViewController *presenter) {
    if (!NSThread.isMainThread || !WCGestureMomentsForwardCanForward(item) || !presenter.view.window || presenter.presentedViewController) return;
    if (objc_getAssociatedObject(presenter, &WCForwardTaskKey)) { WCShowToast(@"正在准备上一条朋友圈"); return; }
    if (!WCRefreshCachedCurrentUser() || !WCCurrentUserWXID().length) { WCShowToast(@"尚未获取当前微信账号"); return; }
    WCMomentsForwardTask *task = [WCMomentsForwardTask new];
    task.item = item; task.presenter = presenter; task.account = WCCurrentUserWXID();
    task.tid = WCForwardText(WCTweakSafeValue(item, @"tid")); task.body = WCForwardText(WCTweakSafeValue(item, @"contentDesc"));
    objc_setAssociatedObject(presenter, &WCForwardTaskKey, task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [WCForwardTasks() addObject:task]; [task start];
}
void WCGestureMomentsForwardSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureMomentsForwardEnabledKey]) return;
    if (!WCGestureEnabled(WCGestureMomentsForwardEnabledKey))
        for (WCMomentsForwardTask *task in WCForwardTasks().allObjects) [task finish:nil];
}
