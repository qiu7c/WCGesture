#import <PhotosUI/PhotosUI.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCVideoCallSettingsController : UITableViewController <PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *rows;
@property (nonatomic, copy) NSString *selectionToken;
@property (nonatomic) BOOL loadingImage;
@property (nonatomic) BOOL loadingVideo;
@property (nonatomic,copy) NSString *videoPickerAccount;
@property (nonatomic) BOOL checkingResources;
@property (nonatomic) BOOL adjusting;
@property (nonatomic, copy) NSString *sliderToken;
@property (nonatomic) CFTimeInterval lastPreview;
@property (nonatomic) BOOL inCallPanel;
@end

static NSDictionary *WCVideoSettingsRow(NSString *title, NSString *kind, NSString *key) {
    return @{@"title":title, @"kind":kind, @"key":key ?: @""};
}

@implementation WCVideoCallSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"视频通话增强";
    self.hidesBottomBarWhenPushed = YES;
    WCGestureSettingsConfigureNavigation(self);
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (self.inCallPanel) {
        self.tableView.backgroundColor = UIColor.clearColor; self.tableView.opaque = NO;
        self.navigationController.view.backgroundColor = UIColor.clearColor;
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithTransparentBackground]; appearance.backgroundEffect = nil;
        appearance.backgroundColor = UIColor.clearColor; appearance.shadowColor = UIColor.clearColor;
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
        self.navigationItem.standardAppearance = appearance;
        self.navigationItem.scrollEdgeAppearance = appearance;
        self.navigationItem.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.navigationController.navigationBar.compactScrollEdgeAppearance = appearance;
            self.navigationItem.compactScrollEdgeAppearance = appearance;
        }
        self.navigationController.navigationBar.translucent = YES;
    }
    if (self.navigationController.viewControllers.firstObject == self)
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
            target:self action:@selector(close)];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged:)
        name:WCGestureVideoCallStateDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged:)
        name:WCGestureDidChangeNotification object:nil];
    [self rebuild];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)settingsChanged:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self settingsChanged:notification]; }); return;
    }
    if (self.adjusting && [self.sliderToken isEqualToString:WCGestureVideoCallContextToken()]) return;
    self.adjusting = NO;
    [self rebuild];
    if (self.checkingResources && [notification.name isEqualToString:WCGestureVideoCallStateDidChangeNotification]) {
        NSString *status = WCGestureVideoCallStatus();
        if (status.length && ![status hasPrefix:@"正在"]) {
            self.checkingResources = NO;
            if (self.view.window) WCShowToast(status);
        }
    }
}
- (void)close { [self.navigationController dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self rebuild]; }
- (void)rebuild {
    NSMutableArray *sections = [NSMutableArray arrayWithObject:@[
        WCVideoSettingsRow(@"视频美颜", @"switch", WCGestureVideoCallBeautyEnabledKey),
        WCVideoSettingsRow(@"贴纸", @"switch", WCGestureVideoCallStickerEnabledKey),
        WCVideoSettingsRow(@"前摄视频镜像", @"switch", WCGestureVideoCallMirrorEnabledKey)]];
    NSMutableArray *virtualVideo=[NSMutableArray arrayWithObject:WCVideoSettingsRow(@"虚拟视频",@"switch",WCGestureVirtualVideoEnabledKey)];
    if(WCGestureEnabled(WCGestureVirtualVideoEnabledKey)) {
        NSString *videoName=WCGestureVirtualVideoSourceName();
        [virtualVideo addObject:WCVideoSettingsRow([videoName isEqualToString:@"未选择"]?@"选择视频":[@"视频：" stringByAppendingString:videoName],@"virtual-source",nil)];
        [virtualVideo addObject:WCVideoSettingsRow([NSString stringWithFormat:@"源视频方向（%ld°）",(long)[NSUserDefaults.standardUserDefaults integerForKey:WCGestureVirtualVideoRotationKey]],@"virtual-rotation",nil)];
        [virtualVideo addObject:WCVideoSettingsRow(@"源视频左右翻转",@"switch",WCGestureVirtualVideoMirrorKey)];
        [virtualVideo addObject:WCVideoSettingsRow(@"使用文件音轨",@"switch",WCGestureVirtualVideoAudioKey)];
        if([NSUserDefaults.standardUserDefaults boolForKey:WCGestureVirtualVideoAudioKey])[virtualVideo addObject:WCVideoSettingsRow(@"混入麦克风",@"switch",WCGestureVirtualVideoMixMicKey)];
        if(![WCGestureVirtualVideoSourceName() isEqualToString:@"未选择"])[virtualVideo addObject:WCVideoSettingsRow(@"移除视频",@"virtual-clear",nil)];
    }
    [sections addObject:virtualVideo];
    if (WCGestureEnabled(WCGestureVideoCallStickerEnabledKey)) {
        NSMutableArray *sticker = [NSMutableArray arrayWithObjects:WCVideoSettingsRow(@"选择图片贴纸", @"image", nil), WCVideoSettingsRow(@"文字贴纸", @"text-sticker", nil), nil];
        if (WCGestureVideoCallHasSticker()) [sticker addObject:WCVideoSettingsRow(@"移动、缩放贴纸", @"move", nil)];
        [sticker addObject:WCVideoSettingsRow(@"移除贴纸", @"clear", nil)]; [sections addObject:sticker];
    }
    if (WCGestureEnabled(WCGestureVideoCallBeautyEnabledKey)) {
        NSArray *items = WCGestureVideoCallBeautyItems();
        if (items.count) {
            NSMutableArray *controls = [NSMutableArray array];
            for (NSDictionary *item in items) {
                NSMutableDictionary *row = [item mutableCopy]; row[@"kind"] = @"value";
                [controls addObject:row];
            }
            [sections addObject:controls];
        }
        [sections addObject:@[WCVideoSettingsRow(@"检查美颜资源", @"prepare", nil),
            WCVideoSettingsRow(@"恢复默认美颜", @"reset", nil)]];
    }
    self.rows = sections;
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView { return self.rows.count; }
- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rows[section].count; }
- (CGFloat)tableView:(__unused UITableView *)tableView heightForRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return ([self.rows[indexPath.section][indexPath.row][@"kind"] isEqualToString:@"value"] ? 84 : 52) * WCGestureSettingsScaleFactor();
}
- (UITableViewCell *)tableView:(__unused UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.rows[indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:16 * WCGestureSettingsScaleFactor()];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14 * WCGestureSettingsScaleFactor()];
    cell.backgroundColor = self.inCallPanel ? [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:.22]
        : UIColor.secondarySystemGroupedBackgroundColor;
    NSString *kind = row[@"kind"];
    if ([kind isEqualToString:@"switch"]) {
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = UIColor.systemBlueColor;
        toggle.on = WCGestureEnabled(row[@"key"]);
        NSString *key = row[@"key"];
        [toggle addAction:[UIAction actionWithHandler:^(UIAction *action) {
            UISwitch *sender = action.sender;
            [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:key];
            WCGestureSettingsPostChange(key);
        }] forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([kind isEqualToString:@"value"]) {
        cell.textLabel.text = nil; cell.selectionStyle = UITableViewCellSelectionStyleNone;
        CGFloat scale = WCGestureSettingsScaleFactor();
        UILabel *title = [UILabel new], *value = [UILabel new];
        title.text = row[@"title"]; title.font = [UIFont systemFontOfSize:14 * scale];
        value.text = [NSString stringWithFormat:@"%.2f", [row[@"value"] doubleValue]];
        value.font = [UIFont monospacedDigitSystemFontOfSize:12 * scale weight:UIFontWeightRegular];
        [value setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title, value]];
        heading.spacing = 8 * scale;
        UISlider *slider = [UISlider new]; slider.minimumTrackTintColor = UIColor.systemBlueColor;
        slider.minimumValue = [row[@"min"] floatValue]; slider.maximumValue = [row[@"max"] floatValue];
        slider.value = [row[@"value"] floatValue]; slider.accessibilityLabel = row[@"title"];
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[heading, slider]];
        stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 4 * scale; stack.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16 * scale],
            [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16 * scale],
            [stack.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor]]];
        NSString *identifier = row[@"id"];
        __weak WCVideoCallSettingsController *weakSelf = self;
        [slider addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
            WCVideoCallSettingsController *owner = weakSelf;
            owner.adjusting = YES; owner.sliderToken = WCGestureVideoCallContextToken(); owner.lastPreview = 0;
        }] forControlEvents:UIControlEventTouchDown];
        [slider addAction:[UIAction actionWithHandler:^(UIAction *action) {
            WCVideoCallSettingsController *owner = weakSelf; UISlider *sender = action.sender;
            value.text = [NSString stringWithFormat:@"%.2f", sender.value];
            if (!owner || !WCGestureVideoCallContextToken().length) return;
            if (!sender.isTracking) { WCGestureVideoCallSetBeautyValue(identifier, sender.value); return; }
            if (![owner.sliderToken isEqualToString:WCGestureVideoCallContextToken()]) return;
            CFTimeInterval now = CACurrentMediaTime();
            if (now - owner.lastPreview >= .05) {
                owner.lastPreview = now; WCGestureVideoCallPreviewBeautyValue(identifier, sender.value);
            }
        }] forControlEvents:UIControlEventValueChanged];
        [slider addAction:[UIAction actionWithHandler:^(UIAction *action) {
            WCVideoCallSettingsController *owner = weakSelf; UISlider *sender = action.sender;
            if (owner.sliderToken.length && [owner.sliderToken isEqualToString:WCGestureVideoCallContextToken()])
                WCGestureVideoCallSetBeautyValue(identifier, sender.value);
            owner.adjusting = NO; owner.sliderToken = nil; [owner rebuild];
        }] forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    } else {
        cell.textLabel.textColor = UIColor.systemBlueColor;
        if ([kind isEqualToString:@"clear"] && !WCGestureVideoCallHasSticker()) cell.textLabel.textColor = UIColor.secondaryLabelColor;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.rows[indexPath.section][indexPath.row];
    NSString *kind = row[@"kind"];
    if ([kind isEqualToString:@"text-sticker"]) { WCGestureVideoCallEditTextSticker(self); return; }
    if ([kind isEqualToString:@"virtual-source"]) {
        if(self.loadingVideo || self.presentedViewController)return;
        self.videoPickerAccount=WCCurrentUserWXID();
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeMovie] asCopy:YES];
        picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];return;
    }
    if ([kind isEqualToString:@"virtual-clear"]) { WCGestureVirtualVideoClear();[self rebuild];return; }
    if ([kind isEqualToString:@"virtual-rotation"]) {
        NSMutableArray *options=[NSMutableArray array];for(NSNumber *angle in @[@0,@90,@180,@270])[options addObject:[WCPopupOption optionWithTitle:[NSString stringWithFormat:@"%@°",angle] value:angle]];
        [WCPopup showOptionsWithTitle:@"源视频方向" message:nil options:options selected:[NSUserDefaults.standardUserDefaults objectForKey:WCGestureVirtualVideoRotationKey] completion:^(id value){
            if(![@[@0,@90,@180,@270] containsObject:value])return;[NSUserDefaults.standardUserDefaults setInteger:[value integerValue] forKey:WCGestureVirtualVideoRotationKey];WCGestureSettingsPostChange(WCGestureVirtualVideoRotationKey);
        }];return;
    }

    if ([kind isEqualToString:@"prepare"]) {
        if (!WCGestureVideoCallContextToken().length) { WCShowToast(@"请在视频通话中检查美颜资源"); return; }
        self.checkingResources = YES;
        WCGestureVideoCallResourcesChanged();
        WCShowToast(WCGestureVideoCallStatus());
    } else if ([kind isEqualToString:@"reset"]) {
        WCGestureVideoCallResetBeauty();
    } else if ([kind isEqualToString:@"clear"]) {
        WCGestureVideoCallClearSticker();
    } else if ([kind isEqualToString:@"move"]) {
        WCGestureVideoCallRepositionSticker(self);
    } else if ([kind isEqualToString:@"image"]) {
        if (self.loadingImage || self.presentedViewController) return;
        self.selectionToken = WCGestureVideoCallContextToken();
        if (!self.selectionToken.length) { WCShowToast(@"请在视频通话中添加贴纸"); return; }
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
        configuration.filter = PHPickerFilter.imagesFilter;
        configuration.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    NSString *token = self.selectionToken;
    self.selectionToken = nil;
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (!provider || self.loadingImage) { [picker dismissViewControllerAnimated:YES completion:nil]; return; }
    self.loadingImage = YES;
    __weak WCVideoCallSettingsController *weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [provider loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier completionHandler:^(NSURL *url, NSError *error) {
            UIImage *image = nil;
            if (url && !error) {
                CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
                if (source) {
                    NSDictionary *options = @{(id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
                        (id)kCGImageSourceCreateThumbnailWithTransform:@YES, (id)kCGImageSourceThumbnailMaxPixelSize:@2048};
                    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                    if (thumbnail) { image = [UIImage imageWithCGImage:thumbnail]; CGImageRelease(thumbnail); }
                    CFRelease(source);
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                WCVideoCallSettingsController *strongSelf = weakSelf;
                strongSelf.loadingImage = NO;
                if (!strongSelf || !strongSelf.view.window || strongSelf.presentedViewController ||
                    !token.length || ![token isEqualToString:WCGestureVideoCallContextToken()]) return;
                if (!image) { WCShowToast(@"图片读取失败"); return; }
                WCGestureVideoCallEditSticker(strongSelf, image);
            });
        }];
    }];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if(self.loadingVideo || !urls.count || ![self.videoPickerAccount isEqualToString:WCCurrentUserWXID() ?: @""])return;
    self.loadingVideo=YES;__weak WCVideoCallSettingsController *weak=self;
    WCGestureVirtualVideoImport(urls.firstObject,^(BOOL success){WCVideoCallSettingsController *host=weak;host.loadingVideo=NO;
        if(!host || ![host.videoPickerAccount isEqualToString:WCCurrentUserWXID() ?: @""])return;
        [host rebuild];if(host.view.window)WCShowToast(success?@"视频已保存":@"视频导入失败");
    });
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { self.videoPickerAccount=nil; }

