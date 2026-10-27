#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

// Parameters describe the controls rather than the feature. More layout
// editors can reuse this page by supplying a preview and parameter list.
@interface WCAdjustmentController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, assign) WCGesturePreviewKind kind;
@property (nonatomic, strong) UIView *preview;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, copy) NSArray<NSDictionary *> *parameters;
@property (nonatomic, copy) NSArray<NSDictionary *> *customParameters;
@property (nonatomic, copy) NSString *customTitle;
@property (nonatomic, strong) UIView *customPreview;
@property (nonatomic, assign) NSInteger previewTheme;
@property (nonatomic, strong) UIView *controlsPanel;
@property (nonatomic, strong) UILabel *panelTitle;
@property (nonatomic, strong) NSLayoutConstraint *panelHeight;
@property (nonatomic, strong) NSLayoutConstraint *previewBottom;
@property (nonatomic, assign) BOOL capturedNavigationState;
@property (nonatomic, assign) BOOL previousNavigationHidden;
@property (nonatomic, assign) NSInteger inputLineSelection;
@end

static NSDictionary *WCParameter(NSString *title, NSString *key, double minimum, double maximum, double reset) {
    return @{ @"title": title, @"key": key, @"minimum": @(minimum), @"maximum": @(maximum), @"reset": @(reset) };
}

