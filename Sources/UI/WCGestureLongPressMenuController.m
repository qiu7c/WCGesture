#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCLongPressToggleTitleKey;

@interface WCLongPressMenuController : UITableViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, copy) NSArray<NSString *> *allTitles;
@property (nonatomic, copy) NSArray<NSString *> *titles;
@property (nonatomic, assign) BOOL moving;
@end

@implementation WCLongPressMenuController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self); self.title = @"长按菜单管理";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 64 * WCGestureSettingsScaleFactor();
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.navigationItem.rightBarButtonItems = @[self.editButtonItem,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTitle)]];
    self.editButtonItem.title = @"排序";
    self.searchField = [UITextField new]; self.searchField.placeholder = @"搜索菜单原名或新名称"; self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(reloadTitles) forControlEvents:UIControlEventEditingChanged];
    self.tableView.tableHeaderView = WCGestureSettingsSearchHeader(self.searchField, self.view.bounds.size.width);
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:WCGestureDidChangeNotification object:nil];
    [self reloadTitles];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (void)changed:(NSNotification *)note {
    if (!self.moving && (!note.object || [note.object hasPrefix:@"com.qiu7c.onewx.chat.long-press-menu."])) [self reloadTitles];
}
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated]; self.editButtonItem.title = editing ? @"完成" : @"排序";
}
- (void)reloadTitles {
    self.allTitles = WCGestureLongPressMenuTitles();
    NSString *query = [self.searchField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSDictionary *mapping = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureLongPressMenuTitleMapKey];
    NSMutableArray *visible = [NSMutableArray array];
    for (NSString *title in self.allTitles) {
        id alias = mapping[title];
        NSString *text = [NSString stringWithFormat:@"%@ %@", title, [alias isKindOfClass:NSString.class] ? alias : @""];
        if (!query.length || [text localizedCaseInsensitiveContainsString:query]) [visible addObject:title];
    }
    self.titles = visible;
    if (query.length && self.editing) [self setEditing:NO animated:NO];
    self.editButtonItem.enabled = !query.length && self.titles.count > 1;
    [self.tableView reloadData];
}
- (void)addTitle {
    __weak typeof(self) weakSelf = self;
    [WCPopup showInputWithTitle:@"手动添加菜单" message:@"填写菜单原名称；出现该项目时即可隐藏、排序或重命名。"
        text:nil placeholder:@"例如：复制" keyboard:UIKeyboardTypeDefault completion:^(NSString *title) {
            NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
            NSMutableArray *manual = [[d arrayForKey:WCGestureLongPressMenuManualTitlesKey] mutableCopy] ?: [NSMutableArray array];
            if (![WCGestureLongPressMenuTitles() containsObject:title]) [manual addObject:title];
            [d setObject:manual forKey:WCGestureLongPressMenuManualTitlesKey];
            weakSelf.searchField.text = @"";
            WCGestureSettingsPostChange(WCGestureLongPressMenuManualTitlesKey);
        }];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.titles.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.allTitles.count ? @"关闭行内开关可隐藏该项；点按修改或恢复名称，排序模式可拖动。修改在下次长按时生效，关闭总开关恢复原菜单。"
        : @"请先长按不同类型的消息，自动收集菜单；也可点右上角“+”添加原名称。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxMenuItem"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"OneWxMenuItem"];
    NSString *title = self.titles[path.row];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    id alias = [d dictionaryForKey:WCGestureLongPressMenuTitleMapKey][title];
    BOOL renamed = [alias isKindOfClass:NSString.class] && [alias length];
    cell.textLabel.text = renamed ? alias : title;
    cell.detailTextLabel.text = renamed ? [@"原名称：" stringByAppendingString:title]
        : ([[d arrayForKey:WCGestureLongPressMenuManualTitlesKey] containsObject:title] ? @"手动添加" : @"自动获取");
    cell.textLabel.font = [UIFont systemFontOfSize:16 * WCGestureSettingsScaleFactor()];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12 * WCGestureSettingsScaleFactor()];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    UISwitch *toggle = [UISwitch new]; toggle.onTintColor = UIColor.systemBlueColor;
    toggle.on = ![[d arrayForKey:WCGestureLongPressMenuHiddenTitlesKey] containsObject:title];
    objc_setAssociatedObject(toggle, &WCLongPressToggleTitleKey, title, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [toggle addTarget:self action:@selector(visibilityChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle; cell.editingAccessoryView = toggle; cell.showsReorderControl = YES;
    return cell;
}
- (void)visibilityChanged:(UISwitch *)toggle {
    NSString *title = objc_getAssociatedObject(toggle, &WCLongPressToggleTitleKey);
    if (!title.length) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *hidden = [[d arrayForKey:WCGestureLongPressMenuHiddenTitlesKey] mutableCopy] ?: [NSMutableArray array];
    if (toggle.on) [hidden removeObject:title]; else if (![hidden containsObject:title]) [hidden addObject:title];
    [d setObject:hidden forKey:WCGestureLongPressMenuHiddenTitlesKey]; WCGestureSettingsPostChange(WCGestureLongPressMenuHiddenTitlesKey);
}
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { return !self.searchField.text.length; }
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)path { return UITableViewCellEditingStyleNone; }
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path { return NO; }
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)destination {
    NSMutableArray *titles = [self.allTitles mutableCopy]; NSString *title = titles[source.row];
    [titles removeObjectAtIndex:source.row]; [titles insertObject:title atIndex:destination.row];
    self.allTitles = titles; self.titles = titles;
    [NSUserDefaults.standardUserDefaults setObject:titles forKey:WCGestureLongPressMenuPreferredOrderKey];
    self.moving = YES; WCGestureSettingsPostChange(WCGestureLongPressMenuPreferredOrderKey); self.moving = NO;
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {
    NSString *title = self.titles[path.row];
    if (![[NSUserDefaults.standardUserDefaults arrayForKey:WCGestureLongPressMenuManualTitlesKey] containsObject:title]) return nil;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除"
        handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
            NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
            for (NSString *key in @[WCGestureLongPressMenuManualTitlesKey, WCGestureLongPressMenuHiddenTitlesKey, WCGestureLongPressMenuPreferredOrderKey]) {
                NSMutableArray *values = [[d arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
                [values removeObject:title]; [d setObject:values forKey:key];
            }
            NSMutableDictionary *mapping = [[d dictionaryForKey:WCGestureLongPressMenuTitleMapKey] mutableCopy] ?: [NSMutableDictionary dictionary];
            [mapping removeObjectForKey:title]; [d setObject:mapping forKey:WCGestureLongPressMenuTitleMapKey];
            WCGestureSettingsPostChange(WCGestureLongPressMenuManualTitlesKey); completion(YES);
        }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; NSString *title = self.titles[path.row];
    [WCPopup showOptionsWithTitle:title message:@"按原名称识别项目，改名不会影响隐藏和排序。"
        options:@[[WCPopupOption optionWithTitle:@"修改名称" value:@0], [WCPopupOption optionWithTitle:@"恢复原名" value:@1]] selected:nil completion:^(id value) {
            if (!value) return;
            if ([value integerValue] == 1) {
                NSMutableDictionary *map = [[NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureLongPressMenuTitleMapKey] mutableCopy] ?: [NSMutableDictionary dictionary];
                [map removeObjectForKey:title]; [NSUserDefaults.standardUserDefaults setObject:map forKey:WCGestureLongPressMenuTitleMapKey];
                WCGestureSettingsPostChange(WCGestureLongPressMenuTitleMapKey); return;
            }
            NSString *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureLongPressMenuTitleMapKey][title];
            [WCPopup showInputWithTitle:@"修改菜单名称" message:[@"原名称：" stringByAppendingString:title] text:saved ?: title placeholder:title keyboard:UIKeyboardTypeDefault completion:^(NSString *alias) {
                NSMutableDictionary *map = [[NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureLongPressMenuTitleMapKey] mutableCopy] ?: [NSMutableDictionary dictionary];
                if ([alias isEqualToString:title]) [map removeObjectForKey:title]; else map[title] = alias;
                [NSUserDefaults.standardUserDefaults setObject:map forKey:WCGestureLongPressMenuTitleMapKey]; WCGestureSettingsPostChange(WCGestureLongPressMenuTitleMapKey);
            }];
        }];
}
@end

UIViewController *WCGestureCreateLongPressMenuController(void) { return [WCLongPressMenuController new]; }
