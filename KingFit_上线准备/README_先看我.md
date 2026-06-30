# KingFit 上线准备包

生成于 2026-06-29，对应版本 1.0(1)，Bundle ID `com.healthyking.app`。结构参照桌面上的 EngApex / GeogApex 上线准备包，但已按健康类 App 的审核重点重写。

## 文件导览

| 文件 | 用途 |
|------|------|
| `00_上线总检查清单.md` | 从这里开始：阻断项、后台待办、已确认事项 |
| `01_App Store商品信息.md` | 名称、副标题、关键词、描述，可直接复制 |
| `02_隐私政策_PrivacyPolicy.md` | 隐私政策正文草案，适合放到 `docs/privacy.html` |
| `03_用户协议_EULA.md` | 用户协议正文草案，强调非医疗用途 |
| `04_App隐私问卷答案.md` | App Privacy 问卷答案，结论：开发者不收集数据 |
| `05_审核备注_ReviewNotes.md` | 审核备注，中英双语，健康类审核说明已写好 |
| `06_免费模式_无内购配置.md` | 明确本 App 免费、无 IAP、无订阅 |
| `07_年龄分级问卷.md` | 年龄分级逐项答案，健康类软件建议 12+ |
| `08_截图与素材清单.md` | 截图尺寸和建议取景 |
| `09_GitHub_Pages_托管说明.md` | 隐私政策 / 用户协议 / 支持页托管建议 |

## 本应用的审核定位

- KingFit 是一般健康与运动趋势工具，不是医疗器械，不提供诊断、治疗、治愈或疾病预防功能。
- App 读取 HealthKit 中的 HRV、静息心率、呼吸率、血氧、睡眠、VO2 Max、体重、步数、活动能量、锻炼时间、锻炼记录、出生日期和生理性别，用于本机生成个人趋势、恢复评分、训练负荷和睡眠详情。
- 当前版本不写入 HealthKit；体重只作为读取指标展示。
- 所有分析都在设备本机完成；无账号、无开发者服务器、无第三方广告/统计 SDK。
- App 完全免费，无内购、无订阅、无付费墙。
- iPhone App 搭配 watchOS App 和 watchOS Widget/Complication。

## 健康类审核特别注意

1. **隐私政策 URL 必须先上线并可访问**。健康数据权限非常敏感，提交前请先完成 `09` 中的静态页托管。
2. **App Privacy 要和代码一致**。虽然 App 会读取 HealthKit 数据，但这些数据只在本机处理，开发者不可访问，因此问卷可填 Data Not Collected；如果未来加入云同步、账号、日志上传或分析 SDK，必须改问卷。
3. **不要把 HealthKit 数据用于广告或营销定向**。当前版本已移除占位推广入口，不使用健康数据做任何营销定向。
4. **不要写医疗功效承诺**。商品信息、截图文案和审核备注都应使用“趋势参考、恢复建议、训练负荷参考”，避免“诊断、预防、治疗、风险预测”等表述。
5. **年龄分级不建议填 4+**。App Store Connect 的年龄分级问卷里有“医疗/治疗信息”项，本应用虽非医疗软件，但展示健康指标、血氧、心率、训练负荷和恢复建议；建议保守选择 12+。

## 当前工程状态（2026-06-29）

- 版本号：1.0(1)
- Bundle ID：`com.healthyking.app`
- 最低 iOS：17.0
- 最低 watchOS：10.0
- 设备：iPhone App + 独立 watchOS App + watchOS Widget/Complication
- App 内购买：无
- 账号登录：无
- 第三方 SDK：未发现
- HealthKit 权限：读取多项健康/运动数据，不写入
- 已有健康免责声明：`ComplianceCopy.onboardingDisclaimer`
- 已有隐私摘要：`ComplianceCopy.privacyPolicySummary`

## 还需上线前完成

1. 创建并上线 `docs/privacy.html`、`docs/terms.html`、`docs/support.html`，再把 URL 填入 ASC。
2. Archive 前核实 `DEVELOPMENT_TEAM`，当前 `project.yml` 为空。
3. 真机测试 HealthKit 授权、拒绝权限、无数据状态、Apple Watch 独立运行、表盘组件显示。
4. 准备 iPhone 截图和 Apple Watch 截图。
