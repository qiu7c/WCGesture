# One Wx 开发交接

最后更新：2026-10-26。本文描述当前工作区；已替换旧版本交接中的重复历史和过期状态。

本次提交说明（2026-10-25）：用户已明确授权提交推送。本轮透明顶栏、自动确认登录、设置样式清理、聊天搜索纠正、朋友圈提醒/保活、视频及预览圆角修正、广告精简和交接文档统一纳入本次提交。下文各节“未提交”保留的是开发时记录，不代表该提交之后的实时工作区状态；最新提交与推送状态以实际 git log / git status / origin/main 为准。编译、真机验证和资料页/相册缩略图补充层级仍未完成，不主动查询 CI。

本次提交说明（2026-10-26）：用户已确认提交当前全部修正，包含资料卡重做、共同群聊跳转与群页入口、顶栏缩放/透明背景/置顶同步、原生群标题居中、相册和资料页视频号封面圆角。以下“当前未提交”为开发期间记录，均纳入本次提交；实时状态以 git status/log 为准。版本保持 1.0.0；只做静态检查，未编译或真机验收，不主动查询 CI。

本次提交说明（2026-10-26）：用户再次明确授权提交推送，纳入当前全部修正：胶囊首帧安装与退出时机、玻璃透明度/外框/图标调节、头像显示、独立表情及聊天图片圆角、圆角设置归并、一级入口搜索与资料卡布局。以下“当前未提交”为开发记录，本轮统一提交；未编译或真机验收，不主动查 CI。

## 2026-10-26 胶囊首帧安装时机（当前未提交）

对照 WCAtlas/Tweak.xm 的 viewDidLoad/viewWillAppear、Update 与 Refresh 分工：迁移版把窗口可见判断放进了唯一 Update，导致页面出现前的调用失效，退出时又在 viewWillDisappear 立即恢复。现新增 PrepareAppearance，在 viewDidLoad 和 viewWillAppear 原生初始化/搜索清理后同步安装导航项，不要求 view.window；正常后续 Update 保留可见/栈顶限制。预加载页面只设置自身 navigationItem，只有栈顶控制器才能接管共享导航栏。胶囊自身布局同步完成，导航栏 layout 当轮清理重建的背景，异步复核仍保留。退出动画保持胶囊，到转场完成或 viewDidDisappear 恢复；交互返回取消则重新准备。搜索入口继续提前恢复，关闭开关与多选逻辑保留。

只做静态检查，未编译、未真机验证、未提交推送。需设备验证首次进入/再次进入、聊天互跳、返回取消、搜索退出和多选。

## 2026-10-26 表情/图片圆角、圆角设置与资料卡密度（当前未提交）

用户提供三处实况层级，要求表情菜单预览、发出的表情、发出的图片分别圆角，并将圆角集中到界面类功能；首页搜索只收录一级菜单；资料卡更透明、取消地区/性别并尽量加长，一页显示基础信息，避免上下滚动；同时继续反馈头像被放大。

- 新增 Features/EmoticonCorner 与 ChatImageCorner。前者处理 EmoticonViewWithPreview 的原生 m_emoticonView/m_emoticonPreview/m_emoticonShowPlayView 媒体槽，以及 EmoticonMessageCellView 内 MMEmoticonView；后者只处理 ImageMessageCellView 内 YYAsyncImageView，独立开关/程度。4 个新 Core key 默认关闭/8pt，0–40 且不超过短边一半，全部进入配置口令。不改 imageScale、原图、原生尺寸或表情包数据。
- Services/WCGestureMediaCorner.m 共用首次原图层快照、唯一设置归属、弱视图登记及下一主循环复核；关闭/离开指定宿主恢复原 radius/masksToBounds/curve/maskedCorners。复用已有 CommonMessageCellView setViewModel/prepareForReuse Hook 转发恢复旧状态，不重复 Hook；UIView 全局转发仍只在 Tweak.x 的原有一处，且只处理已登记目标。动态图、窗口切换、尺寸变化不按旧尺寸缓存跳过。
- UI/WCGestureCornerSettingsController.m：界面类功能 → 圆角设置，集中全局头像、输入栏/内外工具栏、朋友圈（含相册/资料视频号）、表情、聊天图片；移走旧分类中的重复圆角行，旧 key/值保留。输入圆角整页预览入口保留，新增表情/图片使用实际界面验收，不伪造模拟。开关蓝色、子项 18pt 缩进、无独立说明小字。
- 首页 searchEntries 仅收录 indentationDepth==0 的一级条目，不再把格式、位置、半径等子选项加入结果；圆角只搜到“圆角设置”入口，里面的子项不单独铺出。搜索仍不自动启用功能。
- 对照 WCAtlas 的 PrivateContactAvatarImage → plain AspectFit 路径，新增 WCGestureContactUncroppedAvatarView：优先联系人缓存原图，原生加载使用 bRoundCorner:NO，异步拿到图后用普通 UIImageView/AspectFit；不让缩放的 MMHeadImageView 再裁切一遍。顶栏、本人预览和资料卡统一使用此路径，已有圆角由各自外层负责。
- 资料卡主信息移除地区/性别，更换较轻的 ThinMaterial、玻璃 alpha 0.72、遮罩 0.12，文字保持不透明。面板按记录数与安全区加长、所有基础字段同页，关闭主资料纵向滚动；共同群聊列表保留其必要滚动。行高/字号适应可用高度，长内容可缩小或截断显示，点击复制仍保留完整值。此前未提交的顶栏透明度/外框/图标大小调节全部保留。

仅源码和静态检查条件；未编译、未真机验证、未提交推送。待验收：菜单图/GIF/长按预览、双方已发表情/图片、快滚复用与关闭恢复，确认头像/文字/普通图标不受误伤；头像原图加载前后无放大、圆角设置迁移后数值不变；搜索结果仅一级功能；资料卡一屏/横屏/长群资料字段及群列表返回跳转。

## 2026-10-26 透明度与外框/图标独立调节（当前未提交）

用户再次反馈置顶条扁且玻璃不透，明确要求透明度、胶囊整体外观大小与内部图标可分别调整。当前基线 ae8c8fa，新增三个设置 key 均位于 com.qiu7c.onewx.chat.top-bar-capsule.*，Core 声明/定义/defaults 与配置口令同步，版本仍 1.0.0，未获本轮提交推送授权。

