# 审核备注（App Review Information）

> 位置：App Store Connect → App 版本 → “App 审核信息” → 备注（Notes）。
> 目的：主动解释 HealthKit 权限、非医疗用途、免费模式和 Apple Watch 测试路径，减少健康类 App 的信息不足或隐私疑问。

## 联系人信息（必填）

- 名字 / 姓氏：（填你的真实姓名）
- 电话：（可被联系到的号码）
- 邮箱：botonwa83@gmail.com

## 登录账号

本应用无需注册或登录，无需 demo 账号。

## 审核备注（建议英文+中文，复制到 Notes 框）

```text
KingFit is a free general wellness and fitness trend app for iPhone and Apple Watch. It uses HealthKit data, with the user's permission, to show personal health trends, a recovery score, training-load reference, sleep details, daily activity, and Apple Watch complications. No account or login is required.

PRICING / IAP
- The app is completely free.
- There are no in-app purchases, no subscriptions, no paid features, and no paywall.

HEALTHKIT USAGE
- Read access: HRV, resting heart rate, respiratory rate, oxygen saturation, VO2 Max, body mass, heart rate, step count, active energy, Apple exercise time, sleep analysis, workouts, date of birth, and biological sex.
- Write access: none. The current version does not write HealthKit data.
- Purpose: all HealthKit data is used only on-device to calculate and display personal trends, recovery score, training-load reference, sleep details, today's activity, and Apple Watch views.
- The watch app can request HealthKit authorization independently. The watch complication/widget only displays available data and does not trigger a permission prompt by itself.

PRIVACY
- The app has no developer server, no account system, and no third-party ad/analytics/tracking SDKs.
- Health data is processed on device and is not uploaded to the developer.
- HealthKit data is not used for advertising, marketing targeting, data mining, or third-party data sharing.
- Settings includes a static "Discover my other apps" link to the developer's App Store page. It is not personalized and does not use HealthKit data, activity data, recovery scores, or training-load results for marketing.

MEDICAL / WELLNESS SCOPE
- The app is for general wellness and fitness trend reference only.
- It is not a medical device and is not intended to diagnose, treat, cure, or prevent any disease.
- All scores and suggestions are statistical comparisons against the user's own history and are not medical advice.
- The onboarding and Settings screens include this disclaimer in Chinese.

MAIN TEST PATH
1. Launch the app.
2. Complete onboarding and grant HealthKit read permission.
3. Open the tabs: Overview, Trends, Training Load, and Settings.
4. On Apple Watch, open the watch app to view recovery score and trends; add the complication/widget if needed.
5. If the test device has no HealthKit history, the app will show empty-data or "data accumulating" states.

Thank you for the review.
```

```text
中文版：
KingFit 是一款免费的 iPhone + Apple Watch 一般健康与运动趋势参考 App。用户授权后，App 会读取 HealthKit 数据，在本机展示个人健康趋势、恢复评分、训练负荷参考、睡眠详情、今日活动和表盘组件。无需注册或登录。

价格 / 内购：
- App 完全免费。
- 无内购、无订阅、无付费功能、无付费墙。

其他应用入口：
- 设置页底部有固定的“发现我的其他应用”入口，打开开发者的 App Store 页面。
- 该入口不读取 HealthKit 数据，不根据健康指标、运动记录、恢复评分或训练负荷结果做个性化推荐。

HealthKit 使用：
- 读取：HRV、静息心率、呼吸率、血氧、VO2 Max、体重、心率、步数、活动能量、Apple 锻炼时间、睡眠分析、锻炼记录、出生日期、生理性别。
- 写入：无。当前版本不会向 HealthKit 写入健康数据。
- 目的：所有健康数据仅用于本机计算和展示个人趋势、恢复评分、训练负荷参考、睡眠详情、今日活动和 Apple Watch 页面。
- Watch App 可独立请求 HealthKit 授权；表盘组件/Widget 只展示已有授权下可用的数据，不主动触发权限弹窗。

隐私：
- 无开发者服务器、无账号系统、无第三方广告/统计/追踪 SDK。
- 健康数据仅在设备本机处理，不上传给开发者。
- 不使用 HealthKit 数据进行广告、营销定向、数据挖掘或第三方数据分享。

健康/医疗边界：
- App 仅供一般健康与运动趋势参考。
- App 不是医疗器械，不用于诊断、治疗、治愈或预防任何疾病。
- 所有评分和建议均基于用户个人历史数据的统计对比，不构成医疗意见。
- 首次引导和设置页均已展示中文免责声明。

主要测试路径：
1. 启动 App。
2. 完成首次引导并授权读取 HealthKit。
3. 查看“概览”“趋势”“训练负荷”“设置”四个标签页。
4. 在 Apple Watch 上打开 Watch App 查看恢复评分和趋势；如需可添加表盘组件。
5. 如果审核设备没有 HealthKit 历史数据，App 会显示空数据或“数据积累中”状态。
```

## 常见拒因预防

- **Guideline 5.1.1 / HealthKit 隐私**：确保隐私政策 URL 可访问，并说明健康数据不上传、不用于广告、营销或数据交易。
- **Guideline 5.1.3 / Health & Health Research**：保持一般健康定位，不写诊断、治疗、预防疾病或医疗风险预测。
- **Guideline 2.1 缺信息**：审核备注中主动列出 HealthKit 读取/写入类型、用途和测试路径。
- **Guideline 3.1.1 内购**：本 App 无付费内容，无需创建 IAP；不要在 App 内引导站外支付。
- **无数据状态**：审核设备可能没有 Apple Watch 或 HealthKit 历史数据，App 必须能显示空状态。

## 后台 URL（需先完成 09 的 Pages 启用步骤才能填）

- 支持网址：`https://botonwa83-byte.github.io/KingFit/support.html`
- 隐私政策网址：`https://botonwa83-byte.github.io/KingFit/privacy.html`
- 营销网址（选填）：`https://botonwa83-byte.github.io/KingFit/`
