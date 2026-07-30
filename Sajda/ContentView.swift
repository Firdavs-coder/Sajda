import AppKit
import CoreLocation
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PrayerTimesViewModel

    private let panelRadius: CGFloat = 20
    private let ringSize: CGFloat = 78

    var body: some View {
        panelContent
            .frame(width: 320)
            .fixedSize(horizontal: false, vertical: true)
            // Solid dark card fill first so content is always visible, even if
            // glassEffect / host chrome misbehave. Host window is tinted to match.
            .background {
                RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.12))
            }
            .clipShape(RoundedRectangle(cornerRadius: panelRadius, style: .continuous))
            .background(TransparentMenuBarWindow(cornerRadius: panelRadius))
            .preferredColorScheme(.dark)
            .task {
                await viewModel.load()
            }
    }

    private var panelContent: some View {
        Group {
            if let schedule = viewModel.schedule {
                TimelineView(.periodic(from: .now, by: 15)) { timeline in
                    schedulePanel(schedule, now: timeline.date)
                }
            } else if viewModel.isLoading {
                loadingPanel
            } else {
                errorPanel
            }
        }
    }

    // MARK: - Main panel (matches reference popover)

    private func schedulePanel(_ schedule: PrayerSchedule, now: Date) -> some View {
        let nextPrayer = schedule.nextPrayer(after: now)
        let progress = schedule.progress(toward: nextPrayer, at: now)

        return VStack(alignment: .leading, spacing: 0) {
            headerSection(schedule, nextPrayer: nextPrayer, now: now, progress: progress)

            prayerList(schedule, nextPrayer: nextPrayer)
                .padding(.top, 10)

            footerSection(schedule)
                .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Header + circular countdown

    private func headerSection(
        _ schedule: PrayerSchedule,
        nextPrayer: PrayerTime?,
        now: Date,
        progress: Double
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                titleRow(schedule)

                dateBlock(schedule)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            countdownRing(nextPrayer, now: now, progress: progress)
        }
    }

    private func titleRow(_ schedule: PrayerSchedule) -> some View {
        (
            Text("Prayer Times")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            + Text(" | ")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
            + Text(viewModel.locationSubtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))
        )
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dateBlock(_ schedule: PrayerSchedule) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text(schedule.readableDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
    }

    private func countdownRing(_ prayer: PrayerTime?, now: Date, progress: Double) -> some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 5)

            // Progress arc — warm gold like the reference
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.95, green: 0.72, blue: 0.28),
                            Color(red: 1.0, green: 0.82, blue: 0.40),
                            Color(red: 0.95, green: 0.72, blue: 0.28)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: progress)

            VStack(spacing: 1) {
                Text(prayer?.name.rawValue ?? "—")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(prayer?.time ?? "--:--")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(prayer.map { remainingText(until: $0.date, from: now) } ?? "…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(6)
        }
        .frame(width: ringSize, height: ringSize)
    }

    // MARK: Prayer list

    private func prayerList(_ schedule: PrayerSchedule, nextPrayer: PrayerTime?) -> some View {
        VStack(spacing: 2) {
            ForEach(schedule.prayers) { prayer in
                prayerRow(prayer, isHighlighted: prayer.name == nextPrayer?.name)
            }
        }
    }

    private func prayerRow(_ prayer: PrayerTime, isHighlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: prayer.name.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(isHighlighted ? 1 : 0.78))
                .frame(width: 22, alignment: .center)

            Text(prayer.name.rawValue)
                .font(.system(size: 14, weight: isHighlighted ? .semibold : .regular))
                .foregroundStyle(.white.opacity(isHighlighted ? 1 : 0.82))

            Spacer(minLength: 8)

            Text(prayer.time)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(isHighlighted ? 1 : 0.82))
        }
        .padding(.leading, isHighlighted ? 10 : 12)
        .padding(.trailing, 12)
        .frame(height: 36)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.10))
            }
        }
        .overlay(alignment: .leading) {
            if isHighlighted {
                Capsule()
                    .fill(Color(red: 0.45, green: 0.92, blue: 0.55))
                    .frame(width: 3, height: 22)
                    .padding(.leading, 2)
            }
        }
    }

    private func footerSection(_ schedule: PrayerSchedule) -> some View {
        VStack(spacing: 10) {
            Toggle(isOn: launchAtLoginBinding) {
                Text("Open at Login")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Start Sajda automatically so it stays in the menu bar after restart.")

            HStack {
                Text("All times are local")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .help("\(schedule.calculationMethod), \(schedule.timezoneIdentifier)")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { newValue in
                _ = LaunchAtLogin.setEnabled(newValue)
                // Force a view refresh after SMAppService changes.
                viewModel.objectWillChange.send()
            }
        )
    }

    // MARK: Loading / error

    private var loadingPanel: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Getting your location")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var errorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Prayer times unavailable", systemImage: "location.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Text(viewModel.errorMessage ?? "Allow location access and try again.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await viewModel.load(force: true) }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    /// Compact remaining time like "1h 30m" / "12m".
    private func remainingText(until date: Date, from now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}

// MARK: - View model

@MainActor
final class PrayerTimesViewModel: NSObject, ObservableObject {
    @Published var schedule: PrayerSchedule?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var now = Date()
    @Published private var usedApproximateLocation = false

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeoutTask: Task<Void, Never>?
    private var ticker: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        startTicker()
    }

    var menuBarTitle: String {
        guard let nextPrayer = schedule?.nextPrayer(after: now) else {
            return isLoading ? "Sajda" : "Prayer Times"
        }

        return "\(nextPrayer.name.rawValue) \(nextPrayer.time)"
    }

    var locationSubtitle: String {
        if let schedule {
            return usedApproximateLocation ? "\(schedule.locationName) approximate" : schedule.locationName
        }

        if isLoading {
            return "Using current location"
        }

        return "Location needed"
    }

    func load(force: Bool = false) async {
        if isLoading || (!force && schedule != nil) {
            return
        }

        isLoading = true
        errorMessage = nil
        usedApproximateLocation = false

        do {
            let location = try await requestLocation()
            let locationName = await reverseGeocodedName(for: location)
            schedule = try await PrayerTimesService.fetchSchedule(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: locationName
            )
        } catch {
            do {
                let approximateLocation = try await ApproximateLocationService.fetch()
                usedApproximateLocation = true
                schedule = try await PrayerTimesService.fetchSchedule(
                    latitude: approximateLocation.latitude,
                    longitude: approximateLocation.longitude,
                    locationName: approximateLocation.displayName
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
    }

    private func requestLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw PrayerLocationError.servicesDisabled
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                beginLocationRequest(with: continuation)
                locationManager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            return try await withCheckedThrowingContinuation { continuation in
                beginLocationRequest(with: continuation)
                locationManager.requestLocation()
            }
        case .denied, .restricted:
            throw PrayerLocationError.permissionDenied
        @unknown default:
            throw PrayerLocationError.permissionDenied
        }
    }

    private func beginLocationRequest(with continuation: CheckedContinuation<CLLocation, Error>) {
        locationContinuation = continuation
        locationTimeoutTask?.cancel()
        locationTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            await MainActor.run {
                self?.resumeLocationContinuation(with: .failure(PrayerLocationError.locationUnavailable))
            }
        }
    }

    private func reverseGeocodedName(for location: CLLocation) async -> String {
        do {
            guard let placemark = try await geocoder.reverseGeocodeLocation(location).first else {
                return "Current Location"
            }

            let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
            let country = placemark.country

            switch (city, country) {
            case let (city?, country?) where city != country:
                return "\(city), \(country)"
            case let (city?, _):
                return city
            case let (_, country?):
                return country
            default:
                return "Current Location"
            }
        } catch {
            return "Current Location"
        }
    }

    private func resumeLocationContinuation(with result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil

        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension PrayerTimesViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                resumeLocationContinuation(with: .failure(PrayerLocationError.permissionDenied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                resumeLocationContinuation(with: .failure(PrayerLocationError.locationUnavailable))
                return
            }

            resumeLocationContinuation(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            resumeLocationContinuation(with: .failure(error))
        }
    }
}

enum PrayerLocationError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            "Location Services are turned off. Enable them in System Settings to calculate local prayer times."
        case .permissionDenied:
            "Sajda does not have location access. Allow location permission in System Settings and try again."
        case .locationUnavailable:
            "Your current location could not be determined."
        }
    }
}

struct ApproximateLocation {
    let latitude: Double
    let longitude: Double
    let displayName: String
}

enum ApproximateLocationService {
    static func fetch() async throws -> ApproximateLocation {
        let endpoint = URL(string: "https://ipwho.is/")!
        let (data, response) = try await URLSession.shared.data(from: endpoint)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PrayerLocationError.locationUnavailable
        }

        let decoded = try JSONDecoder().decode(IPWhoIsLocationResponse.self, from: data)
        guard decoded.success else {
            throw PrayerLocationError.locationUnavailable
        }

        return ApproximateLocation(
            latitude: decoded.latitude,
            longitude: decoded.longitude,
            displayName: decoded.displayName
        )
    }
}

private struct IPWhoIsLocationResponse: Decodable {
    let success: Bool
    let latitude: Double
    let longitude: Double
    let city: String?
    let region: String?
    let country: String?

    var displayName: String {
        let primary = city ?? region

        switch (primary, country) {
        case let (primary?, country?) where primary != country:
            return "\(primary), \(country)"
        case let (primary?, _):
            return primary
        case let (_, country?):
            return country
        default:
            return "Approximate Location"
        }
    }
}
