#import "Sources/API/WCGestureInternal.h"

@interface WCChangelogController : UITableViewController
@property (nonatomic, copy) NSArray<NSString *> *updates;
@end
@implementation WCChangelogController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"更新日志";WCGestureSettingsConfigureNavigation(self);
    self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=64;
    self.tableView.allowsSelection=NO;
    self.updates=@[
        @"首页搜索框同步圆角与边距，调整顶部导航背景衔接。",
        @"修正首页圆角的布局重入和重复外观刷新问题。",
        @"修复分组角标漏算普通会话未读消息的问题。",
        @"新增首页圆角，支持半径、边距和间距调节；分组栏与列表同步，适配微信深色模式。",
        @"首页精简为六类，同页设置合并到一张圆角卡片，修正箭头和按压高亮越出卡片的问题。",
        @"新增主页分组，支持自定义分组、成员管理和横滑切换。",
        @"新增主页右滑扩展，支持备注、朋友圈、勿扰和置顶等操作。",
        @"新增图片编辑圆形、箭头工具，支持颜色和线宽调节。",
        @"新增头像替换与恢复，并整合到好友、群聊资料卡。",
        @"新增虚拟视频、文字贴纸，扩展钱包金额和聊天记录卡片的本机显示修改。",
        @"扩展多选上限与广告过滤。",
        @"优化分组和头像选择列表，好友、群聊分开展示。",
        @"设置页标题加粗，菜单默认收起；分组栏默认跟随置顶灰色，开启统一改色后默认白色。",
        @"修复分组显示异常，避免防撤回样式干扰普通聊天提示颜色。"];
}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return @"1.0.0 · 2026-10-29"; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.updates.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"update"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"update"];
    cell.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.text=self.updates[path.row];cell.textLabel.numberOfLines=0;
    cell.textLabel.font=[UIFont systemFontOfSize:15*WCGestureSettingsScaleFactor()];cell.textLabel.textColor=UIColor.labelColor;
    return cell;
}
@end
UIViewController *WCGestureCreateChangelogController(void) {
    WCChangelogController *controller=[WCChangelogController new];controller.hidesBottomBarWhenPushed=YES;return controller;
}
