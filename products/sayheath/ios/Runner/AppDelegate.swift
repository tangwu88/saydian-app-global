import Flutter
import UIKit
import Foundation

// The shared EB1 transport calls this static limit in addition to the product gate.
enum IOSWellnessPolicy {
  static let blockedEB1Commands: Set<UInt8> = [0x14,0x15,0x16,0x2c,0x2d,0x32,0x34,0x35,0x36,0x38,0x39,0x3a]
  static let urionLocalCommands = blockedEB1Commands
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bridge: UrionGattTransport?
  private var flags: Set<String> = []
  private var deviceID: String?
  private var deadline: TimeInterval = 0
  private var stopUntil: TimeInterval = 0
  #if !targetEnvironment(simulator)
  private var luck: CoolWearWearableBridge?
  private var qring: QRingWearableBridge?
  #endif
  private var channels: [AnyObject] = []
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let reg = engineBridge.pluginRegistry.registrar(forPlugin:"SayHeathWearables") else { return }
    let ctl = FlutterMethodChannel(name:"app.saydian.say/device",binaryMessenger:reg.messenger())
    ctl.setMethodCallHandler { [weak self] call, reply in
      guard let self else { reply(nil); return }
      if call.method == "prepare" && self.bridge == nil {
        let bridge=UrionGattTransport()
        bridge.productWriteGate = { [weak self] frame, id in self?.allows(frame,id) == true }
        self.bridge=bridge
        let m=FlutterMethodChannel(name:"cc.saidian/urion_methods",binaryMessenger:reg.messenger())
        m.setMethodCallHandler { call, reply in bridge.handle(call,result:reply) }
        let e=FlutterEventChannel(name:"cc.saidian/urion_events",binaryMessenger:reg.messenger())
        e.setStreamHandler(bridge); self.channels.append(contentsOf:[m,e])
        #if !targetEnvironment(simulator)
        self.luck=CoolWearWearableBridge(messenger:reg.messenger()); self.qring=QRingWearableBridge(messenger:reg.messenger())
        #endif
      } else if call.method == "policy" {
        let args=call.arguments as? [String:Any]
        self.deviceID=args?["device"] as? String
        self.flags=Set(args?["features"] as? [String] ?? [])
        self.deadline=ProcessInfo.processInfo.systemUptime + min(60,max(0,args?["seconds"] as? Double ?? 0))
        self.stopUntil=0
      } else if call.method == "stopSchedule" {
        guard let id=call.arguments as? String, !id.isEmpty else {reply(FlutterError(code:"device",message:nil,details:nil));return}
        self.deviceID=id; self.stopUntil=ProcessInfo.processInfo.systemUptime+20
      } else if call.method != "prepare" {reply(FlutterMethodNotImplemented);return}
      reply(nil)
    }
    channels=[ctl]
  }
  private func allows(_ frame:Data,_ id:String?) -> Bool {
    guard frame.count==16 else{return false}
    let c=frame[0],now=ProcessInfo.processInfo.systemUptime
    if [0x03,0x07].contains(c){return true}
    guard let id, id==deviceID else{return false}
    if now < stopUntil && (c==0x36 || (c==0x35 && frame[1]==0)){return true}
    guard now < deadline else{return false}
    let keys:[UInt8:String]=[0x14:"bloodPressure",0x32:"bloodPressure",0x15:"heartRate",0x38:"heartRate",0x2d:"bloodOxygen",0x39:"bloodOxygen",0x34:"pulse",0x3a:"pulse",0x35:"scheduledBP",0x36:"scheduledBP"]
    return keys[c].map(flags.contains) ?? false
  }
}
