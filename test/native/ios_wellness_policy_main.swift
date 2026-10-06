import Foundation

@main
struct IOSWellnessPolicyTests {
  static func main() {
    let capabilities = IOSWellnessPolicy.capabilities([
      "metrics": ["steps", "sleep", "heart_rate", "blood_pressure", "unknown_sensor"],
      "manualMetrics": ["heart_rate"],
      "features": ["find_watch", "health_monitoring"],
      "integratedFeatures": ["health_assessment", "camera"],
    ])
    precondition(capabilities["metrics"] as? [String] == ["steps", "sleep"])
    precondition((capabilities["manualMetrics"] as? [String])?.isEmpty == true)
    precondition(capabilities["features"] as? [String] == ["find_watch"])
    precondition(IOSWellnessPolicy.record(["type": "blood_pressure"]) == nil)
    precondition(IOSWellnessPolicy.record(["type": "unknown_sensor"]) == nil)
    let original: [String: Any] = ["type": "sleep", "id": "synthetic", "samples": [1, 2],
      "values": ["value": 7, "deepHours": 2, "sleepScore": 90, "heartRate": 70]]
    let projected = IOSWellnessPolicy.record(original)!
    precondition(projected["samples"] == nil)
    precondition((projected["values"] as? [String: Int]) == ["value": 7, "deepHours": 2])
    precondition((original["values"] as? [String: Int])?["sleepScore"] == 90)
    precondition(IOSWellnessPolicy.event(type: "measurementComplete", payload: [:]) == nil)
    precondition(IOSWellnessPolicy.blockedEB1Commands.contains(0x14))
    precondition(IOSWellnessPolicy.blockedEB1Commands.contains(0x16))
    precondition(IOSWellnessPolicy.blockedEB1Commands.contains(0x2c))
    precondition(!IOSWellnessPolicy.blockedEB1Commands.contains(0x07))
    let activity: [String: Any] = ["id": "synthetic-old", "type": "steps",
      "deviceId": "synthetic-device", "measuredAt": "2026-10-06T17:00:00.000Z",
      "timezone": "+08:00", "values": ["value": 20], "unit": "步"]
    let summary = WearablePayloadMapper.activityDailySummary(activity, localDate: "2026-10-07")
    precondition(summary["measuredAt"] as? String == activity["measuredAt"] as? String)
    precondition(summary["timezone"] as? String == "+08:00")
    precondition(summary["aggregation"] as? [String: String] == ["kind": "daily_summary", "localDate": "2026-10-07"])
    precondition(summary["id"] as? String == "synthetic-device:steps:daily:2026-10-07")
    precondition(activity["aggregation"] == nil)
    precondition(activity["id"] as? String == "synthetic-old")
    let anotherDay = WearablePayloadMapper.activityDailySummary(activity, localDate: "2026-10-06")
    precondition(anotherDay["id"] as? String != summary["id"] as? String)
    print("iOS wellness native policy: passed")
  }
}
