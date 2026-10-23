import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var showParent = false

    var body: some View {
        NavigationStack {
            HomeView(
                navMode: .homeCardsOnly,
                onSelectLearnTab: {},
                onSelectCardsTab: {},
                onStartLearning: {
                    model.presentLesson(courseId: model.activeSession?.courseId ?? model.contentPackage?.localPreviewCourses.first?.id)
                },
                onOpenParent: { showParent = true }
            )
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { model.lessonVisible },
                set: { if !$0 { model.dismissLesson() } }
            )
        ) {
            CoursePrepView(courseId: model.lessonCourseId ?? "")
                .environment(model)
        }
        .sheet(isPresented: $showParent, onDismiss: { model.reload() }) {
            ParentGateView()
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            // 回到后台后，家长验证作废。答案只留在内存里。
            if phase == .background {
                showParent = false
            }
        }
        .alert(
            "没有完成",
            isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.actionError = nil } }
            )
        ) {
            Button("好") { model.actionError = nil }
        } message: {
            Text(model.actionError ?? "")
        }
    }
}

#Preview {
    RootView()
        .environment(AppModel.preview())
}
