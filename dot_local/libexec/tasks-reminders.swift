// EventKit, not AppleScript: JXA took >2min to read 3 reminders and cannot see recurrence.
import EventKit
import Foundation

let listName = ProcessInfo.processInfo.environment["TASKS_REMINDERS_LIST"] ?? "Inbox"
let iso = ISO8601DateFormatter()
let dayFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone.current
    return f
}()

// A todo.txt threshold is a date; an alarm needs a time. Default 9am local, overridable.
let alarmHour = Int(ProcessInfo.processInfo.environment["TASKS_ALARM_HOUR"] ?? "") ?? 9

func die(_ msg: String) -> Never {
    FileHandle.standardError.write(("tasks-reminders: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

let store = EKEventStore()
var granted = false
let authSem = DispatchSemaphore(value: 0)
store.requestFullAccessToReminders { ok, _ in granted = ok; authSem.signal() }
authSem.wait()
guard granted else { die("no Reminders access (TCC). Run from a terminal that holds it.") }

guard let cal = store.calendars(for: .reminder).first(where: { $0.title == listName }) else {
    die("no reminder list named \(listName)")
}

func fetchAll() -> [EKReminder] {
    var out: [EKReminder] = []
    let sem = DispatchSemaphore(value: 0)
    store.fetchReminders(matching: store.predicateForReminders(in: [cal])) { r in
        out = r ?? []
        sem.signal()
    }
    sem.wait()
    return out
}

func encode(_ r: EKReminder) -> [String: Any] {
    var due: Any = NSNull()
    if let dc = r.dueDateComponents, let d = Calendar.current.date(from: dc) {
        due = dayFmt.string(from: d)
    }
    return [
        "id": r.calendarItemIdentifier,
        "title": r.title ?? "",
        "due": due,
        "notes": r.notes ?? NSNull(),
        "completed": r.isCompleted,
        "priority": r.priority,
        "recurring": r.hasRecurrenceRules,
        "alarm": (r.alarms ?? []).compactMap({ $0.absoluteDate }).first.map { dayFmt.string(from: $0) } ?? NSNull(),
        "modified": iso.string(from: r.lastModifiedDate ?? Date.distantPast),
    ]
}

func emit(_ obj: Any) {
    let d = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    FileHandle.standardOutput.write(d)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}

func setAlarm(_ r: EKReminder, _ day: String?) {
    for a in r.alarms ?? [] { r.removeAlarm(a) }
    guard let day = day, let base = dayFmt.date(from: day),
          let at = Calendar.current.date(bySettingHour: alarmHour, minute: 0, second: 0, of: base)
    else { return }
    r.addAlarm(EKAlarm(absoluteDate: at))
}

// A date-only due, so Calendar shows it on the right day regardless of the viewer's timezone.
func dayComponents(_ s: String) -> DateComponents? {
    guard let d = dayFmt.date(from: s) else { return nil }
    return Calendar.current.dateComponents([.year, .month, .day], from: d)
}

switch CommandLine.arguments.dropFirst().first ?? "" {
case "list":
    emit(fetchAll().map(encode))

case "apply":
    let input = FileHandle.standardInput.readDataToEndOfFile()
    guard let ops = (try? JSONSerialization.jsonObject(with: input)) as? [[String: Any]] else {
        die("apply expects a JSON array of ops on stdin")
    }
    var byID: [String: EKReminder] = [:]
    for r in fetchAll() { byID[r.calendarItemIdentifier] = r }

    var results: [[String: Any]] = []
    for op in ops {
        let kind = op["op"] as? String ?? ""
        let ref = op["ref"] as? String ?? ""
        do {
            switch kind {
            case "create":
                let r = EKReminder(eventStore: store)
                r.calendar = cal
                r.title = op["title"] as? String ?? ""
                if let due = op["due"] as? String { r.dueDateComponents = dayComponents(due) }
                if let notes = op["notes"] as? String { r.notes = notes }
                if let p = op["priority"] as? Int { r.priority = p }
                if op.keys.contains("alarm") { setAlarm(r, op["alarm"] as? String) }
                try store.save(r, commit: false)
                results.append(["ref": ref, "ok": true, "id": r.calendarItemIdentifier])
            case "update":
                guard let id = op["id"] as? String, let r = byID[id] else {
                    results.append(["ref": ref, "ok": false, "error": "unknown id"]); continue
                }
                if let t = op["title"] as? String { r.title = t }
                if op.keys.contains("due") {
                    r.dueDateComponents = (op["due"] as? String).flatMap(dayComponents)
                }
                if let p = op["priority"] as? Int { r.priority = p }
                if op.keys.contains("alarm") { setAlarm(r, op["alarm"] as? String) }
                if let c = op["completed"] as? Bool { r.isCompleted = c }
                try store.save(r, commit: false)
                results.append(["ref": ref, "ok": true, "id": id])
            case "delete":
                guard let id = op["id"] as? String, let r = byID[id] else {
                    results.append(["ref": ref, "ok": false, "error": "unknown id"]); continue
                }
                try store.remove(r, commit: false)
                results.append(["ref": ref, "ok": true, "id": id])
            default:
                results.append(["ref": ref, "ok": false, "error": "unknown op \(kind)"])
            }
        } catch {
            results.append(["ref": ref, "ok": false, "error": "\(error)"])
        }
    }
    // One commit per batch: a partial apply desyncs todo.txt from the snapshot.
    do { try store.commit() } catch { die("commit failed: \(error)") }
    emit(results)

default:
    die("usage: tasks-reminders list | tasks-reminders apply < ops.json")
}
