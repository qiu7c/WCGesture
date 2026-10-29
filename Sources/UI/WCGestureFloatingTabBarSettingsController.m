#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static NSDictionary *WCFloatSwitch(NSString *title, NSString *key) { return @{@"title":title,@"key":key,@"switch":@YES}; }
static NSDictionary *WCFloatNumber(NSString *title, NSString *key, double low, double high) { return @{@"title":title,@"key":key,@"minimum":@(low),@"maximum":@(high)}; }

@interface WCFloatSettingsController : UITableViewController
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *sections;
@property (nonatomic, strong) NSMutableIndexSet *collapsed;
@property (nonatomic, strong) UIView *preview;
@property (nonatomic, strong) UISegmentedControl *theme;
@end
@implementation WCFloatSettingsController
- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) self.hidesBottomBarWhenPushed = YES;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"悬浮底栏"; WCGestureSettingsConfigureNavigation(self);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"重置" style:UIBarButtonItemStylePlain target:self action:@selector(reset)];
    if (self.navigationController.presentingViewController && self.navigationController.viewControllers.firstObject == self)
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0,0,1,12)];
    self.preview = WCGestureCreateFloatingTabBarPreview();
    self.theme = [[UISegmentedControl alloc] initWithItems:@[@"跟随微信",@"浅色",@"深色"]];
    self.theme.selectedSegmentIndex = 0; [self.theme addTarget:self action:@selector(themeChanged) forControlEvents:UIControlEventValueChanged];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.tableView.bounds.size.width,200)];
    [header addSubview:self.preview]; [header addSubview:self.theme]; self.tableView.tableHeaderView = header;
    self.sections = @[
        @[WCFloatSwitch(@"悬浮底栏",WCGestureFloatingTabBarEnabledKey)],
        @[@{@"title":@"外观",@"group":@YES},
          @{@"title":@"背景样式",@"key":WCGestureFloatingTabBarStyleKey,@"choices":@[@"纯色",@"磨砂",@"浅色纯色 · 深色磨砂",@"自定义颜色"]},
          WCFloatNumber(@"背景不透明度 (%)",WCGestureFloatingTabBarAlphaKey,0,100),
          WCFloatSwitch(@"立体阴影",WCGestureFloatingTabBarStereoKey),
          WCFloatSwitch(@"隐藏文字",WCGestureFloatingTabBarHideTextKey),
          @{@"title":@"选中动画",@"key":WCGestureFloatingTabBarAnimationKey,@"choices":@[@"关闭",@"弹性",@"摇摆",@"果冻",@"心跳",@"跳动"]}],
        @[@{@"title":@"位置与圆角",@"group":@YES},
          WCFloatNumber(@"横向扩展",WCGestureFloatingTabBarWidthKey,-50,50),
          WCFloatNumber(@"垂直偏移",WCGestureFloatingTabBarYKey,-40,40),
          WCFloatNumber(@"高度增量",WCGestureFloatingTabBarHeightKey,-40,40),
          WCFloatNumber(@"圆角偏移",WCGestureFloatingTabBarRadiusKey,-50,50)],
        @[@{@"title":@"选中滑块与手势",@"group":@YES},
          WCFloatSwitch(@"隐藏选中滑块",WCGestureFloatingTabBarNoMaskKey),
          WCFloatNumber(@"滑块不透明度 (%)",WCGestureFloatingTabBarMaskAlphaKey,0,100),
          WCFloatSwitch(@"滑块阴影",WCGestureFloatingTabBarMaskGlowKey),
          WCFloatSwitch(@"滑动切换页面",WCGestureFloatingTabBarPanKey),
          WCFloatSwitch(@"长按通讯录调节",WCGestureFloatingTabBarLongPressKey)],
        @[@{@"title":@"角标",@"group":@YES},
          WCFloatSwitch(@"隐藏未读红点",WCGestureFloatingTabBarHideDotKey),
          WCFloatSwitch(@"隐藏未读数字",WCGestureFloatingTabBarHideBadgeKey)],
        @[@{@"title":@"自定义颜色",@"group":@YES},
          @{@"title":@"选中图标与文字",@"key":WCGestureFloatingTabBarSelectedColorKey,@"color":@YES},
          @{@"title":@"浅色背景",@"key":WCGestureFloatingTabBarBackgroundLightKey,@"color":@YES},
          @{@"title":@"深色背景",@"key":WCGestureFloatingTabBarBackgroundDarkKey,@"color":@YES},
          @{@"title":@"浅色滑块",@"key":WCGestureFloatingTabBarMaskLightKey,@"color":@YES},
          @{@"title":@"深色滑块",@"key":WCGestureFloatingTabBarMaskDarkKey,@"color":@YES}]
    ];
    self.collapsed = [NSMutableIndexSet indexSet];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:WCGestureDidChangeNotification object:nil];
    [self themeChanged];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.collapsed = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(1,self.sections.count-1)];
    [self.tableView reloadData];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.tableView.bounds.size.width;
    self.theme.frame = CGRectMake(32,12,MAX(0,width-64),30);
    CGFloat height = [self.preview sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)].height;
    self.preview.frame = CGRectMake(0,42,width,height);
    UIView *header = self.tableView.tableHeaderView;
    if (fabs(header.bounds.size.height-height-42) > .5) {
        header.frame = CGRectMake(0,0,width,height+42); self.tableView.tableHeaderView = header;
    }
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)close { [self.navigationController dismissViewControllerAnimated:YES completion:nil]; }
- (void)themeChanged {
    BOOL dark = self.theme.selectedSegmentIndex == 2 || (self.theme.selectedSegmentIndex == 0 && WCGestureHomePageIsDark(self.view));
    self.preview.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    [self.preview setNeedsLayout];
}
- (void)changed:(NSNotification *)note {
    [self themeChanged];
    [self.view setNeedsLayout];
    for (UITableViewCell *cell in self.tableView.visibleCells) if (((UISlider *)[cell.contentView viewWithTag:9570]).isTracking) return;
    [self.tableView reloadData];
}
- (void)reset {
    for (NSArray *section in self.sections) for (NSDictionary *row in section)
        if (row[@"key"]) [NSUserDefaults.standardUserDefaults removeObjectForKey:row[@"key"]];
    WCGestureSettingsPostChange(WCGestureFloatingTabBarEnabledKey);
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return [self.collapsed containsIndex:section] ? 1 : self.sections[section].count; }
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return 0; }
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section { return 0; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { return self.sections[path.section][path.row][@"maximum"] ? 84 : 50; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = self.sections[path.section][path.row]; NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    UITableViewCell *cell = WCGestureSettingsCardCell(table,nil,UITableViewCellStyleValue1,path);
    cell.textLabel.text = row[@"title"]; cell.textLabel.font = [UIFont systemFontOfSize:16 * WCGestureSettingsScaleFactor()];
    cell.indentationWidth = 18; cell.indentationLevel = path.row ? 1 : 0;
    if (row[@"group"]) {
        cell.imageView.image = [UIImage systemImageNamed:[self.collapsed containsIndex:path.section] ? @"chevron.right" : @"chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightRegular]];
        cell.imageView.tintColor = UIColor.tertiaryLabelColor;
    } else if (row[@"switch"]) {
        UISwitch *toggle = [UISwitch new]; toggle.onTintColor = UIColor.systemBlueColor;
        toggle.on = [d boolForKey:row[@"key"]]; toggle.accessibilityIdentifier = row[@"key"];
        [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle;
    } else if (row[@"maximum"]) {
        cell.textLabel.text = nil;
        UILabel *label = [UILabel new]; label.tag = 9571; label.font = [UIFont systemFontOfSize:15]; label.textColor = UIColor.labelColor;
        label.text = [NSString stringWithFormat:@"%@   %.0f",row[@"title"],[d doubleForKey:row[@"key"]]];
        UISlider *slider = [UISlider new]; slider.tag = 9570;
        slider.minimumValue = [row[@"minimum"] floatValue]; slider.maximumValue = [row[@"maximum"] floatValue];
        slider.value = [d doubleForKey:row[@"key"]]; slider.accessibilityIdentifier = row[@"key"]; slider.accessibilityLabel = row[@"title"];
        [slider addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
        for (UIView *view in @[label,slider]) { view.translatesAutoresizingMaskIntoConstraints = NO; [cell.contentView addSubview:view]; }
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:34], [label.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20], [label.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
            [slider.leadingAnchor constraintEqualToAnchor:label.leadingAnchor], [slider.trailingAnchor constraintEqualToAnchor:label.trailingAnchor], [slider.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:4], [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8]
        ]];
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (row[@"choices"]) {
            NSArray *titles = row[@"choices"]; NSInteger index = [d integerForKey:row[@"key"]];
            cell.detailTextLabel.text = index >= 0 && index < (NSInteger)titles.count ? titles[index] : titles.firstObject;
        } else cell.detailTextLabel.text = [d stringForKey:row[@"key"]].length ? @"已设置" : @"默认";
    }
    return cell;
}
- (void)toggled:(UISwitch *)toggle {
    [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:toggle.accessibilityIdentifier];
    WCGestureSettingsPostChange(toggle.accessibilityIdentifier);
}
- (void)slid:(UISlider *)slider {
    double value = round(slider.value); [NSUserDefaults.standardUserDefaults setDouble:value forKey:slider.accessibilityIdentifier];
    UILabel *label = [slider.superview viewWithTag:9571]; label.text = [NSString stringWithFormat:@"%@   %.0f",slider.accessibilityLabel,value];
    WCGestureSettingsPostChange(slider.accessibilityIdentifier);
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; NSDictionary *row = self.sections[path.section][path.row]; NSString *key = row[@"key"];
    if (row[@"group"]) {
        if ([self.collapsed containsIndex:path.section]) [self.collapsed removeIndex:path.section]; else [self.collapsed addIndex:path.section];
        [table reloadData]; return;
    }
    if (row[@"choices"]) {
        NSMutableArray *options = [NSMutableArray array]; NSArray *titles = row[@"choices"];
        for (NSUInteger i = 0; i < titles.count; i++) [options addObject:[WCPopupOption optionWithTitle:titles[i] value:@(i)]];
        [WCPopup showOptionsWithTitle:row[@"title"] message:nil options:options selected:[NSUserDefaults.standardUserDefaults objectForKey:key] completion:^(id value) {
            [NSUserDefaults.standardUserDefaults setObject:value forKey:key]; WCGestureSettingsPostChange(key);
        }];
    } else if (row[@"color"]) {
        [WCPopup showOptionsWithTitle:row[@"title"] message:nil options:@[[WCPopupOption optionWithTitle:@"选择颜色" value:@1],[WCPopupOption optionWithTitle:@"恢复默认" value:@0]] selected:nil completion:^(id value) {
            if ([value boolValue]) WCGestureEditChatOption(self,@{@"title":row[@"title"],@"type":@"color",@"key":key});
            else { [NSUserDefaults.standardUserDefaults removeObjectForKey:key]; WCGestureSettingsPostChange(key); }
        }];
    }
}
@end
UIViewController *WCGestureCreateFloatingTabBarSettingsController(void) { return [WCFloatSettingsController new]; }
