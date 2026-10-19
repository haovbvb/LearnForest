import SwiftUI

enum ChildTab: Hashable {
    case home
    case learn
    case cards
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: ChildTab = .home
    @State private var showParent = false

    private var navMode: ChildNavMode {
        model.activeProfile?.childNavMode ?? .tabWithHero
    }

    var body: some View {
        Group {
            if navMode == .homeCardsOnly {
                homeOnly
            } else {
                tabShell
            }
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

    /// iPadOS 18 起系统把 TabView 放到顶部。儿童端按 PRD 使用底栏，
    /// 所以这里把 TabView 的尺寸类收成 compact，再把原来的尺寸类交还给页面。
    private var tabShell: some View {
        TabView(selection: $tab) {
            homeStack
                .environment(\.horizontalSizeClass, sizeClass)
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(ChildTab.home)
            NavigationStack {
                LearnView()
            }
            .environment(\.horizontalSizeClass, sizeClass)
            .tabItem { Label("认字", systemImage: "text.book.closed.fill") }
            .tag(ChildTab.learn)
            NavigationStack {
                MyCardsView()
            }
            .environment(\.horizontalSizeClass, sizeClass)
            .tabItem { Label("我的字卡", systemImage: "rectangle.on.rectangle.angled") }
            .tag(ChildTab.cards)
        }
        .environment(\.horizontalSizeClass, .compact)
    }

    private var homeOnly: some View {
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
    }

    private var homeStack: some View {
        NavigationStack {
            HomeView(
                navMode: .tabWithHero,
                onSelectLearnTab: { tab = .learn },
                onSelectCardsTab: { tab = .cards },
                onStartLearning: {
                    model.presentLesson(courseId: model.activeSession?.courseId ?? model.contentPackage?.localPreviewCourses.first?.id)
                },
                onOpenParent: { showParent = true }
            )
        }
    }
}

#Preview {
    RootView()
        .environment(AppModel.preview())
}
