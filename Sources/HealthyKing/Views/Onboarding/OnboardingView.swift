import SwiftUI
import HealthyKingKit

struct OnboardingView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    let onFinished: () -> Void

    @State private var age: Double = 30
    @State private var sex: BiologicalSexInput = .unspecified
    @State private var isConnecting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0x12 / 255, green: 0x4E / 255, blue: 0x8F / 255), Color(red: 0x16 / 255, green: 0xA0 / 255, blue: 0x95 / 255)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)
                                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 8)

                        Text("个人健康趋势教练")
                            .font(.largeTitle.bold())
                        Text("用你自己的历史数据，看懂今天的身体状态")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    Text(ComplianceCopy.onboardingDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .cardStyle()

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "基本信息", systemImage: "person.text.rectangle")
                        Text("仅用于本机计算训练负荷，不会上传")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Stepper(value: $age, in: 13...90) {
                            HStack {
                                Image(systemName: "birthday.cake.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 22)
                                Text("年龄：\(Int(age)) 岁")
                            }
                        }

                        Picker("性别", selection: $sex) {
                            Text("男").tag(BiologicalSexInput.male)
                            Text("女").tag(BiologicalSexInput.female)
                            Text("不透露").tag(BiologicalSexInput.unspecified)
                        }
                        .pickerStyle(.segmented)
                    }
                    .cardStyle()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.tint)
                        Text(ComplianceCopy.privacyPolicySummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .cardStyle()

                    Button {
                        Task { await connect() }
                    } label: {
                        if isConnecting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("连接健康App，开始使用", systemImage: "heart.text.square.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isConnecting)

                    if let error = dataStore.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }

    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        dataStore.age = Int(age)
        dataStore.biologicalSex = sex
        await dataStore.requestAuthorizationAndLoad()
        if dataStore.lastError == nil {
            onFinished()
        }
    }
}
