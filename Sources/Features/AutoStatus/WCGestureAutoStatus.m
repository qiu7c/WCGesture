#import "Sources/API/WCGestureInternal.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

static BOOL WCAutoStatusPublishing;
static BOOL WCAutoStatusSubmitted;
static NSUInteger WCAutoStatusRunID;
static NSString *WCAutoStatusRunAccount;
static BOOL WCAutoStatusRunForce;
static NSURLSession *WCAutoStatusSession;
static NSURLSessionDataTask *WCAutoStatusTask;
static __strong UIViewController *WCAutoStatusActiveController;
static __strong UIView *WCAutoStatusVolumeView;
static __strong UISlider *WCAutoStatusVolumeSlider;
static float WCAutoStatusOriginalVolume;
static BOOL WCAutoStatusVolumeMuted;
static NSUInteger WCAutoStatusVolumeRunID;

static NSError *WCAutoStatusError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.qiu7c.onewx.auto-status" code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"自动更新状态失败"}];
}

static UISlider *WCAutoStatusFindVolumeSlider(UIView *view) {
    if ([view isKindOfClass:UISlider.class]) return (UISlider *)view;
    for (UIView *child in view.subviews) {
        UISlider *slider = WCAutoStatusFindVolumeSlider(child);
        if (slider) return slider;
    }
    return nil;
}

static void WCAutoStatusApplyVolume(float value) {
    if (!WCAutoStatusVolumeSlider) return;
    WCAutoStatusVolumeSlider.value = MIN(1.0f, MAX(0.0f, value));
    [WCAutoStatusVolumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
    [WCAutoStatusVolumeSlider sendActionsForControlEvents:UIControlEventValueChanged];
}

static void WCAutoStatusRestoreVolumeForRun(NSUInteger runID) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ WCAutoStatusRestoreVolumeForRun(runID); }); return; }
    if (!WCAutoStatusVolumeMuted || WCAutoStatusVolumeRunID != runID) return;
    if (WCAutoStatusVolumeSlider.value <= 0.02f) WCAutoStatusApplyVolume(WCAutoStatusOriginalVolume);
    WCAutoStatusVolumeMuted = NO;
    [WCAutoStatusVolumeView removeFromSuperview];
    WCAutoStatusVolumeView = nil;
    WCAutoStatusVolumeSlider = nil;
}

static void WCAutoStatusMuteForVideo(NSUInteger runID) {
    if (!NSThread.isMainThread || WCAutoStatusVolumeMuted) return;
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                if (candidate.isKeyWindow) { window = candidate; break; }
            }
            if (window) break;
        }
    }
    if (!window) for (UIWindow *candidate in UIApplication.sharedApplication.windows) if (candidate.isKeyWindow) { window = candidate; break; }
    Class volumeClass = NSClassFromString(@"MPVolumeView");
    if (!window || !volumeClass) return;
    UIView *volumeView = [[volumeClass alloc] initWithFrame:CGRectMake(-100, -100, 1, 1)];
    volumeView.alpha = 0.01;
    [window addSubview:volumeView];
    [volumeView setNeedsLayout]; [volumeView layoutIfNeeded];
    UISlider *slider = WCAutoStatusFindVolumeSlider(volumeView);
    if (!slider) { [volumeView removeFromSuperview]; return; }
    WCAutoStatusVolumeView = volumeView;
    WCAutoStatusVolumeSlider = slider;
    WCAutoStatusOriginalVolume = slider.value;
    WCAutoStatusVolumeMuted = YES;
    WCAutoStatusVolumeRunID = runID;
    WCAutoStatusApplyVolume(0.0f);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WCAutoStatusRestoreVolumeForRun(runID); });
}

static NSString *WCAutoStatusDateString(NSDate *date, NSString *format) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = NSTimeZone.localTimeZone;
    formatter.dateFormat = format;
    return [formatter stringFromDate:date] ?: @"";
}

static NSString *WCAutoStatusAccount(void) {
    // Refresh from WeChat's current self-contact service every time. The cached
    // wxid can still refer to the previous login when a switch-account window is
    // displayed, so never accept it when refresh fails.
    return WCRefreshCachedCurrentUser() ? WCCurrentUserWXID() : nil;
}

static id WCAutoStatusValue(id object, NSString *key) {
    if (!object || !key.length) return nil;
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}

static NSDictionary *WCAutoStatusIconDictionary(id publishController) {
    id list = WCAutoStatusValue(publishController, @"publishIconList");
    id dictionary = WCAutoStatusValue(list, @"descriptionToIconDict");
    return [dictionary isKindOfClass:NSDictionary.class] ? dictionary : @{};
}

