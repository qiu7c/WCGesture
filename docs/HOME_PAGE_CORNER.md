# 首页圆角

2026-10-29：源码接入，尚未进行iOS编译或真机验收。

入口：界面类功能 → 圆角设置 → 首页圆角。默认关闭；开启后默认半径16pt、左右边距16pt、卡片间距8pt，分别可调0–48、0–32、0–24。数值跟随界面大小换算一次，半径不超过目标短边的一半。四个key均在Core声明、定义、注册默认值并接入口令导出；已有配置不改名。

## 显示与配色

- 搜索框当前采用WCSearchBar外层自绘背景surface，保留原生输入框frame/约束。背景直接对齐主表卡片，限制在祖先实际裁切范围内，替代此前直接增大searchBoxContainer的方法；激活搜索隐藏surface并恢复原生背景。
- 搜索容器高度目标为40×布局比例，在原搜索栏可用高度内居中；边距先在主表坐标生成再转换。首页顶栏现在直接使用与列表留白一致的实色（覆盖此前透明方案），并通过首页原生背景/模糊getter保持一致，关闭恢复原行为。
- 分组和系统横幅相连，只在合并区域顶端/末端保留外圆角，去除内部间距。首页圆角下新增“合并置顶”，默认关闭；打开后置顶列表接入合并区域，普通会话仍独立。没有横幅/置顶时按实际非空分区收尾；未开启分组时保持各分区独立。新key为`com.qiu7c.onewx.home.corner.mergePinned`，已补Core/default/口令导出。
- 首页搜索输入容器使用同一半径和左右边距，搜索区外层使用页面留白色；只处理首页持有的WCSearchBar，激活原生搜索时恢复。首页navigationItem四种背景外观透明，保留标题/按钮并与页面底色衔接，不改共享导航栏；关闭恢复原外观。
- 会话按UITableView当前数据源的section首/末行生成上/下圆角；单行四角，中间行保持直边。当前表格已经经过HomeGroups投影，因此不按未筛选行号、固定section编号或屏外cell的无障碍标签判断。
- 分组导航使用自己的背景surface，与列表使用同一边距和半径；按钮、角标和手势保留，原生tableHeaderView仍保留在wrapper中。设备横条和置顶折叠条通过已有MFBannerBtn/MainFrameSectionFoldView布局入口同步，作为独立原生对象处理。
- 浅色卡片固定白色，深色卡片固定0.11灰度；页面留白为浅色0.95/深色0.04灰度。这些是本功能明确的配色，不再取原生置顶图像颜色；圆角开启期间优先于旧分组统一改色，关闭后恢复原设置。
- 优先读取8.0.79已核实的 `+[MMDarkModeConfigUtil isDarkMode]`，支持微信独立于系统的深色设置；模式更新及表格trait更新后刷新颜色。分组文字和默认滑块也用微信模式，而非只依赖系统labelColor。

## 实现与依据

独立目录 `Sources/Features/HomePageCorner`。复用既有主页viewDidLoad/viewDidLayoutSubviews/willDisplay入口；新增类方法均核对Hook去重。会话背景回调 `updateCellBackground:` 的参数按8.0.79头文件使用id，不错误截断成BOOL；高度和header view方法来自MMUIViewController继承链。没有对不存在的estimatedHeight delegate调用orig。

布局参考已还原WCRefine的表宽绝对内缩与section首末位；mask沿用UIBezierPath/CAShapeLayer。缓存bounds/半径/角位，变化才更新path，关闭隐式路径动画。恢复只处理本功能自己的mask、颜色、隐藏状态和横向frame，保留原生后续更新的纵向位置。私有会话背景字段只在NewMainFrameCell分支读取，不对设备cell反复触发未知KVC异常。

未照搬来源插件的授权、设置版本迁移、其它页面识别或尚未还原的黄白style/grouping逻辑；也未新增定时器、全局UIView扫描或重复安装逻辑。配置的类型、有限值和范围在读取边界统一处理，内部使用缓存后的参数。

## 验证

已做括号/import、单ctor/init、Hook去重、API/4个新key/default/口令与34旧别名、私有签名及git diff静态核对。静态检查不代表Theos编译或实际显示成功；本机没有iOS SDK，不主动查询CI。

待设备验收：首次进入、重启、微信浅深色独立切换、分组过滤/空分组、设备横条出现移除、置顶折叠展开、快速滚动复用、左右滑动菜单、界面比例调整、开关关闭后的恢复。没有将这些场景写成已通过。
