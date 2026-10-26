#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCCornerSettingsController : UITableViewController
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *sections;
@property (nonatomic, strong) NSMutableIndexSet *collapsed;
@end
static NSDictionary *WCCornerSwitch(NSString *title, NSString *key) { return @{@"title":title,@"key":key,@"switch":@YES}; }
static NSDictionary *WCCornerNumber(NSString *title, NSString *key, double maximum) { return @{@"title":title,@"key":key,@"maximum":@(maximum)}; }
@implementation WCCornerSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"圆角设置"; WCGestureSettingsConfigureNavigation(self);
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor; self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.sections = @[
        @[WCCornerSwitch(@"全局头像圆角",WCGestureGlobalAvatarRoundingEnabledKey),WCCornerNumber(@"头像圆角程度 (%)",WCGestureGlobalAvatarCornerPercentKey,100)],
        @[WCCornerSwitch(@"聊天输入栏圆角",WCGestureChatInputRoundingEnabledKey),WCCornerSwitch(@"输入框内部圆角",WCGestureChatInputInnerRoundingKey),WCCornerNumber(@"内部圆角程度",WCGestureChatInputInnerRadiusKey,40),WCCornerSwitch(@"外部工具栏圆角",WCGestureChatInputOuterRoundingKey),WCCornerNumber(@"外部圆角程度",WCGestureChatInputOuterRadiusKey,40),@{@"title":@"整页圆角预览与调节",@"preview":@YES}],
        @[WCCornerSwitch(@"朋友圈圆角",WCGestureMomentsImageCornerEnabledKey),WCCornerNumber(@"圆角程度",WCGestureMomentsImageCornerRadiusKey,40)],
        @[WCCornerSwitch(@"表情圆角",WCGestureEmoticonCornerEnabledKey),WCCornerNumber(@"圆角程度",WCGestureEmoticonCornerRadiusKey,40)],
        @[WCCornerSwitch(@"聊天图片圆角",WCGestureChatImageCornerEnabledKey),WCCornerNumber(@"圆角程度",WCGestureChatImageCornerRadiusKey,40)]
    ];
    self.collapsed = [NSMutableIndexSet indexSet];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:WCGestureDidChangeNotification object:nil];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)changed:(NSNotification *)note {
    for (UITableViewCell *cell in self.tableView.visibleCells) if (((UISlider *)[cell.contentView viewWithTag:9550]).isTracking) return;
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.collapsed containsIndex:section] ? 1 : self.sections[section].count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path { return self.sections[path.section][path.row][@"maximum"] ? 84 : 50; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = self.sections[path.section][path.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; cell.textLabel.font = [UIFont systemFontOfSize:16]; cell.textLabel.text = row[@"title"];
    cell.indentationLevel = path.row ? 1 : 0; cell.indentationWidth = 18;
    if (!path.row) {
        cell.imageView.image = [UIImage systemImageNamed:[self.collapsed containsIndex:path.section] ? @"chevron.right" : @"chevron.down"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightRegular]];
        cell.imageView.tintColor = UIColor.tertiaryLabelColor;
    }
    if (row[@"switch"]) {
        UISwitch *toggle = [UISwitch new]; toggle.onTintColor = UIColor.systemBlueColor; toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:row[@"key"]];
        toggle.accessibilityIdentifier = row[@"key"]; [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle;
    } else if (row[@"maximum"]) {
        cell.textLabel.text = nil;
        UILabel *label = [UILabel new]; label.tag = 9551; label.textColor = UIColor.labelColor; label.font = [UIFont systemFontOfSize:15];
        label.text = [NSString stringWithFormat:@"%@   %.0f",row[@"title"],[NSUserDefaults.standardUserDefaults doubleForKey:row[@"key"]]];
        UISlider *slider = [UISlider new]; slider.tag = 9550; slider.minimumValue = 0; slider.maximumValue = [row[@"maximum"] floatValue]; slider.value = [NSUserDefaults.standardUserDefaults doubleForKey:row[@"key"]]; slider.accessibilityIdentifier = row[@"key"];
        slider.accessibilityLabel = row[@"title"]; [slider addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
        for (UIView *view in @[label,slider]) { view.translatesAutoresizingMaskIntoConstraints = NO; [cell.contentView addSubview:view]; }
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:34], [label.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20], [label.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
            [slider.leadingAnchor constraintEqualToAnchor:label.leadingAnchor], [slider.trailingAnchor constraintEqualToAnchor:label.trailingAnchor], [slider.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:4], [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8]
        ]];
    } else { cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    return cell;
}
- (void)toggled:(UISwitch *)toggle { [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:toggle.accessibilityIdentifier]; WCGestureSettingsPostChange(toggle.accessibilityIdentifier); }
- (void)slid:(UISlider *)slider {
    NSString *key = slider.accessibilityIdentifier; double value = round(slider.value);
    [NSUserDefaults.standardUserDefaults setDouble:value forKey:key];
    UILabel *label = [slider.superview viewWithTag:9551];
    for (NSArray *section in self.sections) for (NSDictionary *row in section) if ([row[@"key"] isEqualToString:key]) label.text = [NSString stringWithFormat:@"%@   %.0f",row[@"title"],value];
    WCGestureSettingsPostChange(key);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; NSDictionary *row = self.sections[path.section][path.row];
    if (!path.row) {
        if ([self.collapsed containsIndex:path.section]) [self.collapsed removeIndex:path.section]; else [self.collapsed addIndex:path.section];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:path.section] withRowAnimation:UITableViewRowAnimationAutomatic]; return;
    }
    if (row[@"preview"]) { [self.navigationController pushViewController:WCGestureCreatePositionEditor(WCGesturePreviewInputRounding) animated:YES]; return; }
    if (!row[@"maximum"]) return;
    [WCPopup showInputWithTitle:row[@"title"] message:nil text:[NSString stringWithFormat:@"%.0f",[NSUserDefaults.standardUserDefaults doubleForKey:row[@"key"]]] placeholder:[NSString stringWithFormat:@"0 - %@",row[@"maximum"]] keyboard:UIKeyboardTypeDecimalPad completion:^(NSString *text) {
        double value; NSScanner *scanner = [NSScanner scannerWithString:text];
        if (![scanner scanDouble:&value] || !scanner.isAtEnd || !isfinite(value)) return;
        [NSUserDefaults.standardUserDefaults setDouble:MAX(0,MIN([row[@"maximum"] doubleValue],value)) forKey:row[@"key"]]; WCGestureSettingsPostChange(row[@"key"]);
    }];
}
@end
UIViewController *WCGestureCreateCornerSettingsController(void) { return [WCCornerSettingsController new]; }
