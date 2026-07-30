import SwiftUI

@main
struct SajdaApp: App {
    @StateObject private var viewModel = PrayerTimesViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            Text(viewModel.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // Keep the menu bar item after reboot without opening the app by hand.
        LaunchAtLogin.enableOnFirstLaunchIfNeeded()
    }
}
