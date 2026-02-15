import Foundation

/// Provides SOAP request functionality for UPnP control of Sonos devices.
final class SOAPClient: Sendable {

    enum SOAPError: Error, LocalizedError {
        case invalidURL
        case httpError(Int)
        case noData
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .httpError(let code): return "HTTP error \(code)"
            case .noData: return "No data received"
            case .parseError(let msg): return "Parse error: \(msg)"
            }
        }
    }

    // Common Sonos UPnP service endpoints
    enum Service: String {
        case avTransport = "/MediaRenderer/AVTransport/Control"
        case renderingControl = "/MediaRenderer/RenderingControl/Control"
        case contentDirectory = "/MediaServer/ContentDirectory/Control"
        case zoneGroupTopology = "/ZoneGroupTopology/Control"
        case deviceProperties = "/DeviceProperties/Control"
        case groupRenderingControl = "/MediaRenderer/GroupRenderingControl/Control"

        var urn: String {
            switch self {
            case .avTransport:
                return "urn:schemas-upnp-org:service:AVTransport:1"
            case .renderingControl:
                return "urn:schemas-upnp-org:service:RenderingControl:1"
            case .contentDirectory:
                return "urn:schemas-upnp-org:service:ContentDirectory:1"
            case .zoneGroupTopology:
                return "urn:schemas-upnp-org:service:ZoneGroupTopology:1"
            case .deviceProperties:
                return "urn:schemas-upnp-org:service:DeviceProperties:1"
            case .groupRenderingControl:
                return "urn:schemas-upnp-org:service:GroupRenderingControl:1"
            }
        }
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    /// Send a SOAP request and return the raw XML response body.
    func send(
        to baseURL: URL,
        service: Service,
        action: String,
        arguments: [(String, String)] = [],
        instanceID: String = "0"
    ) async throws -> String {
        let url = baseURL.appendingPathComponent(service.rawValue)

        var body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
                    s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:\(action) xmlns:u="\(service.urn)">
              <InstanceID>\(instanceID)</InstanceID>
        """

        for (key, value) in arguments {
            body += "\n      <\(key)>\(value.xmlEscaped)</\(key)>"
        }

        body += """

            </u:\(action)>
          </s:Body>
        </s:Envelope>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(service.urn)#\(action)", forHTTPHeaderField: "SOAPAction")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SOAPError.httpError(httpResponse.statusCode)
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw SOAPError.noData
        }

        return responseString
    }
}

extension String {
    /// Escape special XML characters for use in XML element content/attributes.
    /// Important: Only call on raw (unescaped) strings. Calling on already-escaped
    /// strings will double-escape entities (e.g. &amp; becomes &amp;amp;).
    var xmlEscaped: String {
        var result = ""
        result.reserveCapacity(self.count)
        for char in self {
            switch char {
            case "&":  result += "&amp;"
            case "<":  result += "&lt;"
            case ">":  result += "&gt;"
            case "\"": result += "&quot;"
            case "'":  result += "&apos;"
            default:   result.append(char)
            }
        }
        return result
    }
}
