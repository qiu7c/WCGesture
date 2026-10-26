# PKC 自动更新微信状态静态取证

分析对象：用户提供的 PKC_0.9-9-Beta2.deb。只读取 DEB/Mach-O 数据，不运行包内程序或脚本。按用户要求由 gpt-6-luna 子代理进行反编译分析。

取证中间件、解包内容及可复现脚本保留在仓库外 `../_analysis_pkc/`，可信 Python 解析依赖位于 `../_analysis_pkc_tools/`；这些不加入项目。主要脚本为 `reproduce_pkc_evidence.py`，报告为 `auto_status_report.md`。以下地址为包内 arm64 dylib 的代码/常量偏移。

## 已确认行为

- 设置入口 `addWXZTSection`：0x52ca8；状态图标选择 `showZTTypeOptions`：0x532cc；自定义图标设置：0x53738；手动测试：0x53ff4。
- `pkcWXZTEnable` 主开关；`pkcWXZTUpHours` 是每日触发小时，0–23，UI 缺省 8，不是循环间隔。
- `pkcWXZTType` 保存原生状态描述名称，通过 `publishIconList.descriptionToIconDict` 获取图标；特殊值 `userdefine` 使用 `pkcZTDiyIconId/pkcZTDiyIconDes`。默认状态“做好事”，ID 1074。自定义图标采用原构造器 initWithIconId:type:showType:actions:flags:，参数为 type=2、showType=0、actions=nil、flags=1（0xafb84–0xafbbc）。
- 文案 `pkcZTTextType`：0 不添加、1 `pkcZTTextDiy`、2 `pkcZTTextAPI`；文本 API 响应直接作为文案，不解析 JSON。
- 背景 `pkcZTImgType`：0 本地、1 `pkcZTImgAPI` 图片、2 `pkcZTVideoAPI` 视频。图片 API 返回图片字节，视频 API 返回视频字节。本地路径引用 wxzt.png/wxzt.mp4；包内没有随附这两个文件。
- 调度是 `MicroMessengerAppDelegate careEnoughForTheLiving` 中的检查（0x1518f4–0x151bc0），到设定小时及以后且当日未触发才执行；先缓存今日 yyyy-MM-dd，然后调用自动更新块（0x1907b8/0x1907dc）。网络或发布失败不自动重试当天。
- 核心 `-[EXXjxe pkcWXZT]`：0xaf9a8；创建并初始化 `TextStatePublishViewController`，设 iconWrap 和 descriptionTextView.textView 后使用原生动作，无需展示编辑页。
- 图片通过 `onGetTextStateImage:source:` 传入，source=1，寄存器证据在 0xb0754–0xb0774。视频通过 `SightDraftItem draftItemWithThumbImg:nil andPath:inMode:`（mode=2），`SightDraft addItem:`，再交给 `handleDidFinishPickingSightWithInfo:`。发布动作使用 `onDone`。
- 视频处理临时静音并安排恢复，原包 `setSystemVolume:` 地址 0xaf7dc；视频回调后等待 3 秒再提交，4 秒恢复音量。

## One Wx 对应实现

独立 `Features/AutoStatus`；复用已有应用回调 Hook，不增加后台轮询。原生类只动态解析，缺失入口报告错误。设置放“插件类配置 → 自动更新微信状态”，不复制原包授权、无关功能或二进制。

保留每日触发前记日期的语义，运行记录按当前微信账号隔离；手动更新可绕过每日时间限制。加入网络错误/超时、关闭/配置变更时取消未提交任务、会话与账号复核、有界忙状态、媒体验证与临时文件清理。静音恢复只处理自己的运行过程，不覆盖期间用户调整后的音量。本地媒体由用户导入，互斥替换图片/视频；配置分享不包含本地文件或触发日期。

## 验证边界

已核对当前微信 8.0.79 头文件中原生状态控制器、图标、图片回调和视频草稿 selector 及参数类型。只做静态检查，没有 iOS 编译或设备验收。

原生回调的实际调度频率、后台获得运行机会、私有实现版本兼容、原生异步上传完成时机、服务端接受结果和视频音量恢复都需要设备验证。调用 onDone 仅表示交给微信处理，不宣称发布成功；本地忙状态超时释放也不是成功回执。
