#import "Sources/API/WCGestureInternal.h"

// One Wx management UI. Native replacement/saving contracts are documented in
// docs/REVERSE_IMPLEMENTATION_EVIDENCE.md; this list uses existing contact APIs.
@interface WCCustomAvatarController : UITableViewController <UITextFieldDelegate>
@property (nonatomic,copy) NSString *account;
@property (nonatomic,strong) UITextField *searchField;
@property (nonatomic,copy) NSArray<NSDictionary *> *contacts;
@property (nonatomic,copy) NSArray<NSDictionary *> *filtered;
@property (nonatomic,copy) NSArray<NSArray<NSDictionary *> *> *contactSections;
@end
@implementation WCCustomAvatarController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"替换头像";WCGestureSettingsConfigureNavigation(self);
    if (WCRefreshCachedCurrentUser()) self.account=WCCurrentUserWXID();
    self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight=60*WCGestureSettingsScaleFactor();self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
    self.searchField=[UITextField new];self.searchField.placeholder=@"搜索联系人或群聊";self.searchField.delegate=self;
    [self.searchField addTarget:self action:@selector(filterContacts) forControlEvents:UIControlEventEditingChanged];
    self.tableView.tableHeaderView=WCGestureSettingsSearchHeader(self.searchField,self.view.bounds.size.width);
    NSMutableDictionary *rows=[NSMutableDictionary dictionary];
    for (id contact in WCGesturePrivateContactList()) {
        NSString *name=[contact isKindOfClass:NSString.class]?contact:WCPrivateContactUserName(contact);
        id native=[contact isKindOfClass:NSString.class]?WCPrivateContact(name):contact;
        NSInteger kind=WCGestureContactPickerKind(native,name);
        if (kind==NSNotFound) continue;
        rows[name]=@{@"user":name,@"kind":@(kind),@"name":WCGesturePrivateContactDisplayName([contact isKindOfClass:NSString.class]?WCPrivateContact(name):contact,name)};
    }
    NSMutableArray *saved=[WCGestureCustomAvatarSavedUsers() mutableCopy];
    if (self.account.length) [saved addObject:self.account];
    for (NSString *user in saved) if (!rows[user]) {
        NSInteger kind=WCGestureContactPickerKind(WCPrivateContact(user),user);
        if (kind!=NSNotFound) rows[user]=@{@"user":user,@"kind":@(kind),@"name":WCGesturePrivateNotificationDisplayName(user,user)};
    }
    self.contacts=[rows.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
    [self filterContacts];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated];[self.tableView reloadData]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder];return YES; }
- (void)filterContacts {
    NSString *query=self.searchField.text ?: @"";
    self.filtered=query.length?[self.contacts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row,__unused NSDictionary *bindings){return [row[@"name"] localizedCaseInsensitiveContainsString:query] || [row[@"user"] localizedCaseInsensitiveContainsString:query];}]]:self.contacts;
    NSMutableArray *friends=[NSMutableArray array], *groups=[NSMutableArray array];
    for (NSDictionary *row in self.filtered) [( [row[@"kind"] integerValue]==0 ? friends : groups ) addObject:row];
    self.contactSections=@[friends,groups];
    [self.tableView reloadData];
}
- (NSArray<NSDictionary *> *)rowsInSection:(NSInteger)section {
    return self.contactSections[section];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return section==0?@"好友":@"群聊"; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self rowsInSection:section].count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row=[self rowsInSection:path.section][path.row];NSString *user=row[@"user"];
    UITableViewCell *cell=WCGestureContactPickerCell(tableView,user,row[@"name"]);
    UILabel *status=[UILabel new];status.text=@"已替换";status.font=[UIFont systemFontOfSize:12*WCGestureSettingsScaleFactor()];status.textColor=UIColor.secondaryLabelColor;[status sizeToFit];
    cell.accessoryView=[WCGestureCustomAvatarSavedUsers() containsObject:user]?status:nil;
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (BOOL)validAccount { return self.account.length && [self.account isEqualToString:WCCurrentUserWXID() ?: @""]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];if (![self validAccount]) { WCShowToast(@"账号已变化，请重新打开");return; }
    NSDictionary *row=[self rowsInSection:path.section][path.row];
    __weak WCCustomAvatarController *weak=self;
    WCGesturePresentCustomAvatarEditor(self,row[@"user"],^(BOOL changed){
        if (changed && [weak validAccount]) [weak.tableView reloadData];
    });
}

@end
UIViewController *WCGestureCreateCustomAvatarController(void) { return [WCCustomAvatarController new]; }
