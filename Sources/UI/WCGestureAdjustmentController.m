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
@property (nonatomic, strong) NSLayoutConstraint *panelHeight;
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
    self.title = self.customTitle ?: (self.kind == WCGesturePreviewAntiRevoke ? @"提示外观预览" : @"消息时间位置预览");
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
    self.controlsPanel.hidden = YES;
    UILabel *title = [UILabel new]; title.text = @"预览调节"; title.textColor = UIColor.labelColor;
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem]; [reset setTitle:@"重置" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem]; [done setTitle:@"完成" forState:UIControlStateNormal];
    [done addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *view in @[self.preview, self.controlsPanel]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:view]; }
    for (UIView *view in @[title, reset, done, self.table]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.controlsPanel addSubview:view]; }
    self.panelHeight = [self.controlsPanel.heightAnchor constraintEqualToConstant:360];
    NSLayoutYAxisAnchor *previewTop = self.customPreview ? self.view.safeAreaLayoutGuide.topAnchor : self.view.topAnchor;
    [NSLayoutConstraint activateConstraints:@[
        [self.preview.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.preview.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.preview.topAnchor constraintEqualToAnchor:previewTop],
        [self.preview.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"调节" style:UIBarButtonItemStylePlain target:self action:@selector(togglePanel)];
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
    if (fabs(self.panelHeight.constant - height) > 0.5) self.panelHeight.constant = height;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, self.view.safeAreaInsets.bottom, 0);
    WCGestureSetPreviewObscuredHeight(self.preview, self.controlsPanel.hidden ? 0 : self.panelHeight.constant);
}
- (void)togglePanel {
    self.controlsPanel.hidden = !self.controlsPanel.hidden;
    WCGestureSetPreviewObscuredHeight(self.preview, self.controlsPanel.hidden ? 0 : self.panelHeight.constant);
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
    BOOL revoke = self.kind == WCGesturePreviewAntiRevoke;
    BOOL side = [NSUserDefaults.standardUserDefaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    NSMutableArray *parameters = [NSMutableArray arrayWithObjects:
        @{ @"title": @"调节项目", @"targets": @[@"时间", @"防撤回", @"布局", @"圆角"] },
        @{ @"title": @"预览外观", @"themes": @[@"系统", @"浅色", @"深色"] }, nil];
    if (self.kind == WCGesturePreviewInputRounding) {
        [parameters addObject:@{ @"title": @"输入框高度", @"inputLines": @[@"单行", @"三行", @"五行"] }];
        [parameters addObject:@{ @"option": @{ @"title": @"聊天输入栏圆角", @"type": @"bool", @"key": WCGestureChatInputRoundingEnabledKey } }];
        [parameters addObject:@{ @"option": @{ @"title": @"输入框内部圆角", @"type": @"bool", @"key": WCGestureChatInputInnerRoundingKey } }];
        [parameters addObject:WCParameter(@"内部圆角程度", WCGestureChatInputInnerRadiusKey, 0, 40, 18)];
        [parameters addObject:@{ @"option": @{ @"title": @"外部工具栏圆角", @"type": @"bool", @"key": WCGestureChatInputOuterRoundingKey } }];
        [parameters addObject:WCParameter(@"外部圆角程度", WCGestureChatInputOuterRadiusKey, 0, 40, 22)];
        self.parameters = parameters; [self.table reloadData]; [self.preview setNeedsLayout]; return;
    }
    if (self.kind == WCGesturePreviewLayout) {
        [parameters addObject:WCParameter(@"界面比例 (%)", WCGesturePageScalePercentKey, 70, 100, 90)];
        [parameters addObject:@{ @"option": @{ @"title": @"界面大小", @"type": @"bool", @"key": WCGesturePageScaleEnabledKey } }];
        [parameters addObject:@{ @"option": @{ @"title": @"包含插件界面", @"type": @"bool", @"key": WCGesturePageScalePluginUIKey } }];
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
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.kind == WCGesturePreviewInputRounding
        ? @"预览展示所选配置；开启总开关后应用到真实聊天。圆角不超过控件高度的一半，可切换多行查看。" : nil;
}
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
        UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:parameter[@"targets"]];
        segments.selectedSegmentIndex = self.kind;
        [segments addTarget:self action:@selector(targetChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = segments;
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
            UISwitch *toggle = [UISwitch new]; toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:option[@"key"]];
            toggle.tag = path.row; [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle;
        } else { cell.detailTextLabel.text = WCGestureChatOptionDetail(option); cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    } else if (parameter[@"segments"]) {
        cell.textLabel.text = parameter[@"title"];
        UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:parameter[@"segments"]];
        segments.selectedSegmentIndex = MIN(2, MAX(0, [NSUserDefaults.standardUserDefaults integerForKey:parameter[@"key"]]));
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
        UISlider *slider = [UISlider new]; slider.tag = 9200;
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
- (void)targetChanged:(UISegmentedControl *)segments {
    self.kind = segments.selectedSegmentIndex;
    WCGestureSetChatPreviewKind(self.preview, self.kind);
    [self rebuildParameters];
}
- (void)inputLinesChanged:(UISegmentedControl *)segments {
    self.inputLineSelection = segments.selectedSegmentIndex;
    WCGestureSetPreviewInputLines(self.preview, 1 + 2 * self.inputLineSelection);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *parameter = self.parameters[path.row];
    if (parameter[@"option"]) { WCGestureEditChatOption(self, parameter[@"option"]); return; }
    if (parameter[@"textKey"]) {
        NSString *key = parameter[@"textKey"];
        [WCPopup showInputWithTitle:parameter[@"title"] message:@"实时预览气泡旁提示文字" text:[NSUserDefaults.standardUserDefaults stringForKey:key] placeholder:@"已拦截撤回"
            keyboard:UIKeyboardTypeDefault completion:^(NSString *text) {
                [NSUserDefaults.standardUserDefaults setObject:text forKey:key]; WCGestureSettingsPostChange(key);
            }];
    } else if (parameter[@"minimum"]) {
        NSString *key = parameter[@"key"];
        [WCPopup showInputWithTitle:parameter[@"title"] message:[NSString stringWithFormat:@"范围 %@ 到 %@", parameter[@"minimum"], parameter[@"maximum"]]
            text:[NSString stringWithFormat:@"%.0f", [NSUserDefaults.standardUserDefaults doubleForKey:key]] placeholder:nil keyboard:UIKeyboardTypeNumbersAndPunctuation completion:^(NSString *text) {
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
