#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCMomentsFriendPicker : UITableViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, copy) NSArray<NSDictionary *> *friends;
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleFriends;
@end

@implementation WCMomentsFriendPicker
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self);
    self.title = @"特别关心好友";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 60 * WCGestureSettingsScaleFactor();
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.searchField = [UITextField new];
    self.searchField.placeholder = @"搜索好友";
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(filterFriends) forControlEvents:UIControlEventEditingChanged];
    self.tableView.tableHeaderView = WCGestureSettingsSearchHeader(self.searchField, self.view.bounds.size.width);
    NSMutableDictionary *friends = [NSMutableDictionary dictionary];
    for (id candidate in WCGesturePrivateContactList()) {
        NSString *username = [candidate isKindOfClass:NSString.class] ? candidate : WCPrivateContactUserName(candidate);
        if (!username.length || [username hasSuffix:@"@chatroom"] || [username isEqualToString:@"filehelper"]
            || [username isEqualToString:WCCurrentUserWXID()]) continue;
        id contact = [candidate isKindOfClass:NSString.class] ? WCPrivateContact(username) : candidate;
        SEL single = NSSelectorFromString(@"isWeixinSingleConatct");
        NSMethodSignature *signature = [contact methodSignatureForSelector:single];
        if ([contact respondsToSelector:single] && signature.numberOfArguments == 2
            && (signature.methodReturnType[0] == 'B' || signature.methodReturnType[0] == 'c')
            && !((BOOL (*)(id, SEL))objc_msgSend)(contact, single)) continue;
        friends[username] = @{ @"username": username,
            @"name": WCGesturePrivateContactDisplayName(contact, username) };
    }
    // Keep saved selections removable even when a contact is no longer in the native list.
    for (NSString *username in WCGestureMomentsReminderUsers()) {
        if (!friends[username]) friends[username] = @{ @"username": username,
            @"name": WCGesturePrivateNotificationDisplayName(username, username) };
    }
    self.friends = [friends.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
    }];
    [self filterFriends];
}
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (void)filterFriends {
    NSString *query = [self.searchField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.visibleFriends = query.length ? [self.friends filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, __unused NSDictionary *bindings) {
        return [item[@"name"] localizedCaseInsensitiveContainsString:query]
            || [item[@"username"] localizedCaseInsensitiveContainsString:query];
    }]] : self.friends;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleFriends.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    NSDictionary *item = self.visibleFriends[path.row];
    CGFloat scale = WCGestureSettingsScaleFactor();
    UIView *avatar = WCGestureContactAvatarView(item[@"username"]);
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.userInteractionEnabled = NO;
    avatar.layer.cornerRadius = 6 * scale;
    avatar.clipsToBounds = YES;
    UILabel *name = [UILabel new];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.font = [UIFont systemFontOfSize:16 * scale weight:UIFontWeightRegular];
    name.text = item[@"name"];
    name.textColor = UIColor.labelColor;
    [cell.contentView addSubview:avatar];
    [cell.contentView addSubview:name];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16 * scale],
        [avatar.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [avatar.widthAnchor constraintEqualToConstant:40 * scale],
        [avatar.heightAnchor constraintEqualToConstant:40 * scale],
        [name.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:12 * scale],
        [name.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12 * scale],
        [name.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
    ]];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.tintColor = UIColor.systemBlueColor;
    cell.accessoryType = [WCGestureMomentsReminderUsers() containsObject:item[@"username"]]
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSString *username = self.visibleFriends[path.row][@"username"];
    WCGestureMomentsReminderSetUserSelected(username, ![WCGestureMomentsReminderUsers() containsObject:username]);
    [tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
}
@end

UIViewController *WCGestureCreateMomentsFriendPicker(void) { return [WCMomentsFriendPicker new]; }
