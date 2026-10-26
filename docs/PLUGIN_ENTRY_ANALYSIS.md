# 设置入口与资料清空取证摘要

用户提供插件管理_0.1-6(2).deb，包 ID com.25mao.wcplugins；SHA256 87e59e117ad37427c7a71cabd9e508fb3f07e5c43cc5fe655b4bb75ba6bf28ad，arm64，cryptid=0。静态分析未执行包内程序，原包和证据不入项目。完整报告位于 C:/Users/HX2026/Desktop/Tweak/_analysis_plugin_manager/report.md。

## 管理器契约

- WCPluginsMgr sharedInstance 返回单例。
- registerControllerWithTitle:version:controller: 返回 void，三个对象参数。controller 保存后由管理页直接交给 NSClassFromString，再 alloc/init，因此必须传类名 NSString。
- plugins 为模型数组；每次注册新建 WCPluginModel 并 addObject，原版没有去重/注销接口。模型有 title/version/controller/key/isController，没有图标字段。
- 插件管理自己的“插件”导航 cell 插入 MoreViewController.addFunctionSection 原实现之后的第 2 组（从 0 开始）；点击推入 WCPluginsViewController。
- reloadTableData 从单例数组构建管理页列表；控制器型条目普通导航，switch 型条目读写对应 NSUserDefaults。

One Wx 仅维护自身模型；使用运行时类和注册 API 判断可用，提供我的页面/管理器/微信设置三个互斥位置。设置页原理参考 Mieing/WCTestHook 的 NewSettingViewController 生命周期、表管理器、普通 cell 工厂和 reload；参考提交 f64cce997944f44108f97eb8a232b6d6795e6d0c（MIT，见 THIRD_PARTY/WCTestHook-LICENSE.txt），源码没有直接并入项目。

## 资料清空契约

用户上一包 WCRefine 的确认动作：新建 SettingMyProfileViewController → view/fetchData → m_infoLogic.m_usrInfo，失败回退 controller.m_usrInfo → KVC 设置 m_uiSex=0、m_nsCountry/m_nsProvince/m_nsCity为空 → 调用大写 Save。

原包结果文案明确说地区已清空，但性别暂时无法清除；并未等待服务器回执。本包不提供 Save 内部 CGI/HTTP/序列化实现。One Wx 保留真实能力边界和操作确认，并为字段写入失败加入恢复。完整逆向证据位于 C:/Users/HX2026/Desktop/Tweak/_analysis_wcrefine/REPORT.md。

仅静态检查；所有运行结果需要 Theos 编译和设备验证。
