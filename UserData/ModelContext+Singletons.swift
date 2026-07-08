import SwiftData

extension ModelContext {
    /// Fetch-and-merge per SPEC §4: never trust that exactly one
    /// "singleton" record exists — CloudKit can duplicate one across
    /// devices before merges settle.
    func fetchOrCreateStreakRecord() -> StreakRecord {
        let records = (try? fetch(FetchDescriptor<StreakRecord>())) ?? []
        guard !records.isEmpty else {
            let record = StreakRecord()
            insert(record)
            return record
        }
        guard records.count > 1 else { return records[0] }
        let winner = StreakRecord.merge(records)
        for record in records where record !== winner {
            delete(record)
        }
        return winner
    }

    /// Same fetch-and-merge convention as `fetchOrCreateStreakRecord`.
    /// Preferences have no natural "most favorable" candidate, so ties are
    /// broken by simply keeping the first and discarding the rest.
    func fetchOrCreateUserPreferences() -> UserPreferences {
        let records = (try? fetch(FetchDescriptor<UserPreferences>())) ?? []
        guard !records.isEmpty else {
            let preferences = UserPreferences()
            insert(preferences)
            return preferences
        }
        for record in records.dropFirst() {
            delete(record)
        }
        return records[0]
    }
}
