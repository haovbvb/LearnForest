import Foundation

enum StudyLimitKind: Equatable {
    case session
    case daily
}

/// 单次上限看这一轮前台认字的秒数；每日上限看该档案当天已经记下的有效时长。
/// nil 或 0 分钟表示关闭。到点只说明该休息，不表示惩罚。
enum StudyTimeLimit {
    static func reached(
        sittingSeconds: Int,
        sessionLimitMinutes: Int?,
        dailySeconds: Int,
        dailyLimitMinutes: Int?
    ) -> StudyLimitKind? {
        if let minutes = dailyLimitMinutes, minutes > 0, dailySeconds >= minutes * 60 {
            return .daily
        }
        if let minutes = sessionLimitMinutes, minutes > 0, sittingSeconds >= minutes * 60 {
            return .session
        }
        return nil
    }
}

enum StudyDay {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