@end

UIViewController *WCGestureCreateVideoCallSettingsController(void) { return [WCVideoCallSettingsController new]; }

@interface WCVideoControlsPresentation : UIPresentationController
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) UIView *grabber;
@property (nonatomic) CGFloat panelHeight;
@property (nonatomic) CGFloat dragHeight;
@end
@implementation WCVideoControlsPresentation
- (BOOL)shouldRemovePresentersView { return NO; }
- (CGRect)frameOfPresentedViewInContainerView {
    UIView *container = self.containerView; UIEdgeInsets safe = container.safeAreaInsets;
    CGFloat bottom = CGRectGetHeight(container.bounds) - safe.bottom - 8;
    CGFloat maximum = MAX(1, bottom - safe.top - 12);
    CGFloat height = MIN(maximum, self.panelHeight > 0 ? self.panelHeight : 320);
    return CGRectMake(safe.left + 10, bottom - height,
        MAX(1, CGRectGetWidth(container.bounds) - safe.left - safe.right - 20), height);
}
- (void)layoutPanel {
    CGRect frame = self.frameOfPresentedViewInContainerView;
    self.presentedView.bounds = (CGRect){CGPointZero, frame.size};
    self.presentedView.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    self.glass.frame = frame;
    if ([self.presentedViewController isKindOfClass:UINavigationController.class]) {
        UINavigationBar *bar = ((UINavigationController *)self.presentedViewController).navigationBar;
        self.grabber.frame = CGRectMake((bar.bounds.size.width - 34) / 2, 2, 34, 4);
    }
}
- (void)presentationTransitionWillBegin {
    self.glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    self.glass.layer.cornerRadius = 20; self.glass.layer.masksToBounds = YES;
    self.glass.contentView.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:.12];
    [self.containerView insertSubview:self.glass atIndex:0];
    self.presentedView.backgroundColor = UIColor.clearColor;
    self.presentedView.layer.cornerRadius = 20; self.presentedView.layer.masksToBounds = YES;
    self.glass.alpha = 0; [self layoutPanel];
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        self.glass.alpha = 1;
    } completion:nil];
}
- (void)presentationTransitionDidEnd:(BOOL)completed {
    if (!completed) { [self.glass removeFromSuperview]; return; }
    self.glass.alpha = 1;
    if ([self.presentedViewController isKindOfClass:UINavigationController.class]) {
        UINavigationBar *bar = ((UINavigationController *)self.presentedViewController).navigationBar;
        self.grabber = [UIView new]; self.grabber.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:.35];
        self.grabber.layer.cornerRadius = 2; self.grabber.userInteractionEnabled = NO;
        [bar addSubview:self.grabber];
        [bar addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)]];
        [self layoutPanel];
    }
}
- (void)containerViewWillLayoutSubviews { [super containerViewWillLayoutSubviews]; [self layoutPanel]; }
- (void)dragPanel:(UIPanGestureRecognizer *)gesture {
    CGFloat maximum = MAX(1, self.containerView.bounds.size.height - self.containerView.safeAreaInsets.top -
        self.containerView.safeAreaInsets.bottom - 20);
    if (gesture.state == UIGestureRecognizerStateBegan) self.dragHeight = self.presentedView.bounds.size.height;
    CGFloat delta = [gesture translationInView:self.containerView].y;
    if (gesture.state == UIGestureRecognizerStateChanged) {
        self.panelHeight = MAX(MIN(180, maximum), MIN(maximum, self.dragHeight - delta)); [self layoutPanel];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        if (gesture.state == UIGestureRecognizerStateEnded && delta > 100 && [gesture velocityInView:self.containerView].y > 600)
            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        else {
            self.panelHeight = MAX(MIN(260, maximum), MIN(maximum, self.panelHeight));
            [UIView animateWithDuration:.2 animations:^{ [self layoutPanel]; }];
        }
    }
}
- (void)dismissalTransitionWillBegin {
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        self.glass.alpha = 0;
    } completion:nil];
}
- (void)dismissalTransitionDidEnd:(BOOL)completed {
    if (completed) { [self.glass removeFromSuperview]; [self.grabber removeFromSuperview]; }
    else self.glass.alpha = 1;
}
@end

