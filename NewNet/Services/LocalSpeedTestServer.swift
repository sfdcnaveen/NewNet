import Foundation
import Network

final class LocalSpeedTestServer {
    private let queue = DispatchQueue(label: "LocalSpeedTestServer")
    private var listener: NWListener?
    private var isRunning = false

    private let downloadSizeBytes = 20 * 1024 * 1024
    private let chunkSize = 64 * 1024

    func start(onReady: @escaping (SpeedTestEndpoints) -> Void) {
        guard !isRunning else { return }
        isRunning = true

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard let port = listener.port else { return }
                    let endpoints = SpeedTestEndpoints(
                        serverName: "Localhost",
                        pingURL: URL(string: "http://127.0.0.1:\(port)/ping")!,
                        downloadURL: URL(string: "http://127.0.0.1:\(port)/download")!,
                        uploadURL: URL(string: "http://127.0.0.1:\(port)/upload")!
                    )
                    DispatchQueue.main.async {
                        onReady(endpoints)
                    }
                default:
                    break
                }
            }

            listener.start(queue: queue)
        } catch {
            isRunning = false
        }
    }

    private func handle(connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveRequest(on: connection, buffer: Data())
            }
        }
        connection.start(queue: queue)
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, error in
            guard let self else { return }
            guard let data, error == nil else {
                connection.cancel()
                return
            }

            var accumulated = buffer
            accumulated.append(data)

            if let headerRange = accumulated.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = accumulated.subdata(in: accumulated.startIndex..<headerRange.lowerBound)
                let bodyStart = headerRange.upperBound
                let bodyData = accumulated.subdata(in: bodyStart..<accumulated.endIndex)
                let request = self.parseRequest(headerData: headerData)
                self.handleRequest(
                    request,
                    bodyData: bodyData,
                    on: connection
                )
                return
            }

            self.receiveRequest(on: connection, buffer: accumulated)
        }
    }

    private func handleRequest(
        _ request: ParsedRequest,
        bodyData: Data,
        on connection: NWConnection
    ) {
        switch request.path {
        case "/ping":
            sendResponse(on: connection, status: "200 OK", body: Data("ok".utf8))
        case "/download":
            sendDownload(on: connection)
        case "/upload":
            receiveUploadBody(
                expectedLength: request.contentLength,
                initialBody: bodyData,
                on: connection
            )
        default:
            sendResponse(on: connection, status: "404 Not Found", body: Data("not found".utf8))
        }
    }

    private func sendDownload(on connection: NWConnection) {
        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: application/octet-stream",
            "Content-Length: \(downloadSizeBytes)",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")

        connection.send(content: Data(headers.utf8), completion: .contentProcessed { [weak self] _ in
            self?.sendDownloadChunks(on: connection, remaining: self?.downloadSizeBytes ?? 0)
        })
    }

    private func sendDownloadChunks(on connection: NWConnection, remaining: Int) {
        guard remaining > 0 else {
            connection.cancel()
            return
        }

        let size = min(chunkSize, remaining)
        let chunk = Data(repeating: 0x5A, count: size)
        connection.send(content: chunk, completion: .contentProcessed { [weak self] _ in
            self?.sendDownloadChunks(on: connection, remaining: remaining - size)
        })
    }

    private func receiveUploadBody(
        expectedLength: Int,
        initialBody: Data,
        on connection: NWConnection
    ) {
        if expectedLength <= 0 {
            sendResponse(on: connection, status: "200 OK", body: Data("ok".utf8))
            return
        }

        var received = initialBody.count
        if received >= expectedLength {
            sendResponse(on: connection, status: "200 OK", body: Data("ok".utf8))
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, error in
            guard let self else { return }
            guard let data, error == nil else {
                connection.cancel()
                return
            }

            received += data.count
            if received >= expectedLength {
                self.sendResponse(on: connection, status: "200 OK", body: Data("ok".utf8))
            } else {
                self.receiveUploadBody(
                    expectedLength: expectedLength,
                    initialBody: Data(),
                    on: connection
                )
            }
        }
    }

    private func sendResponse(on connection: NWConnection, status: String, body: Data) {
        let headers = [
            "HTTP/1.1 \(status)",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Length: \(body.count)",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")

        let payload = Data(headers.utf8) + body
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func parseRequest(headerData: Data) -> ParsedRequest {
        let headerString = String(decoding: headerData, as: UTF8.self)
        let lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false)
        let requestLine = lines.first ?? ""
        let parts = requestLine.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : "GET"
        let path = parts.count > 1 ? String(parts[1]) : "/"

        var contentLength = 0
        for line in lines.dropFirst() {
            let components = line.split(separator: ":", maxSplits: 1)
            guard components.count == 2 else { continue }
            let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "content-length" {
                contentLength = Int(value) ?? 0
            }
        }

        return ParsedRequest(method: method, path: path, contentLength: contentLength)
    }
}

private struct ParsedRequest {
    let method: String
    let path: String
    let contentLength: Int
}
