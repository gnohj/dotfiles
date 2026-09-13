// IOHIDEventSystem thermal sensors: readable instantly and without root, unlike powermetrics.
import Foundation

typealias ClientRef = CFTypeRef
typealias ServiceRef = CFTypeRef

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_ a: CFAllocator?) -> ClientRef?
@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ c: ClientRef?, _ m: CFDictionary?) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ c: ClientRef?) -> CFArray?
@_silgen_name("IOHIDServiceClientCopyProperty")
func IOHIDServiceClientCopyProperty(_ s: ServiceRef?, _ k: CFString) -> CFTypeRef?
@_silgen_name("IOHIDServiceClientCopyEvent")
func IOHIDServiceClientCopyEvent(_ s: ServiceRef?, _ t: Int64, _ o: Int32, _ ts: UInt64) -> CFTypeRef?
@_silgen_name("IOHIDEventGetFloatValue")
func IOHIDEventGetFloatValue(_ e: CFTypeRef?, _ f: Int32) -> Double

let kTemperature: Int64 = 15
let prefix = ProcessInfo.processInfo.environment["CPU_TEMP_SENSORS"] ?? "PMU tdie"

guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { exit(1) }
_ = IOHIDEventSystemClientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 0x0005] as CFDictionary)
guard let services = IOHIDEventSystemClientCopyServices(client) as? [ServiceRef] else { exit(1) }

var total = 0.0
var count = 0
for service in services {
    guard let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String,
          name.hasPrefix(prefix),
          let event = IOHIDServiceClientCopyEvent(service, kTemperature, 0, 0) else { continue }
    let value = IOHIDEventGetFloatValue(event, Int32(kTemperature << 16))
    // A disconnected sensor reads 0; averaging it in would drag the whole figure down.
    if value > 0 { total += value; count += 1 }
}
guard count > 0 else { exit(1) }
print(Int((total / Double(count)).rounded()))
