// Focuses the target window natively first so AeroSpace can't bounce via the previous workspace (#2297).
import AppKit

let aerospaceCli = "/opt/homebrew/bin/aerospace"
let stateDir = NSHomeDirectory() + "/.cache/aerospace"
let mruDir = stateDir + "/mru"

struct WindowRow {
    let id: UInt32
    let workspace: String
    let pid: pid_t
}

func logError(_ message: String) {
    FileHandle.standardError.write("aerospace-workspace: ERROR: \(message)\n".data(using: .utf8)!)
}

func execCli(_ args: [String]) -> Never {
    let argv = ([aerospaceCli] + args).map { strdup($0) } + [nil]
    execv(aerospaceCli, argv)
    exit(127)
}

func littleEndianBytes(_ n: UInt32) -> [UInt8] { withUnsafeBytes(of: n.littleEndian, Array.init) }

func writeAll(_ fd: Int32, _ bytes: [UInt8]) -> Bool {
    var sent = 0
    while sent < bytes.count {
        let n = bytes.withUnsafeBytes { write(fd, $0.baseAddress! + sent, bytes.count - sent) }
        if n <= 0 { return false }
        sent += n
    }
    return true
}

func readExactly(_ fd: Int32, _ count: Int) -> [UInt8]? {
    var buffer = [UInt8](repeating: 0, count: count)
    var got = 0
    while got < count {
        let n = buffer.withUnsafeMutableBytes { read(fd, $0.baseAddress! + got, count - got) }
        if n <= 0 { return nil }
        got += n
    }
    return buffer
}

func readUInt32(_ fd: Int32) -> UInt32? {
    readExactly(fd, 4).map { $0.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) } }
}

func connectToAeroSpace() -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var timeout = timeval(tv_sec: 1, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let path = "/tmp/bobko.aerospace-\(NSUserName()).sock"
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    _ = withUnsafeMutablePointer(to: &address.sun_path) {
        $0.withMemoryRebound(to: CChar.self, capacity: capacity) { strncpy($0, path, capacity - 1) }
    }
    let connected = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    let protocolVersion: UInt32 = 1
    guard connected == 0, writeAll(fd, littleEndianBytes(protocolVersion)), readUInt32(fd) == protocolVersion else {
        close(fd)
        return nil
    }
    return fd
}

func run(_ fd: Int32, _ args: [String]) -> (exitCode: Int32, stdout: String)? {
    let request: [String: Any] = ["command": "", "args": args, "stdin": ""]
    guard let payload = try? JSONSerialization.data(withJSONObject: request),
          writeAll(fd, littleEndianBytes(UInt32(payload.count)) + [UInt8](payload)),
          let length = readUInt32(fd),
          let body = readExactly(fd, Int(length)),
          let response = try? JSONSerialization.jsonObject(with: Data(body)) as? [String: Any]
    else { return nil }
    return ((response["exitCode"] as? NSNumber)?.int32Value ?? 1, response["stdout"] as? String ?? "")
}

func query(_ fd: Int32, _ args: [String]) -> String? {
    guard let result = run(fd, args), result.exitCode == 0 else { return nil }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}

func parseRows(_ listing: String) -> [WindowRow] {
    listing.split(separator: "\n").compactMap { line in
        let fields = line.split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 3, let id = UInt32(fields[0]), let pid = pid_t(fields[2]) else { return nil }
        return WindowRow(id: id, workspace: String(fields[1]), pid: pid)
    }
}

func lastFocusedAt(_ windowId: UInt32) -> timespec? {
    var info = stat()
    guard stat("\(mruDir)/\(windowId)", &info) == 0 else { return nil }
    return info.st_mtimespec
}

func mostRecent<T>(_ items: [T], _ focusedAt: (T) -> timespec?) -> T? {
    items
        .compactMap { item in focusedAt(item).map { (item, $0) } }
        .max { ($0.1.tv_sec, $0.1.tv_nsec) < ($1.1.tv_sec, $1.1.tv_nsec) }?
        .0
}

// The focused window's file is the newest one only while the on-focus-changed hook is still firing.
func mruHookIsLive(focusedWindowId: UInt32?) -> Bool {
    guard let focusedWindowId else { return true }
    let ids = ((try? FileManager.default.contentsOfDirectory(atPath: mruDir)) ?? []).compactMap(UInt32.init)
    return mostRecent(ids, lastFocusedAt) == focusedWindowId
}

// The hook writes "<prev> <current>"; a current that no longer matches means the file is stale.
func recordedPreviousWorkspace(current: String) -> String? {
    let recorded = (try? String(contentsOfFile: stateDir + "/prev-workspace", encoding: .utf8)) ?? ""
    let fields = recorded.split(separator: " ").map(String.init)
    guard fields.count == 2, fields[1] == current, fields[0] != current else { return nil }
    return fields[0]
}

@_silgen_name("_AXUIElementGetWindow")
func axWindowId(_ element: AXUIElement, _ windowId: inout CGWindowID) -> AXError

func raise(_ window: WindowRow) -> Bool {
    guard AXIsProcessTrusted() else { return false }
    let app = AXUIElementCreateApplication(window.pid)
    AXUIElementSetMessagingTimeout(app, 0.2)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let axWindows = value as? [AXUIElement]
    else { return false }
    for axWindow in axWindows {
        var id: CGWindowID = 0
        guard axWindowId(axWindow, &id) == .success, id == window.id else { continue }
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        return AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString) == .success
    }
    return false
}

