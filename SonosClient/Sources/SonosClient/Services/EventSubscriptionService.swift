import Foundation

/// Subscribes to UPnP event notifications from Sonos devices for real-time state updates.
/// Uses HTTP SUBSCRIBE to register a callback, then receives NOTIFY messages.
actor EventSubscriptionService {
    private var subscriptions: [String: String] = [:] // path -> SID
    private var callbackPort: UInt16 = 0
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }

    /// Subscribe to events from a specific service on a device.
    func subscribe(device: SonosDevice, servicePath: String, callbackURL: String, timeout: Int = 600) async throws -> String {
        let url = device.baseURL.appendingPathComponent(servicePath)
        var request = URLRequest(url: url)
        request.httpMethod = "SUBSCRIBE"
        request.setValue("<\(callbackURL)>", forHTTPHeaderField: "CALLBACK")
        request.setValue("upnp:event", forHTTPHeaderField: "NT")
        request.setValue("Second-\(timeout)", forHTTPHeaderField: "TIMEOUT")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EventError.subscriptionFailed
        }

        let sid = httpResponse.value(forHTTPHeaderField: "SID") ?? ""
        let key = "\(device.id):\(servicePath)"
        subscriptions[key] = sid
        return sid
    }

    /// Renew an existing subscription.
    func renew(device: SonosDevice, servicePath: String, timeout: Int = 600) async throws {
        let key = "\(device.id):\(servicePath)"
        guard let sid = subscriptions[key] else { return }

        let url = device.baseURL.appendingPathComponent(servicePath)
        var request = URLRequest(url: url)
        request.httpMethod = "SUBSCRIBE"
        request.setValue(sid, forHTTPHeaderField: "SID")
        request.setValue("Second-\(timeout)", forHTTPHeaderField: "TIMEOUT")

        let _ = try await session.data(for: request)
    }

    /// Unsubscribe from events.
    func unsubscribe(device: SonosDevice, servicePath: String) async throws {
        let key = "\(device.id):\(servicePath)"
        guard let sid = subscriptions[key] else { return }

        let url = device.baseURL.appendingPathComponent(servicePath)
        var request = URLRequest(url: url)
        request.httpMethod = "UNSUBSCRIBE"
        request.setValue(sid, forHTTPHeaderField: "SID")

        let _ = try? await session.data(for: request)
        subscriptions.removeValue(forKey: key)
    }

    func unsubscribeAll(device: SonosDevice) async {
        let keys = subscriptions.keys.filter { $0.hasPrefix(device.id) }
        for key in keys {
            subscriptions.removeValue(forKey: key)
        }
    }

    enum EventError: Error {
        case subscriptionFailed
    }
}

/// Well-known Sonos event subscription endpoints.
enum SonosEventPath {
    static let avTransport = "/MediaRenderer/AVTransport/Event"
    static let renderingControl = "/MediaRenderer/RenderingControl/Event"
    static let zoneGroupTopology = "/ZoneGroupTopology/Event"
    static let contentDirectory = "/MediaServer/ContentDirectory/Event"
    static let groupRenderingControl = "/MediaRenderer/GroupRenderingControl/Event"
}
