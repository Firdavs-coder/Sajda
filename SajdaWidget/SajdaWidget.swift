import SwiftUI
import WidgetKit

struct SajdaWidgetEntry: TimelineEntry {
    let date: Date
    let schedule: PrayerSchedule?
    let errorMessage: String?
}

struct SajdaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SajdaWidgetEntry {
        SajdaWidgetEntry(date: .now, schedule: .sample, errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SajdaWidgetEntry) -> Void) {
        completion(SajdaWidgetEntry(date: .now, schedule: .sample, errorMessage: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SajdaWidgetEntry>) -> Void) {
        Task {
            do {
                let schedule = try await PrayerTimesService.fetchSchedule()
                let entry = SajdaWidgetEntry(date: .now, schedule: schedule, errorMessage: nil)
                let nextRefresh = schedule.nextPrayer()?.date ?? Date(timeIntervalSinceNow: 60 * 60)
                let refreshDate = min(nextRefresh.addingTimeInterval(60), Date(timeIntervalSinceNow: 60 * 60))
                completion(Timeline(entries: [entry], policy: .after(refreshDate)))
            } catch {
                let entry = SajdaWidgetEntry(date: .now, schedule: nil, errorMessage: error.localizedDescription)
                completion(Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 15 * 60))))
            }
        }
    }
}

struct SajdaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SajdaWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.10),
                    Color(red: 0.04, green: 0.22, blue: 0.20),
                    Color(red: 0.24, green: 0.18, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sajda")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.86))

            Spacer(minLength: 0)

            if let nextPrayer {
                Image(systemName: nextPrayer.name.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.teal)
                Text(nextPrayer.name.rawValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(nextPrayer.time)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(nextPrayer.date, style: .relative)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            } else {
                unavailableView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sajda")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
                Text(entry.schedule?.locationName ?? "London")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))

                Spacer(minLength: 0)

                if let nextPrayer {
                    Text(nextPrayer.name.rawValue)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(nextPrayer.time)
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(nextPrayer.date, style: .relative)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                } else {
                    unavailableView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            prayerColumn(limit: 4)
                .frame(width: 126)
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sajda")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(entry.schedule?.readableDate ?? "London prayer times")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                if let nextPrayer {
                    Image(systemName: nextPrayer.name.symbolName)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.teal)
                }
            }

            if let nextPrayer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                    HStack(alignment: .firstTextBaseline) {
                        Text(nextPrayer.name.rawValue)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                        Spacer()
                        Text(nextPrayer.time)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    Text(nextPrayer.date, style: .relative)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else {
                unavailableView
            }

            prayerColumn(limit: 6)
        }
    }

    private var nextPrayer: PrayerTime? {
        entry.schedule?.nextPrayer(after: entry.date)
    }

    private func prayerColumn(limit: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(Array((entry.schedule?.prayers ?? PrayerSchedule.sample.prayers).prefix(limit))) { prayer in
                HStack(spacing: 8) {
                    Image(systemName: prayer.name.symbolName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.teal)
                        .frame(width: 16)
                    Text(prayer.name.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(prayer.time)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(height: 20)
            }
        }
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.teal)
            Text("Unavailable")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(entry.errorMessage ?? "Refresh later")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)
        }
    }
}

struct SajdaWidget: Widget {
    let kind = "SajdaPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SajdaTimelineProvider()) { entry in
            SajdaWidgetView(entry: entry)
        }
        .configurationDisplayName("Sajda")
        .description("See London prayer times and the next prayer.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct SajdaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SajdaWidget()
    }
}

