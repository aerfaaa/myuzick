import Foundation

extension Double {
    var formattedTime: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