@interface WCVideoControlsTransition : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic) BOOL presenting;
@end
@implementation WCVideoControlsTransition
- (NSTimeInterval)transitionDuration:(__unused id<UIViewControllerContextTransitioning>)context { return .25; }
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context {
    UIViewController *controller = [context viewControllerForKey:self.presenting ? UITransitionContextToViewControllerKey : UITransitionContextFromViewControllerKey];
    UIView *view = [context viewForKey:self.presenting ? UITransitionContextToViewKey : UITransitionContextFromViewKey] ?: controller.view;
    if (self.presenting) {
        view.frame = [context finalFrameForViewController:controller]; [context.containerView addSubview:view];
        view.transform = CGAffineTransformMakeTranslation(0, view.bounds.size.height + 32);
    }
    [UIView animateWithDuration:[self transitionDuration:context] animations:^{
        view.transform = self.presenting ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, view.bounds.size.height + 32);
    } completion:^(__unused BOOL finished) {
        if (context.transitionWasCancelled) view.transform = CGAffineTransformIdentity;
        [context completeTransition:!context.transitionWasCancelled];
    }];
}
@end

@interface WCVideoControlsDelegate : NSObject <UIViewControllerTransitioningDelegate>
@end
@implementation WCVideoControlsDelegate
- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented
    presentingViewController:(UIViewController *)presenting sourceViewController:(__unused UIViewController *)source {
    return [[WCVideoControlsPresentation alloc] initWithPresentedViewController:presented presentingViewController:presenting];
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(__unused UIViewController *)presented
    presentingController:(__unused UIViewController *)presenting sourceController:(__unused UIViewController *)source {
    WCVideoControlsTransition *transition = [WCVideoControlsTransition new]; transition.presenting = YES; return transition;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(__unused UIViewController *)dismissed {
    return [WCVideoControlsTransition new];
}
@end

void WCGesturePresentVideoCallSettings(UIViewController *presenter) {
    if (!presenter.view.window || presenter.presentedViewController) return;
    WCVideoCallSettingsController *settings = [WCVideoCallSettingsController new]; settings.inCallPanel = YES;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    static WCVideoControlsDelegate *delegate; static dispatch_once_t once;
    dispatch_once(&once, ^{ delegate = [WCVideoControlsDelegate new]; });
    navigation.modalPresentationStyle = UIModalPresentationCustom; navigation.transitioningDelegate = delegate;
    [presenter presentViewController:navigation animated:YES completion:nil];
}


// One Wx basic text-to-image adapter. This is not an online/PAG template clone.
// The verified call compositor accepts the resulting transparent UIImage via
// the existing sticker editor's affine bake path.
void WCGestureVideoCallEditTextSticker(UIViewController *presenter) {
    NSString *token=WCGestureVideoCallContextToken();
    if(!token.length || !WCGestureEnabled(WCGestureVideoCallStickerEnabledKey)){WCShowToast(@"请在视频通话中开启贴纸");return;}
    __weak UIViewController *weak=presenter;
    [WCPopup showInputWithTitle:@"文字贴纸" message:nil text:nil placeholder:@"输入文字，最多 128 字" keyboard:UIKeyboardTypeDefault completion:^(NSString *text){
        UIViewController *host=weak;if(!host.view.window || ![token isEqualToString:WCGestureVideoCallContextToken()] || !WCGestureEnabled(WCGestureVideoCallStickerEnabledKey))return;
        if(!text.length || text.length>128){WCShowToast(@"请输入 1–128 字");return;}
        NSMutableParagraphStyle *paragraph=[NSMutableParagraphStyle new];paragraph.alignment=NSTextAlignmentCenter;paragraph.lineBreakMode=NSLineBreakByWordWrapping;
        NSDictionary *attributes=@{NSFontAttributeName:[UIFont systemFontOfSize:52 weight:UIFontWeightMedium],NSForegroundColorAttributeName:UIColor.whiteColor,
            NSStrokeColorAttributeName:UIColor.blackColor,NSStrokeWidthAttributeName:@(-3),NSParagraphStyleAttributeName:paragraph};
        CGRect bounds=[text boundingRectWithSize:CGSizeMake(960,1200) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:attributes context:nil];
        CGSize size=CGSizeMake(ceil(bounds.size.width)+32,ceil(bounds.size.height)+32);
        if(size.width<1 || size.height<1 || size.height>1232)return;
        UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=1;format.opaque=NO;
        UIImage *image=[[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(__unused UIGraphicsImageRendererContext *context){
            [text drawWithRect:CGRectMake(16,16,size.width-32,size.height-32) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:attributes context:nil];
        }];
        WCGestureVideoCallEditSticker(host,image);
    }];
}
