#import <PhotosUI/PhotosUI.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCVideoCallSettingsController : UITableViewController <PHPickerViewControllerDelegate>
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *rows;
@property (nonatomic, copy) NSString *selectionToken;
@property (nonatomic) BOOL loadingImage;
@property (nonatomic) BOOL checkingResources;
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
        WCVideoSettingsRow(@"图片贴纸", @"switch", WCGestureVideoCallStickerEnabledKey),
        WCVideoSettingsRow(@"前摄视频镜像", @"switch", WCGestureVideoCallMirrorEnabledKey)]];
    if (WCGestureEnabled(WCGestureVideoCallStickerEnabledKey)) [sections addObject:@[
        WCVideoSettingsRow(@"选择图片贴纸", @"image", nil), WCVideoSettingsRow(@"移除贴纸", @"clear", nil)]];
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
    return 52 * WCGestureSettingsScaleFactor();
}
- (UITableViewCell *)tableView:(__unused UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.rows[indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:16 * WCGestureSettingsScaleFactor()];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14 * WCGestureSettingsScaleFactor()];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
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
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f", [row[@"value"] doubleValue]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
    if ([kind isEqualToString:@"prepare"]) {
        if (!WCGestureVideoCallContextToken().length) { WCShowToast(@"请在视频通话中检查美颜资源"); return; }
        self.checkingResources = YES;
        WCGestureVideoCallResourcesChanged();
        WCShowToast(WCGestureVideoCallStatus());
    } else if ([kind isEqualToString:@"reset"]) {
        WCGestureVideoCallResetBeauty();
    } else if ([kind isEqualToString:@"clear"]) {
        WCGestureVideoCallClearSticker();
    } else if ([kind isEqualToString:@"value"]) {
        NSString *identifier = row[@"id"];
        NSString *token = WCGestureVideoCallContextToken();
        if (!token.length) { WCShowToast(@"请在视频通话中调节美颜"); return; }
        double minimum = [row[@"min"] doubleValue], maximum = [row[@"max"] doubleValue];
        [WCPopup showInputWithTitle:row[@"title"] message:nil
            text:[NSString stringWithFormat:@"%.2f", [row[@"value"] doubleValue]]
            placeholder:[NSString stringWithFormat:@"%.2f - %.2f", minimum, maximum]
            keyboard:UIKeyboardTypeNumbersAndPunctuation completion:^(NSString *text) {
                if (![token isEqualToString:WCGestureVideoCallContextToken()]) return;
                NSScanner *scanner = [NSScanner scannerWithString:text];
                double value = 0;
                if (![scanner scanDouble:&value] || !scanner.isAtEnd || !isfinite(value)) return;
                WCGestureVideoCallSetBeautyValue(identifier, MIN(maximum, MAX(minimum, value)));
            }];
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
@end

UIViewController *WCGestureCreateVideoCallSettingsController(void) { return [WCVideoCallSettingsController new]; }
