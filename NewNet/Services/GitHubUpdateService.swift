import Foundation
import Combine
import OSLog
import AppKit

enum GitHubUpdateState: Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(version: String, releaseNotes: String, url: URL)
    case error(String)
}

@MainActor
final class GitHubUpdateService: ObservableObject {
    @Published private(set) var state: GitHubUpdateState = .idle
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "GitHubUpdates")
    private let repo = "sfdcnaveen/NewNet"
    
    func checkForUpdates() {
        guard state != .checking else { return }
        state = .checking
        
        Task {
            do {
                let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
                
                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    self.state = .updateAvailable(
                        version: latestVersion,
                        releaseNotes: release.body ?? "No release notes provided.",
                        url: URL(string: release.htmlUrl)!
                    )
                } else {
                    self.state = .upToDate(version: currentVersion)
                }
            } catch {
                logger.error("Failed to check for updates: \(error.localizedDescription)")
                self.state = .error(error.localizedDescription)
            }
        }
    }
    
    func openReleasePage(url: URL) {
        NSWorkspace.shared.open(url)
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}
