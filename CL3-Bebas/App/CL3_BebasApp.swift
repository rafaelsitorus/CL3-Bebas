import SwiftUI
import SwiftData

@main
struct CL3_BebasApp: App {

    /// Shared SwiftData container for the app's persisted history.
    ///
    /// `RecordingHistoryModel` is the only `@Model` we own today. We
    /// keep the container at the App level so the same store is
    /// visible to every feature — `HistoryView` reads from it via
    /// `@Query`, and `AppRootView` writes a new row every time the
    /// user finishes a recording.
    ///
    /// If the on-disk store is corrupted / from a future schema
    /// version, we fall back to an in-memory store so the app still
    /// launches instead of crashing on first run.
    let modelContainer: ModelContainer = {
        let schema = Schema([RecordingHistoryModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema mismatch / corrupt store — retry with an
            // in-memory store so the rest of the app keeps working.
            // (We never silently wipe the on-disk store; if a future
            // migration fails the user can still launch and we can
            // surface the failure from the fallback container.)
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
