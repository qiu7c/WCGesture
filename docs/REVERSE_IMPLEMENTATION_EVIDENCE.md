# 2026-10-28 接入依据与适配边界

用户授权实现清单1–5，第6项尽量实现，并要求不凭猜测写原插件逻辑。本次已写入功能代码、API、Hook、设置、默认值及配置分享接线。版本仍为1.0.0；没有本轮提交推送授权。当前只做静态验证，不声称编译或设备运行成功。

“原版证据”是已核对的类、选择器、参数或算法；“One Wx 适配”是本项目明确设计的实现，不冒称从原二进制逐句还原。样本均未执行或安装，解包材料、第三方二进制及分析脚本留在仓库外。

## 1. 原生图片编辑：圆/椭圆与箭头

入口：聊天类功能 → 图片编辑增强。默认关闭，线宽1–16（One Wx默认4）、两种颜色独立设置。

代码：`Sources/Features/ImageAnnotation/`、`Sources/API/WCGestureImageAnnotationAPI.h`。

原版证据：黄白报告 `_analysis_huangbai_image_editor_20261027/REPORT.md`、`IMPLEMENTATION_READY.md`、`PLACEMENT_CONTRACT.md`。

- 安装器 `HBInstallImageAnnotationHooksIfNeeded 0x3608b0` 以 layout/reload/window、原生工具切换和gestureRecognizerShouldBegin覆盖新旧两套编辑器；实际类为 WCEditImageLayoutView、EditImageIntialView、WCEditImageScrollView、EditImageScrollView、EditImageEmotionTool。代码保留唯一Hook和原方法转发。
- 模式2为椭圆、1为箭头；几何 helper `0x6a576c`：头长 `H=min(.55*distance,max(3*lineWidth,18))`，两翼为 `E-H*u ± .55*H*perp(u)`。源反汇编的FMSUB语义已按 Arm 手册复核，更正早期推导的符号错误，没有采用错误端点。权威语义参考：[Arm armasm Reference Guide](https://documentation-service.arm.com/static/5f3fa899428f7a6b3328fd44)。
- 透明UIImage由 UIGraphicsImageRenderer 栅格化路径；0x6a4bd4的留边为四倍线宽；0x6a427c明确调用 `[state.editor didSelectEmoticonWithWrap:nil decodedImage:image]`。结果走原生组件插入，保留原生导出链，没有另写一个只盖屏幕的最终结果。
- 原生 `_drawViewWidgetArray` 与 `EditImageModView._czUIView` 已由样本字节解码和8079/8080头文件交叉确认。原版capture/restore保存center、transform、_viewScale、_widgetScale。

One Wx适配：原版新widget最终lookup顺序、首次placement分支和toolbar的精确frame没有彻底恢复。因此代码对数组做插入前后唯一对象差集，再按已确认字段unwrap及类型检查；利用公开UIView坐标/仿射变换，把新组件放到拖画位置，不编造私有scale公式。保留原生scale当前值，后续只保存/恢复已读取的placement。工具条放在原生底部栏上方，原生pen不可见时不在裁剪专用页面新增工具。renderer单边最多2048px/逻辑范围8192pt，是One Wx资源上限。配置线宽默认值不是声称原版默认值。

待设备验证：两套编辑器、长图/旋转/缩放后标注位置，原生组件再次缩放是否跳动，原生撤销/重做/保存/发送是否收录标注；静态证据只能确认提交到组件链，不能保证宿主的全部后续行为。

## 2. 自定义头像替换

入口：增强类功能 → 替换头像 → 设置替换头像。列表可搜索联系人/群聊，包含当前账号与已有替换记录；操作为修改/恢复。

代码：`Sources/Features/CustomAvatar/`、`Sources/UI/WCGestureCustomAvatarController.m`。MMHeadImageView.layoutSubviews/didMoveToWindow复用既有AvatarAppearance Hook，不叠加同方法Hook。

原版证据：WeChatX `_analysis_wechatx_avatar_20261028/PORT_SPEC.md`、`REPORT.md`、`IMPLEMENTATION.md`。

- `WXInitCustomAvatar 0x4c381c` 安装五个MMHeadImageMgr getter与MMHeadImageView更新方法。实际username取自原生nsUsrName；五个getter签名，尤其带BOOL* out参数及两种getRoundImage参数顺序已独立核对。
- 命中替换图时 `retHeadImgIsExistedLocal` 置YES；未命中转原IMP，保留原scene/category等参数。
- 保存规格：640×640px JPEG、quality=0.92；文件名按UTF16白名单编码，其他单元为`_%04x`。查图按username+size+radius+scale缓存，异步回填核对版本。

One Wx适配：文件存 `Documents/OneWxCustomAvatars/<account>.account/<username>.jpg`，账号隔离，使用本项目独立索引。系统选图及联系人管理UI为One Wx界面，不伪造原版尚未确认的删除按钮选择器。通过UIKit定向绘制完成中心裁剪，修复样本把point rect直接用于CGImage像素裁剪的风险。只替换图片，不放大原生view/frame或改contentMode；0尺寸view等待布局。头像圆角由已有全局圆角控制器与原生bRoundedCorner/conerSize共同决定。源图/变体缓存有内存界限，缺失文件负缓存避免布局反复读盘；图片像素单边最多2048。epoch、每用户版本和账号共同拦截陈旧回填，关闭/移除时恢复所持原图并请求原生更新。

这是本机显示替换，不上传头像，也不修改微信联系人数据库或微信原头像文件。saved-users索引与图文件不是跨设备配置，索引不进配置口令。仍需逐页面验证聊天、资料页、会话列表、朋友圈及群头像异步更新和切号。

## 3. 虚拟视频通话与音轨

入口：聊天类功能 → 视频通话增强 → 虚拟视频。支持导入本地视频、源视频0/90/180/270度方向、源视频左右翻转、使用文件音轨、混入麦克风、移除视频。开关默认关闭；文件音轨/混音也默认关闭。

代码：`Sources/Features/VirtualVideo/`、既有VideoCallEffects capture/lifecycle Hook、VideoCallSettingsController。

原版证据：小微 `media_video/HOOK_CAPTURE_SPEC.md`、`PORT_READY.md`、`VCAM_DEEP.md`。

- 原版以AVAssetReader读取文件，经真实capture delegate的 `captureOutput:didOutputSampleBuffer:fromConnection:` 替换sample，再调用原delegate；原文件音轨按capture ASBD配置PCM输出；替换不可用时转发原sample。
- 原版独立PCM helper `0x55e88` 的int16算法为`.75*file + .75*mic`并限幅，但未证明它与所有原声分支的实际连线；代码不声称该连线已还原。

One Wx适配：复用现有AVVideoDevice回调，原方法只转发一次；其余音频delegate由真实AVCaptureAudioDataOutput setter注册，检查ABI并保留各class自己的原IMP。AVVideoDevice不另装第二个运行时Hook，super调用有重入深度保护。

使用已解码的输入文件帧与track.preferredTransform，适配原生sample尺寸和像素格式；不抄未证实的“固定90度”。Core Image复用既有颜色方向校准，再把文件变换与用户方向分别处理；源视频翻转与公共capture connection的isVideoMirrored作异或，避免把采集层镜像丢失。方向最终仍需实机两端验证。

时间轴采用capture PTS相对首个视频PTS再对文件duration取模，时间回跳/循环/reader失败时显式重建reader。无效/过早的音频PTS不能重置视频。文件音轨按同一时间轴读入，重采样到支持的capture PCM描述；目前限定小端交错单/双声道signed-int16或float32，其他格式保留原sample。PCM混音为明确的One Wx开关，int16沿用已证实的0.75系数并限幅，float32是同原则的本项目扩展。拒绝无限陈旧帧；锁竞争、格式不支持、素材未就绪或解码失败时保留原生采集输入，这是可触发真实摄像头/麦克风透传的回退，不保证无间隙伪装。

每次返回的替换sample归调用方所有，在原delegate调用结束的finally统一释放；reader缓存单独持有并在重建/停止释放。挂断、设备停止、切后台、关闭、换素材都清reader、计时和cached sample，避免下一次通话复用旧帧。导入先复制到本项目目录并探测首个视频帧，再按账号发布索引；换账号/更晚导入使旧导入失效；原输入文件不覆盖。素材索引不进配置口令。

这些循环/同步/资源策略是明确的One Wx实现，不称原版已完整还原。待验：对端看到的方向、首帧/循环/切镜头、不同capture队列/PTS、文件音轨及麦克风增益/同步，后台/挂断立即重拨、硬件解码与内存/FPS。

## 4. 零钱通与经营账户本机金额

入口：增强类功能 → 钱包金额本机显示。保留钱包余额，新增零钱通/经营账户独立金额，0表示该类不替换。

依据：小微 `finance/FINANCE_PORT_SPEC.md`。Hook包括 WCPayWalletViewController.updateBalanceNumber/updateLqtNumber、LQT/Balance detail.viewWillAppear，以及TimeoutNumber.updateNumber/defaultNumber/updateNumberInternal。数字仍由原生renderer显示；捕获真实值与刷新值分开，嵌套调用计数避免把假值再次记为原值。

余额/lqt以核实的balanceNumber/lqtNumber/timeoutNumber字段匹配；余额详情按原生标题、balanceTitleLabel分类。样本经营账户实际为附近“经营/商户”标签分类，没有已证实的专用class/字段。One Wx保持文字分类，但收紧到已知钱包上下文和局部经营账户/商户余额标签组，未匹配就用原值；不编造merchantBalance属性。更换UI文案可能不能覆盖，应以实际视图树补证据。

不修改钱包模型、支付请求或服务器金额。关闭/金额0按所记录的原生更新值恢复；需验主界面/详情页、滚动数字和文字宽度、变更配置及关闭恢复。

## 5. 合并聊天记录卡片标题/描述

入口：聊天类功能 → 本地聊天编辑 → 记录卡片修改。长按卡片“修改”，再选标题/描述；“恢复”只还原本插件仍拥有的字段。

依据：小微 `chat_edit/DEEP_EDIT.md` 中0x9def0/0x9e060。实际字段为 `viewModel.messageWrap.m_extendInfoWithMsgType.m_oRecordItem.title/desc`，完成后调用updateLayouts。实现复用MessageEditing记录、消息身份校验和既有BaseMessageCellView菜单Hook，不新增重复菜单Hook。

One Wx增加原文快照、账号/会话/消息身份校验、连续修改与关闭/离页恢复。card只更新模型布局，不清空可能影响recordItem的文字缓存；此前普通文字恢复修正保留。未调用DB修改/发送接口，属于当前本机展示修改。待验卡片不同记录类型、复用、长标题/描述和恢复。

## 6. 贴纸扩展的实际交付范围

视频通话增强新增“文字贴纸”，复用已有可拖动/缩放/旋转的透明编辑器和帧合成路径；与本地图片共享当前贴纸槽。取消编辑保留原贴纸，确认才替换当前贴纸。

依据：黄白贴纸确认路径把透明整画布UIImage交给通话帧合成器。One Wx基础文字由公开UIKit绘制为透明图，再复用这个输入契约；字体/描边/限长是One Wx设计，不宣称原版文字模板渲染器已还原。

高级审查见小微研究目录 `media_video/ADVANCED_PORT_SPEC.md`：虽已证实MMFinderLiveTextStickerItem/createDefault与native editor类，在线catalog、远端字体/模板资源、PAG动画到通话编辑器/合成器的桥仍未闭合。本次不新增失效的在线模板或动画开关，不把PAG单帧截图称动画。用户要求“尽量实现”的本次范围为可用的基础文字贴纸，高级部分仍保留缺口。

## 校验记录

- 临时静态脚本 `C:/Users/HX2026/Desktop/Tweak/_analysis_onewx_ports_20261028/check_port_integration.py`：15个新key声明/定义/default、13个设置分享项、2个运行索引排除；旧34短别名保留；5个API领域声明/实现/伞头接线核对；多property声明检查；从实际C表达式提取的箭头5000组方向/长度/对称/界限验证。
- 既有集成脚本：204个源码/头文件括号和import检查、292个唯一Logos方法、单ctor/init与API/default/share检查。运行时音频delegate安装另外按class去重并检查已有AVVideoDevice复用，未以Logos计数冒充运行时证明。
- `git diff --check`通过；没有把静态结果称为iOS编译成功。
- Windows无本地Theos/iOS SDK；未本地编译、未设备运行、不主动查CI；未提交推送。新增功能默认关闭。需要实际构建与上述设备场景验收后才能确认效果。
