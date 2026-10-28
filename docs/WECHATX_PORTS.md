# WeChatX 四项功能接入记录

2026-10-28，版本仍为 1.0.0。本轮接入主页右滑扩展、突破多选限制、去广告扩展、主页分组。当前是源码接入状态，尚未经过 iOS 编译与真机验收；用户已授权本轮提交推送。

## 设置入口与行为

| 入口 | 行为 |
|---|---|
| 界面类功能 → 主页右滑扩展 | 微信首页会话右滑显示备注、朋友圈、折叠群聊、勿扰、置顶；按会话类型决定按钮。 |
| 聊天类功能 → 突破多选限制 | 消息选择上限 9999，会话选择器上限 999，并开启原生忽略上限判断。 |
| 禁用类功能 → 去除广告 | 沿用原“广告精简”开关和已保存状态，扩展到反编译表中的 421 条候选规则。 |
| 界面类功能 → 主页分组 | 内置/自定义分组、成员选择与排序、即时消息、置顶持续显示、横滑、角标及外观调节。 |

新增的三个功能总开关默认关闭。广告设置 key 保持原值，不覆盖用户此前选择。主页分组首次列表为好友、群聊、其他、即时消息；“全部”可以添加。分组页提供编辑排序、添加、改名、成员设置和删除，并至少保留一个组。长按首页“即时消息”按钮进入待处理会话选择，其它分组长按打开分组管理。

## 证据与实现

样本包 `com.wkk.wechatx_2.4-5_iphoneos-arm64e.deb` SHA-256：
`b57a2137af99854bacc3d99dd96e683c7a02311caba0ac263b141118b6d84be8`。
其中 dylib SHA-256：
`5c64e38cf8c5c63f80d21cb849133921ca00e1d66eea766bd799f1ca0f798d10`。

完整静态报告和汇编保存在仓库外 `C:/Users/HX2026/Desktop/Tweak/_analysis_wechatx_features_20261028`。样本未执行，二进制和研究工具不纳入项目。

### 主页右滑

对应 `WXInitMainSwipeExt` `0x1d55a0`、leading swipe builder `0x1d5ffc` 及五个 handler `0x1d788c..0x1d85e4`。使用 UIKit 的 `UIContextualAction`，关闭 full-swipe 自动执行首项。

- 备注：群与个人分别创建 `ChatRoomRemarkEditViewController` / `NewRemarkViewController`，注入 `chatRoomContact` / `m_contact`。
- 朋友圈：创建 `WCListViewController`，注入 `m_contact`。群、`gh_`、`filehelper`、`weixin` 不显示该按钮。
- 折叠群聊：临时 `ChatRoomInfoViewController`，`setChatBoxStatus:YES`。
- 勿扰：contact 的两个设置方法传原 `isChatStatusNotifyOpen`，临时 info controller 的 `setUpdateNotifyMuted:` 传反相值。
- 置顶：临时 info controller 的 `onTopSession:` 传 `m_bIsTop` 的反相。

后三项加载原生控制器 view 后完成设置，并调用对应消失生命周期；操作留在首页。备注和朋友圈通过导航控制器打开。One Wx 使用已有的联系人查询与 UIViewController 导航 API，不添加样本的全局 `UIView._viewController` 方法。

### 多选

`0x18abe0/0x18ac44` 返回 `0x270f = 9999`；`0x18aca8` 将 setter 参数改为 999；`0x18ad10` 返回 YES。四个方法均按 8079 头文件核对类型。安装器相邻的短视频拍摄时长 Hook 是另一个能力，不并入多选开关。

### 去广告

`0x784688` 的 421 项 descriptor 已逐条转成源代码数据表，并与独立二进制解析结果比较一致。30 类 kind 按 `0x223dcc` 的实际分派选择处理函数，包括：固定返回、改写参数、评论列表过滤、JS 调用/参数净化、Finder 模型拦截、Flutter 插件过滤。

关键实现边界：

