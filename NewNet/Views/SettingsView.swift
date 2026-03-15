import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    private let ytDLPService = YTDLPService()

    var body: some View {
        Form {
            Section("Download Engine") {
                Stepper(value: maxSegmentsBinding, in: 1...8) {
                    HStack {
                        Text("Parallel segments")
                        Spacer()
                        Text("\(settings.maxSegments)")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Speed limit")
                    Spacer()
                    TextField(
                        "Unlimited",
                        value: speedLimitBinding,
                        formatter: NumberFormatter.integerFormatter
                    )
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }

                Toggle("Resume downloads after app restart", isOn: autoResumeBinding)
            }

            Section("yt-dlp") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Override path")
                    Spacer()
                    TextField("/opt/homebrew/bin/yt-dlp", text: ytDLPPathBinding)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 220)
                }

                Picker("Default social-media mode", selection: preferredMediaBinding) {
                    ForEach(DownloadContentPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }

                LabeledContent("Resolved binary") {
                    Text(ytDLPService.discoveredBinaryDescription(settings: settings))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                Text("NewNet downloads yt-dlp automatically when a supported social-media link is added. Leave the override empty unless you want to force a specific binary.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Section("Smart Features") {
                Toggle("Detect links copied to clipboard", isOn: clipboardBinding)
            }

            Section {
                Text("NewNet keeps transfers lightweight by sampling interface counters once per second, persists downloads in Application Support, and uses yt-dlp for supported social-media links. Download only content you are authorized to save.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .background(.thinMaterial)
    }

    private var maxSegmentsBinding: Binding<Int> {
        Binding(
            get: { settings.maxSegments },
            set: { settings.maxSegments = $0 }
        )
    }

    private var speedLimitBinding: Binding<Int> {
        Binding(
            get: { settings.speedLimitKBps },
            set: { settings.speedLimitKBps = $0 }
        )
    }

    private var clipboardBinding: Binding<Bool> {
        Binding(
            get: { settings.clipboardMonitoringEnabled },
            set: { settings.clipboardMonitoringEnabled = $0 }
        )
    }

    private var autoResumeBinding: Binding<Bool> {
        Binding(
            get: { settings.autoResumeDownloads },
            set: { settings.autoResumeDownloads = $0 }
        )
    }

    private var ytDLPPathBinding: Binding<String> {
        Binding(
            get: { settings.ytDLPPath },
            set: { settings.ytDLPPath = $0 }
        )
    }

    private var preferredMediaBinding: Binding<DownloadContentPreference> {
        Binding(
            get: { settings.preferredMediaType },
            set: { settings.preferredMediaType = $0 }
        )
    }
}

private extension NumberFormatter {
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 999_999
        return formatter
    }()
}