static id WCAutoStatusMakeController(void) {
    @try {
        Class cls = NSClassFromString(@"TextStatePublishViewController");
        if (!cls) return nil;
        id controller = [[cls alloc] init];
        if ([controller respondsToSelector:@selector(loadViewIfNeeded)]) [controller loadViewIfNeeded];
        else if ([controller respondsToSelector:NSSelectorFromString(@"viewDidLoad")])
            ((void (*)(id, SEL))objc_msgSend)(controller, NSSelectorFromString(@"viewDidLoad"));
        return controller;
    } @catch (NSException *exception) {
        WCLog(@"自动状态：初始化原生发布控制器失败 %@", exception.name);
        return nil;
    }
}

NSArray<NSDictionary<NSString *,NSString *> *> *WCGestureAutoStatusIconOptions(void) {
    __block NSArray *result = @[];
    void (^readOptions)(void) = ^{
        id controller = WCAutoStatusMakeController();
        NSDictionary *icons = WCAutoStatusIconDictionary(controller);
        NSMutableArray *options = [NSMutableArray array];
        for (id title in icons) {
            if (![title isKindOfClass:NSString.class] || ![title length]) continue;
            [options addObject:@{@"title": title, @"value": title}];
        }
        [options sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"title"] localizedStandardCompare:b[@"title"]];
        }];
        result = options.copy;
    };
    if (NSThread.isMainThread) readOptions();
    else dispatch_sync(dispatch_get_main_queue(), readOptions);
    return result;
}

static BOOL WCAutoStatusWriteAttemptForAccount(NSString *account, NSString *date) {
    if (!account.length || !date.length) return NO;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *attempts = [[defaults dictionaryForKey:WCGestureAutoStatusLastAttemptKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    attempts[account] = date;
    [defaults setObject:attempts forKey:WCGestureAutoStatusLastAttemptKey];
    return YES;
}

static NSURL *WCAutoStatusURL(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *encoded = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURL *url = encoded.length ? [NSURL URLWithString:encoded] : nil;
    NSString *scheme = url.scheme.lowercaseString;
    return ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) ? url : nil;
}

static BOOL WCAutoStatusIsCurrentRun(NSUInteger runID, NSString *account) {
    if (runID != WCAutoStatusRunID || ![account isEqualToString:WCAutoStatusRunAccount] ||
        ![account isEqualToString:WCAutoStatusAccount()]) return NO;
    return WCAutoStatusRunForce || [NSUserDefaults.standardUserDefaults boolForKey:WCGestureAutoStatusEnabledKey];
}

static BOOL WCAutoStatusCurrentRun(void) {
    return WCAutoStatusIsCurrentRun(WCAutoStatusRunID, WCAutoStatusRunAccount);
}

static void WCAutoStatusAbandonStaleRun(NSUInteger runID) {
    if (runID != WCAutoStatusRunID || WCAutoStatusSubmitted) return;
    ++WCAutoStatusRunID;
    [WCAutoStatusTask cancel]; WCAutoStatusTask = nil;
    [WCAutoStatusSession invalidateAndCancel]; WCAutoStatusSession = nil;
    WCAutoStatusPublishing = NO;
    WCAutoStatusActiveController = nil;
    WCAutoStatusRestoreVolumeForRun(runID);
}

static void WCAutoStatusFetch(NSURL *url, NSUInteger runID, NSString *account, void (^completion)(NSData *, NSError *)) {
    if (!url) { completion(nil, WCAutoStatusError(1, @"请输入有效的 HTTP/HTTPS 地址")); return; }
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 30.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    WCAutoStatusSession = session;
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *finalError = error;
        if (!finalError && [response isKindOfClass:NSHTTPURLResponse.class] &&
            ((NSHTTPURLResponse *)response).statusCode >= 400)
            finalError = WCAutoStatusError(((NSHTTPURLResponse *)response).statusCode, @"状态 API 返回错误");
        if (!finalError && !data.length) finalError = WCAutoStatusError(2, @"状态 API 返回内容为空");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!WCAutoStatusIsCurrentRun(runID, account)) {
                [session finishTasksAndInvalidate];
                WCAutoStatusAbandonStaleRun(runID);
                return;
            }
            WCAutoStatusTask = nil;
            WCAutoStatusSession = nil;
            completion(finalError ? nil : data, finalError);
            [session finishTasksAndInvalidate];
        });
    }];
    WCAutoStatusTask = task;
    [task resume];
}

