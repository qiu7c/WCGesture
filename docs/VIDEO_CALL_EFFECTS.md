# 视频通话增强

更新：2026-10-27。当前有镜像、滑杆和贴纸编辑器重做，未提交；未本地编译或真机验证。不主动查询 CI。

## 当前交互

聊天类功能 → 视频通话增强，视频美颜/图片贴纸/前摄视频镜像三个开关默认关闭。原生接通与实际通话视图负责挂载“通话调节”，相机 stopSession 不视为整场挂断。入口以可见原生麦克风/扬声器/视频/翻转/挂断控件的坐标并集为锚，放在操作区上方右侧；等待/接通重新解析，不再固定右上角。原生控件不可用时退到底部操作区上方。黄白静态审计确认其按原生控件几何布局，但具体邻接控件及精确偏移未还原，本实现只采用相近区域布局。

iOS14+ 通话调节使用自有 UIKit presentation：底部圆角半透明超薄材质模糊、透明导航栏和低不透明度分组背景，文字/滑杆保持不透明，默认约320pt。拖动导航栏调整高度，快速下拉关闭；正常设置页仍保留原背景。美颜列表直接拖动滑杆，最多20Hz预览，松手保存；不弹逐项数字框，拖动中不重建控件。参数名、范围仍取微信原生当前资源方案。

图片由系统 PHPicker 选择、ImageIO 最长边2048解码；随后关闭调节面板，在透明全屏通话画布中单指拖动、双指缩放和旋转。工具条提供取消/居中/完成，图片边框仅用于编辑，不写入最终贴纸。完成时烘焙最长边1536的透明画布；取消恢复原图案。原图与归一化位置仅保留本次通话，可再次点击“移动、缩放贴纸”编辑。编辑期间暂停旧贴纸，避免重影。自有编辑器取代原 Finder Live 编辑器，原生编辑器的确认/取消 Hook 已移除。

## 镜像与方向

旧的私有 rotation 换轴代码未解决用户实测问题，现已删除。镜像改用系统 AVCaptureConnection.videoMirrored，按原生基准值切换左右翻转，不修改旋转角。每个连接记录原 mirroring/automatic 状态，设置在自有 controlQueue 串行合并，关闭/后台/停止设备/挂断恢复；设备/代次/账号隔离旧任务。单独镜像不生成替换帧、不进入 Core Image。原 WCVideoSampleBufferRender 和 XImageViewRenderer 覆盖全部移除，保留微信渲染器行为。

Apple 明确描述该属性为水平镜像，AVCaptureVideoDataOutput 会把效果应用到回调像素：[videoMirrored](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/isvideomirrored?language=objc)。这与读取不明私有 rotation 后手动翻帧不同；微信后续实际处理、本端和对端仍需设备验证。

美颜/贴纸的 Core Image 输出首次使用时，会创建四角颜色不同的2×2缓冲，实际渲染并读回，校准 destination.flipped，使行列顺序与输入保持一致。若两种行向均不匹配，停止当前合成并回退原帧。该运行时自检尚未在本机执行，不能当作编译/设备验证已通过。贴纸画布按显示 aspect-fill 的逆比例映射进入输出帧，避免旧 MAX 比例把编辑结果裁掉。

## 原生美颜与所有权

资源服务 MMLiveResUpdateMgr 在主线程通过当前 MMContext 获取，再保留给串行资源工作；资源 type184/subtype3，版本取 latest-ready，配置 contents.json，使用 MMLivePathUtil/MMLiveBeautyPackage/MMWeEffectManager/MMLiveBeautyLogic/MMWeEffectFrame。MemoryMappedKV 使用 One Wx 命名空间并按账号隔离。接通可重试准备，预检区分资源服务、引擎与资源文件失败。

输入像素先复制再交原生美颜引擎，不写原 sample。帧处理 tryLock，争用/未就绪/分配失败走原帧；原生效果线程同步工作。成功输出保留时间戳和附件，格式/尺寸沿用输入，宽高比不兼容时回退。所有CF对象在finally释放，借用的原生 sample 属性先清空。后台暂停、挂断清理引擎/图片/池/CIContext；异步参数、照片、贴纸确认核对当前代次和账号。

## 配置与验证

沿用 com.qiu7c.onewx.chat.video-call.beauty.enabled / sticker.enabled / mirror.enabled，默认均NO，beauty.values为空字典。无新增持久 key。图片、位置、连接快照不持久化或导出口令。

已做静态括号/import、API定义、自有类实现、Hook去重/单ctor-init、配置与git diff --check；不等于真实编译。设备重点：仅镜像/仅美颜/仅贴纸及组合；前后摄与四方向；双方画面与贴纸文字/位置；运行时四角测试；连续拖动与松手保存；编辑取消/居中/重进；控制面板大小；相机重建、最小化、后台、挂断重拨、切号和原状态恢复。