@implementation WCAdjustmentController
- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self);
    self.title = self.customTitle ?: @"聊天外观预览";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.preview = self.customPreview ?: WCGestureCreateChatPreview(self.kind);
    WCGestureSetPreviewEditing(self.preview, YES);
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self; self.table.delegate = self;
    self.table.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.controlsPanel = [UIView new];
    self.controlsPanel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.controlsPanel.layer.cornerRadius = 20;
    self.controlsPanel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.controlsPanel.clipsToBounds = YES;
    self.controlsPanel.hidden = self.customPreview != nil;
    UILabel *title = [UILabel new]; self.panelTitle = title; title.text = @"预览调节"; title.textColor = UIColor.labelColor;
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem]; [reset setTitle:@"重置" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem]; [done setTitle:@"完成" forState:UIControlStateNormal];
    [done addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *view in @[self.preview, self.controlsPanel]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:view]; }
    for (UIView *view in @[title, reset, done, self.table]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.controlsPanel addSubview:view]; }
    self.panelHeight = [self.controlsPanel.heightAnchor constraintEqualToConstant:360];
    self.previewBottom = [self.preview.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
    self.previewBottom.constant = self.controlsPanel.hidden ? 0 : -372;
    self.preview.clipsToBounds = YES;
    NSLayoutYAxisAnchor *previewTop = self.customPreview ? self.view.safeAreaLayoutGuide.topAnchor : self.view.topAnchor;
    [NSLayoutConstraint activateConstraints:@[
        [self.preview.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.preview.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.preview.topAnchor constraintEqualToAnchor:previewTop],
        self.previewBottom,
        [self.controlsPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.controlsPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.controlsPanel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor], self.panelHeight,
        [title.leadingAnchor constraintEqualToAnchor:self.controlsPanel.leadingAnchor constant:20],
        [title.topAnchor constraintEqualToAnchor:self.controlsPanel.topAnchor constant:14],
        [done.trailingAnchor constraintEqualToAnchor:self.controlsPanel.trailingAnchor constant:-16],
        [done.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [reset.trailingAnchor constraintEqualToAnchor:done.leadingAnchor constant:-20],
        [reset.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.table.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [self.table.leadingAnchor constraintEqualToAnchor:self.controlsPanel.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.controlsPanel.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.controlsPanel.bottomAnchor],
    ]];
    __weak typeof(self) weakSelf = self;
    WCGestureSetPreviewNavigation(self.preview, ^{ [weakSelf.navigationController popViewControllerAnimated:YES]; }, ^{ [weakSelf togglePanel]; });
    WCGestureSetPreviewControlsExpanded(self.preview, !self.controlsPanel.hidden);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"外观调节" style:UIBarButtonItemStylePlain target:self action:@selector(togglePanel)];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:WCGestureDidChangeNotification object:nil];
    [self rebuildParameters];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.capturedNavigationState) {
        self.previousNavigationHidden = self.navigationController.navigationBarHidden;
        self.capturedNavigationState = YES;
    }
    if (!self.customPreview) [self.navigationController setNavigationBarHidden:YES animated:animated];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.customPreview) [self.navigationController setNavigationBarHidden:self.previousNavigationHidden animated:animated];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat available = CGRectGetHeight(self.view.bounds) - self.view.safeAreaInsets.top - 60;
    CGFloat height = MIN(MAX(180, available), MIN(420, CGRectGetHeight(self.view.bounds) * 0.55));
    if (!self.customPreview) {
        BOOL capsule = self.kind == WCGesturePreviewChatTopBar || WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey);
        CGFloat minimumPreview = self.view.safeAreaInsets.top + 44 + (capsule ? 44 : 0) + 52 + 55 + 70;
        height = MIN(height, MAX(100, CGRectGetHeight(self.view.bounds) - minimumPreview - 12));
    }
    if (fabs(self.panelHeight.constant - height) > 0.5) self.panelHeight.constant = height;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, self.view.safeAreaInsets.bottom, 0);
    self.previewBottom.constant = self.controlsPanel.hidden ? 0 : -(self.panelHeight.constant + 12);
    self.preview.layer.cornerRadius = self.controlsPanel.hidden ? 0 : 20;
    self.preview.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
}
- (void)togglePanel {
    self.controlsPanel.hidden = !self.controlsPanel.hidden;
    WCGestureSetPreviewControlsExpanded(self.preview, !self.controlsPanel.hidden);
    self.previewBottom.constant = self.controlsPanel.hidden ? 0 : -(self.panelHeight.constant + 12);
    self.preview.layer.cornerRadius = self.controlsPanel.hidden ? 0 : 20;
    self.preview.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [self.view layoutIfNeeded];
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    if (self.previewTheme == 2) return UIStatusBarStyleLightContent;
    if (self.previewTheme == 1) return UIStatusBarStyleDarkContent;
    return [super preferredStatusBarStyle];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)rebuildParameters {
    if (self.customParameters) {
        self.parameters = self.customParameters;
        [self.table reloadData]; [self.preview setNeedsLayout];
        return;
    }
    NSArray *targetTitles = @[@"消息时间", @"防撤回提示", @"输入圆角", @"胶囊顶栏", @"头像圆角"];
    self.panelTitle.text = targetTitles[self.kind];
    [self.view setNeedsLayout];
    BOOL revoke = self.kind == WCGesturePreviewAntiRevoke;
    BOOL side = [NSUserDefaults.standardUserDefaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    NSMutableArray *parameters = [NSMutableArray arrayWithObjects:
        @{ @"title": @"调节项目", @"targets": targetTitles },
        @{ @"title": @"预览外观", @"themes": @[@"系统", @"浅色", @"深色"] }, nil];
    if (self.kind == WCGesturePreviewAvatarRounding) {
        [parameters addObject:@{ @"option": @{ @"title": @"全局头像圆角", @"type": @"bool", @"key": WCGestureGlobalAvatarRoundingEnabledKey } }];
        [parameters addObject:WCParameter(@"头像圆角程度 (%)", WCGestureGlobalAvatarCornerPercentKey, 0, 100, 100)];
        self.parameters = parameters; [self.table reloadData]; [self.preview setNeedsLayout]; return;
    }
    if (self.kind == WCGesturePreviewChatTopBar) {
        [parameters addObject:@{ @"option": @{ @"title": @"胶囊顶栏", @"type": @"bool", @"key": WCGestureChatTopBarCapsuleEnabledKey } }];
        [parameters addObject:WCParameter(@"玻璃透明度 (%)", WCGestureChatGlassTransparencyKey, 0, 100, 50)];
        [parameters addObject:WCParameter(@"胶囊外框大小 (%)", WCGestureChatTopBarShellScaleKey, 80, 140, 100)];
        [parameters addObject:WCParameter(@"图标大小", WCGestureChatTopBarIconSizeKey, 12, 26, 18)];
        [parameters addObject:WCParameter(@"模糊强度 (%)", WCGestureChatGlassBlurIntensityKey, 0, 100, 20)];
        [parameters addObject:WCParameter(@"头像大小", WCGestureChatTopBarAvatarSizeKey, 24, 34, 30)];
        [parameters addObject:WCParameter(@"昵称字号", WCGestureChatTopBarNicknameSizeKey, 12, 18, 15)];
        [parameters addObject:@{ @"option": @{ @"title": @"聊天搜索按钮", @"type": @"bool", @"key": WCGestureChatSearchEnabledKey } }];
        self.parameters = parameters; [self.table reloadData]; [self.preview setNeedsLayout]; return;
    }
    if (self.kind == WCGesturePreviewInputRounding) {
        [parameters addObject:@{ @"title": @"输入框高度", @"inputLines": @[@"单行", @"三行", @"五行"] }];
        [parameters addObject:@{ @"option": @{ @"title": @"聊天输入栏圆角", @"type": @"bool", @"key": WCGestureChatInputRoundingEnabledKey } }];
        [parameters addObject:@{ @"option": @{ @"title": @"输入框内部圆角", @"type": @"bool", @"key": WCGestureChatInputInnerRoundingKey } }];
        [parameters addObject:WCParameter(@"内部圆角程度", WCGestureChatInputInnerRadiusKey, 0, 40, 18)];
        [parameters addObject:@{ @"option": @{ @"title": @"外部工具栏圆角", @"type": @"bool", @"key": WCGestureChatInputOuterRoundingKey } }];
        [parameters addObject:WCParameter(@"外部圆角程度", WCGestureChatInputOuterRadiusKey, 0, 40, 22)];
        self.parameters = parameters; [self.table reloadData]; [self.preview setNeedsLayout]; return;
    }
    NSArray *options = WCGestureChatOptions(revoke, NO);
    if (!revoke) {
        [parameters addObject:@{ @"option": options.firstObject }];
        if (side) [parameters addObject:@{ @"title": @"垂直基准", @"segments": @[@"顶部", @"中间", @"底部"], @"key": WCGestureMessageTimePositionKey, @"reset": @2 }];
    } else {
        [parameters addObject:@{ @"option": options.firstObject }];
        if ([NSUserDefaults.standardUserDefaults integerForKey:WCGestureAntiRevokePromptStyleKey] == 1)
            [parameters addObject:@{ @"title": @"提示文字", @"textKey": WCGestureAntiRevokeSideTextKey }];
    }
    BOOL revokeSide = revoke && [NSUserDefaults.standardUserDefaults integerForKey:WCGestureAntiRevokePromptStyleKey] == 1;
    if (revokeSide || (!revoke && side)) {
        [parameters addObject:WCParameter(@"水平位置 X", revoke ? WCGestureAntiRevokeSideOffsetXKey : WCGestureMessageTimeOffsetXKey, -80, 80, 0)];
        [parameters addObject:WCParameter(@"垂直位置 Y", revoke ? WCGestureAntiRevokeSideOffsetYKey : WCGestureMessageTimeOffsetYKey, -80, 80, revoke ? 10 : 0)];
    } else if (!revoke) [parameters addObject:WCParameter(@"头像时间间距", WCGestureMessageTimeAvatarSpacingKey, -6, 8, -2)];
    if (!revoke) [parameters addObject:WCParameter(@"时间字号", WCGestureMessageTimeFontSizeKey, 8, 18, 10)];
    for (NSDictionary *option in options) {
        NSString *type = option[@"type"];
        if ([type isEqualToString:@"color"] || [type isEqualToString:@"format"] ||
            ([type isEqualToString:@"template"] && [option[@"key"] isEqualToString:WCGestureAntiRevokeLocalTemplateKey]) ||
            ([type isEqualToString:@"bool"] && !revoke)) [parameters addObject:@{ @"option": option }];
    }
    self.parameters = parameters;
    [self.table reloadData];
    [self.preview setNeedsLayout];
}
- (void)changed:(NSNotification *)note {
    [self.preview setNeedsLayout];
    // Keep an actively dragged slider alive; rebuilding it loses its touch.
    for (UITableViewCell *cell in self.table.visibleCells) {
        UISlider *slider = [cell.contentView viewWithTag:9200];
        if (slider.isTracking) return;
    }
    [self rebuildParameters];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.parameters.count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return self.parameters[path.row][@"minimum"] ? 86 * WCGestureSettingsScaleFactor() : 52 * WCGestureSettingsScaleFactor();
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *parameter = self.parameters[path.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.font = [UIFont systemFontOfSize:15 * WCGestureSettingsScaleFactor()];
    NSDictionary *option = parameter[@"option"];
    if (parameter[@"targets"]) {
        cell.textLabel.text = parameter[@"title"];
        cell.detailTextLabel.text = parameter[@"targets"][self.kind];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14 * WCGestureSettingsScaleFactor()];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (parameter[@"inputLines"]) {
        cell.textLabel.text = parameter[@"title"];
        UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:parameter[@"inputLines"]];
        segments.selectedSegmentIndex = self.inputLineSelection;
        [segments addTarget:self action:@selector(inputLinesChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = segments;
    } else if (parameter[@"themes"]) {
        cell.textLabel.text = parameter[@"title"];
        UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:parameter[@"themes"]];
        segments.selectedSegmentIndex = self.previewTheme;
        [segments addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = segments;
    } else if (option) {
        cell.textLabel.text = option[@"title"];
        if ([option[@"type"] isEqualToString:@"bool"]) {
            UISwitch *toggle = [UISwitch new]; toggle.onTintColor = UIColor.systemBlueColor; toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:option[@"key"]];
            toggle.tag = path.row; [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle;
        } else { cell.detailTextLabel.text = WCGestureChatOptionDetail(option); cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    } else if (parameter[@"segments"]) {
        cell.textLabel.text = parameter[@"title"];
        UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:parameter[@"segments"]];
        segments.selectedSegmentIndex = MIN((NSInteger)[parameter[@"segments"] count] - 1, MAX(0, [NSUserDefaults.standardUserDefaults integerForKey:parameter[@"key"]]));
        segments.tag = path.row; [segments addTarget:self action:@selector(segmented:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = segments;
    } else if (parameter[@"textKey"]) {
        cell.textLabel.text = parameter[@"title"];
        cell.detailTextLabel.text = [NSUserDefaults.standardUserDefaults stringForKey:parameter[@"textKey"]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        // Auto Layout keeps the sliders usable when the plugin UI is scaled.
        cell.textLabel.text = nil;
        UILabel *label = [UILabel new]; label.tag = 9201;
        label.textColor = UIColor.labelColor;
        label.font = [UIFont monospacedDigitSystemFontOfSize:14 * WCGestureSettingsScaleFactor() weight:UIFontWeightRegular];
        double value = [NSUserDefaults.standardUserDefaults doubleForKey:parameter[@"key"]];
        label.text = [NSString stringWithFormat:@"%@   %.0f", parameter[@"title"], value];
        UISlider *slider = [UISlider new]; slider.tag = 9200; slider.minimumTrackTintColor = UIColor.systemBlueColor;
        slider.minimumValue = [parameter[@"minimum"] floatValue]; slider.maximumValue = [parameter[@"maximum"] floatValue]; slider.value = value;
        slider.accessibilityIdentifier = parameter[@"key"];
        [slider addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
        for (UIView *view in @[label, slider]) { view.translatesAutoresizingMaskIntoConstraints = NO; [cell.contentView addSubview:view]; }
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [label.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [label.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
            [slider.leadingAnchor constraintEqualToAnchor:label.leadingAnchor],
            [slider.trailingAnchor constraintEqualToAnchor:label.trailingAnchor],
            [slider.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:4],
            [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
        ]];
    }
    return cell;
}
- (void)slid:(UISlider *)slider {
    double value = round(slider.value); NSString *key = slider.accessibilityIdentifier;
    [NSUserDefaults.standardUserDefaults setDouble:value forKey:key];
    UIView *parent = slider.superview;
    UILabel *label = [parent viewWithTag:9201];
    for (NSDictionary *parameter in self.parameters) if ([parameter[@"key"] isEqualToString:key]) label.text = [NSString stringWithFormat:@"%@   %.0f", parameter[@"title"], value];
    WCGestureSettingsPostChange(key);
}
- (void)toggled:(UISwitch *)toggle {
    NSDictionary *option = self.parameters[toggle.tag][@"option"];
    [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:option[@"key"]]; WCGestureSettingsPostChange(option[@"key"]);
}
- (void)segmented:(UISegmentedControl *)segments {
    NSString *key = self.parameters[segments.tag][@"key"];
    [NSUserDefaults.standardUserDefaults setInteger:segments.selectedSegmentIndex forKey:key]; WCGestureSettingsPostChange(key);
}
- (void)themeChanged:(UISegmentedControl *)segments {
    self.previewTheme = segments.selectedSegmentIndex;
    self.preview.overrideUserInterfaceStyle = (UIUserInterfaceStyle)self.previewTheme;
    [self.preview setNeedsLayout];
    [self setNeedsStatusBarAppearanceUpdate];
}
- (void)inputLinesChanged:(UISegmentedControl *)segments {
    self.inputLineSelection = segments.selectedSegmentIndex;
    WCGestureSetPreviewInputLines(self.preview, 1 + 2 * self.inputLineSelection);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *parameter = self.parameters[path.row];
    if (parameter[@"targets"]) {
        NSMutableArray *options = [NSMutableArray array];
        NSArray *titles = parameter[@"targets"];
        for (NSUInteger i = 0; i < titles.count; i++) [options addObject:[WCPopupOption optionWithTitle:titles[i] value:@(i)]];
        __weak WCAdjustmentController *weakSelf = self;
        [WCPopup showOptionsWithTitle:@"选择调节项目" message:nil options:options selected:@(self.kind) completion:^(id value) {
            WCAdjustmentController *controller = weakSelf;
            NSInteger index = [value integerValue];
            if (!controller || !value || index < 0 || index >= (NSInteger)titles.count) return;
            controller.kind = index; WCGestureSetChatPreviewKind(controller.preview, controller.kind); [controller rebuildParameters];
        }]; return;
    }
    if (parameter[@"option"]) { WCGestureEditChatOption(self, parameter[@"option"]); return; }
    if (parameter[@"textKey"]) {
        NSString *key = parameter[@"textKey"];
        [WCPopup showInputWithTitle:parameter[@"title"] message:nil text:[NSUserDefaults.standardUserDefaults stringForKey:key] placeholder:@"已拦截撤回"
            keyboard:UIKeyboardTypeDefault completion:^(NSString *text) {
                [NSUserDefaults.standardUserDefaults setObject:text forKey:key]; WCGestureSettingsPostChange(key);
            }];
    } else if (parameter[@"minimum"]) {
        NSString *key = parameter[@"key"];
        [WCPopup showInputWithTitle:parameter[@"title"] message:nil
            text:[NSString stringWithFormat:@"%.0f", [NSUserDefaults.standardUserDefaults doubleForKey:key]] placeholder:[NSString stringWithFormat:@"%@ - %@", parameter[@"minimum"], parameter[@"maximum"]] keyboard:UIKeyboardTypeNumbersAndPunctuation completion:^(NSString *text) {
                NSScanner *scanner = [NSScanner scannerWithString:text]; double value;
                if (![scanner scanDouble:&value] || !scanner.isAtEnd || !isfinite(value)) return;
                [NSUserDefaults.standardUserDefaults setDouble:MIN([parameter[@"maximum"] doubleValue], MAX([parameter[@"minimum"] doubleValue], value)) forKey:key];
                WCGestureSettingsPostChange(key);
            }];
    }
}
- (void)reset {
    for (NSDictionary *parameter in self.parameters) {
        if (parameter[@"reset"] && ![parameter[@"key"] isEqualToString:WCGestureMessageTimeFontSizeKey]) [NSUserDefaults.standardUserDefaults setObject:parameter[@"reset"] forKey:parameter[@"key"]];
    }
    WCGestureSettingsPostChange(nil);
}
@end

UIViewController *WCGestureCreatePositionEditor(WCGesturePreviewKind kind) {
    WCAdjustmentController *controller = [WCAdjustmentController new]; controller.kind = kind; return controller;
}

UIViewController *WCGestureCreateAdjustmentEditor(NSString *title, UIView *preview, NSArray<NSDictionary *> *parameters) {
    WCAdjustmentController *controller = [WCAdjustmentController new];
    controller.customPreview = preview; controller.customTitle = title; controller.customParameters = parameters;
    return controller;
}
