#import "Sources/API/WCGestureInternal.h"

static UITableViewCell *WCVirtualLocationCell(NSString *title, NSString *value) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    CGFloat scale = WCGestureSettingsScaleFactor();
    cell.textLabel.text = title; cell.detailTextLabel.text = value;
    cell.textLabel.font = [UIFont systemFontOfSize:16 * scale];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14 * scale];
    cell.textLabel.textColor = UIColor.labelColor; cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    return cell;
}

@interface WCVirtualLocationCoordinateEditor : UITableViewController
@property (nonatomic, strong) NSArray<UITextField *> *fields;
@end
@implementation WCVirtualLocationCoordinateEditor
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"手动输入坐标"; self.hidesBottomBarWhenPushed = YES;
    WCGestureSettingsConfigureNavigation(self); self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    NSMutableArray *fields = [NSMutableArray array];
    NSArray *placeholders = @[@"纬度 -90～90", @"经度 -180～180", @"位置名称（可选）"];
    for (NSUInteger index = 0; index < 3; index++) {
        UITextField *field = [UITextField new]; field.placeholder = placeholders[index];
        field.textColor = UIColor.labelColor; field.textAlignment = NSTextAlignmentRight;
        field.font = [UIFont systemFontOfSize:15 * WCGestureSettingsScaleFactor()];
        field.keyboardType = index < 2 ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDefault;
        field.autocorrectionType = UITextAutocorrectionTypeNo; [fields addObject:field];
    }
    self.fields = fields;
    if (WCGestureVirtualLocationHasSelection()) {
        CLLocationCoordinate2D coordinate = WCGestureVirtualLocationCoordinate();
        self.fields[0].text = [NSString stringWithFormat:@"%.6f", coordinate.latitude];
        self.fields[1].text = [NSString stringWithFormat:@"%.6f", coordinate.longitude];
        self.fields[2].text = [NSUserDefaults.standardUserDefaults stringForKey:WCGestureVirtualLocationNameKey];
    }
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}
- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section { return 4; }
- (CGFloat)tableView:(__unused UITableView *)tableView heightForRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return 54 * WCGestureSettingsScaleFactor();
}
- (UITableViewCell *)tableView:(__unused UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = WCVirtualLocationCell(@[@"纬度", @"经度", @"名称", @"保存坐标"][indexPath.row], nil);
    if (indexPath.row < 3) {
        UITextField *field = self.fields[indexPath.row];
        field.frame = CGRectMake(0, 0, MIN(220, self.tableView.bounds.size.width * .58), 40);
        cell.accessoryView = field; cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else cell.textLabel.textColor = UIColor.systemBlueColor;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; if (indexPath.row != 3) return;
    double values[2] = {0, 0};
    for (NSUInteger index = 0; index < 2; index++) {
        NSString *text = [self.fields[index].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSScanner *scanner = [NSScanner scannerWithString:text ?: @""]; scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        if (![scanner scanDouble:&values[index]] || !scanner.isAtEnd) { WCShowToast(@"请输入完整有效的经纬度"); return; }
    }
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(values[0], values[1]);
    if (!WCGestureVirtualLocationCoordinateIsValid(coordinate)) { WCShowToast(@"经纬度超出范围或同时为零"); return; }
    WCGestureVirtualLocationSetCoordinate(coordinate, [self.fields[2].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]);
    [self.view endEditing:YES]; [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface WCVirtualLocationSettingsController : UITableViewController
@property (nonatomic, copy) NSArray<NSDictionary *> *presets;
@end
@implementation WCVirtualLocationSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"虚拟定位"; self.hidesBottomBarWhenPushed = YES;
    WCGestureSettingsConfigureNavigation(self); self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; }
- (void)reload { self.presets = WCGestureVirtualLocationPresets(); [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView { return 5; }
- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : section == 1 ? 3 : section == 2 ? self.presets.count + 1 : section == 3 ? 4 : 1;
}
- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 2 ? @"收藏位置" : section == 3 ? @"坐标微调" : nil;
}
- (void)tableView:(__unused UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(__unused NSInteger)section {
    if ([view isKindOfClass:UITableViewHeaderFooterView.class])
        ((UITableViewHeaderFooterView *)view).textLabel.font = [UIFont systemFontOfSize:14 * WCGestureSettingsScaleFactor()];
}
- (CGFloat)tableView:(__unused UITableView *)tableView heightForRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return 54 * WCGestureSettingsScaleFactor();
}
- (UITableViewCell *)tableView:(__unused UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section, row = indexPath.row;
    NSString *title = nil, *value = nil;
    if (section == 0) title = row == 0 ? @"启用虚拟定位" : @"朋友圈虚拟定位";
    else if (section == 1) { title = @[@"当前定位", @"地图选点", @"手动输入坐标"][row]; if (row == 0) value = WCGestureVirtualLocationSummary(); }
    else if (section == 2) {
        if (row == (NSInteger)self.presets.count) title = @"收藏当前坐标";
        else {
            NSDictionary *preset = self.presets[row]; title = [preset[@"name"] length] ? preset[@"name"] : @"未命名位置";
            value = [NSString stringWithFormat:@"%.6f, %.6f", [preset[@"latitude"] doubleValue], [preset[@"longitude"] doubleValue]];
        }
    } else if (section == 3) { title = @[@"向北微调", @"向南微调", @"向东微调", @"向西微调"][row]; value = @"0.001°"; }
    else title = @"清除当前定位";
    UITableViewCell *cell = WCVirtualLocationCell(title, value);
    if (section == 0) {
        UISwitch *toggle = [UISwitch new]; toggle.tag = row;
        toggle.onTintColor = UIColor.systemBlueColor;
        toggle.on = WCGestureEnabled(row == 0 ? WCGestureVirtualLocationEnabledKey : WCGestureVirtualLocationMomentsEnabledKey);
        [toggle addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle; cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (section == 1) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    else if (section == 4) cell.textLabel.textColor = UIColor.systemRedColor;
    else if (section == 2 && row == (NSInteger)self.presets.count) cell.textLabel.textColor = UIColor.systemBlueColor;
    return cell;
}
- (void)toggle:(UISwitch *)toggle {
    NSString *key = toggle.tag == 0 ? WCGestureVirtualLocationEnabledKey : WCGestureVirtualLocationMomentsEnabledKey;
    [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:key]; WCGestureSettingsPostChange(key);
}
- (void)editCoordinates { [self.navigationController pushViewController:[WCVirtualLocationCoordinateEditor new] animated:YES]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; NSInteger section = indexPath.section, row = indexPath.row;
    if (section == 1) {
        if (row == 1) {
            if (!WCGestureVirtualLocationPresentPicker(self)) { WCShowToast(@"地图选点暂不可用，请手动输入坐标"); [self editCoordinates]; }
        } else [self editCoordinates];
    } else if (section == 2) {
        if (row == (NSInteger)self.presets.count) { [self savePreset]; return; }
        NSDictionary *preset = self.presets[row];
        WCGestureVirtualLocationSetCoordinate(CLLocationCoordinate2DMake([preset[@"latitude"] doubleValue], [preset[@"longitude"] doubleValue]), preset[@"name"]);
        [self reload];
    } else if (section == 3) {
        if (!WCGestureVirtualLocationHasSelection()) { WCShowToast(@"请先选择坐标"); return; }
        double latitude = row == 0 ? .001 : row == 1 ? -.001 : 0;
        double longitude = row == 2 ? .001 : row == 3 ? -.001 : 0;
        WCGestureVirtualLocationNudge(latitude, longitude); [self reload];
    } else if (section == 4) {
        WCGestureVirtualLocationClear(); [self reload];
    }
}
- (void)savePreset {
    if (!WCGestureVirtualLocationHasSelection()) { WCShowToast(@"请先选择坐标"); return; }
    CLLocationCoordinate2D coordinate = WCGestureVirtualLocationCoordinate();
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"收藏当前坐标" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"位置名称"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!name.length) name = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
        WCGestureVirtualLocationAddPreset(name, coordinate); [weakSelf reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (UISwipeActionsConfiguration *)tableView:(__unused UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 2 || indexPath.row >= (NSInteger)self.presets.count) return nil;
    NSDictionary *preset = self.presets[indexPath.row]; __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除"
        handler:^(__unused UIContextualAction *action, __unused UIView *view, void (^completion)(BOOL)) {
        NSUInteger index = [WCGestureVirtualLocationPresets() indexOfObject:preset];
        if (index != NSNotFound) WCGestureVirtualLocationRemovePresetAtIndex(index);
        [weakSelf reload]; completion(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}
@end

UIViewController *WCGestureCreateVirtualLocationSettingsController(void) { return [WCVirtualLocationSettingsController new]; }
