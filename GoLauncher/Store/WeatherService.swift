import CoreLocation
import Foundation

/// Current weather for the Weather widget, from Open-Meteo (free, no API key, no paid Apple account).
/// Location is asked for once and used only to look up the forecast.
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct Current: Equatable {
        var temperature: Double
        var high: Double
        var low: Double
        var code: Int
        var place: String?
        var fetched: Date
    }

    enum Status: Equatable {
        case idle, needsPermission, denied, loading, failed, ready
    }

    @Published private(set) var current: Current?
    @Published private(set) var status: Status = .idle

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var place: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var usesFahrenheit: Bool {
        Locale.current.measurementSystem == .us
    }

    /// Fetches new weather if there's none yet or it's more than 30 minutes old.
    func refreshIfNeeded() {
        if let current, Date().timeIntervalSince(current.fetched) < 30 * 60 { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .needsPermission
        case .denied, .restricted:
            status = .denied
        default:
            if current == nil { status = .loading }
            manager.requestLocation()
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func retry() {
        current = nil
        refreshIfNeeded()
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.refreshIfNeeded() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        fetch(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let name = placemarks?.first?.locality
            DispatchQueue.main.async {
                self?.place = name
                if name != nil { self?.current?.place = name }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if self.current == nil { self.status = .failed }
        }
    }

    // MARK: Network

    private struct Response: Decodable {
        struct CurrentValues: Decodable {
            let temperature: Double
            let code: Int
            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case code = "weather_code"
            }
        }
        struct Daily: Decodable {
            let high: [Double]
            let low: [Double]
            enum CodingKeys: String, CodingKey {
                case high = "temperature_2m_max"
                case low = "temperature_2m_min"
            }
        }
        let current: CurrentValues
        let daily: Daily
    }

    private func fetch(latitude: Double, longitude: Double) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: usesFahrenheit ? "fahrenheit" : "celsius"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        guard let url = components?.url else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            let decoded = data.flatMap { try? JSONDecoder().decode(Response.self, from: $0) }
            DispatchQueue.main.async {
                guard let decoded else {
                    if self.current == nil { self.status = .failed }
                    return
                }
                self.current = Current(
                    temperature: decoded.current.temperature,
                    high: decoded.daily.high.first ?? decoded.current.temperature,
                    low: decoded.daily.low.first ?? decoded.current.temperature,
                    code: decoded.current.code,
                    place: self.place,
                    fetched: Date()
                )
                self.status = .ready
            }
        }.resume()
    }

    // MARK: Weather codes (WMO)

    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67, 80...82: return "Rain"
        case 71...77, 85, 86: return "Snow"
        case 95...99: return "Thunderstorms"
        default: return "—"
        }
    }
}
