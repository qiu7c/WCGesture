#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static NSDictionary *WCOption(NSString *title, NSString *type, NSString *key) {
    return @{ @"title": title, @"type": type, @"key": key ?: @"" };
}

NSArray<NSDictionary *> *WCGestureChatOptions(BOOL antiRevoke, BOOL includeHidden) {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *rows = [NSMutableArray array];
    if (antiRevoke) {
        BOOL side = [d integerForKey:WCGestureAntiRevokePromptStyleKey] == 1;
        [rows addObject:WCOption(@"防撤回提示方案", @"prompt-style", WCGestureAntiRevokePromptStyleKey)];
        [rows addObject:WCOption(@"整页提示预览", @"revoke-position", nil)];
        if (!side || includeHidden) [rows addObject:WCOption(@"本地提示模板", @"template", WCGestureAntiRevokeLocalTemplateKey)];
        [rows addObject:WCOption(@"浅色模式提示颜色", @"color", side ? WCGestureAntiRevokeSideLightTextColorKey : WCGestureAntiRevokeLocalLightTextColorKey)];
        [rows addObject:WCOption(@"深色模式提示颜色", @"color", side ? WCGestureAntiRevokeSideDarkTextColorKey : WCGestureAntiRevokeLocalDarkTextColorKey)];
        [rows addObject:WCOption(@"回复撤回者", @"bool", WCGestureAntiRevokeNotifySenderKey)];
        if (includeHidden || [d boolForKey:WCGestureAntiRevokeNotifySenderKey]) {
            [rows addObject:WCOption(@"回复时间限制", @"filter", WCGestureAntiRevokeTimeFilterKey)];
            [rows addObject:WCOption(@"回复消息模板", @"template", WCGestureAntiRevokeReplyTemplateKey)];
        }
        [rows addObject:WCOption(@"防撤回记录中心", @"records", nil)];
        [rows addObject:WCOption(@"本地保存撤回记录", @"bool", WCGestureAntiRevokePersistRecordsKey)];
    } else {
        BOOL side = [d boolForKey:WCGestureMessageTimeBubbleSideKey];
        [rows addObject:WCOption(@"时间显示位置", @"time-mode", WCGestureMessageTimeBubbleSideKey)];
        [rows addObject:WCOption(@"整页聊天预览与调节", @"time-position", nil)];
        if (side || includeHidden) [rows addObject:WCOption(@"消息旁垂直位置", @"time-position", WCGestureMessageTimePositionKey)];
        if (!side || includeHidden) [rows addObject:WCOption(@"头像时间间距", @"time-position", WCGestureMessageTimeAvatarSpacingKey)];
        [rows addObject:WCOption(@"时间格式", @"format", WCGestureMessageTimeFormatKey)];
        [rows addObject:WCOption(@"时间字号", @"font-size", WCGestureMessageTimeFontSizeKey)];
        [rows addObject:WCOption(@"时间文字加粗", @"bool", WCGestureMessageTimeBoldKey)];
        [rows addObject:WCOption(@"浅色模式时间颜色", @"color", WCGestureMessageTimeLightColorKey)];
        [rows addObject:WCOption(@"深色模式时间颜色", @"color", WCGestureMessageTimeDarkColorKey)];
    }
    return rows;
}

NSString *WCGestureChatOptionDetail(NSDictionary *option) {
    NSString *type = option[@"type"], *key = option[@"key"];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if ([type isEqualToString:@"wallet-lqt"]) return WCGestureWalletDisplayTextForKind(2);
    if ([type isEqualToString:@"wallet-merchant"]) return WCGestureWalletDisplayTextForKind(3);
    if ([type isEqualToString:@"wallet-display"]) return WCGestureWalletDisplayText();
    if ([type isEqualToString:@"long-press-menu"]) return [NSString stringWithFormat:@"%lu 项", (unsigned long)WCGestureLongPressMenuTitles().count];
    if ([type isEqualToString:@"prompt-style"]) return [d integerForKey:key] == 1 ? @"气泡旁" : @"消息下方";
    if ([type isEqualToString:@"time-mode"]) return [d boolForKey:key] ? @"消息右侧" : @"头像下方";
    if ([type isEqualToString:@"format"]) return [d stringForKey:key] ?: @"MM-dd HH:mm:ss";
    if ([type isEqualToString:@"font-size"]) return [NSString stringWithFormat:@"%.0f", [d doubleForKey:key]];
    if ([type isEqualToString:@"filter"]) {
        double seconds = [d doubleForKey:key];
        if (seconds <= 0) return @"不限制";
        return seconds >= 3600 ? [NSString stringWithFormat:@"%.0f 小时", seconds / 3600] : [NSString stringWithFormat:@"%.0f 分钟", seconds / 60];
    }
    if ([type isEqualToString:@"color"]) {
        NSString *hex = [d stringForKey:key];
        return hex.length ? hex.uppercaseString : @"跟随默认";
    }
    if ([type isEqualToString:@"time-position"] && [key isEqualToString:WCGestureMessageTimePositionKey]) {
        return @[@"顶部", @"中间", @"底部"][MIN(2, MAX(0, [d integerForKey:key]))];
    }
    if ([key isEqualToString:WCGestureMessageTimeAvatarSpacingKey]) return [NSString stringWithFormat:@"%.0f", [d doubleForKey:key]];
    return @"";
}

