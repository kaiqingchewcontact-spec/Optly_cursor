import Foundation

struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var mode: FocusMode
    var blockedApps: [String]
    var suggestedPlaylist: PlaylistSuggestion
    var breakSchedule: BreakSchedule
    var productivityScore: Int

    enum FocusMode: String, Codable, CaseIterable {
        case deepWork
        case creative
        case meetingPrep
        case windDown
    }

    struct PlaylistSuggestion: Codable, Equatable {
        var title: String
        var urlString: String?
        var genre: String
    }

    struct BreakSchedule: Codable, Equatable {
        var focusMinutes: Int
        var shortBreakMinutes: Int
        var longBreakMinutes: Int
        var cyclesBeforeLongBreak: Int
    }
}

// MARK: - Formatting

extension FocusSession {
    static let intervalFormatter: DateIntervalFormatter = {
        let f = DateIntervalFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - Sample data

extension FocusSession {
    static let sample = FocusSession(
        id: UUID(),
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date(),
        mode: .deepWork,
        blockedApps: ["SocialScroll", "MessageHub", "VideoBox"],
        suggestedPlaylist: PlaylistSuggestion(
            title: "Deep Work — Minimal Pulse",
            urlString: "https://music.example.com/playlists/deep-work",
            genre: "Ambient / electronic"
        ),
        breakSchedule: BreakSchedule(
            focusMinutes: 50,
            shortBreakMinutes: 10,
            longBreakMinutes: 20,
            cyclesBeforeLongBreak: 3
        ),
        productivityScore: 86
    )

    static let samples: [FocusSession] = [
        sample,
        FocusSession(
            id: UUID(),
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-5400),
            mode: .creative,
            blockedApps: ["Email", "Calendar"],
            suggestedPlaylist: PlaylistSuggestion(
                title: "Creative Flow",
                urlString: nil,
                genre: "Instrumental jazz"
            ),
            breakSchedule: BreakSchedule(
                focusMinutes: 25,
                shortBreakMinutes: 5,
                longBreakMinutes: 15,
                cyclesBeforeLongBreak: 4
            ),
            productivityScore: 72
        )
    ]
}
