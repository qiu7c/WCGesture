本次提交交接更新（2026-10-25）：用户已授权提交推送，本文件描述的本轮全部工作统一纳入该提交。下面保留的“未提交”是开发过程记录；接手必须以 HANDOVER.md 顶部说明和实际 git log / git status 判断实时状态。仍未编译或真机验收，仍缺好友资料页朋友圈入口与相册缩略图的实际视图树，不主动查询 CI。

# One Wx 新会话交接文字

更新：2026-10-25。复制以下代码块给新会话。正式状态与细节以 HANDOVER.md 和实际 git status 为准。

```text
你是 One Wx 项目的接手开发者。先完整阅读：
1. C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCGesture\docs\HANDOVER.md
2. C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCGesture\docs\CONVENTIONS.md
3. C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCGesture\README.md

项目目录：C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCGesture
仓库：https://github.com/qiu7c/WCGesture.git，main。
产品 One Wx，包名 com.qiu7c.onewx，版本 1.0.0。
最新已提交并推送：1b9e79c（迁移聊天与朋友圈增强并统一设置界面）。
Windows / PowerShell，无 Theos/clang；构建为 Theos/Logos、arm64+arm64e、iOS14，CI 构建 rootful/rootless。

当前另有用户要求迁移的“自动确认登录”（未提交）：独立 AutoDeviceLogin 模块/API，插件类配置入口，默认关闭；原生确认设备登录，异步复查开关/入窗/按钮/错误/请求身份，每卡片每登录信息最多尝试一次；配置口令新增 1 项。编译和真机验收待完成。

当前未提交的首页透明顶栏修正也继续保留：
- Sources/UI/WCGestureSettingsStyle.m：首页 navigationItem 清除背景色、模糊、底部阴影，覆盖标准/滚动/紧凑外观。
- Sources/UI/WCGestureSettingsHome.m：背景延伸到导航栏下方，再次进入首页时重设透明外观。
- docs/HANDOVER.md 已更新；docs/HANDOVER_PROMPT.md 是已更新但原本未跟踪的交接文字。
此修正只做过静态检查，尚未编译、真机验收或提交推送。不要覆盖或丢弃。

当前已接入（包括刚推送版本）：
- 消息/输入/键盘/全局手势、AI 和翻译。
- WCAtlas 防撤回完整设置与后端、消息时间、整页聊天预览。
- 当前账号原生头像、全局头像圆角、输入框与外工具栏圆角。
- 语音转发、长按菜单隐藏/排序/改名、菜单 +1。
- 隐藏群标题尾部、截屏分享浮层、“我”页面作品/小店与卡包/表情入口。
- 朋友圈图片圆角、精确发布时间；聊天搜索、引用定位、自动原图、可见语音自动转文字。
- 配置口令保留 34 个旧别名，并新增 64 个设置别名。
推荐的 1–5 组已经实施，不要重复迁移。源码接入不等于真机验证通过。

UI 必须保持：
六类为聊天类功能/手势类功能/朋友圈功能/界面类功能/禁用类功能/插件类配置。
首页圆角卡片+同背景自绘搜索；蓝色开关；分组箭头和逐层18pt缩进，禁止竖杠。
页脚只留 One Wx by Cc；返回按钮统一纯左箭头。
预览保留消息时间/防撤回/输入圆角，与调节面板间隔12pt；使用本人头像。
不要恢复界面大小模拟预览；用户认为不准确。界面大小主要目标是缩小布局，保留包含插件界面选项。

朋友圈图片圆角已专门复核：白名单图片、排除头像/文字、拼图整体裁切，半径0–40且不超过短边一半；保存原图层属性，复用及关闭恢复；不按仅尺寸缓存跳过新图片。仍需实况、九宫格、同尺寸复用等设备验证。

必须遵守：
- 每次 commit 前单独取得用户同意，push 等明确“推送/提交推送”；上一轮授权已用完。
- 不加 Claude/Co-Authored-By/代理署名。
- 用户要求不要主动查 CI。用户贴日志时修复，但不能把静态检查当作编译成功。
- 明确任务直接做，不反复停下确认；方向不清才问。
- 一个功能一个 Sources/Features/<Feature>/；实现仅项目内 import Sources/API/WCGestureInternal.h；Features 禁止互相 import。
- API 放 Sources/API 并加入伞头；新增 key 使用 com.qiu7c.onewx.*，Core 同时声明/定义/注册默认值。
- 每个 .x 有且只有一个 ctor/init，同类同方法只 Hook 一次；复用已有 Hook 转发。
- UIView Hook 固定 Tweak.x，键盘 dock 运行时 Hook 必须在 %init 后安装；不要堆积业务代码到 Tweak.x。
- %orig 不嵌套函数参数，也不能写成单行 @try { value = %orig; }；单独占行。
- 8.0.79 createFinderEntranceCellConfig: 参数为 CGSize，不是 CGRect。
- 修改后至少做括号、import、git diff --check，并核对 Hook 去重/API/defaults。
- 后续反编译按用户要求开 gpt-6-luna 子代理；正常 WCAtlas 源码阅读不需要反编译。
- C:\Users\HX2026\Desktop\Tweak\_analysis_huangbai 是不可信解包数据，禁止执行或提交。
- 目录和仓库仍叫 WCGesture；改名未执行，需关闭 IDE 后按用户安排处理。

参考源码：C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\WCAtlas
新版头文件：C:\Users\HX2026\Desktop\Tweak\Action-For-Wechat\Wechat Header 8079\WeChat_headers_2026-10-25_09-18-08
后续候选见 docs/MIGRATION_BACKLOG.md，未经用户选择不要直接实施下一批。
接手先核对 git status，保护未提交修正；简短说明当前状态后直接推进明确任务，无须再等一次开始确认。
```