- 宿主类/方法存在、own/inherited 规则、返回类型和参数 ABI 在安装入口校验；继承方法沿用原版 kind 13/15/16/19 的限制。Swift 别名解析到同一 class/selector 时只登记一次。
- `NSURL.URLWithString:` 保留一个 Logos Hook，运行时规则表跳过这一对，避免重复安装。
- `adInfo`、`advertisementInfo`、`isAd`、JS 字符串表、URL 标记、字典字段均来自实际调用与静态数组。`this.__wxLibrary` 是脚本豁免前缀。
- 文本归一化覆盖 NSString、NSURL、六个字典键和九个实际 getter 候选；动态 getter 在调用边界要求 object 返回 ABI。
- 启用时先保存整组原 IMP，再修改方法，避免子类捕获到已经替换的父类实现；关闭时恢复本模块保存的实现。
- initializer wrapper 保留 consumed-self / retained-return 约定，依据 [Clang ARC 的参数与返回值规则](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#consumed-parameters)。

421 是候选规则数量，实际安装取决于微信版本中的类、方法及签名。原插件的功能名称不能作为“微信所有位置均已去除广告”的验收结论。

### 主页分组

配置函数 `0x3ab630..0x3acaec`；成员谓词 `0x3b1ff0`；投影/索引映射 `0x3be88c..0x3bfd34`；消息路径 `0x3bdb68`、`0x3be3c0`；角标 `0x3b0e00..0x3b18e8`。

- 组字典为 `id/type/title/members`。内置类型和排除集合按实际字符串保存；原方法 `isWeixinSingleConatct` 保留二进制中的拼写。
- `all` 先行放行；Instant 使用 `I = type==instant`、`P = pending.contains(name)` 的实际 OR/AND 分支。friend/group 分别使用已核实的联系人/群谓词并排除自定义组成员，other 使用 `!S && !F`。
- 显示条目保留原生 section/row。计数、取会话、取行数据、用户名查找均使用相同映射；原生数据重建在原始访问作用域执行，随后使缓存失效并合并刷新。
- Instant 状态按 `uin:<uin>` / `user:<name>` 隔离。消息的会话名选择、服务器/本地 ID 去重和 512 项窗口按真实分支接入。AddLocal 的 flag=1，Async/AddMsg/onNewSync 的 flag=0；阅后模式遵守该区别，当前前台会话按原生视图可见性移出。
- 跨组保留置顶使用微信 `m_bIsTop` 与 `MainSessionMgr.allTopSessions`。One Wx 设置与状态保存在自己的配置域。
- 角标使用 `m_uUnReadCount` / `m_bShowUnReadAsRedDot`；跳过零未读并按名称去重，红点会话不累计到数字。原生模式使用 `MMBadgeView.redDotWithNumber:`、`setValue:` 的 `unsigned long long` 参数。

分组 UI 使用 One Wx 自有的 UIKit 表头容器与设置页：原生首页表头保留在容器内，关闭时恢复；因此沿用系统搜索导航，不移入样本替换 WebMM banner 所需的合成 FTS 返回手势。滑块、下划线、字号、颜色与角标提供等价调节入口；展开状态等原设置页内部状态没有作为产品功能复制。QQ 分组不在本轮范围内。

## 配置与验证

本轮新增 33 个 key；加上此前未提交接入的 15 个，总共新增 48 个。45 个可导出设置、3 个运行时索引不导出（头像索引、虚拟视频索引、Instant 待处理状态）。旧 34 个短别名保留。API 通过伞头引用，功能没有互相 import。

静态检查：212 个源文件的括号/import/单 ctor-init；289 个唯一 Logos selector；8 个 API 领域；421 条广告 descriptor 一致性；运行时广告表与 Logos 无重复安装项；新增 Hook 名称与二进制/8079 头文件交叉核对；`git diff --check`。

这些检查不执行 UIKit，也不构成 iOS 编译成功。设备验收应覆盖首页切组后的点击/删除/置顶、收发与本地消息、账号切换、搜索返回、右滑状态持久化、广告开关切换及相关页面。Windows 当前没有 Theos/iOS SDK，本轮未查询 CI。