- 玻璃透明度 0–100%，默认 50：实际玻璃 UIView 的 alpha=1-透明度，作用于材质、阴影高光和边缘，文字/头像/图标是同级内容，不一起变淡；顶栏及置顶共享。与已有模糊强度独立，透明度 100 隐藏玻璃仍可操作按钮；系统降低透明度时材质按已有实色降级，但仍尊重用户的玻璃透明度数值。
- 胶囊外框大小 80–140%，默认 100：调整玻璃外框高度与横向留白，不做整层 transform，不缩放图标、头像或字体。可见高度限制在 44pt 导航宿主内并至少容纳内部内容；宽度按实际屏宽/原生附加按钮避让。
- 图标大小 12–26，默认 18：独立调整返回、搜索、更多图标，保留原头像大小/昵称字号设置。右侧宽度给大图标保留最低间距，原生和预览使用同一预算。
- 置顶条恢复 WCAtlas 的 MIN(容器高度,40pt)，去掉上轮多乘的界面比例，不再因 70–90% 界面设置额外变扁；仍只覆盖标题行、不把展开列表拉满。预览示例同样恢复 40pt，间距单独跟随界面比例。
- 参数集中在原消息时间共用整页预览的“顶栏”面板，滑杆/数值输入/重置可用，不加说明小字。未增加 Hook 或框架。仅静态检查，未编译、未真机验证、未提交推送；需要实测真实背景透出、0/50/100% 透明、各种外框/图标组合、置顶展开/收起与原生按钮操作。

## 2026-10-26 资料卡 UI 与共同群聊、群页入口修正（当前未提交）

用户反馈资料卡外观/头像裁切差，要求玻璃高斯模糊，且共同群聊不能跳转、群资料入口未见。旧版确实只有复制字段处理，共同群聊只是缓存数字，没有行动路由。

- UI 改为 UIKit SystemMaterial 玻璃背景、轻遮罩、细边缘，保留居中约 52% 安全区高、90% 宽且最大 440pt，内容内部滚动。基础资料自定义左右字段/值布局，值支持多行；不再使用系统 Subtitle 上下堆叠。共同群聊在同一个半屏弹窗中切换列表，左箭头回资料，右上关闭；实际加载/空/重试状态占列表内容，不增加设置说明小字。
- 头像新增仅供本卡调用的“不预裁圆”原生加载 API，原有其他模块头像 API 行为不变。资料卡使用单个外层头像宿主裁切，加载到原图时用 AspectFit 显示；未加载时保留原生异步载图，短期延期刷新。默认 10pt 圆角，开启全局头像圆角时按其百分比计算，避免原生圆角再叠一圈。昵称与资料标题整理为单一头像行。
- 共同群聊复用 WCAtlas 的 ContactRelatedGroupLogic initWithContact:/trySearchRelatedGroup/getContactRelatedGroup/isSearchDone（均核对 8.0.79 签名），直接保留请求，最多 10 秒有界异步等候，去重并按群名排序。关闭或重试释放请求，延期步骤弱引用，请求失效后停止；账号/主开关检查。未知/超时不显示成零。点“共同群聊”打开列表，再点具体群，先关闭弹窗再调用现有原生聊天跳转 API；失败有操作反馈。
- 群资料页原来已有 Hook，但插入默认首分组可能落入原生成员宫格。现在避开 memListSection/首个成员分组，读取 cellConfig.leftConfig 标题定位群名/群备注分组，并迁走原先错误分组中的插件行；补 viewWillAppear/viewDidAppear 最终显示时机。仍只删除自己带标记的行，不改原生条目。
- 新增 API 均加入现有伞头，未新增 key/defaults/全局 UIView Hook。之前未提交的顶栏、置顶、群标题和朋友圈/视频号圆角修正完整保留。当前仍未编译、未真机验收、未提交推送。待验收：玻璃浅深色/降低透明度/横屏和长字段，头像慢加载/全局圆角，好友/自己/群成员/群聊入口，群列表加载/空/失败重试与实际跳转、关卡取消请求。

## 2026-10-26 资料页视频号封面圆角（当前未提交）

用户补充的视频号资料入口层级为 WCFinderWXContactEntranceView → coverStackView（261×48）→ 两个 48×48 UIImageView，各含 12×12 视频角标。沿用现有朋友圈圆角开关/程度，只登记原生 coverStackView 为专用缩略图根，分别裁切直接子 UIImageView 的外层边界；不圆角整个视频号入口，不处理旁边头像、认证标识、名称或内部角标。半径仍为 0–40pt 且不超过图片短边一半。

新增 WCFinderWXContactEntranceView layoutSubviews/didMoveToWindow 转发，复用唯一 owner、原始图层保存和延期复核。coverStackView 更换或离窗时恢复旧封面并移除登记；关闭功能按现有设置刷新恢复。已核对 8.0.79 coverStackView 属性及 UIView 继承；没有触碰含 C++ vector 参数的 setupViewWithNewStyle 接口，没有新增全局 UIView Hook、设置 key 或默认值。附件仅作诊断数据读取，未执行或提交。括号/import/Hook 去重/API 和原生声明核对通过；未编译、未真机验证、未提交推送。

## 2026-10-26 朋友圈相册媒体圆角反馈（当前未提交）

用户提供 WCListViewController 的真实层级：普通 WCListPhotoCellView / WCListSightCellView 中，WCImageView、WCPuzzleImageView 被 UIButton 包住，按钮还包含 RichTextView 正文；置顶 WCListHybridCellView 则直接含 MMImageGridView。旧遍历把所有 UIButton 分支都跳过，导致只有置顶行可达，普通图片/视频/拼图漏处理。

现在仅在上述三类相册媒体 cell 根下放行按钮遍历，不圆角 309pt 宽且包含正文的按钮本身；圆角加在外层 WCImageView（包括视频封面及其 SightFileMaskView）、WCPuzzleImageView 或 MMImageGridView。相册宫格按最外层框整体裁切，不再对内部小图重复圆角；跳过 RichTextView/UILabel/头像，保留日期、正文、封面及头像原样。继续使用唯一 owner 和首次原始图层快照，关闭恢复、0–40pt 且不超过短边一半，不按同尺寸跳过。

新增 WCListSightCellView initTailView、WCListHybridCellView reloadItemContainerView 的初始化/复用转发，并在三类媒体初始化入口合并下一主循环复核，均已对照 8.0.79 头文件；未新增 UIView Hook、key 或默认值。附件只作为视图诊断数据读取，未执行或拷贝到仓库。当前已有相册页实况树；好友资料页入口若仍异常，仍需那一处实际层级。

本轮与未提交的胶囊/背景/置顶/群标题修正一起保留。仅静态检查，尚未编译、真机验收或提交推送。需验证普通图片、视频封面及图标、拼图整体、置顶宫格、同尺寸滚动复用、日期正文不受裁切，以及关闭恢复。

## 2026-10-26 顶栏实机反馈修正（当前未提交）

用户反馈胶囊过大、界面缩小时未跟随、顶栏原生背景残留，并要求置顶同步；另外指出隐藏群标题尾部后没有居中。03ab697 已推送，本节是其后的工作区修正，尚未提交。

