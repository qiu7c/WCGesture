#import "Sources/API/WCGestureInternal.h"

@interface WCRevokeRecordsController : UITableViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, copy) NSArray<NSDictionary *> *records;
@end
@implementation WCRevokeRecordsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self); self.title = @"防撤回记录中心";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72 * WCGestureSettingsScaleFactor();
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.searchField = [UITextField new];
    self.searchField.placeholder = @"搜索联系人、会话或内容";
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(reloadRecords) forControlEvents:UIControlEventEditingChanged];
    self.tableView.tableHeaderView = WCGestureSettingsSearchHeader(self.searchField, self.view.bounds.size.width);
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(recordsChanged:) name:WCGestureDidChangeNotification object:nil];
    [self reloadRecords];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)recordsChanged:(NSNotification *)note { [self reloadRecords]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (void)reloadRecords {
    NSString *query = [self.searchField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *record in WCGestureAntiRevokeRecords()) {
        NSString *search = [NSString stringWithFormat:@"%@ %@ %@", record[@"contact"], record[@"session"], record[@"summary"]];
        if (!query.length || [search localizedCaseInsensitiveContainsString:query]) [filtered addObject:record];
    }
    self.records = filtered; [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.records.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RevokeRecord"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RevokeRecord"];
    NSDictionary *record = self.records[path.row];
    NSUInteger type = [record[@"type"] unsignedIntegerValue];
    NSDateFormatter *formatter = [NSDateFormatter new]; formatter.dateFormat = @"MM-dd HH:mm:ss";
    NSString *date = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[record[@"time"] doubleValue]]];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", record[@"contact"], WCGestureAntiRevokeMessageTypeName(type)];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %@", date, record[@"summary"]];
    cell.detailTextLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont systemFontOfSize:16 * WCGestureSettingsScaleFactor()];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12 * WCGestureSettingsScaleFactor()];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
@end

UIViewController *WCGestureCreateRevokeRecordsController(void) { return [WCRevokeRecordsController new]; }