static void WCAutoStatusShowError(NSError *error) {
    if (error.localizedDescription.length) WCShowToast(error.localizedDescription);
}

static void WCAutoStatusFinish(id controller, NSError *error) {
    if (error) WCAutoStatusShowError(error);
    WCAutoStatusPublishing = NO;
    WCAutoStatusSubmitted = NO;
    WCAutoStatusActiveController = nil;
    if (error) WCAutoStatusRestoreVolumeForRun(WCAutoStatusRunID);
    (void)controller;
}

static id WCAutoStatusConfiguredIcon(id controller, NSUserDefaults *defaults) {
    @try {
        NSString *selected = [defaults stringForKey:WCGestureAutoStatusIconTypeKey] ?: @"做好事";
        NSDictionary *icons = WCAutoStatusIconDictionary(controller);
        if (![selected isEqualToString:@"userdefine"]) return icons[selected];
        NSString *iconID = [defaults stringForKey:WCGestureAutoStatusIconIDKey];
        if (!iconID.length) return nil;
        Class iconClass = NSClassFromString(@"TextStateIcon");
        SEL initializer = NSSelectorFromString(@"initWithIconId:type:showType:actions:flags:");
        if (!iconClass || ![iconClass instancesRespondToSelector:initializer]) return nil;
        // PKC 0xafb84–0xafbbc: type=2, showType=0, actions=nil, flags=1.
        id icon = ((id (*)(id, SEL, id, unsigned int, unsigned int, id, unsigned long long))objc_msgSend)(
            [iconClass alloc], initializer, iconID, 2U, 0U, nil, 1ULL);
        [icon setValue:[defaults stringForKey:WCGestureAutoStatusIconDescriptionKey] ?: @"" forKey:@"customIconDescription"];
        return icon;
    } @catch (NSException *exception) {
        WCLog(@"自动状态：构建原生状态图标失败 %@", exception.name);
        return nil;
    }
}

static BOOL WCAutoStatusSetText(id controller, NSString *text) {
    id wrapper = WCAutoStatusValue(controller, @"descriptionTextView");
    id textView = WCAutoStatusValue(wrapper, @"textView");
    if (![textView respondsToSelector:@selector(setText:)]) return NO;
    ((void (*)(id, SEL, id))objc_msgSend)(textView, @selector(setText:), text ?: @"");
    return YES;
}

static void WCAutoStatusCommit(id controller) {
    if (!WCAutoStatusCurrentRun()) { WCAutoStatusAbandonStaleRun(WCAutoStatusRunID); return; }
    SEL selector = NSSelectorFromString(@"onDone");
    if (![controller respondsToSelector:selector]) selector = NSSelectorFromString(@"onTapDoneButton:");
    if ([controller respondsToSelector:selector]) {
        @try {
            if (sel_getName(selector)[strlen(sel_getName(selector)) - 1] == ':')
                ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, nil);
            else ((void (*)(id, SEL))objc_msgSend)(controller, selector);
        } @catch (NSException *exception) {
            WCLog(@"自动状态：原生提交入口抛出异常 %@", exception.name);
            WCAutoStatusFinish(controller, WCAutoStatusError(17, @"微信状态提交入口执行失败"));
            return;
        }
        WCAutoStatusSubmitted = YES;
        NSUInteger submittedRunID = WCAutoStatusRunID;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (submittedRunID == WCAutoStatusRunID && WCAutoStatusSubmitted) {
                WCAutoStatusPublishing = NO;
                WCAutoStatusSubmitted = NO;
                WCAutoStatusActiveController = nil;
            }
        });
    } else {
        WCAutoStatusFinish(controller, WCAutoStatusError(3, @"当前微信版本缺少状态发布入口"));
    }
}

static void WCAutoStatusDeliverImage(id controller, UIImage *image) {
    if (!WCAutoStatusCurrentRun()) { WCAutoStatusAbandonStaleRun(WCAutoStatusRunID); return; }
    if (!image) { WCAutoStatusFinish(controller, WCAutoStatusError(4, @"无法读取状态图片")); return; }
    SEL selector = NSSelectorFromString(@"onGetTextStateImage:source:");
    if (![controller respondsToSelector:selector]) {
        WCAutoStatusFinish(controller, WCAutoStatusError(5, @"当前微信版本不支持状态图片")); return;
    }
    @try {
        ((void (*)(id, SEL, id, unsigned int))objc_msgSend)(controller, selector, image, 1);
    } @catch (NSException *exception) {
        WCLog(@"自动状态：原生图片接入失败 %@", exception.name);
        WCAutoStatusFinish(controller, WCAutoStatusError(19, @"微信状态图片入口执行失败")); return;
    }
    WCAutoStatusCommit(controller);
}

