#import "Sources/API/WCGestureInternal.h"

// One Wx management UI. Native replacement/saving contracts are documented in
// docs/REVERSE_IMPLEMENTATION_EVIDENCE.md; this list uses existing contact APIs.
@interface WCCustomAvatarController : UITableViewController <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic,copy) NSString *account;
@property (nonatomic,strong) UITextField *searchField;
@property (nonatomic,copy) NSArray<NSDictionary *> *contacts;
@property (nonatomic,copy) NSArray<NSDictionary *> *filtered;
@property (nonatomic,copy) NSString *pickingUser;
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
        if (!name.length) continue;
        rows[name]=@{@"user":name,@"name":WCGesturePrivateContactDisplayName([contact isKindOfClass:NSString.class]?WCPrivateContact(name):contact,name)};
    }
    NSMutableArray *saved=[WCGestureCustomAvatarSavedUsers() mutableCopy];
    if (self.account.length) [saved addObject:self.account];
    for (NSString *user in saved) if (!rows[user]) rows[user]=@{@"user":user,@"name":WCGesturePrivateNotificationDisplayName(user,user)};
    self.contacts=[rows.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
    [self filterContacts];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated];[self.tableView reloadData]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder];return YES; }
- (void)filterContacts {
    NSString *query=self.searchField.text ?: @"";
    self.filtered=query.length?[self.contacts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row,__unused NSDictionary *bindings){return [row[@"name"] localizedCaseInsensitiveContainsString:query] || [row[@"user"] localizedCaseInsensitiveContainsString:query];}]]:self.contacts;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.filtered.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"avatar"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"avatar"];
    NSDictionary *row=self.filtered[path.row];NSString *user=row[@"user"];
    cell.textLabel.text=row[@"name"];cell.textLabel.font=[UIFont systemFontOfSize:15*WCGestureSettingsScaleFactor()];
    cell.detailTextLabel.text=[WCGestureCustomAvatarSavedUsers() containsObject:user]?@"已替换":nil;
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (BOOL)validAccount { return self.account.length && [self.account isEqualToString:WCCurrentUserWXID() ?: @""]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];if (![self validAccount]) { WCShowToast(@"账号已变化，请重新打开");return; }
    NSString *user=self.filtered[path.row][@"user"];__weak WCCustomAvatarController *weak=self;
    if (![WCGestureCustomAvatarSavedUsers() containsObject:user]) { [self pickUser:user];return; }
    [WCPopup showOptionsWithTitle:self.filtered[path.row][@"name"] message:nil options:@[
        [WCPopupOption optionWithTitle:@"修改" value:@"change"],[WCPopupOption optionWithTitle:@"恢复" value:@"restore"]] selected:nil completion:^(id choice){
        WCCustomAvatarController *host=weak;if (![host validAccount] || !host.view.window)return;
        if ([choice isEqual:@"restore"]) WCGestureCustomAvatarRemove(user,^(BOOL success){ if ([host validAccount]) { [host.tableView reloadData];if(!success)WCShowToast(@"恢复失败"); } });
        else if ([choice isEqual:@"change"]) [host pickUser:user];
    }];
}
- (void)pickUser:(NSString *)user {
    if (![self validAccount] || self.presentedViewController || !self.view.window)return;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) { WCShowToast(@"相册不可用");return; }
    self.pickingUser=user;UIImagePickerController *picker=[UIImagePickerController new];
    picker.sourceType=UIImagePickerControllerSourceTypePhotoLibrary;picker.allowsEditing=YES;picker.delegate=self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { self.pickingUser=nil;[picker dismissViewControllerAnimated:YES completion:nil]; }
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image=info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    NSString *user=self.pickingUser;self.pickingUser=nil;__weak WCCustomAvatarController *weak=self;
    [picker dismissViewControllerAnimated:YES completion:^{
        WCCustomAvatarController *host=weak;if (![host validAccount] || !user.length || ![image isKindOfClass:UIImage.class])return;
        WCGestureCustomAvatarSave(user,image,^(BOOL success){if([host validAccount]){[host.tableView reloadData];if(!success)WCShowToast(@"保存头像失败");}});
    }];
}
@end
UIViewController *WCGestureCreateCustomAvatarController(void) { return [WCCustomAvatarController new]; }
