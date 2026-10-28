# 已研究功能的接入核对

核对日期：2026-10-28。依据当前 WCGesture 工作区、HANDOVER.md 和仓库外静态报告。这里“已接入”仅指源码存在，不能当作编译或真机验证通过。旧 MIGRATION_BACKLOG.md 包含尚未研究/未选择的 WCAtlas 候选，不全部计入此次反编译接入范围。

## 本轮接入状态（2026-10-28更新）

用户已选择1–5实现、第6尽量。以下是源码接入状态，全部尚待编译和真机验证；证据与适配逐项见 [REVERSE_IMPLEMENTATION_EVIDENCE.md](REVERSE_IMPLEMENTATION_EVIDENCE.md)。

| 项目 | 当前交付 | 保留边界 |
|---|---|---|
| 1 图片编辑增强 | 圆/椭圆、箭头、线宽/颜色、原生widget提交 | 新widget位置/工具条为One Wx坐标适配；原生撤销/导出待设备验证 |
| 2 头像替换 | username映射、本地图片/缓存、原生getter/view重设、恢复与账号隔离 | 不改真实头像；逐屏覆盖待验 |
| 3 虚拟视频 | 导入、capture供帧、循环、方向/镜像、文件音轨及麦克风混音 | 时间/循环/资源归属是明确One Wx策略；不可用时原生输入透传，需两端设备验收 |
| 4 钱包显示扩展 | 零钱通/经营账户独立金额与关闭恢复 | 经营为钱包局部文字分类，未匹配原值；不改交易 |
| 5 记录卡片编辑 | title/desc、原文快照和恢复 | 当前本机展示；不同卡片类型待验 |
| 6 高级贴纸尽量 | 基础文字贴纸，复用既有透明图编辑/帧合成 | 在线模板/字体catalog/PAG桥未闭合，尚未接入 |
| 防封检测研究 | 未加入 | 无可直接接入并证明效果的已确证行为链 |

## 已有源码，避免重复加入

- PKC 自动更新微信状态：AutoStatus。
- WCRefine 清空地区/性别：ProfilePrivacy。
- 外部插件管理注册、我的页面/插件管理/微信设置页入口：SettingsEntry。
- 黄白服务页/收藏页/朋友圈相册 Face ID 上锁：ServicePageLock。
- 黄白视频美颜、普通图片贴纸、左右镜像：VideoCallEffects；高级部分单列为缺口。
- 小微普通文字与时间标签修改：MessageEditing。
- 小微聊天图片/视频本地替换：ChatMediaReplacement。
- 小微当前聊天节点排序：ChatMessageOrdering。
- 转账卡片本机金额显示：MessageEditing；钱包余额显示：WalletDisplay。
- 用户要求的输入框长按现场录音：InputVoice。此交互是按用户要求做的适配，不能宣称小微原版就是现场录音。

## 按用户要求排除

- 收款码/付款码跳转：此前明确要求先删除，未因本次“全部”自行恢复。
- 语音包/长按发送现成语音素材：用户明确不要；现场录音已有独立实现。
- 未被用户要求研究的 WCAtlas 候选，不混入本次待接入清单。

## 取证来源

- 仓库外 `_analysis_huangbai_image_editor_20261027/REPORT.md`、`READINESS.md`。
- 仓库外 `_analysis_wechatx_avatar_20261028/REPORT.md`、`IMPLEMENTATION.md`、`READINESS.md`。
- 仓库外 `_analysis_xiaowei_3312_20261027/REPORT.md`、`finance/REPORT.md`、`chat_edit/DEEP_EDIT.md`、`media_video/VCAM_DEEP.md`。
- 仓库外 `_analysis_huangbai_video_20261026/IMPLEMENTATION_READINESS.md`。
- 仓库外 `_analysis_huangbai_detection_20261027/AUDIT.md`。

本表不是完成声明；未提交/推送，未执行样本，未主动查询CI。新增代码必须区分原版已证实逻辑与 One Wx 自有适配，不把自有设计称作反编译还原。

## 2026-10-28 本轮四项 WeChatX 接入

主页右滑扩展、多选限制、去广告规则表和主页分组均已源码接入；详见 [WECHATX_PORTS.md](WECHATX_PORTS.md)。当前未提交、未编译、未真机验收。此前高级在线贴纸/PAG 的研究限制仍按原记录保留。