static void WCAutoStatusDeliverVideo(id controller, NSString *path) {
    if (!WCAutoStatusCurrentRun()) { WCAutoStatusAbandonStaleRun(WCAutoStatusRunID); return; }
    @try {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
        if (![asset tracksWithMediaType:AVMediaTypeVideo].count) {
            WCAutoStatusFinish(controller, WCAutoStatusError(15, @"状态视频文件无法解码或不含视频轨道")); return;
        }
    } @catch (NSException *exception) {
        WCLog(@"自动状态：校验视频失败 %@", exception.name);
        WCAutoStatusFinish(controller, WCAutoStatusError(15, @"状态视频文件无法解码")); return;
    }
    Class itemClass = NSClassFromString(@"SightDraftItem");
    Class draftClass = NSClassFromString(@"SightDraft");
    SEL itemSelector = NSSelectorFromString(@"draftItemWithThumbImg:andPath:inMode:");
    SEL addSelector = NSSelectorFromString(@"addItem:");
    SEL pickSelector = NSSelectorFromString(@"handleDidFinishPickingSightWithInfo:");
    if (!itemClass || !draftClass || ![itemClass respondsToSelector:itemSelector] ||
        ![draftClass instancesRespondToSelector:addSelector] || ![controller respondsToSelector:pickSelector]) {
        WCAutoStatusFinish(controller, WCAutoStatusError(6, @"当前微信版本不支持状态视频")); return;
    }
    id item = nil, draft = nil;
    @try {
        item = ((id (*)(id, SEL, id, id, unsigned long long))objc_msgSend)(itemClass, itemSelector, nil, path, 2ULL);
        draft = [[draftClass alloc] init];
    } @catch (NSException *exception) {
        WCLog(@"自动状态：创建原生视频草稿失败 %@", exception.name);
        WCAutoStatusFinish(controller, WCAutoStatusError(7, @"无法创建微信状态视频草稿")); return;
    }
    if (!item || !draft) { WCAutoStatusFinish(controller, WCAutoStatusError(7, @"无法创建微信状态视频草稿")); return; }
    WCAutoStatusMuteForVideo(WCAutoStatusRunID);
    @try {
        ((void (*)(id, SEL, id))objc_msgSend)(draft, addSelector, item);
        ((void (*)(id, SEL, id))objc_msgSend)(controller, pickSelector, draft);
    } @catch (NSException *exception) {
        WCLog(@"自动状态：原生视频接入失败 %@", exception.name);
        WCAutoStatusFinish(controller, WCAutoStatusError(18, @"微信状态视频入口执行失败")); return;
    }
    NSUInteger runID = WCAutoStatusRunID;
    NSString *account = [WCAutoStatusRunAccount copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!WCAutoStatusIsCurrentRun(runID, account)) { WCAutoStatusAbandonStaleRun(runID); return; }
        WCAutoStatusCommit(controller);
    });
}