- 确认旧版把 44pt 点击宿主同时当作玻璃可见高度，且没有接入界面大小。现在保留标准 44pt 导航宿主，可见胶囊按 WCAtlas 的左 MAX(38,头像+8)、右 MAX(36,头像+6) 为基准，头像/字号/图标/间距/宽度与 WCGestureLayoutScaleFactor 同步（70–100%），不受“包含插件界面”开关影响。左上限由 260 收紧为 205×比例，右搜索胶囊由 88 改 76×比例；预览用同一渲染器。
- 补齐 WCAtlas 的导航宿主背景处理：共享 UINavigationBar 四种 appearance、translucent、宿主颜色/边框/裁切、已知 Background/Backdrop/Material、MMNewMsgContentNavBar/MMMsgContentNavBar 内的嵌套背景与模糊。每个改动保存原值，按导航栏唯一 owner 交接及离页/关闭恢复，排除插件胶囊和展开列表主体；导航布局完成后合并延期复核，避免原生后置布局把背景加回。新增的是 UINavigationBar 子类 Hook，UIView Hook 仍仅 Tweak.x 一个。
- 新增 ChatTopBar/WCGestureChatPinnedGlass.m 与 MMMsgCommonTipsView 布局/入窗转发。对照 WCAtlas 原版 MIN(容器高度,40pt)，玻璃仅覆盖固定标题行，跟随 40×界面比例、左右 8×比例；列表展开时不把玻璃拉满。与顶栏共用模糊强度，置顶固定磨砂（原版即如此）；保存/恢复原颜色、边框与阴影，离窗/关闭恢复。共用聊天预览增加置顶示例。
- 隐藏群标题尾部：补可选 GetTitleLabelOffset 运行时 Hook（只安装无参数、CGFloat 返回且已存在的接口，避免给 8.0.79 缺失 selector 注入假实现），开启时偏移归零；原生群聊标题在已有聊天布局/标题更新 Hook 后，将标题容器与主标签中心对齐导航栏，关闭恢复原帧/对齐，不移动胶囊中的左侧昵称。未新增重复 Hook 或设置 key。
- Windows 仅静态检查；尚未编译、查询 CI 或真机验证。待验收：70/90/100% 的实际与预览大小、深浅色背景、系统/自定义导航、往返和取消侧滑后的背景恢复，置顶折叠/展开/收起不溢出，关闭恢复，以及原生群标题居中、搜索/多选/长群名和其他界面不受影响。

## 2026-10-26 三项小功能（纳入本次提交）

用户选择通话气泡二次确认、资料信息卡片、自动勾选合并发送，并指定资料卡居中、约半屏。均独立 Features 目录，三个新 key 在 Core 声明/定义/默认关闭并加入配置别名；此前未提交的胶囊顶栏全部保留。用户已于 2026-10-26 授权本轮提交推送，胶囊及这三项功能一并纳入本次提交；版本核对为 1.0.0。

- CallConfirmation：拦截 VoIPBubbleMessageCellView 的 startVoiceVoip/startVideoVoip，标准确认弹窗；弱引用气泡并保存消息身份及服务器/本地 ID，确认前检查仍在窗口且同一消息，单次旁路令牌重入原生调用并 finally 清除。开启后无法弹窗不会悄悄直拨。只覆盖聊天通话记录气泡，不声称覆盖所有拨号入口。
- ContactInfoCard：WeixinContactInfoAssist 的 initData/reloadTableView/viewDidAppear 以及 ChatRoomInfoViewController 的 initData/reloadTableData/reloadProfileTableData，新增带专属标记的资料信息行，去重/关闭时只移除自己的行，合并延期刷新表格。8.0.79 插入索引 unsigned int、移除索引 unsigned long long，工厂首参 SEL，运行时核对签名。资料卡 UI 在 Sources/UI/WCGestureContactInfoCardController.m，OverFullScreen 遮罩＋安全区居中卡片，优先 52% 安全区高度、90% 宽度且最大 440pt，内容内部滚动；点击遮罩/关闭按钮退出，点字段复制。好友显示本机已有 ID/昵称/备注/微信号/签名/地区/性别/添加时间天数；群聊增加成员数/群主/管理员/简介/链接，群成员附可用群昵称/身份；共同群聊只读取原生已完成的缓存，不伪造缺失值。不迁移上游支付查询脱敏姓名、未接入的屏蔽/发送确认开关、踢群等无关操作。
- AutoCombineSend：复用 AutoOriginal 六个现有 Hook 转发，补独立两个 picker/preview viewDidAppear（不重复 Hook）。异步合并请求，弱持有页面；需自动原图＋本功能同时开启且原生 isCombineSendHidden 为 NO、控件在窗口，运行时核对 BOOL getter/setter/updateSelected。通过原生 controlCenter setIsCombineSend:YES 和视图 updateSelected:YES 同步；每个符合条件的控件/控制中心组合只自动选择一次，隐藏后解除标记，普通刷新不强制勾回用户已取消的选项；关闭不清除用户原生勾选。

本机只有静态检查条件；尚未编译、真机验收。待验证：语音/视频取消确认、连续点击、气泡复用/离窗；好友/自己/群聊/群成员入口、重复刷新及关闭移除、长字段与横屏/深浅色/大字体；单张/多张/混合视频、切换预览、手动取消、减少选择后再次满足条件、关闭自动原图/合并开关。

## 2026-10-26 胶囊顶栏迁移（纳入本次提交）

用户要求迁移并优化 WCAtlas 顶部胶囊，预览必须使用消息时间的同一个页面。新增 Features/ChatTopBar（玻璃、共用胶囊绘制、原生状态管理、独立标题/多选 Hook）。界面类功能下“胶囊顶栏”默认关闭，展开提供“整页顶栏预览与调节”；原有整页聊天预览增加第四个“顶栏”调节项目，继续保留消息时间、防撤回、输入圆角、本人头像和 12pt 面板间距，没有新增另一套模拟页面。

