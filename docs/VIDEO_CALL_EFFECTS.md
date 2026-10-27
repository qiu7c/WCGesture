# 视频通话增强接入记录

日期：2026-10-27。当前为源码接入，未 Theos 编译或真机验证，未提交推送。

## 本轮范围

入口为“聊天类功能 → 视频通话增强”，包含视频美颜、图片贴纸、前摄视频镜像，三个开关默认关闭。通话页显示蓝色“通话调节”按钮；iOS 15 以上默认半屏调节，背景保留真实通话画面；iOS 14 使用系统 page sheet。没有新增独立说明小字、假相机预览或未实现的动态素材开关。

- 美颜使用微信 `MMLiveResUpdateMgr`、`MMLivePathUtil`、`MMLiveBeautyPackage`、`MMWeEffectManager`、`MMLiveBeautyLogic` 和 `MMWeEffectFrame`。资源类型 184、子类型 3，版本取原生 latest-ready 查询，配置文件为 `contents.json`。参数名、范围与当前默认方案的参数项取自微信资源包，不硬编码“磨皮/瘦脸”范围。自有 MemoryMappedKV 命名空间按账号隔离，不修改微信原生美颜存储。
- 图片贴纸限一张静态图片，保留透明通道。系统 PHPicker 选择后用 ImageIO 限制解码尺寸，再进入微信原生图片贴纸编辑器；支持其拖动、缩放与旋转。仅处理本插件创建的编辑器的确认/取消，不拦截其他直播编辑器。确认时按 manipulation view 的三个转换角点生成仿射矩阵，烘焙整张透明画布位图；不是在本地视频上盖 UIImageView。画布最长边限 1536，源图片解码最长边限 2048。这些尺寸限制是 One Wx 自有内存策略。
- 镜像对前摄输出帧处理；相机镜像后再合成贴纸，使图片内文字和编辑位置保持一致。原生 renderer 两处 mirror 参数覆盖及 `XImageViewRenderer.name` 四项过滤沿用已确认规则；标记改成调用作用域的线程局部值，保存并恢复原值。原生 renderer 的最新请求值单独记录，关闭/离开/后台/帧处理故障后重新同步，不永久强制 NO。

文字模板、在线素材目录、PAG 手势动画、妆容和滤镜资源不在本轮已实现范围。未把头文件中存在的 Finder Live 审核或 lower-third API 当作普通通话所需依赖。

## 管线与资源所有权

`AVVideoDevice.captureOutput:didOutputSampleBuffer:fromConnection:` 接入处理，继续交给原生 IMP 完成后续管线。仅跟踪已进入的视频通话控制器，音频通话和关闭状态直接使用原帧。通话控制器在 `viewWillAppear:` 开始绑定，布局只补按钮/模式同步。

美颜资源准备在独立串行队列进行，不在每帧查询磁盘或初始化引擎。帧使用 tryLock；争用、资源未就绪或池分配失败使用原帧。输入先复制到独立像素缓冲，交给原生美颜引擎的 sample 不引用原始输入像素；效果线程内同步渲染。输出对象须为原生帧类型，像素缓冲 retain 后才离开效果线程。

Core Image 使用有错误返回的 CIRenderTask，并等待完成；成功后才创建 sample。输出保留源像素格式和尺寸，复制传播附件及 sample 附件、PTS/DTS/duration；不修改源 sample。原生输出宽高比变化时不猜旋转、不强行拉伸，恢复原生画面。所有本地 CF 对象统一在 finally 清理，借用的 frame.sampleBuffer 在释放 sample 前清空。

挂断/离开会递增通话代次、清除图片、注销当前设备、保存并停止自有引擎、释放像素池和 CIContext。后台暂停处理并保存参数；前台重查账号。准备结果、参数编辑、照片异步加载和贴纸确认分别校验通话代次/账号，防止旧操作影响新通话。UI 只读取不可变参数快照，不等待帧锁或效果线程。

以上失败回退、资源限额、线程作用域和所有权结构是 One Wx 的适配设计，不声称逐分支复原黄白助手。尚未闭合的 capture 内部方向码不直接当作系统 videoOrientation 使用；本轮保留输入方向，由原生帧/引擎处理自身 rotation，不另加猜测旋转。

## 配置

四个键均在 Core 声明/定义/默认注册并加入原配置口令别名，不改旧动作编号或别名：

| 后缀（前缀 `com.qiu7c.onewx.chat.video-call.`） | 默认 | 含义 |
|---|---|---|
| beauty.enabled | NO | 视频美颜 |
| sticker.enabled | NO | 本次通话图片贴纸 |
| mirror.enabled | NO | 前摄视频镜像 |
| beauty.values | 空字典 | One Wx 参数覆盖值，按微信 itemId 保存 |

图片/通话状态/缓冲不持久化、不进入口令。参数覆盖值是插件配置；原生缓存按账号隔离。导入参数会校验类型、有限数值与当前资源包范围后应用。

## 验证状态

已做括号、唯一项目 import、Hook 去重、每个 x 的 ctor/init、API 定义、配置 defaults/share、私有类运行时引用、部分 8.0.79 ABI 和 git diff --check 静态核对。系统附件传播和 Core Image 渲染接口参考 [Apple Core Video](https://developer.apple.com/documentation/corevideo/cvbufferpropagateattachments(_:_:))、[Apple Core Image](https://developer.apple.com/documentation/coreimage/cicontext)。静态检查不代表编译或通话发送验证通过。

设备重点：呼入/呼出；首次资源准备/缺失/下载后重试；前后摄与四个方向；双方画面、贴纸文字方向与落点；原生已有美颜是否叠加；像素格式/分辨率切换；确认/取消/关闭开关；参数导入；后台返回；最小化恢复；挂断重拨和切号。仍需确认当前微信构建的 render 返回类型、GPU 输出支持，以及后续原生处理是否改变已合成的效果。
