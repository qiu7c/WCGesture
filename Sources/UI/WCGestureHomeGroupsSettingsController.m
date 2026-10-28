#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCHomeGroupMembers : UITableViewController <UITextFieldDelegate>
@property (nonatomic, copy) NSString *groupID;
@property (nonatomic) BOOL instant;
@property (nonatomic, strong) NSMutableSet *selected;
@property (nonatomic, copy) NSArray<NSDictionary *> *contacts;
@property (nonatomic, copy) NSArray<NSDictionary *> *filtered;
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *contactSections;
@property (nonatomic, strong) UITextField *search;
@end
@implementation WCHomeGroupMembers
- (void)viewDidLoad {
    [super viewDidLoad];self.title=self.instant?@"即时消息会话":@"分组成员";WCGestureSettingsConfigureNavigation(self);
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStylePlain target:self action:@selector(save)];
    self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight=64*WCGestureSettingsScaleFactor();
    self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
    NSMutableSet *assigned=[NSMutableSet set];
    for (NSDictionary *group in WCGestureHomeGroupsList()) if (!self.instant && [group[@"type"] isEqual:@"custom"] && ![group[@"id"] isEqual:self.groupID]) [assigned addObjectsFromArray:group[@"members"]];
    NSMutableDictionary *rows=[NSMutableDictionary dictionary];
    for (id contact in WCGesturePrivateContactList()) {
        NSString *user=[contact isKindOfClass:NSString.class]?contact:WCPrivateContactUserName(contact);
        id native=[contact isKindOfClass:NSString.class]?WCPrivateContact(user):contact;
        NSInteger kind=WCGestureContactPickerKind(native,user);
        if (kind==NSNotFound || [assigned containsObject:user]) continue;
        rows[user]=@{@"user":user,@"kind":@(kind),@"title":WCGesturePrivateContactDisplayName([contact isKindOfClass:NSString.class]?WCPrivateContact(user):contact,user)};
    }
    for (NSString *user in self.selected) if (!rows[user]) {
        NSInteger kind=WCGestureContactPickerKind(WCPrivateContact(user),user);
        if (kind!=NSNotFound) rows[user]=@{@"user":user,@"kind":@(kind),@"title":WCGesturePrivateNotificationDisplayName(user,user)};
    }
    self.contacts=[rows.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"title"] localizedCaseInsensitiveCompare:b[@"title"]];}];
    self.search=[UITextField new];self.search.placeholder=@"搜索联系人或群聊";self.search.delegate=self;
    [self.search addTarget:self action:@selector(filter) forControlEvents:UIControlEventEditingChanged];
    self.tableView.tableHeaderView=WCGestureSettingsSearchHeader(self.search,self.view.bounds.size.width);[self filter];
}
- (void)filter {
    NSString *q=self.search.text ?: @"";
    self.filtered=q.length?[self.contacts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row,__unused NSDictionary *bindings){return [row[@"title"] localizedCaseInsensitiveContainsString:q] || [row[@"user"] localizedCaseInsensitiveContainsString:q];}]]:self.contacts;
    NSMutableArray *friends=[NSMutableArray array], *groups=[NSMutableArray array];
    for (NSDictionary *row in self.filtered) [( [row[@"kind"] integerValue]==0 ? friends : groups ) addObject:row];
    self.contactSections=@[friends,groups];
    [self.tableView reloadData];
}
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder];return YES; }
- (NSArray<NSDictionary *> *)rowsInSection:(NSInteger)section {
    return self.contactSections[section];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return section==0?@"好友":@"群聊"; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return [self rowsInSection:section].count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row=[self rowsInSection:path.section][path.row];
    UITableViewCell *cell=WCGestureContactPickerCell(table,row[@"user"],row[@"title"]);
    cell.accessoryType=[self.selected containsObject:row[@"user"]]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;cell.tintColor=UIColor.systemBlueColor;return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    NSString *user=[self rowsInSection:path.section][path.row][@"user"];
    if ([self.selected containsObject:user]) [self.selected removeObject:user];else [self.selected addObject:user];
    [table deselectRowAtIndexPath:path animated:YES];[table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
}
- (void)save {
    if (self.instant) { WCGestureHomeGroupsSetPendingNames(self.selected.allObjects);[self.navigationController popViewControllerAnimated:YES];return; }
    NSMutableArray *groups=[WCGestureHomeGroupsList() mutableCopy];
    for (NSUInteger i=0;i<groups.count;i++) if ([groups[i][@"id"] isEqual:self.groupID]) {
        NSMutableDictionary *group=[groups[i] mutableCopy];group[@"members"]=[self.selected.allObjects sortedArrayUsingSelector:@selector(compare:)];groups[i]=group;break;
    }
    WCGestureHomeGroupsSave(groups);[self.navigationController popViewControllerAnimated:YES];
}
@end

@interface WCHomeGroupsSettings : UITableViewController
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *rows;
@property (nonatomic, strong) NSMutableIndexSet *openSections;
@end
@implementation WCHomeGroupsSettings
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"主页分组";WCGestureSettingsConfigureNavigation(self);
    self.navigationItem.rightBarButtonItem=self.editButtonItem;
    self.openSections=[NSMutableIndexSet indexSet];
    self.tableView.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    self.tableView.sectionHeaderHeight=0;self.tableView.sectionFooterHeight=0;
    self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight=50*WCGestureSettingsScaleFactor();
    // Each number row contains its actual storage key and allowed UI range.
    self.rows=@[
      @[@{@"title":@"启用主页分组",@"key":WCGestureHomeGroupsEnabledKey,@"type":@"switch"}],
      @[],
      @[@{@"title":@"阅后移出即时消息",@"key":WCGestureHomeGroupsBurnAfterReadingKey,@"type":@"switch"},
        @{@"title":@"置顶会话持续显示",@"key":WCGestureHomeGroupsPinnedPersistentKey,@"type":@"switch"},
        @{@"title":@"横滑切换",@"key":WCGestureHomeGroupsGestureKey,@"type":@"switch"},
        @{@"title":@"循环切换",@"key":WCGestureHomeGroupsContinuousKey,@"type":@"switch"},
        @{@"title":@"反转方向",@"key":WCGestureHomeGroupsReverseKey,@"type":@"switch"},
        @{@"title":@"横滑震感",@"key":WCGestureHomeGroupsHapticKey,@"type":@"switch"},
        @{@"title":@"按钮震感",@"key":WCGestureHomeGroupsButtonHapticKey,@"type":@"switch"},
        @{@"title":@"两侧手势范围",@"key":WCGestureHomeGroupsGestureRatioKey,@"type":@"number",@"min":@0.02,@"max":@1}],
      @[@{@"title":@"统一改色",@"key":WCGestureHomeGroupsUnifiedColorEnabledKey,@"type":@"switch"},
        @{@"title":@"统一背景颜色",@"key":WCGestureHomeGroupsUnifiedColorKey,@"type":@"color"},
        @{@"title":@"字号",@"key":WCGestureHomeGroupsFontSizeKey,@"type":@"number",@"min":@10,@"max":@24},
        @{@"title":@"字重",@"key":WCGestureHomeGroupsFontWeightKey,@"type":@"number",@"min":@100,@"max":@900},
        @{@"title":@"选中滑块",@"key":WCGestureHomeGroupsSliderKey,@"type":@"switch"},
        @{@"title":@"滑块大小 (%)",@"key":WCGestureHomeGroupsSliderSizeKey,@"type":@"number",@"min":@0,@"max":@100},
        @{@"title":@"滑块圆角",@"key":WCGestureHomeGroupsSliderRadiusKey,@"type":@"number",@"min":@0,@"max":@100},
        @{@"title":@"滑块动画",@"key":WCGestureHomeGroupsSliderAnimationKey,@"type":@"switch"},
        @{@"title":@"滑块颜色",@"key":WCGestureHomeGroupsSliderColorKey,@"type":@"color"},
        @{@"title":@"下划线",@"key":WCGestureHomeGroupsUnderlineKey,@"type":@"switch"},
        @{@"title":@"下划线长度",@"key":WCGestureHomeGroupsUnderlineLengthKey,@"type":@"number",@"min":@1,@"max":@200},
        @{@"title":@"下划线粗细",@"key":WCGestureHomeGroupsUnderlineThicknessKey,@"type":@"number",@"min":@0.5,@"max":@20},
        @{@"title":@"下划线偏移",@"key":WCGestureHomeGroupsUnderlineOffsetKey,@"type":@"number",@"min":@-50,@"max":@50},
        @{@"title":@"下划线颜色",@"key":WCGestureHomeGroupsUnderlineColorKey,@"type":@"color"}],
      @[@{@"title":@"隐藏角标",@"key":WCGestureHomeGroupsHideBadgesKey,@"type":@"switch"},
        @{@"title":@"隐藏红点",@"key":WCGestureHomeGroupsHideRedDotsKey,@"type":@"switch"},
        @{@"title":@"原生角标样式",@"key":WCGestureHomeGroupsNativeBadgeKey,@"type":@"switch"},
        @{@"title":@"角标横向偏移",@"key":WCGestureHomeGroupsBadgeXKey,@"type":@"number",@"min":@-50,@"max":@50},
        @{@"title":@"角标纵向偏移",@"key":WCGestureHomeGroupsBadgeYKey,@"type":@"number",@"min":@-50,@"max":@50},
        @{@"title":@"角标背景",@"key":WCGestureHomeGroupsBadgeColorKey,@"type":@"color"},
        @{@"title":@"角标文字",@"key":WCGestureHomeGroupsBadgeTextColorKey,@"type":@"color"}]];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated];[self.openSections removeAllIndexes];[self.tableView reloadData]; }
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return 0; }
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section { return 0; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return self.rows.count; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { if (section==0) return 1;
    if (![self.openSections containsIndex:section]) return 1;
    return 1+(section==1?WCGestureHomeGroupsList().count+1:self.rows[section].count); }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return nil; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.font=[UIFont systemFontOfSize:15*WCGestureSettingsScaleFactor()];cell.detailTextLabel.font=[UIFont systemFontOfSize:13*WCGestureSettingsScaleFactor()];
    cell.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    if (path.section>0 && path.row==0) {
        cell.textLabel.text=@[@"",@"分组管理",@"切换与置顶",@"分组外观",@"未读角标"][path.section];
        cell.imageView.image=[UIImage systemImageNamed:@[@"",@"rectangle.3.group",@"arrow.left.arrow.right",@"slider.horizontal.3",@"app.badge"][path.section]
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular]];
        cell.imageView.tintColor=UIColor.systemBlueColor;
        UIImageView *arrow=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[self.openSections containsIndex:path.section]?@"chevron.down":@"chevron.right"]];
        arrow.tintColor=UIColor.tertiaryLabelColor;arrow.frame=CGRectMake(0,0,12,16);arrow.contentMode=UIViewContentModeScaleAspectFit;cell.accessoryView=arrow;return cell;
    }
    if (path.section>0) cell.indentationLevel=1;
    cell.indentationWidth=18*WCGestureSettingsScaleFactor();
    NSInteger rowIndex=path.row-(path.section>0?1:0);
    if (path.section==1) {
        if (rowIndex==(NSInteger)WCGestureHomeGroupsList().count) { cell.textLabel.text=@"添加分组";cell.textLabel.textColor=UIColor.systemBlueColor;return cell; }
        NSDictionary *group=WCGestureHomeGroupsList()[rowIndex];cell.textLabel.text=group[@"title"];
        cell.detailTextLabel.text=[group[@"id"] isEqual:WCGestureHomeGroupsSelected()]?@"当前":([group[@"type"] isEqual:@"custom"]?[NSString stringWithFormat:@"%lu 位",(unsigned long)[group[@"members"] count]]:nil);
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
    }
    NSDictionary *row=self.rows[path.section][rowIndex];NSString *key=row[@"key"];cell.textLabel.text=row[@"title"];
    if ([row[@"type"] isEqual:@"switch"]) {
        UISwitch *toggle=[UISwitch new];toggle.onTintColor=UIColor.systemBlueColor;toggle.on=[NSUserDefaults.standardUserDefaults boolForKey:key];
        toggle.accessibilityIdentifier=key;[toggle addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;
    } else { cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;if ([row[@"type"] isEqual:@"number"]) cell.detailTextLabel.text=[[NSUserDefaults.standardUserDefaults objectForKey:key] description]; }
    return cell;
}
- (void)toggle:(UISwitch *)toggle {
    [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:toggle.accessibilityIdentifier];WCGestureSettingsPostChange(toggle.accessibilityIdentifier);
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section>0 && path.row==0) {
        if ([self.openSections containsIndex:path.section]) [self.openSections removeIndex:path.section];else [self.openSections addIndex:path.section];
        [table reloadSections:[NSIndexSet indexSetWithIndex:path.section] withRowAnimation:UITableViewRowAnimationAutomatic];return;
    }
    NSInteger rowIndex=path.row-(path.section>0?1:0);
    if (path.section==1) {
        if (rowIndex==(NSInteger)WCGestureHomeGroupsList().count) { [self addGroup];return; }
        [self editGroup:WCGestureHomeGroupsList()[rowIndex]];return;
    }
    NSDictionary *row=self.rows[path.section][rowIndex];NSString *key=row[@"key"];
    if ([row[@"type"] isEqual:@"color"]) { WCGestureEditChatOption(self,@{@"title":row[@"title"],@"type":@"color",@"key":key});return; }
    if (![row[@"type"] isEqual:@"number"]) return;
    [WCPopup showInputWithTitle:row[@"title"] message:nil text:[[NSUserDefaults.standardUserDefaults objectForKey:key] description]
        placeholder:[NSString stringWithFormat:@"%@–%@",row[@"min"],row[@"max"]] keyboard:UIKeyboardTypeNumbersAndPunctuation completion:^(NSString *text){
        NSScanner *scan=[NSScanner scannerWithString:text];double value=0;
        if (![scan scanDouble:&value] || !scan.isAtEnd || !isfinite(value) || value<[row[@"min"] doubleValue] || value>[row[@"max"] doubleValue]) { WCShowToast(@"数值超出范围");return; }
        [NSUserDefaults.standardUserDefaults setDouble:value forKey:key];WCGestureSettingsPostChange(key);[self.tableView reloadData];
    }];
}
- (void)addGroup {
    NSMutableArray *options=[NSMutableArray arrayWithObject:[WCPopupOption optionWithTitle:@"自定义分组" value:@"custom"]];
    NSArray *builtins=@[@{@"id":@"builtin.all",@"type":@"all",@"title":@"全部"},@{@"id":@"builtin.friend",@"type":@"friend",@"title":@"好友"},@{@"id":@"builtin.group",@"type":@"group",@"title":@"群聊"},@{@"id":@"builtin.other",@"type":@"other",@"title":@"其他"},@{@"id":@"builtin.instant",@"type":@"instant",@"title":@"即时消息"}];
    NSSet *ids=[NSSet setWithArray:[WCGestureHomeGroupsList() valueForKey:@"id"]];
    for (NSDictionary *group in builtins) if (![ids containsObject:group[@"id"]]) [options addObject:[WCPopupOption optionWithTitle:group[@"title"] value:group]];
    [WCPopup showOptionsWithTitle:@"添加分组" message:nil options:options selected:nil completion:^(id choice){
        if ([choice isKindOfClass:NSDictionary.class]) { NSMutableArray *groups=[WCGestureHomeGroupsList() mutableCopy];[groups addObject:choice];WCGestureHomeGroupsSave(groups);[self.tableView reloadData];return; }
        [WCPopup showInputWithTitle:@"新建分组" message:nil text:nil placeholder:@"分组名称" keyboard:UIKeyboardTypeDefault completion:^(NSString *title){
            if (!title.length) return;NSMutableArray *groups=[WCGestureHomeGroupsList() mutableCopy];
            [groups addObject:@{@"id":NSUUID.UUID.UUIDString,@"type":@"custom",@"title":title,@"members":@[]}];WCGestureHomeGroupsSave(groups);[self.tableView reloadData];
        }];
    }];
}
- (void)editGroup:(NSDictionary *)group {
    NSMutableArray *options=[NSMutableArray arrayWithObjects:[WCPopupOption optionWithTitle:@"切换到此分组" value:@"select"],[WCPopupOption optionWithTitle:@"重命名" value:@"rename"],nil];
    if ([group[@"type"] isEqual:@"custom"]) [options addObject:[WCPopupOption optionWithTitle:@"设置成员" value:@"members"]];
    [WCPopup showOptionsWithTitle:group[@"title"] message:nil options:options selected:nil completion:^(id action){
        if ([action isEqual:@"select"]) { WCGestureHomeGroupsSelect(group[@"id"]);[self.tableView reloadData]; }
        else if ([action isEqual:@"members"]) {
            WCHomeGroupMembers *picker=[[WCHomeGroupMembers alloc] initWithStyle:UITableViewStyleInsetGrouped];picker.hidesBottomBarWhenPushed=YES;picker.groupID=group[@"id"];picker.selected=[NSMutableSet setWithArray:group[@"members"]];
            [self.navigationController pushViewController:picker animated:YES];
        } else if ([action isEqual:@"rename"]) {
            [WCPopup showInputWithTitle:@"重命名" message:nil text:group[@"title"] placeholder:@"分组名称" keyboard:UIKeyboardTypeDefault completion:^(NSString *title){
                if (!title.length)return;NSMutableArray *groups=[WCGestureHomeGroupsList() mutableCopy];
                for (NSUInteger i=0;i<groups.count;i++) if ([groups[i][@"id"] isEqual:group[@"id"]]) { NSMutableDictionary *item=[groups[i] mutableCopy];item[@"title"]=title;groups[i]=item;break; }
                WCGestureHomeGroupsSave(groups);[self.tableView reloadData];
            }];
        }
    }];
}
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path { return path.section==1 && path.row>0 && path.row<=(NSInteger)WCGestureHomeGroupsList().count; }
- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path { return [self tableView:table canEditRowAtIndexPath:path]; }
- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)target {
    return [NSIndexPath indexPathForRow:MAX(1,MIN((NSInteger)WCGestureHomeGroupsList().count,target.row)) inSection:1];
}
- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    NSMutableArray *groups=[WCGestureHomeGroupsList() mutableCopy];id group=groups[source.row-1];[groups removeObjectAtIndex:source.row-1];[groups insertObject:group atIndex:target.row-1];WCGestureHomeGroupsSave(groups);
}
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style!=UITableViewCellEditingStyleDelete) return;
    if (WCGestureHomeGroupsList().count<2) { WCShowToast(@"至少保留一个分组");return; }
    NSMutableArray *groups=[WCGestureHomeGroupsList() mutableCopy];[groups removeObjectAtIndex:path.row-1];WCGestureHomeGroupsSave(groups);[table reloadData];
}
@end

UIViewController *WCGestureCreateHomeGroupsSettingsController(void) { WCHomeGroupsSettings *controller=[[WCHomeGroupsSettings alloc] initWithStyle:UITableViewStylePlain];controller.hidesBottomBarWhenPushed=YES;return controller; }

UIViewController *WCGestureCreateHomeGroupsPendingController(void) { WCHomeGroupMembers *picker=[[WCHomeGroupMembers alloc] initWithStyle:UITableViewStyleInsetGrouped];picker.instant=YES;picker.hidesBottomBarWhenPushed=YES;picker.selected=[NSMutableSet setWithArray:WCGestureHomeGroupsPendingNames()];return picker; }