- 五个新 key 均在 Core 声明/定义/defaults 并加入配置口令：主开关、玻璃样式（默认伪液态）、模糊强度 20–100（默认 20）、头像大小 24–34（默认 30）、昵称字号 12–18（默认 15）。数值滑块、输入、样式切换和重置位于同一预览面板。
- 原生与预览共享 WCGestureChatTopCapsuleView/玻璃绘制：左返回＋头像＋昵称，右原生更多＋可选搜索。长昵称按导航可用宽度截断，保留额外原生按钮，44pt 点击区域；字号响应动态字体并封顶。输入状态保留绿色点提示。
- 优化采用按控制器保存/恢复状态、复用已有胶囊、配置不变不重建排版/图标，尺寸变化才失效固有尺寸；玻璃只在配置、重新入窗、前台和外观变化时刷新，几何更新关闭隐式动画，系统降低透明度时用实色背景。未修改共享导航栏 appearance，只作用于当前 navigationItem，并针对已知导航背景视图保存/恢复 hidden。
- 复用 ChatUtilities 的 viewWillAppear/viewDidLayout 和 MessageGestures 的 viewDidAppear/viewWillDisappear 转发，避免同类同方法重复 Hook；搜索启用/取消后恢复胶囊，搜索过程中和消息多选使用原生顶栏，页面离开/关闭功能恢复状态，侧滑取消由 didAppear 重建。Tweak.x 仅新增设置变更分发，不添加 UIView Hook。
- 8.0.79 头文件核对 updateTitleView:、updateTitleView:ignoreAnimation:、enterMultiSelectMode/exitMultiSelectMode、GetCContact/getRightBarButton 和多选状态 getter。只做源码/静态检查，尚未编译、真机验收或提交。待验证：单聊/群聊/公众号，长昵称/大字体/窄屏横屏，头像加载、正在输入、深浅色/降低透明度、前后台、返回/取消侧滑、原生更多菜单/附加按钮、多选、搜索开关/取消/重开、预览切换/滑块及关闭恢复。WCAtlas 的置顶消息条玻璃装饰及发送确认长按依赖未纳入本次顶部导航胶囊范围。

## 2026-10-26 上轮修正（已提交 bbf8672）

- 用户反馈广告精简开启后进入朋友圈闪退。移除 WCTimelineMgr 三处改写原生广告更新输入的 Hook；广告读取保留原调用后返回独立可变空数组，避免原生后续增删遇到不可变 NSArray。公众号广告列表同样返回可变数组。移除 WCAdvertiseStatMgr 元数据置空及 WCUserComment 广告身份/扩展数据改写，保留原生模型一致性。没有崩溃日志，以上是修复已识别风险，实际闪退根因与修复效果仍需设备复测；未宣称问题已经验证解决。
- 迁移 WCAtlas“通知直达聊天”：聊天类功能单开关，默认关闭，新增 key `com.qiu7c.onewx.chat.notification-direct-chat.enabled` 并纳入配置口令。独立 NotificationDirectChat 模块复用现有两个通知响应 Hook，朋友圈自有通知优先，普通通知只接默认点击动作和 `u` 会话字段，其他动作交回原生。延迟 0.3 秒打开、启动/解锁等待最多再尝试 8 次；关闭、换号或更新通知任务取消旧跳转。WeChat 层使用 8.0.79 的 MMMsgLogicManager 按联系人跳转接口，运行时检查签名和导航状态，同会话不重复入栈。仍需单聊/群聊、冷启动、解锁、快速连续点击与通知快捷回复真机验证。
- 用户更新首页字重要求：首页分类主标题和首页 One Wx 标题改半粗；子页继续常规字重，不恢复说明小字。
- 只有静态检查条件；未编译、未查询 CI、未真机验证。最近已推送提交为 996edcd，实时状态以 git status/log 为准。

## 1. 接手先看这里

先完整阅读本文、[CONVENTIONS.md](CONVENTIONS.md) 和 [README.md](../README.md)。
功能逐项对照见 [WCATLAS_PARITY.md](WCATLAS_PARITY.md)，未迁移功能见 [MIGRATION_BACKLOG.md](MIGRATION_BACKLOG.md)。
给新会话的可复制文字见 [HANDOVER_PROMPT.md](HANDOVER_PROMPT.md)。

| 项目 | 当前值 |
|---|---|
| 产品 | One Wx，原 WCGesture / 微信手势 |
| 包名 / 版本 | com.qiu7c.onewx / 1.0.0 |
| dylib / 注入 plist | OneWx.dylib / OneWx.plist |
| 仓库 / 分支 | https://github.com/qiu7c/WCGesture.git / main |
| 本地目录 | C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCGesture |
| 本次提交基线 | 1b9e79c：迁移聊天与朋友圈增强并统一设置界面；本轮合并提交的实际哈希以 git log -1 为准 |
| 构建 | Theos / Logos；arm64 + arm64e；iOS 14.0；rootful + rootless |
| 本机 | Windows / PowerShell，无 Theos/clang，不能本地编译 iOS tweak |

本轮开发开始时 HEAD 与本地 origin/main 均为 1b9e79cecc59fba7488b5bb344382d73b980a996；这是提交前基线。
该记录不是实时远端查询。没有检查 CI 或宣称最新构建成功。

### 当前未提交内容

首页透明顶栏修正涉及以下两个源码文件（继续保留）：

- Sources/UI/WCGestureSettingsStyle.m
- Sources/UI/WCGestureSettingsHome.m

另外本文和 HANDOVER_PROMPT.md 正在更新。HANDOVER_PROMPT.md 是原本存在的未跟踪文件，上次推送未纳入；本次用户明确要求更新交接文字，因此更新了它。请保留，不要误删。

首页顶栏修正已经写入工作区，但没有提交推送：

- 首页 navigationItem 清除背景色、模糊和底部阴影。
- 覆盖 standard、scrollEdge、compact，以及 iOS 15+ compactScrollEdge 外观。
- 首页背景延伸到导航栏下方；再次进入首页时重设透明外观。
- 保留系统安全区滚动调整；没有修改微信共享 navigationBar，也没有修改子页或 Tweak.x。
- 只完成结构、import 和 diff 检查。需要真机验证滚动、深浅色、横屏、返回首页以及退出到微信后的导航栏恢复。

### 本次新增：自动确认登录（未提交）

用户明确要求迁移自动确认登录。新增 Sources/Features/AutoDeviceLogin/ 及 API，沿用 WCAtlas 的 MultiDeviceCardLoginContentView 原生 onTapConfirmButton；8.0.79 头文件已核对。插件类配置中的“自动确认登录”默认关闭，支持首页搜索和配置口令（原 64 项追加 1 项，旧别名不变）。

布局和入窗时调度，同一卡片每个登录信息对象最多自动尝试一次；异步执行前重查开关、窗口、按钮可用性、错误状态和登录信息身份。失败不自动重试，交给用户手动处理。未增加游戏扫码授权或后台保活。仍需编译及真机验证电脑/平板、重复布局、卡片复用、离窗、开关关闭和失败手动处理；静态检查不能替代这些验证。


### 设置界面清理（本次用户要求，未提交）

删除设置列表全部 14 处独立说明小字及 Hint 行类型。自动确认登录、语音转发、聊天搜索、菜单 +1、自动原图、隐藏群标题尾部改为直接开关；所有分组在生成行后按实际子项数量判断能否折叠，单行无箭头。首页分类、设置/分组行、导航标题、预览调节标题及弹窗文字统一常规字重。保留消息时间功能的用户可选加粗、必要输入参数说明和操作反馈（自动确认登录后的提示仍在）。需真机验证字体、折叠、搜索定位及开关切换。

