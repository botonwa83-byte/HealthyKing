import SwiftUI

/// Static, non-targeted cross-promotion to the developer's other apps.
/// Deliberately does not read any HealthKit/app-usage data to decide what
/// to show -- per Apple Guideline 5.1.1, health data may never be used to
/// drive advertising or marketing decisions.
struct CrossPromoCard: View {
    /// Replace with the real App Store URL before release.
    let appStoreURL = URL(string: "https://apps.apple.com/")!

    var body: some View {
        Link(destination: appStoreURL) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("发现更多好用的App")
                        .font(.subheadline.bold())
                    Text("来看看我们的其他作品")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
    }
}
