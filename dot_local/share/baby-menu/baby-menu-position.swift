import AppKit
import ApplicationServices
import Foundation

let monitorName = CommandLine.arguments.dropFirst().first ?? ""
let screens = NSScreen.screens
guard
  let primaryScreen = screens.first,
  let targetScreen = screens.first(where: { $0.localizedName == monitorName })
else {
  exit(1)
}

func firstWindow() -> AXUIElement? {
  guard
    let application = NSRunningApplication.runningApplications(withBundleIdentifier: "com.kunchenguid.baby-menu").first
  else {
    return nil
  }

  let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
  var windowsValue: CFTypeRef?
  guard
    AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
    let windows = windowsValue as? [AXUIElement]
  else {
    return nil
  }
  return windows.first
}

func position(_ window: AXUIElement) -> Bool {
  var sizeValue: CFTypeRef?
  guard
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
    let rawSize = sizeValue,
    CFGetTypeID(rawSize) == AXValueGetTypeID()
  else {
    return false
  }

  var windowSize = CGSize.zero
  guard AXValueGetValue(rawSize as! AXValue, .cgSize, &windowSize), windowSize.width > 0 else {
    return false
  }

  var targetPosition = CGPoint(
    x: targetScreen.frame.maxX - windowSize.width - 12,
    y: primaryScreen.frame.maxY - targetScreen.frame.maxY + 44
  )
  guard let positionValue = AXValueCreate(.cgPoint, &targetPosition) else {
    return false
  }

  return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue) == .success
}

let discoveryDeadline = Date().addingTimeInterval(3)
var window: AXUIElement?
while window == nil && Date() < discoveryDeadline {
  window = firstWindow()
  if window == nil {
    Thread.sleep(forTimeInterval: 0.002)
  }
}

guard let window else {
  exit(1)
}

for _ in 0..<75 {
  _ = position(window)
  Thread.sleep(forTimeInterval: 0.02)
}