补充清理：用户要求覆盖全部设置页面，继续移除 37 处输入/选项/文本弹窗说明、3 处管理/记录/调节页脚说明及格式/模板编辑页帮助标签和约束。输入范围用占位文字，保留实际设置值、记录内容和错误/操作结果。本轮这五个源码文件净减少 40 行，另有自动登录及交接文档新增，不能用工作区总增删判断 UI 清理规模。

### 聊天搜索迁移纠正（用户反馈后，未提交）

用户反馈搜索按钮蓝色且过大，打开后不能搜索。复查确认旧迁移只创建默认系统放大镜并调用 onSearchButton:，遗漏 WCAtlas 的原生按钮工厂与 MsgSearchHelper/WCSearcher 完整打开/清理流程。不能再把“8.0.79 存在该 selector”当成等价迁移或可用证明。

现在按 WCAtlas 独立搜索入口补齐：MMUICommonUtil 的 icons_outlined_search 原生按钮工厂，labelColor 跟随深浅色，工厂不可用时才用 18pt 图标；初始化当前聊天持有的 m_oMsgSearchHelper，再取其 searcher/getSearcher，使用 pushSearchControllerWithCompletion: 或 setActive:animated:completion:。不创建另一套 helper。取消/侧滑/返回清理搜索条与包装视图、移除临时手势并恢复原交互返回状态；延期清理带会话身份检查，避免影响快速重开。8.0.79 initMsgSearchHelper: 参数核对为 int，原生按钮工厂 style 为 unsigned long long（arm64 NSUInteger）。

取消通知采用 8.0.79 已有的 MsgSearchHelper wcsDidDismissSearch:，不照搬该版本 BaseMsgContentViewController 头文件中未找到的 msgSearchBarCancel。没有新增设置 key，也未修改引用定位。仍需编译与真机验收：单聊/群聊搜索有结果的关键词、点结果定位、取消、侧滑、再次进入、快速关闭重开、深浅色按钮和原生更多按钮。

### 朋友圈特别关心、互动通知、后台保活（本次用户授权，未提交）

本次明确要求三项全部迁移，已接入完整依赖；主开关默认关闭。

- 特别关心：Sources/Features/MomentsReminder/。朋友圈功能中选择好友（搜索/原生头像/多选）、检测间隔 30–3600 秒（默认 60）。首次读取建立基线，按账号保存每位好友最多 200 个已见 tid，只提醒新检测到且 24 小时内的内容。支持转发文字至自己或文件传输助手，图片/视频独立默认关闭，包含实况视频分支。文字/图片/视频发送适配位于 WeChat/WCGestureMessageSending.m，复用微信原生发送链路。
- 互动通知：Sources/Features/MomentsInteractionReminder/。Hook WCNotificationCenterMgr 的 getUnReadMessageCount（unsigned int）及 getLastUnReadMessage，读取 WCSNSMessage 的点赞/评论类型和详情，按账号去重；显示详细信息默认开启。附带原生发现页 openAlbum 隐式初始化，带取消代次与账号检查，不以初始化失败冒充成功。
- 通知：前台使用移植的通知横幅队列（最多 8 项、5 秒去重、4 秒自动收起、点击/上滑）；后台使用 UserNotifications，开启时仅在未决定权限时请求授权。通知点击通过两个原生回调入口打开朋友圈，使用 One Wx 自己的标识，不拦截普通微信通知。
- 后台保活：Sources/Features/BackgroundKeeper/。插件类配置直接开关。保留原后台任务申请/到期释放、25 秒续时检测和按需静音 WAV 循环；回前台/关闭开关释放资源。记录原音频类别、模式和选项，只在保活仍拥有该音频配置时恢复；不主动覆盖录音/通话类别。
- 调度：Services/WCGestureMomentsMonitoring.m 负责 10 秒轻量 Tick，只有任一提醒开启才创建定时器，特别关心另外遵守用户设置的间隔；保活是独立开关，不因开启提醒而自动开启。生命周期 Hook 单独放 BackgroundKeeperHooks.x，Tweak.x 仅加启动/设置变更调度。
- 8.0.79 适配：联系人列表参数均为 unsigned int；WCListViewController initData: 为 BOOL；图片下载类别、downloadType、imageOfSize: 为 long long；视频下载返回和 DownloadMode 为 unsigned long long。按类别工厂获取原生下载器，视频用 hasSight/pathForSightData 或 hasAttachVideo/pathForAttachVideoData 判断可用；不沿用源码中该媒体类未见的 getFormatVideoPath。异步轮询和发送前复核开关、账号、选择列表、目标和代次；关闭/换号/改目标后停止旧转发。
- 配置：新增 10 个设置别名（累计追加 75 项＝原 64＋自动登录 1＋本次 10），保留 34 个旧别名；另 2 个运行状态 key 在 Core 声明/定义/defaults，排除配置口令。新增 AVFoundation、UserNotifications、CoreMedia 链接。
- UI：沿用常规字重、无独立说明小字；特别关心和互动通知有实际子项可展开，后台保活只有开关。原未提交透明顶栏、自动登录、设置清理与聊天搜索修正均保留。

仅完成源码与静态核对，未编译、未查 CI、未真机验证。待验收：首轮基线与后续新帖、重复 tid/重启/账号切换、好友增删及间隔边界；点赞/评论详情与聚合/清零；通知允许/拒绝、前台横幅和后台点击；文字/多图/视频/实况向两个目标转发、下载超时与关闭取消；锁屏后台时长、回前台、语音消息/录音/通话/音乐及保活关闭后的音频恢复。不能保证被系统终止后继续执行，或未被微信读取到的朋友圈/互动能被检测。

### 朋友圈圆角问题反馈与广告精简（最新用户授权，未提交）

用户附件给出 WCTimeLineCellView → WCContentItemViewTemplateVideo → WCSNSNodeVideoView → WCPlayerView/WCPlayerLayerView。用户已明确：预览图指好友资料页朋友圈入口＋朋友圈相册列表缩略图；“圆角自己变”是设置数值不变，滚动/播放后外观改变。

