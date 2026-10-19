import SwiftUI

/// 成人验证题。答案只在内存里，不写入 UserDefaults。
/// 购买、外链在 V1.0 不做；若以后加上，要再验一次。
struct ParentGateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var challenge = AdultChallenge.make()
    @State private var entry = ""
    @State private var message: String?
    @State private var passed = false

    var body: some View {
        NavigationStack {
            Group {
                if passed {
                    ParentCenterView()
                } else {
                    gate
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { dismiss() }
                }
            }
        }
    }

    private var gate: some View {
        ZStack {
            ForestPalette.parentBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("请家长来回答")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("这是成人验证，用来保护设置和档案。")
                    .font(.title3)
                    .foregroundStyle(ForestPalette.inkSoft)
                Text(challenge.prompt)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(ForestPalette.ink)
                TextField("答案", text: $entry)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .frame(maxWidth: 280, minHeight: 64)
                    .padding(.horizontal, 12)
                    .background(ForestPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button("进入", action: submit)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 280, minHeight: 64)
                    .background(ForestPalette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                if let message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(ForestPalette.gentleAlert)
                }
            }
            .padding(32)
        }
        .navigationTitle("家长验证")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        let trimmed = entry.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), value == challenge.answer else {
            message = "请家长再算一次"
            entry = ""
            challenge = AdultChallenge.make()
            return
        }
        message = nil
        passed = true
    }
}

struct AdultChallenge: Equatable {
    var prompt: String
    var answer: Int

    static func make() -> AdultChallenge {
        let left = Int.random(in: 13...19)
        let right = Int.random(in: 12...19)
        return AdultChallenge(prompt: "\(left) × \(right) = ？", answer: left * right)
    }
}
