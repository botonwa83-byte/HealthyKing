import Foundation

/// Centralized user-facing copy that must stay within the FDA "General
/// Wellness" safe-harbor framing: no disease names, no diagnostic claims,
/// no risk-of-disease language. Keeping this in one file makes it easy to
/// audit before every release.
public enum ComplianceCopy {
    public static let onboardingDisclaimer = """
    本应用仅供一般健康与运动趋势参考，不用于诊断、治疗、治愈或预防任何疾病。\
    所有评分和建议均基于你个人历史数据的统计对比，不构成医疗意见。\
    如有持续不适或健康疑虑，请咨询专业医生。
    """

    public static let privacyPolicySummary = """
    你的健康数据仅用于在本机生成趋势分析和评分，不会用于广告、营销或第三方数据交易，\
    也不会被用来定向投放任何广告内容。数据处理完全在你的设备和你的 iCloud 账户内完成。
    """

    public static let healthShareUsageDescription =
        "用于读取心率、HRV、睡眠、血氧等数据，在本机生成你的个人趋势与恢复评分。"
}
