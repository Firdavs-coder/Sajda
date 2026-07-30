import Foundation

struct PrayerSchedule: Equatable {
    let readableDate: String
    let hijriDate: String
    let locationName: String
    let calculationMethod: String
    let timezoneIdentifier: String
    let prayers: [PrayerTime]

    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    func nextPrayer(after date: Date = .now) -> PrayerTime? {
        prayers.first { $0.date > date } ?? prayers.first.map { firstPrayer in
            var tomorrow = firstPrayer
            tomorrow.date = Calendar(identifier: .gregorian)
                .date(byAdding: .day, value: 1, to: firstPrayer.date) ?? firstPrayer.date
            return tomorrow
        }
    }

    /// Prayer that most recently started at or before `date` (wraps to previous day).
    func previousPrayer(before date: Date = .now) -> PrayerTime? {
        if let previous = prayers.last(where: { $0.date <= date }) {
            return previous
        }

        // Before Fajr: previous period starts at yesterday's Isha.
        guard let last = prayers.last else { return nil }
        var yesterday = last
        yesterday.date = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -1, to: last.date) ?? last.date
        return yesterday
    }

    /// 0…1 progress from the previous prayer toward the next one.
    func progress(toward next: PrayerTime?, at date: Date = .now) -> Double {
        guard let next else { return 0 }
        guard let previous = previousPrayer(before: date) else { return 0 }

        let total = next.date.timeIntervalSince(previous.date)
        guard total > 0 else { return 0 }

        let elapsed = date.timeIntervalSince(previous.date)
        return min(1, max(0, elapsed / total))
    }

    func withLocationName(_ locationName: String) -> PrayerSchedule {
        PrayerSchedule(
            readableDate: readableDate,
            hijriDate: hijriDate,
            locationName: locationName,
            calculationMethod: calculationMethod,
            timezoneIdentifier: timezoneIdentifier,
            prayers: prayers
        )
    }
}

struct PrayerTime: Identifiable, Equatable {
    let name: PrayerName
    let time: String
    var date: Date

    var id: String { name.rawValue }
}

enum PrayerName: String, CaseIterable, Equatable {
    case fajr = "Fajr"
    case sunrise = "Sunrise"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    var symbolName: String {
        switch self {
        case .fajr:
            "sunrise.fill"
        case .sunrise:
            "sun.max"
        case .dhuhr:
            "sun.max.fill"
        case .asr:
            "cloud.sun.fill"
        case .maghrib:
            "sunset.fill"
        case .isha:
            "moon.stars.fill"
        }
    }
}

enum PrayerTimesService {
    private static let defaultLocationName = "London"
    private static let defaultLatitude = 51.5074
    private static let defaultLongitude = -0.1278

    static func fetchSchedule() async throws -> PrayerSchedule {
        try await fetchSchedule(
            latitude: defaultLatitude,
            longitude: defaultLongitude,
            locationName: defaultLocationName
        )
    }

    static func fetchSchedule(
        latitude: Double,
        longitude: Double,
        locationName: String
    ) async throws -> PrayerSchedule {
        var components = URLComponents(string: "https://api.aladhan.com/v1/timings")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "method", value: "2")
        ]

        guard let endpoint = components.url else {
            throw PrayerTimesError.badResponse
        }

        let (data, response) = try await URLSession.shared.data(from: endpoint)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PrayerTimesError.badResponse
        }

        let decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
        return try decoded.schedule(locationName: locationName)
    }
}

enum PrayerTimesError: LocalizedError {
    case badResponse
    case missingDate

    var errorDescription: String? {
        switch self {
        case .badResponse:
            "Prayer times could not be loaded."
        case .missingDate:
            "Prayer time data was incomplete."
        }
    }
}

extension PrayerSchedule {
    static let sample = PrayerSchedule(
        readableDate: "Wed, 29 Jul 2026",
        hijriDate: "15 Safar 1448",
        locationName: "London",
        calculationMethod: "Islamic Society of North America (ISNA)",
        timezoneIdentifier: "Europe/London",
        prayers: [
            PrayerTime(name: .fajr, time: "03:13", date: Date(timeIntervalSinceNow: -18_000)),
            PrayerTime(name: .sunrise, time: "05:20", date: Date(timeIntervalSinceNow: -10_000)),
            PrayerTime(name: .dhuhr, time: "13:07", date: Date(timeIntervalSinceNow: 3_600)),
            PrayerTime(name: .asr, time: "17:19", date: Date(timeIntervalSinceNow: 18_000)),
            PrayerTime(name: .maghrib, time: "20:54", date: Date(timeIntervalSinceNow: 31_000)),
            PrayerTime(name: .isha, time: "23:00", date: Date(timeIntervalSinceNow: 39_000))
        ]
    )
}

private struct AladhanResponse: Decodable {
    let data: AladhanData

    func schedule(locationName: String) throws -> PrayerSchedule {
        try data.schedule(locationName: locationName)
    }
}

private struct AladhanData: Decodable {
    let timings: [String: String]
    let date: AladhanDate
    let meta: AladhanMeta

    func schedule(locationName: String) throws -> PrayerSchedule {
        let timezone = TimeZone(identifier: meta.timezone) ?? .current
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timezone
        parser.dateFormat = "dd-MM-yyyy HH:mm"

        let prayers = PrayerName.allCases.compactMap { name -> PrayerTime? in
            guard let rawTime = timings[name.rawValue] else { return nil }
            let time = rawTime.components(separatedBy: " ").first ?? rawTime
            guard let date = parser.date(from: "\(date.gregorian.date) \(time)") else { return nil }
            return PrayerTime(name: name, time: time, date: date)
        }

        guard prayers.isEmpty == false else {
            throw PrayerTimesError.missingDate
        }

        return PrayerSchedule(
            readableDate: date.displayGregorian(timezone: timezone),
            hijriDate: "\(date.hijri.day) \(date.hijri.month.en) \(date.hijri.year)",
            locationName: locationName,
            calculationMethod: meta.method.name,
            timezoneIdentifier: meta.timezone,
            prayers: prayers
        )
    }
}

private struct AladhanDate: Decodable {
    let readable: String
    let hijri: HijriDate
    let gregorian: GregorianDate

    /// e.g. "Thu, 30 Jul 2026"
    func displayGregorian(timezone: TimeZone) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timezone
        parser.dateFormat = "dd-MM-yyyy"

        guard let parsed = parser.date(from: gregorian.date) else {
            return readable
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "E, d MMM yyyy"
        return formatter.string(from: parsed)
    }
}

private struct GregorianDate: Decodable {
    let date: String
}

private struct HijriDate: Decodable {
    let day: String
    let month: HijriMonth
    let year: String
}

private struct HijriMonth: Decodable {
    let en: String
}

private struct AladhanMeta: Decodable {
    let timezone: String
    let method: CalculationMethod
}

private struct CalculationMethod: Decodable {
    let name: String
}
