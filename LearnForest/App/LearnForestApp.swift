import SwiftUI

// LearnForest（学习森林）家族工程。
// 本目标是「识字森林」中文识字，不是英语森林 / Word Forest。
// 英语线以后复用设计系统和本地档案，使用自己的内容包。

@main
struct LearnForestApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(ForestPalette.leaf)
        }
    }
}
