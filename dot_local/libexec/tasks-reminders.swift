// EventKit, not AppleScript: JXA took >2min to read 3 reminders and cannot see recurrence.
import EventKit
import Foundation

let listName = ProcessInfo.processInfo.environment["TASKS_REMINDERS_LIST"] ?? "Projects (Personal)"
let iso = ISO8601DateFormatter()
let dayFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone.current
    return f
}()
let timeFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
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

// Each command asks only for the access it uses, so a missing Calendar grant never stops Reminders.
func requireAccess(_ type: EKEntityType) {
    var granted = false
    let sem = DispatchSemaphore(value: 0)
    let done: (Bool, Error?) -> Void = { ok, _ in granted = ok; sem.signal() }
    if type == .reminder {
        store.requestFullAccessToReminders(completion: done)
    } else {
        store.requestFullAccessToEvents(completion: done)
    }
    sem.wait()
    let name = type == .reminder ? "Reminders" : "Calendar"
    guard granted else { die("no \(name) access (TCC). Run from a terminal that holds it.") }
}

// Under launchd TCC checks the mise python shim; a disclaimed re-spawn makes our Info.plist the one checked.
func becomeResponsible() {
    let flag = "TASKS_REMINDERS_DISCLAIMED"
    guard getenv(flag) == nil, let path = Bundle.main.executablePath,
          let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim")
    else { return }
    typealias Disclaim = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32
    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    _ = unsafeBitCast(sym, to: Disclaim.self)(&attr, 1)
    setenv(flag, "1", 1)
    var argv: [UnsafeMutablePointer<CChar>?] = CommandLine.arguments.map { strdup($0) } + [nil]
    var pid: pid_t = 0
    guard posix_spawn(&pid, path, nil, &attr, &argv, environ) == 0 else { return }
    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
    exit((status >> 8) & 0xff)
}

var calendars: [EKCalendar] = []

func openReminders() {
    requireAccess(.reminder)
    calendars = store.calendars(for: .reminder)
    guard calendars.contains(where: { $0.title == listName }) else {
        die("no reminder list named \(listName)")
    }
}

// Subscribed and birthday calendars are read-only feeds nobody schedules into.
func eventCalendars() -> [EKCalendar] {
    store.calendars(for: .event).filter { $0.type != .subscription && $0.type != .birthday }
}

// Names the account an event came from, which is what tells a capture apart in tuxedo.
func eventSource(_ src: EKSource) -> String {
    switch src.sourceType {
    case .exchange: return "outlook"
    case .calDAV: return src.title == "iCloud" ? "icloud" : "gcal"
    default: return "calendar"
    }
}

// Every occurrence of a series shares eventIdentifier, so the occurrence day is what tells them apart.
func eventID(_ e: EKEvent) -> String {
    let base = e.eventIdentifier ?? ""
    let recurring = e.hasRecurrenceRules || e.isDetached
    return recurring ? "\(base)#\(dayFmt.string(from: e.occurrenceDate ?? e.startDate))" : base
}

func encodeEvent(_ e: EKEvent) -> [String: Any] {
    let me = (e.attendees ?? []).first(where: { $0.isCurrentUser })
    return [
        "id": eventID(e),
        "calendar": e.calendar.title,
        "source": eventSource(e.calendar.source),
        "title": e.title ?? "",
        "start": dayFmt.string(from: e.startDate),
        "time": e.isAllDay ? NSNull() : timeFmt.string(from: e.startDate),
        // A detached occurrence has no rules of its own but still belongs to a series.
        "recurring": e.hasRecurrenceRules || e.isDetached,
        "declined": me?.participantStatus == .declined || e.status == .canceled,
    ]
}

func calendar(named name: String?) -> EKCalendar? {
    let wanted = name ?? listName
    return calendars.first(where: { $0.title == wanted })
}

func fetchAll() -> [EKReminder] {
    var out: [EKReminder] = []
    let sem = DispatchSemaphore(value: 0)
    store.fetchReminders(matching: store.predicateForReminders(in: calendars)) { r in
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
        "list": r.calendar.title,
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
    openReminders()
    emit(fetchAll().map(encode))

case "lists":
    openReminders()
    emit(calendars.map { $0.title })

case "calendars":
    becomeResponsible()
    requireAccess(.event)
    emit(eventCalendars().map { $0.title })

case "events":
    // stdin: {"days": N, "calendars": [titles] or null, "ids": [event ids to look up wherever they now fall]}
    becomeResponsible()
    requireAccess(.event)
    let input = FileHandle.standardInput.readDataToEndOfFile()
    let req = ((try? JSONSerialization.jsonObject(with: input)) as? [String: Any]) ?? [:]
    let days = req["days"] as? Int ?? 14
    let wanted = req["calendars"] as? [String]
    let cals = eventCalendars().filter { wanted?.contains($0.title) ?? true }
    var byID: [String: EKEvent] = [:]
    func collect(_ from: Date, _ to: Date, _ in_: [EKCalendar]) {
        for e in store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: in_)) {
            byID[eventID(e)] = e
        }
    }
    let today = Calendar.current.startOfDay(for: Date())
    if !cals.isEmpty {
        collect(today, Calendar.current.date(byAdding: .day, value: days, to: today)!, cals)
    }
    for id in req["ids"] as? [String] ?? [] where byID[id] == nil {
        let parts = id.split(separator: "#", maxSplits: 1).map(String.init)
        if parts.count == 2, let day = dayFmt.date(from: parts[1]) {
            // An occurrence is only reachable by searching around the day it belongs to.
            let cal = Calendar.current
            collect(cal.date(byAdding: .day, value: -1, to: day)!, cal.date(byAdding: .day, value: 2, to: day)!, eventCalendars())
        } else if let e = store.event(withIdentifier: id) {
            byID[id] = e
        }
    }
    emit(byID.values.map(encodeEvent))

case "apply":
    openReminders()
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
                guard let target = calendar(named: op["list"] as? String) else {
                    results.append(["ref": ref, "ok": false, "error": "no reminder list named \(op["list"] ?? "")"]); continue
                }
                r.calendar = target
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
                if let l = op["list"] as? String {
                    guard let target = calendar(named: l) else {
                        results.append(["ref": ref, "ok": false, "error": "no reminder list named \(l)"]); continue
                    }
                    r.calendar = target
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
    die("usage: tasks-reminders list | lists | apply < ops.json | calendars | events < query.json")
}
