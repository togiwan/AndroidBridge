import SwiftUI

@main
struct AndroidBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AndroidBridgeStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 820, minHeight: 520)
                .task {
                    await store.refreshDevices()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