- 原实现只匹配 WCImageView/MMWebImageView/WCPuzzleImageView，遗漏视频；嵌套的 Grid 和 Cell 能各自登记同一目标并互相恢复图层，这是复用外观变化的风险，不能把旧静态复核当真机正确性。
- 当前改为 WCSNSNodeVideoView 整体裁切（封面/播放层共用边界），不圆角全屏播放器本身。图片/拼图保持限定媒体容器；MMImageGridView 使用原生 m_arrOfViews 逐块裁切。
- 每个目标保存唯一 owner，跨根移交保留第一次原始图层状态，旧 owner 不得恢复新 owner 的目标；重设半径不再先 Reset 并重复采集基线。保存/恢复 cornerRadius、cornerCurve、masksToBounds 和 maskedCorners，应用/恢复关闭隐式动画。仍为 0–40pt、短边一半封顶，不写回或自动更改用户数值。
- 增加 WeixinContactInfoAssist getAlbumView 和 albumView:displayCellsWithDataItems:cellLeftContext: 入口（末参数 double *），只标记专用相册预览区域；不把整个资料页纳入图片识别。WCListPhotoCellView initImageGridView、MMImageGridView/WCSNSNodeVideoView 布局转发补上刷新时机。
- UIView Hook 仍只有 Tweak.x 一个；新增一行转发，只处理已有状态/已登记根，合并延后复核到私有子类布局结束后，不全局扫描所有 UIImageView。关闭恢复，移到不支持的全屏/其他宿主时恢复。
- 设置名称改为“朋友圈圆角 / 圆角程度”，旧 image-corner 设置 key 和别名保持原样。资料页和相册列表仍缺实际视图树，若未命中不能宣称已完全解决；需用户补两处缩略图的父链/子树及图层值。

广告精简新增独立 Sources/Features/AdBlocker/，禁用类功能中仅一个默认关闭的开关，配置口令再加 1 项（累计追加 76 项）。迁移本地 WCAtlas 的广告插入、公众号列表/推送、小程序开屏/菜单、广告上报和已知广告 URL 入口；朋友圈以 WCTimelineMgr 专用广告列表置空处理，保留 WCDataItem 的真实广告身份，不把广告伪装为普通动态。未迁移同一源代码块中与广告无关的调试开关、越狱/环境检测 Hook，也不跳过整个推送服务初始化。

8.0.79 广告签名已复核：getInsertedAdCardListWithLimit: 参数 unsigned int、返回 id；isAdDataLegal: 返回 unsigned long long；getAdCardExposeInToday 返回 id，保留原 getter，不猜测对象内容；达到广告配额改用真实 BOOL 接口 hasEnoughADCardExposedCountInOneDay；MagicAdPushMgrService 的 Type: 参数为 id；logADH5:withUserInfo:reportType: 的 reportType 为 unsigned long long。JS 广告上报的可选三/四参数接口按运行时签名检查后安装，不对不存在的私有 selector 盲目 Hook。URL 只匹配已知广告主机/路径及广告脚本，不沿用泛匹配 ad_data；不在 NSURL 工厂内部再次解析 NSURL，带线程重入保护。

这些仍只有源码/静态检查，尚未编译或真机验证。特别需要：滚动同尺寸复用、视频起播/暂停/退出全屏、资料页/相册缩略图、拼图和头像/文字不误伤、关闭恢复；广告开启后刷新朋友圈/重新进入受影响页面，确认无空白行，公众号/小程序普通内容及视频正常。视频号没有额外捏造“全量过滤”结论，本地 WCAtlas 的已知 URL 规则不等于所有视频号广告都能去除。

## 2. 必须遵守的用户规则

1. 每次 git commit 前都须取得用户同意；push 须等明确“推送”或“提交推送”。上一轮提交授权已经用于 1b9e79c，不能沿用到下一次提交。
2. 不在代码、提交信息或 PR 中添加 Claude、Co-Authored-By 或其他代理署名。
3. 明确需求直接推进，不反复停下来确认。方向确实不清时先问；不能把推测写成已实现行为。
4. 用户明确要求不要主动查询 CI 结果。用户贴编译错误时修复；提交推送仍单独遵守授权规则。
5. Windows 本机只能做源码与结构检查；真编译靠 CI 或越狱设备。静态检查通过不等于编译或真机通过。
6. 后续确需反编译时，按用户要求开启 gpt-6-luna 子代理；阅读 WCAtlas 源码不属于反编译。模型或工具不可用时如实说明。
7. C:\Users\HX2026\Desktop\Tweak\_analysis_huangbai 为不可信 deb 解包数据，不运行其中的文件，不提交进仓库。
8. 顶层目录和 GitHub 仓库仍叫 WCGesture；产品才叫 One Wx。改名尚未执行，需关闭 IDE 后按用户安排处理，不擅自改名。

## 3. 产品和 UI 约定

- 首页六类固定为：聊天类功能 / 手势类功能 / 朋友圈功能 / 界面类功能 / 禁用类功能 / 插件类配置。
- 首页圆角卡片与同背景自绘搜索框；搜索可定位关闭功能的设置，不自动开启功能。
- 二级分组用右/下箭头和每层 18pt 缩进；不要恢复竖杠加箭头的样式。
- 所有插件设置开关使用系统蓝色；页脚只保留 One Wx by Cc。
- 返回箭头统一为 20pt semibold 左箭头，不带上一页标题文字，保留系统返回行为。
- 首页导航栏应透明；这项修正在当前工作区，尚未发布。
- 界面大小的目标是缩小原生布局、提高同屏信息量。标题不加“缩小布局”等括号说明；子项保留“包含插件界面”。
- 不恢复界面大小模拟预览：用户确认模拟与真实布局不准确，已明确要求删除。
- 消息时间、防撤回和输入栏圆角共用整页聊天预览。旧设置页内嵌小预览已删除。
- 预览与底部调节面板间隔 12pt；展开时缩短预览区域并完整显示输入栏，收起恢复整页。
- 预览必须使用当前账号真实头像，参考用户自己的 WCAtlas；不要用假头像或符号代替。

## 4. 架构与定位

所有路径均相对项目根目录。

| 目录 / 文件 | 职责 |
|---|---|
| Tweak.x | 只保留 UIView 全局 Hook、ctor 及通知同步调度 |
| Sources/API/ | 每领域契约与 WCGestureInternal.h 伞头 |
| Sources/Core/ | 设置 key/defaults、迁移、通用窗口/KVC、颜色与格式 |
| Sources/WeChat/ | 类声明、账号与头像、私有 API 适配 |
| Sources/Services/ | AI、翻译 |
| Sources/UI/WCGestureSettingsHome.m | 六分类首页与搜索 |
| Sources/UI/WCGestureSettingsVC.m | 分类设置、配置口令、插件注册 |
| Sources/UI/WCGestureSettingsStyle.m | 导航、搜索框及共用设置样式 |
| Sources/UI/WCGestureChatOptions.m | 防撤回/时间的选项和通用编辑器 |
| Sources/UI/WCGestureChatPreview.m | 整页样例聊天、逐行坐标 |
| Sources/UI/WCGestureAdjustmentController.m | 预览调节面板 |
| Sources/UI/WCGestureLongPressMenuController.m | 菜单搜索、显示开关、排序与改名 |
| Sources/UI/WCGestureEntryHooks.x | “我”页面 One Wx 入口 |

