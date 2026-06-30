# App 隐私问卷答案（App Privacy / Data Collection）

> 位置：App Store Connect → App 隐私（App Privacy）→ 编辑。
> 依据：当前版本无账号、无开发者服务器、无第三方广告/统计 SDK；HealthKit 数据只在设备本机读取和分析，开发者不可访问。
> 结论：开发者不收集数据（Data Not Collected）。

## 第一题：你或你的第三方合作伙伴是否从此 App 收集数据？

**选择：否 / Data Not Collected（不收集数据）**

理由：

- App 不要求注册或登录。
- App 不内置第三方广告、分析、社交、崩溃统计或追踪 SDK。
- App 读取的 HealthKit 数据只在用户设备本机用于生成趋势、恢复评分、训练负荷、睡眠详情和 Apple Watch 展示。
- 开发者没有服务器接收这些健康数据，也不能访问用户的 HealthKit 数据。
- 当前版本不写入 HealthKit；体重只作为读取指标用于本机趋势展示。
- App 不使用 HealthKit 数据做广告、营销定向或第三方数据交易。
- `@AppStorage("hasCompletedOnboarding")` 仅在本地保存是否完成首次引导，不上传。

## 若后台强制要求逐类确认，按下表填写

| 数据类别 | 是否收集 | 说明 |
|----------|----------|------|
| 联系信息（姓名/邮箱/电话/地址） | 否 | App 无账号、无联系信息输入 |
| 健康与健身 | 否 | 读取/写入发生在 HealthKit 与本机分析流程中，开发者不收集、不上传、不可访问 |
| 财务信息 | 否 | App 完全免费，无内购、无订阅 |
| 位置 | 否 | 不请求定位 |
| 敏感信息 | 否 | 不上传敏感信息给开发者 |
| 通讯录 | 否 | 不请求通讯录 |
| 用户内容 | 否 | 不上传照片、文本、音频等用户内容 |
| 浏览记录 | 否 | 无网页浏览记录收集 |
| 搜索记录 | 否 | 无搜索功能数据上传 |
| 标识符（用户 ID / 设备 ID） | 否 | 无账号 ID、无广告 ID、无设备标识符上传 |
| 使用数据（产品交互/广告数据） | 否 | 无分析 SDK，交互数据不上传 |
| 诊断（崩溃/性能日志） | 否 | 当前未集成崩溃/性能日志上传 SDK |
| 其它数据 | 否 | 无其它开发者可访问的数据收集 |

## 追踪（App Tracking Transparency）

- 是否用于追踪？**否**。
- 是否需要 ATT 授权弹窗？**否**。
- 是否使用健康数据投放广告或做营销定向？**否**。

## HealthKit 相关说明（给自己核对）

App Privacy 的“收集”重点是开发者或第三方是否从 App 获得数据。当前 App 会读取 HealthKit 数据，但只在本机处理，开发者不接收，因此可填 Data Not Collected。

如果未来加入以下任一能力，必须重新填写问卷并更新隐私政策：

- 账号系统
- 云同步
- 开发者服务器
- 崩溃/性能日志上传
- 产品分析 SDK
- 广告 SDK
- 社交分享或社区
- 远程 AI / 模型 API 分析健康数据

## 工程项待处理

`PrivacyInfo.xcprivacy` 已新增到 `Sources/SharedPrivacy/PrivacyInfo.xcprivacy`：

- `NSPrivacyTracking = false`
- `NSPrivacyTrackingDomains = []`
- `NSPrivacyCollectedDataTypes = []`
- `NSPrivacyAccessedAPITypes` 包含 UserDefaults
- UserDefaults 理由码：`CA92.1`

这与 App Privacy 问卷“Data Not Collected”并不矛盾：隐私清单声明的是访问系统 API 的原因，App Privacy 问卷声明的是开发者是否收集用户数据。