@interface WCChatColorPicker : UIColorPickerViewController <UIColorPickerViewControllerDelegate>
@property (nonatomic, copy) NSString *defaultsKey;
@end
@implementation WCChatColorPicker
- (void)viewDidLoad { [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self); self.delegate = self; self.supportsAlpha = YES; }
- (void)saveColor:(UIColor *)color {
    UIColor *resolved = [color resolvedColorWithTraitCollection:self.traitCollection];
    [NSUserDefaults.standardUserDefaults setObject:WCGestureHexStringFromColor(resolved) forKey:self.defaultsKey];
    WCGestureSettingsPostChange(self.defaultsKey);
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker { [self saveColor:picker.selectedColor]; }
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker { [self saveColor:picker.selectedColor]; }
- (void)colorPickerViewController:(UIColorPickerViewController *)picker didSelectColor:(UIColor *)color continuously:(BOOL)continuous API_AVAILABLE(ios(15.0)) {
    [self saveColor:color];
}
@end

@interface WCChatTextEditor : UIViewController
@property (nonatomic, copy) NSDictionary *option;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) NSLayoutConstraint *editorBottom;
@end
@implementation WCChatTextEditor
- (NSString *)defaultText {
    NSString *key = self.option[@"key"];
    if ([self.option[@"type"] isEqualToString:@"format"]) return [key isEqualToString:WCGestureMomentsTimeFormatKey] ? @"yyyy-MM-dd HH:mm:ss" : @"MM-dd HH:mm:ss";
    return WCGestureAntiRevokeDefaultTemplate([key isEqualToString:WCGestureAntiRevokeReplyTemplateKey]);
}
- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self);
    self.title = self.option[@"title"];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.textView = [UITextView new];
    self.textView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.textView.layer.cornerRadius = 16;
    self.textView.textContainerInset = UIEdgeInsetsMake(16, 16, 16, 16);
    self.textView.font = [UIFont systemFontOfSize:17 * WCGestureSettingsScaleFactor()];
    self.textView.textColor = UIColor.labelColor;
    NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:self.option[@"key"]];
    self.textView.text = saved.length ? saved : self.defaultText;
    self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"恢复默认" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *view in @[self.textView, reset]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:view]; }
    self.editorBottom = [self.textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16];
    [NSLayoutConstraint activateConstraints:@[
        [reset.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [reset.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [reset.heightAnchor constraintEqualToConstant:40],
        [self.textView.topAnchor constraintEqualToAnchor:reset.bottomAnchor constant:8],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20], self.editorBottom,
    ]];
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];
    toolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithTitle:@"收起键盘" style:UIBarButtonItemStyleDone target:self action:@selector(hideKeyboard)]];
    self.textView.inputAccessoryView = toolbar;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)keyboard:(NSNotification *)note {
    CGRect frame = [self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGFloat overlap = MAX(0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(frame) - self.view.safeAreaInsets.bottom);
    self.editorBottom.constant = -16 - overlap;
    [self.view layoutIfNeeded];
}
- (void)hideKeyboard { [self.view endEditing:YES]; }
- (void)reset { self.textView.text = self.defaultText; }
- (void)save {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!text.length) text = self.defaultText;
    if ([self.option[@"type"] isEqualToString:@"format"]) {
        text = WCGestureNormalizedDateFormat(text);
        if (!text) { [WCPopup showMessage:@"时间格式不支持" message:@"最多 64 字符，请使用支持的日期符号。 "]; return; }
    }
    [NSUserDefaults.standardUserDefaults setObject:text forKey:self.option[@"key"]];
    WCGestureSettingsPostChange(self.option[@"key"]);
    [self.navigationController popViewControllerAnimated:YES];
}
@end