static void WCAutoStatusStartWithText(id controller, NSString *text) {
    if (!WCAutoStatusCurrentRun()) { WCAutoStatusAbandonStaleRun(WCAutoStatusRunID); return; }
    if (!controller) { WCAutoStatusFinish(nil, WCAutoStatusError(8, @"微信状态发布界面不可用")); return; }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id icon = WCAutoStatusConfiguredIcon(controller, defaults);
    if (!icon) { WCAutoStatusFinish(controller, WCAutoStatusError(9, @"所选状态图标在当前微信版本中不可用")); return; }
    SEL setIcon = NSSelectorFromString(@"setIconWrap:");
    if (![controller respondsToSelector:setIcon]) { WCAutoStatusFinish(controller, WCAutoStatusError(10, @"当前微信版本缺少状态图标接口")); return; }
    BOOL configured = NO;
    @try {
        ((void (*)(id, SEL, id))objc_msgSend)(controller, setIcon, icon);
        configured = WCAutoStatusSetText(controller, text);
    } @catch (NSException *exception) {
        WCLog(@"自动状态：设置原生图标/文案失败 %@", exception.name);
    }
    if (!configured) {
        WCAutoStatusFinish(controller, WCAutoStatusError(11, @"当前微信版本缺少状态文案输入框")); return;
    }

    NSInteger mode = [defaults integerForKey:WCGestureAutoStatusMediaModeKey];
    NSString *localImage = WCGestureAutoStatusMediaPath(NO);
    NSString *localVideo = WCGestureAutoStatusMediaPath(YES);
    if (mode == 0) mode = [NSFileManager.defaultManager fileExistsAtPath:localImage] ? 3 :
                          ([NSFileManager.defaultManager fileExistsAtPath:localVideo] ? 4 : 0);
    if (mode == 1) {
        NSURL *url = WCAutoStatusURL([defaults stringForKey:WCGestureAutoStatusImageURLKey] ?: @"");
        NSUInteger runID = WCAutoStatusRunID;
        NSString *account = [WCAutoStatusRunAccount copy];
        WCAutoStatusFetch(url, runID, account, ^(NSData *data, NSError *error) {
            if (!WCAutoStatusIsCurrentRun(runID, account)) { WCAutoStatusAbandonStaleRun(runID); return; }
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            if (error || !image) WCAutoStatusFinish(controller, error ?: WCAutoStatusError(12, @"图片 API 未返回有效图片"));
            else WCAutoStatusDeliverImage(controller, image);
        });
    } else if (mode == 2) {
        NSURL *url = WCAutoStatusURL([defaults stringForKey:WCGestureAutoStatusVideoURLKey] ?: @"");
        NSUInteger runID = WCAutoStatusRunID;
        NSString *account = [WCAutoStatusRunAccount copy];
        WCAutoStatusFetch(url, runID, account, ^(NSData *data, NSError *error) {
            if (!WCAutoStatusIsCurrentRun(runID, account)) { WCAutoStatusAbandonStaleRun(runID); return; }
            if (error) { WCAutoStatusFinish(controller, error); return; }
            NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"OneWxAutoStatus"];
            [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            NSString *path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
            NSError *writeError = nil;
            if (![data writeToFile:path options:NSDataWritingAtomic error:&writeError]) { WCAutoStatusFinish(controller, writeError); return; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(24 * 60 * 60 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            });
            WCAutoStatusDeliverVideo(controller, path);
        });
    } else if (mode == 3) {
        WCAutoStatusDeliverImage(controller, [UIImage imageWithContentsOfFile:localImage]);
    } else if (mode == 4) {
        WCAutoStatusDeliverVideo(controller, localVideo);
    } else {
        WCAutoStatusCommit(controller);
    }
}

static void WCAutoStatusBeginPublication(BOOL force) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ WCAutoStatusBeginPublication(force); }); return; }
    if (WCAutoStatusPublishing) return;
    if (!force && ![NSUserDefaults.standardUserDefaults boolForKey:WCGestureAutoStatusEnabledKey]) return;
    NSString *account = WCAutoStatusAccount();
    if (!account.length) { if (force) WCShowToast(@"无法读取当前微信账号"); return; }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *today = WCAutoStatusDateString(NSDate.date, @"yyyy-MM-dd");
    if (!force) {
        NSDictionary *attempts = [defaults dictionaryForKey:WCGestureAutoStatusLastAttemptKey];
        if ([attempts[account] isEqualToString:today]) return;
        NSInteger hour = [defaults integerForKey:WCGestureAutoStatusHourKey];
        NSInteger currentHour = [WCAutoStatusDateString(NSDate.date, @"H") integerValue];
        if (hour < 0 || hour > 23 || currentHour < hour) return;
    }
    // Like the analyzed feature, record the attempt before network/native publish,
    // so a failure does not cause a rapid retry loop during the same day.
    WCAutoStatusWriteAttemptForAccount(account, today);
    WCAutoStatusPublishing = YES;
    WCAutoStatusSubmitted = NO;
    NSUInteger runID = ++WCAutoStatusRunID;
    WCAutoStatusRunAccount = [account copy];
    WCAutoStatusRunForce = force;
    id controller = WCAutoStatusMakeController();
    if (!controller) { WCAutoStatusFinish(nil, WCAutoStatusError(13, @"当前微信版本缺少状态发布界面")); return; }
    WCAutoStatusActiveController = controller;
    if (runID != WCAutoStatusRunID || !WCAutoStatusIsCurrentRun(runID, account)) { WCAutoStatusAbandonStaleRun(runID); return; }
    NSInteger textMode = [defaults integerForKey:WCGestureAutoStatusTextModeKey];
    if (textMode == 2) {
        NSURL *url = WCAutoStatusURL([defaults stringForKey:WCGestureAutoStatusTextURLKey] ?: @"");
        WCAutoStatusFetch(url, runID, account, ^(NSData *data, NSError *error) {
            if (!WCAutoStatusIsCurrentRun(runID, account)) { WCAutoStatusAbandonStaleRun(runID); return; }
            NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
            if (error || !text) WCAutoStatusFinish(controller, error ?: WCAutoStatusError(14, @"文案 API 未返回 UTF-8 纯文本"));
            else WCAutoStatusStartWithText(controller, text);
        });
    } else {
        WCAutoStatusStartWithText(controller, textMode == 1 ? ([defaults stringForKey:WCGestureAutoStatusTextKey] ?: @"") : @"");
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (runID == WCAutoStatusRunID && WCAutoStatusPublishing && !WCAutoStatusSubmitted)
            WCAutoStatusFinish(controller, WCAutoStatusError(16, @"状态发布流程超时，请检查微信状态页"));
    });
}