func activateAndWait(_ pid: pid_t) {
    guard let app = NSRunningApplication(processIdentifier: pid) else { return }
    app.activate(options: [])
    let deadline = Date().addingTimeInterval(0.25)
    while !app.isActive && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.005))
    }
}

func focusTargetWindow(of workspace: String, among rows: [WindowRow], trustMru: Bool) {
    let targetWindows = rows.filter { $0.workspace == workspace }
    let onlyHere = { (pid: pid_t) in !rows.contains { $0.pid == pid && $0.workspace != workspace } }
    let soleApp = Set(targetWindows.map(\.pid)).count == 1 ? targetWindows.first?.pid : nil
    let candidate = (trustMru ? mostRecent(targetWindows) { lastFocusedAt($0.id) } : nil)
        ?? (targetWindows.count == 1 ? targetWindows.first : nil)
    if let candidate {
        if raise(candidate) || onlyHere(candidate.pid) { activateAndWait(candidate.pid) }
    } else if let soleApp, onlyHere(soleApp) {
        activateAndWait(soleApp)
    }
}

func pruneClosedWindows(_ rows: [WindowRow]) {
    let live = Set(rows.map { String($0.id) })
    for name in (try? FileManager.default.contentsOfDirectory(atPath: mruDir)) ?? [] where !live.contains(name) {
        unlink("\(mruDir)/\(name)")
    }
}

let listFormat = "%{window-id}|%{workspace}|%{app-pid}"

func installedAeroSpaceVersion() -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(filePath: aerospaceCli)
    process.arguments = ["--version"]
    process.standardOutput = pipe
    guard (try? process.run()) != nil else { return nil }
    process.waitUntilExit()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return output.split(separator: "\n").first { $0.contains("CLI client version") }.map(String.init)
}

// Report-only health check for update(): silent and exit 0 when nothing needs attention.
func selfCheck() -> Int32 {
    var problems: [String] = []
    if let fd = connectToAeroSpace(),
       let focused = query(fd, ["list-workspaces", "--focused"]),
       let listing = query(fd, ["list-windows", "--all", "--format", listFormat])
    {
        if !listing.isEmpty && parseRows(listing).isEmpty { problems.append("list-windows output no longer parses") }
        let recorded = (try? String(contentsOfFile: stateDir + "/prev-workspace", encoding: .utf8)) ?? ""
        let fields = recorded.split(separator: " ", omittingEmptySubsequences: false)
        if fields.count != 2 || fields.contains(where: \.isEmpty) || fields[1] != focused {
            problems.append("exec-on-workspace-change is not recording prev-workspace (got '\(recorded)')")
        }
        let focusedWindowId = query(fd, ["list-windows", "--focused", "--format", "%{window-id}"]).flatMap(UInt32.init)
        if !mruHookIsLive(focusedWindowId: focusedWindowId) { problems.append("on-focus-changed is not touching mru/<window-id>") }
    } else {
        problems.append("the AeroSpace socket protocol or queries changed; switches fall back to plain AeroSpace")
    }
    let versionFile = stateDir + "/checked-version"
    let lastChecked = try? String(contentsOfFile: versionFile, encoding: .utf8)
    if let version = installedAeroSpaceVersion(), version != lastChecked {
        if lastChecked != nil {
            problems.append("AeroSpace changed (\(version)); if #2297 is fixed upstream, retire this workaround: https://github.com/nikitabobko/AeroSpace/discussions/2297")
        }
        try? version.write(toFile: versionFile, atomically: true, encoding: .utf8)
    }
    for problem in problems { print("   aerospace-workspace: \(problem)") }
    return problems.isEmpty ? 0 : 1
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 1 else {
    FileHandle.standardError.write("usage: aerospace-workspace <workspace> | --back-and-forth | --check\n".data(using: .utf8)!)
    exit(64)
}
if arguments[0] == "--check" { exit(selfCheck()) }
let backAndForth = arguments[0] == "--back-and-forth"
let plainCommand = backAndForth ? ["workspace-back-and-forth"] : ["workspace", arguments[0]]
guard let fd = connectToAeroSpace() else {
    logError("no AeroSpace socket handshake, running the plain CLI")
    execCli(plainCommand)
}
guard let focusedWorkspace = query(fd, ["list-workspaces", "--focused"]),
      let listing = query(fd, ["list-windows", "--all", "--format", listFormat])
else {
    logError("AeroSpace rejected a query, running a plain switch")
    execCli(plainCommand)
}
let rows = parseRows(listing)
let target = backAndForth ? recordedPreviousWorkspace(current: focusedWorkspace) : arguments[0]
if let target, target != focusedWorkspace {
    let focusedWindowId = query(fd, ["list-windows", "--focused", "--format", "%{window-id}"]).flatMap(UInt32.init)
    focusTargetWindow(of: target, among: rows, trustMru: mruHookIsLive(focusedWindowId: focusedWindowId))
}
let command = target.map { ["workspace", $0] } ?? plainCommand
guard let result = run(fd, command) else {
    logError("AeroSpace did not answer: \(command.joined(separator: " "))")
    exit(1)
}
pruneClosedWindows(rows)
exit(result.exitCode)
