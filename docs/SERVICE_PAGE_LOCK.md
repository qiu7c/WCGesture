# 页面上锁

入口：增强类功能 → 页面上锁，包含三个独立开关，默认均关闭：

| 开关 | “我”页面原生入口 |
|---|---|
| 服务页上锁 | MoreViewController.showWCPayView |
| 收藏页上锁 | MoreViewController.showFavoriteView |
| 朋友圈相册上锁 | MoreViewController.showMyWCView |

开启后每次入口操作使用系统 `LAPolicyDeviceOwnerAuthentication` 验证，优先生物识别，系统可回退设备密码。原生方法在认证成功且当前账号、原页面/窗口、前台状态均仍有效时执行一次。不增加免验证时间，不存密码或生物识别数据，不修改微信钱包锁或支付验证。授权仅属于本次页面和原控制器，服务/收藏/相册之间不共享授权。已进入页面后的后台遮罩、其他深链及其他人的朋友圈相册入口不属于本次已接入范围。

取消、失败、策略不可用、缺少 Face ID 使用说明、离开原页、进入后台、账号改变、开关改变或请求超时，均不执行待处理跳转。连续点击不叠加认证请求。系统认证可能临时令应用非激活，因此只在真正进入后台时取消；成功回调先于激活到达时，等待激活并重新校验来源。授权只包围本次同步原生调用，不缓存给后续点击。

## 与黄白研究的对应关系

静态证据确认黄白替换 `showWCPayView`、读取 `showWCPayViewBool`，并调用 `canEvaluatePolicy:error:` / `evaluatePolicy:localizedReason:reply:`，policy 参数为 2。继续恢复跳转表和 callback 后确认：开关关闭直接原方法；开启后进入认证；两个成功回调分别异步切到主队列调用同一原 IMP 一次，失败回调不调用原 IMP。首次可用性检查失败会再检查一次，后备检查仍失败则清理返回；已解析路径未见共享解锁缓存写入。One Wx 使用项目内独立实现和自己的 key，采用该成功放行主流程，系统策略只检查一次，另加来源/账号/前台校验与超时清理。

黄白的类注册参数尚未独立确证；One Wx 根据本地 8.0.79 头文件在 MoreViewController.showWCPayView 接入。原版具体错误提示、宿主实际点击路由及其他模块是否存在缓存仍未验证，因此不宣称整包逐分支复刻。完整研究和指令证据保存在仓库外的 `_analysis_huangbai_pagelock_20261027/SERVICE_PAGE_LOCK.md`，不打包二进制或反汇编进项目。

系统策略说明：[Apple DeviceOwnerAuthentication](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthentication?language=objc)。系统密码回退属于该策略；这不是“只接受 Face ID”的认证模式。

## 接线与验证

- `Sources/Features/ServicePageLock` 实现与独立 Logos Hook，只有一个 ctor/init；API 经伞头提供。
- 三个 key：`com.qiu7c.onewx.privacy.service-page-lock.enabled`、`com.qiu7c.onewx.privacy.favorites-page-lock.enabled`、`com.qiu7c.onewx.privacy.moments-album-page-lock.enabled`；Core 声明/定义/default 与具名配置口令别名齐全，改变当前页面的锁设置会取消其待处理请求。
- 显式链接系统 LocalAuthentication；微信私有类不参与静态链接。
- 已做静态检查，未在 Windows 上编译或真机验证，不查询 CI。

设备验收：三个开关各自关闭/单独开启/组合开启；各入口成功进入一次，取消/失败/无系统密码不进入；密码回退；连续点击；系统验证临时非激活；后台/切标签/切账号/退出页面后旧回调不跳转；再次进入重新验证；原生钱包锁仍可再次验证；目标微信构建的实际点击路由与三个 hook 是否对应。