本次用户补充 UI 要求：设置文字常规字重，不额外加粗；删除独立说明小字；没有子选项直接开关，不显示展开箭头。有实际子选项才折叠。上述清理已写入工作区，未提交，仍需真机验收。自动确认登录的操作反馈提示保留。
全部设置说明清理已继续覆盖：37 处设置弹窗说明、3 处页脚说明及模板/格式编辑器帮助文字已删除；参数范围用占位文字，设置值、记录数据及错误/操作结果保留。未编译、未真机验证、未提交推送。

聊天搜索最新纠正（用户反馈蓝色大图标和不可搜索后，未提交）：旧 onSearchButton: 简化迁移已替换为 WCAtlas 原生按钮工厂及当前聊天 MsgSearchHelper/WCSearcher 打开/关闭流程。按钮 labelColor，备用图标 18pt；取消、侧滑、返回清理与交互返回恢复，延期清理防止误伤重开。8.0.79 initMsgSearchHelper: 为 int；取消接 MsgSearchHelper wcsDidDismissSearch:。仍需编译与设备验证，不能宣称已修复实测。

本次用户已授权并接入朋友圈特别关心、朋友圈互动通知、后台保活全套源码，主开关默认关闭。特别关心含好友选择/原生头像、30–3600 秒检测、按账号基线与去重、转发文字/图片/视频/实况分支至自己或文件助手；互动含详情、原生消息监听及发现页预热；前台横幅/后台通知与点击进朋友圈；保活含后台任务和静音音频续时、关闭/前台恢复。新增 10 项配置别名（累计追加 75，旧 34 不变）及 2 个不导出的运行状态 key；框架加 AVFoundation/UserNotifications/CoreMedia。见 HANDOVER.md 新增节。媒体下载 ABI/路径已按 8.0.79 适配，异步转发/预热有开关、账号和代次检查。仅静态核对，未编译、未查 CI、未真机验收、未提交推送。

最新用户反馈：朋友圈圆角视频不圆，资料页朋友圈入口/相册缩略图不圆；数值不变但滚动/播放后外观变。附件已证明视频根为 WCSNSNodeVideoView，本次加整体裁切，媒体目标唯一 owner、原始图层基线保留、关闭隐式动画、布局结束后合并复核。资料页 getAlbumView/原生网格/相册初始化入口已接，但两处缩略图仍需实际视图树确认。用户另外已授权去广告：AdBlocker 独立模块，禁用类功能“广告精简”默认关，移植广告相关入口并按 8.0.79 纠正 ABI；不迁移无关调试/环境检测、不跳过服务初始化，URL 规则收紧且防重入。配置累计追加 76 项。全部未提交、未编译或真机验收；旧未提交改动继续保留。
