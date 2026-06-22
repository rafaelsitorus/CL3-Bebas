import SwiftUI
import SwiftData

@main
struct CL3_BebasApp: App {

    let modelContainer: ModelContainer = {
        let schema = Schema([RecordingHistoryModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ SwiftData store unavailable, falling back to in-memory: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create SwiftData container: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}