void WCGestureAutoStatusCheck(void) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ WCGestureAutoStatusCheck(); }); return; }
    WCAutoStatusBeginPublication(NO);
}

void WCGestureAutoStatusSettingsChanged(NSString *key) {
    if (key.length && ![key hasPrefix:@"com.qiu7c.onewx.automation.auto-status."]) return;
    if (!WCAutoStatusPublishing || WCAutoStatusSubmitted) return;
    NSUInteger cancelledRunID = WCAutoStatusRunID;
    ++WCAutoStatusRunID;
    [WCAutoStatusTask cancel]; WCAutoStatusTask = nil;
    [WCAutoStatusSession invalidateAndCancel]; WCAutoStatusSession = nil;
    UIViewController *controller = WCAutoStatusActiveController;
    WCAutoStatusActiveController = nil;
    WCAutoStatusPublishing = NO;
    WCAutoStatusSubmitted = NO;
    WCAutoStatusRestoreVolumeForRun(cancelledRunID);
    (void)controller;
}

void WCGestureAutoStatusPublishNow(void) { WCAutoStatusBeginPublication(YES); }

NSString *WCGestureAutoStatusMediaPath(BOOL video) {
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documents = urls.firstObject;
    if (!documents) return @"";
    NSURL *directory = [[documents URLByAppendingPathComponent:@"Preferences" isDirectory:YES] URLByAppendingPathComponent:@"OneWx/AutoStatus" isDirectory:YES];
    return [[directory URLByAppendingPathComponent:(video ? @"background.mp4" : @"background-image")] path];
}

BOOL WCGestureAutoStatusImportMedia(NSURL *url, BOOL video, NSError **error) {
    if (error) *error = nil;
    if (!url.isFileURL) { if (error) *error = WCAutoStatusError(20, @"请选择本地图片或视频文件"); return NO; }
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:error];
    if (![attributes[NSFileSize] unsignedLongLongValue]) { if (error && !*error) *error = WCAutoStatusError(21, @"所选文件为空"); return NO; }
    if (video) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        if (![asset tracksWithMediaType:AVMediaTypeVideo].count) { if (error) *error = WCAutoStatusError(22, @"所选文件不包含视频轨道"); return NO; }
    } else {
        UIImage *image = [UIImage imageWithContentsOfFile:url.path];
        if (!image) { if (error) *error = WCAutoStatusError(23, @"所选文件不是有效图片"); return NO; }
        image = nil;
    }
    NSString *destination = WCGestureAutoStatusMediaPath(video);
    NSString *directory = [destination stringByDeletingLastPathComponent];
    NSError *fileError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&fileError]) {
        if (error) *error = fileError; return NO;
    }
    NSString *temporary = [destination stringByAppendingFormat:@".%@.tmp", NSUUID.UUID.UUIDString];
    if (![NSFileManager.defaultManager copyItemAtURL:url toURL:[NSURL fileURLWithPath:temporary] error:&fileError]) { if (error) *error = fileError; return NO; }
    if ([NSFileManager.defaultManager fileExistsAtPath:destination] &&
        ![NSFileManager.defaultManager removeItemAtPath:destination error:&fileError]) {
        [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
        if (error) *error = fileError; return NO;
    }
    if (![NSFileManager.defaultManager moveItemAtPath:temporary toPath:destination error:&fileError]) {
        [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
        if (error) *error = fileError; return NO;
    }
    NSString *otherType = WCGestureAutoStatusMediaPath(!video);
    [NSFileManager.defaultManager removeItemAtPath:otherType error:nil];
    return YES;
}