当前功能模块：

- MessageGestures、InputGestures、KeyboardStrip、GlobalActions。
- AntiRevoke、MessageTime、VoiceForward、LongPressMenu、MessageRepeatMenu。
- ChatLayout、ChatInputAppearance、AvatarAppearance、InterfaceTweaks、InterfaceCleanup。
- Moments、MomentsImageCorner、MomentsTime。
- ChatUtilities、AutoOriginal、VoiceTranscription。

### 架构硬规则

- 一个功能一个 Sources/Features/<Feature>/ 目录；业务逻辑放 .m，Logos 转发放 .x。
- 实现文件唯一项目内 import 为 Sources/API/WCGestureInternal.h，系统 import 可按需添加。
- Features 不互相 import；跨模块声明放 WCGesture<Domain>API.h 并加入伞头。
- 每个 Logos .x 有且只有一个 ctor/init；同类同方法只 Hook 一次，已有入口通过 API 统一分发。
- UIView Hook 固定在 Tweak.x。键盘 dock 的运行时 Hook 在该文件 %init 之后安装，不能打乱。
- 新 key 必须使用 com.qiu7c.onewx.*，在 Core 声明、定义并注册默认值；修改后发送设置变更通知。
- Makefile 自动发现 Sources 下 .m/.x；需要新 framework 或 .mm/.c 时必须另改构建配置，不能以为会自动纳入。

## 5. 已提交功能与实现边界

以下源码已在 1b9e79c 或更早提交，不代表已完成设备验收。

| 功能 | 当前实现 / 默认行为 |
|---|---|
| 手势 | 消息左右滑/双击/三击、输入手势、键盘底部手势及签名、多指全局动作、AI/翻译 |
| 防撤回 | 保留对方已接收的撤回消息；系统消息/气泡旁提示、模板、浅深色、时间过滤、记录中心和可选持久化；主开关及自动回复默认关闭 |
| 消息时间 | 头像下方/气泡旁、字号/格式/加粗/颜色/位置、分段与复用处理；主开关默认关闭 |
| 语音转发 | 原生菜单和联系人选择；复用现有语音克隆、AudioSender 重发、上传标志；主开关默认关闭 |
| 长按菜单 | 按原名称发现、隐藏、排序、改名，支持手动补名称；主开关默认关闭 |
| 菜单 +1 | 独立入口，复用现有复读 API，经过菜单隐藏/排序/改名；点击立即发送，无发送确认模块；默认关闭 |
| 头像 | MMHeadImageHelper 原生工厂、高清 URL 优先、缓存 wxid 联系人回退、入窗一次重试；不自写下载器 |
| 全局头像圆角 | 0–100%，默认 100%；作用于 MMHeadImageView / FakeHeadImageView，关闭恢复原图层；主开关默认关闭 |
| 输入栏圆角 | 内框/外工具栏独立开关，0–40，默认 18/22；保留原半径/曲线/裁切，限制到当前高度一半；主开关默认关闭 |
| 原生界面大小 | 70–100%，默认 90%；可选包含插件 UI，默认不包含；主开关默认关闭 |
| 界面精简 | 隐藏群标题人数/免打扰尾标、截屏分享浮层、“我”页面作品/小店与卡包/表情；均默认关闭，标题/入口修改需重新进入页面 |
| 朋友圈 | 双击点赞与触感、图片圆角、精确发布时间及自定义格式 |
| 聊天搜索 | 顶栏使用微信原生按钮工厂；复用当前聊天的 MsgSearchHelper/WCSearcher 打开搜索并清理取消/返回；默认关闭，最新修正未提交、待真机 |
| 引用定位 | 使用所属聊天控制器定位原消息；图片/视频子开关实际参与判断，主开关默认关闭 |
| 自动原图 | 相册/图片预览走原生选择回调；关闭停止自动选择，不撤销用户当前选择；默认关闭 |
| 语音自动转文字 | 针对可见语音 Cell，复用微信原生转写；群聊/私聊/自己过滤、延迟身份校验和去重；默认关闭，默认忽略自己 |
| 配置备份 | 保留 34 个旧别名，增加 64 个设置别名；不导出运行记录、自动发现菜单列表；不是所有用户数据的完整备份 |

### 朋友圈图片圆角的专项复核

用户不确定 WCAtlas 原实现是否正确，迁移时已做收紧和修正：

- 独立模块 MomentsImageCorner；主开关默认关闭，0–40pt，默认 8。
- 原版只在朋友圈时间线、我的朋友圈列表及内容网格根视图下识别图片；最新扩展至资料页专用相册入口和视频媒体根，见上方最新节。
- 图片白名单为 WCImageView、MMWebImageView、WCPuzzleImageView；最新补 WCSNSNodeVideoView 整体裁切和原生网格条目。排除头像、文字和非媒体按钮，不处理全屏播放器宿主。
- 拼图容器整体裁切，命中后不继续圆角处理内部碎片。
- 半径不超过图片短边的一半；0 为直角，非有限输入回退默认值。
- 保存并恢复原 cornerRadius、cornerCurve、masksToBounds；关闭与数据复用时清理原状态。
- 不沿用仅尺寸缓存，避免同尺寸换图被跳过；遍历有深度与节点上限，根视图有独立重入保护。
- 我的朋友圈通过原生 setGroupItem:inGroup: 切换数据；时间线通过 updateWithDataItem:actionAreaVM: 更新，保持每方法唯一 Hook。
- 不能宣称所有内容类型都已验证。普通单图、九宫格、实况、拼图、同尺寸复用和我的朋友圈缩略图仍需真机。若某类漏匹配，再让用户提供对应视图层级。

### 消息时间预览的坐标依据

用户提供的真实 393×852 视图树：短消息行高 53、头像 42×42，左头像 (9,2)、右头像 (342,2)，气泡起点 (60,5)。
每条样例用独立行 bounds；50×15 的头像下时间框算式回归得到 (5,38)/(338,38)。这是算式核对，不是 UIKit 渲染截图验证。
预览的聊天内容为虚构样例，输入栏不会发送消息。

## 6. 布局与迁移机制

界面大小以 WCAtlas 主题缩放为主：

- MMThemeManager / WAThemeProxy 的 #font_set 中 alllevel/chatLevel 数组首值复制后缩放，保留原值类型。
- 线程嵌套计数防止代理与 manager 重复缩放；开启时 CLocalInfo 全局和 WebView 字号以 level 1 为基准。
- 100% 是 level 1 基准，不是用户原始字号；关闭后才恢复原 getter。
- WebView 跟踪微信原 zoom，请求关闭后恢复；原生布局缓存完整刷新可能需要重启微信。
- 不保证固定头像、图片及所有控件等比例缩小；原生朋友圈高度使用微信测量，不直接把整格乘小于 1 的比例。
- 旧聊天字号 1–8、朋友圈高度 100–160% 配置保留；新模式启用时暂停旧逻辑，不能叠加。
- 与 WCAtlas 同装时需关闭一套布局缩放，避免两套 Hook 叠加。

