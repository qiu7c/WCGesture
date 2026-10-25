#import "Sources/API/WCGestureInternal.h"

@interface WCGestureSettingsController () <UISearchResultsUpdating>
@property (nonatomic, strong) UISearchController *settingsSearch;
@property (nonatomic, copy) NSArray<NSDictionary *> *searchIndex;
@property (nonatomic, copy) NSArray<NSDictionary *> *results;
@end

@implementation WCGestureSettingsController
- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"One Wx";
    WCRefreshCachedCurrentUser();
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 64;
    self.definesPresentationContext = YES;
    self.settingsSearch = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.settingsSearch.searchResultsUpdater = self;
    self.settingsSearch.obscuresBackgroundDuringPresentation = NO;
    self.settingsSearch.searchBar.placeholder = @"搜索功能或设置";
    self.navigationItem.searchController = self.settingsSearch;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 72)];
    footer.numberOfLines = 3;
    footer.text = @"One Wx 2.0.0\n联系作者：Cc\nOne Wx by Cc";
    footer.textAlignment = NSTextAlignmentCenter;
    footer.font = [UIFont systemFontOfSize:12];
    footer.textColor = UIColor.secondaryLabelColor;
    self.tableView.tableFooterView = footer;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.searchIndex = [WCGestureDetailController searchEntries];
    [self updateSearchResultsForSearchController:self.settingsSearch];
}
- (BOOL)isSearching {
    return [self.settingsSearch.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
}
- (void)updateSearchResultsForSearchController:(UISearchController *)controller {
    NSString *query = [controller.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *results = [NSMutableArray array];
    if (query.length) {
        for (NSDictionary *entry in self.searchIndex) {
            NSString *text = [NSString stringWithFormat:@"%@ %@ %@", entry[@"title"], entry[@"categoryTitle"], entry[@"sectionTitle"]];
            if ([text rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) [results addObject:entry];
        }
    }
    self.results = results;
    UILabel *empty = [UILabel new];
    empty.text = @"没有找到相关设置";
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.secondaryLabelColor;
    self.tableView.backgroundView = query.length && !results.count ? empty : nil;
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isSearching ? 1 : 6;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isSearching ? self.results.count : 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxHome"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"OneWxHome"];
    NSArray *titles = @[@"聊天类功能", @"手势类功能", @"朋友圈功能", @"界面类功能", @"禁用类功能", @"插件类配置"];
    NSArray *symbols = @[@"bubble.left.and.bubble.right", @"hand.tap", @"heart", @"rectangle.3.offgrid", @"nosign", @"gearshape"];
    NSArray *colors = @[UIColor.systemBlueColor, UIColor.systemGreenColor, UIColor.systemPinkColor, UIColor.systemPurpleColor, UIColor.systemRedColor, UIColor.systemOrangeColor];
    NSInteger category = self.isSearching ? [self.results[indexPath.row][@"category"] integerValue] : indexPath.section;
    cell.textLabel.text = self.isSearching ? self.results[indexPath.row][@"title"] : titles[category];
    cell.detailTextLabel.text = self.isSearching ? [NSString stringWithFormat:@"%@ · %@", titles[category], self.results[indexPath.row][@"sectionTitle"]] : nil;
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.imageView.image = [UIImage systemImageNamed:symbols[category]];
    cell.imageView.tintColor = colors[category];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *result = self.isSearching ? self.results[indexPath.row] : nil;
    NSInteger category = result ? [result[@"category"] integerValue] : indexPath.section;
    WCGestureDetailController *detail = [[WCGestureDetailController alloc] initWithCategory:category];
    if (result) [detail focusSearchResult:result];
    self.settingsSearch.active = NO;
    [self.navigationController pushViewController:detail animated:YES];
}
@end
