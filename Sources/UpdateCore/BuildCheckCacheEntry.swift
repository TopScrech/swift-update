import Foundation

struct BuildCheckCacheEntry: Codable {
    let fingerprint: String
    let checkedAt: Date
    let report: BuildCheckReport

    func isValid(fingerprint: String, now: Date) -> Bool {
        let age = now.timeIntervalSince(checkedAt)
        return self.fingerprint == fingerprint && report.success && age >= 0 && age < 15 * 60
    }
}