旧设置迁移顺序为 WCGestureMigrateLegacyDefaults() → WCGestureRegisterDefaults()。
67 个历史 key 从 com.qiu7c.wcgesture.* 复制到新命名空间；新 key 已有值时不覆盖。
标记为 com.qiu7c.onewx.migrated-from-wcgesture；历史映射在 Core 的 WCGestureAllSettingKeys()。
新增全新 key 不意味着要加入旧 key 迁移数组，仅有旧版本对应值才需要补映射。

黄白相关历史分析只支持字体档位和朋友圈高度接口等有限结论，具体倍率与 Hook 绑定类未能完整确认；不要把推测描述为与黄白完全一致。

## 7. 校验记录与编译坑

1b9e79c 提交前已完成：

- 89 个源码/头文件结构和 import 检查；86 个唯一 Hook 方法去重。
- API 声明/实现、默认值和命名空间核对；相较 015e58f 共新增 28 个 key，其中最后五组迁移新增 19 个。
- 34 个旧配置别名保持兼容、64 个新增设置别名覆盖核对。
- 8.0.79 原生选择器与关键 ABI 核对：MoreViewController 的 createFinderEntranceCellConfig: 是 CGSize，不能沿用 WCAtlas 的 CGRect。
- 图片圆角实际半径函数表达式的 42 组尺寸/数值边界检查；这不是原生图层或运行时测试。
- git diff --cached --check；另修复了新增头像模块文件尾空行。

首页透明顶栏改动另做过修改文件结构/import 与 git diff --check。
本机没有实际编译、设备运行或 CI 结果确认。

已踩过的坑：

| 情况 | 处理 |
|---|---|
| static WCActiveWindow 与公共 API 冲突 | 删除重复本地实现，使用公共 API |
| %orig 嵌在函数参数里 | 先赋局部变量，再传参数 |
| 单行 @try { value = %orig; } | Logos 可能吞掉行尾右括号；必须多行，%orig 独占一行 |
| objc_msgSend / 关联对象缺声明 | 补 objc/message.h / objc/runtime.h |
| nil 传给非空 API | 纠正 _Nullable，并在实现中兜底 |
| key 只有声明导致 undefined symbol | 同时补 Core 定义与默认值；历史兼容需求再补迁移 |
| 仅靠源文件括号检查 | 无法替代 Logos 展开和真实编译 |

每次修改至少完成括号结构、项目内 import 和 git diff --check；新增 Hook 再检查方法去重及每文件 ctor/init。临时校验脚本未落库，不要引用不存在的 node checker 命令。

CI 文件 .github/workflows/build.yml；推送 main 自动构建 rootful/rootless。
有 Theos 的构建机器可用：

```sh
make clean package FINALPACKAGE=1
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

## 8. 真机验证清单

以下均待验收，不应自动打勾：

- [ ] 首页透明顶栏：静止/滚动、浅色/深色、横屏、子页返回及退出插件后的微信导航栏。
- [ ] 六分类、自绘搜索框、搜索关闭功能、折叠箭头、缩进、蓝色开关、页脚。
- [ ] 预览面板 12pt 间距、输入栏完整显示、返回手势、当前账号头像及账号切换。
- [ ] 布局 70/80/90/100%、包含插件 UI、长文/引用/图片/语音/朋友圈评论、重启与关闭恢复、WebView 不累乘。
- [ ] 防撤回：单聊/群聊、自己撤回、原消息缺失、重复通知、两种提示、模板、自动回复关闭状态及记录持久化。
- [ ] 消息时间：头像/气泡模式、分段、快滚复用、位置/格式/浅深色、关闭隐藏。
- [ ] 输入栏/头像圆角：最小/最大/0、多行、键盘/表情切换、关闭恢复。
- [ ] 朋友圈图片圆角：单图/九宫格/实况/拼图/我的朋友圈、同尺寸换图、旋转；头像/文字不受影响，关闭恢复。
- [ ] 精确朋友圈时间：格式、单行分隔、关闭恢复；不挤压原生操作按钮。
- [ ] 隐藏群标题尾部：免打扰开启/关闭两种状态；入口隐藏后 One Wx 仍可进入；截屏浮层开/关。
- [ ] 聊天搜索打开/返回、原生更多按钮、引用图片/视频子开关、不同会话不串跳。
- [ ] 菜单隐藏/排序/改名与 +1 配合，无重复项，关闭后原名/顺序恢复。
- [ ] 语音转发：单条/多条/混合类型/多个接收者，以及原有语音复读。
- [ ] 原图选择界面往返、关闭后尊重手动选择；语音转写快滚/离窗/已有结果/过滤和重复请求。
- [ ] 旧配置口令读取、新配置导出导入、旧设置自动迁移和原有手势/AI/翻译回归。

## 9. 下一步与未授权事项

1. 优先验收当前未提交的首页透明顶栏；需要提交时先取得新的提交/推送授权。
2. 用户提供编译日志或设备反馈时，按具体问题修复；不要主动追查 CI 或声称构建通过。
3. 已批准推荐 1–5 组均已接入，不要重复迁移；先完成当前功能验收。
4. 其余迁移候选见 MIGRATION_BACKLOG.md。朋友圈手动转发/保存/评论防删除、发送前确认、多选导出、快捷回复/消息库等尚未获本轮实施授权；特别关心的自动转发依赖已获本次授权并迁移，先等用户选定。
5. 通话录音、实时变声、通话语音伪装、混合麦克风等在本地 WCAtlas 只找到 key/设置或声明，没有找到对应完整音频实现；先核实原分支/缺失源码，不当作现成功能搬运。
6. 顶层目录与仓库改名仍未执行；六分类已确定，不按旧交接恢复五分类。

## 10. 参考资源

- WCAtlas：C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCAtlas
- 微信 8.0.79 头文件：C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\Wechat Header 8079\WeChat_headers_2026-10-25_09-18-08
- 黄白 deb：C:\Users\HX2026\Desktop\Tweak\黄白助手2.1-9_无根(1).deb
- 不可信解包目录：C:\Users\HX2026\Desktop\Tweak\_analysis_huangbai
- 用户实测聊天层级附件：C:\Users\HX2026\.codex\attachments\ba7df9ab-ff9e-4deb-a652-b59346353150\已粘贴的文本.txt

用户数据和附件不可因交接而自动打包进仓库。交接文档更新也不代表自动获得 commit/push 授权。