void WCGestureEditChatOption(UIViewController *presenter, NSDictionary *option) {
    NSString *type = option[@"type"], *key = option[@"key"], *title = option[@"title"];
    NSDictionary *previewKinds = @{ @"time-position": @(WCGesturePreviewMessageTime),
        @"revoke-position": @(WCGesturePreviewAntiRevoke),
        @"input-rounding-position": @(WCGesturePreviewInputRounding),
        @"top-bar-position": @(WCGesturePreviewChatTopBar) };
    NSNumber *previewKind = previewKinds[type];
    if (previewKind) {
        [presenter.navigationController pushViewController:WCGestureCreatePositionEditor(previewKind.integerValue) animated:YES];
    } else if ([type isEqualToString:@"moments-feed-preview"]) {
        [presenter.navigationController pushViewController:WCGestureCreateMomentsFeedPreviewController() animated:YES];
    } else if ([type isEqualToString:@"floating-tab-bar"]) {
        [presenter.navigationController pushViewController:WCGestureCreateFloatingTabBarSettingsController() animated:YES];
    } else if ([type isEqualToString:@"home-groups"]) {
        [presenter.navigationController pushViewController:WCGestureCreateHomeGroupsSettingsController() animated:YES];
    } else if ([type isEqualToString:@"custom-avatar"]) {
        [presenter.navigationController pushViewController:WCGestureCreateCustomAvatarController() animated:YES];
    } else if ([type isEqualToString:@"virtual-location"]) {
        [presenter.navigationController pushViewController:WCGestureCreateVirtualLocationSettingsController() animated:YES];
    } else if ([type isEqualToString:@"wallet-lqt"]) {
        WCGestureWalletDisplayEditKind(2);
    } else if ([type isEqualToString:@"wallet-merchant"]) {
        WCGestureWalletDisplayEditKind(3);
    } else if ([type isEqualToString:@"wallet-display"]) {
        WCGestureWalletDisplayEdit();
    } else if ([type isEqualToString:@"clear-profile"]) {
        WCGesturePresentClearProfileInformation();
    } else if ([type isEqualToString:@"auto-status"]) {
        [presenter.navigationController pushViewController:WCGestureCreateAutoStatusSettingsController() animated:YES];
    } else if ([type isEqualToString:@"corner-settings"]) {
        [presenter.navigationController pushViewController:WCGestureCreateCornerSettingsController() animated:YES];
    } else if ([type isEqualToString:@"long-press-menu"]) {
        [presenter.navigationController pushViewController:WCGestureCreateLongPressMenuController() animated:YES];
    } else if ([type isEqualToString:@"records"]) {
        [presenter.navigationController pushViewController:WCGestureCreateRevokeRecordsController() animated:YES];
    } else if ([type isEqualToString:@"color"]) {
        WCChatColorPicker *picker = [WCChatColorPicker new];
        picker.defaultsKey = key; picker.title = title;
        picker.selectedColor = WCGestureColorForDefaultsKey(key, UIColor.secondaryLabelColor);
        [presenter presentViewController:picker animated:YES completion:nil];
    } else if ([type isEqualToString:@"template"] || [type isEqualToString:@"format"]) {
        WCChatTextEditor *editor = [WCChatTextEditor new]; editor.option = option;
        [presenter.navigationController pushViewController:editor animated:YES];
    } else if ([type isEqualToString:@"font-size"]) {
        [WCPopup showInputWithTitle:title message:nil text:[NSString stringWithFormat:@"%.0f", [NSUserDefaults.standardUserDefaults doubleForKey:key]]
            placeholder:@"8 - 18" keyboard:UIKeyboardTypeDecimalPad completion:^(NSString *text) {
                double value = text.doubleValue; if (!isfinite(value)) return;
                [NSUserDefaults.standardUserDefaults setDouble:MIN(18, MAX(8, value)) forKey:key]; WCGestureSettingsPostChange(key);
            }];
    } else {
        NSArray *titles, *values;
        if ([type isEqualToString:@"filter"]) {
            titles = @[@"不限制", @"1 分钟", @"5 分钟", @"30 分钟", @"1 小时", @"24 小时"];
            values = @[@0, @60, @300, @1800, @3600, @86400];
        } else if ([type isEqualToString:@"time-mode"]) {
            titles = @[@"头像下方", @"消息右侧"]; values = @[@NO, @YES];
        } else if ([type isEqualToString:@"prompt-style"]) {
            titles = @[@"消息下方", @"气泡旁"]; values = @[@0, @1];
        } else return;
        NSMutableArray *options = [NSMutableArray array];
        for (NSUInteger i = 0; i < titles.count; i++) [options addObject:[WCPopupOption optionWithTitle:titles[i] value:values[i]]];
        [WCPopup showOptionsWithTitle:title message:nil options:options
            selected:[NSUserDefaults.standardUserDefaults objectForKey:key] completion:^(id value) {
                if (!value) return;
                [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
                if ([type isEqualToString:@"time-mode"]) [NSUserDefaults.standardUserDefaults setBool:![value boolValue] forKey:WCGestureMessageTimeBelowAvatarKey];
                WCGestureSettingsPostChange(key);
            }];
    }
}
