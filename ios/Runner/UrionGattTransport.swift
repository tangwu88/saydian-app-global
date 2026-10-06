import CoreBluetooth
import Flutter
import Foundation

/// CoreBluetooth transports verified EB1 advertisements and 16-byte frames.
/// All health interpretation is shared with Android in Dart.
final class UrionGattTransport: NSObject, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
  private let serviceID = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
  private let writeID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
  private let notifyID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
  private let infoID = CBUUID(string: "180A")
  private let firmwareID = CBUUID(string: "2A26")
  private let hardwareID = CBUUID(string: "2A27")
  private lazy var central = CBCentralManager(delegate: self, queue: .main)
  private var sink: FlutterEventSink?
  private var devices: [String: CBPeripheral] = [:]
  private var descriptions: [String: [String: Any]] = [:]
  private var active: CBPeripheral?
  private var retiring: [UUID: CBPeripheral] = [:]
  private var retirementWaiters: [(Bool) -> Void] = []
  private var retirementTimer: Timer?
  private var nativeID: String?
  private var writer: CBCharacteristic?
  private var notify: CBCharacteristic?
  private var pendingScan: FlutterResult?
  private var pendingConnect: FlutterResult?
  private var pendingWrite: FlutterResult?
  private var scanTimer: Timer?
  private var firmware: String?
  private var hardware: String?
  private var generation = 0

  override init() {
    super.init()
    _ = central
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "scanDevices":
      finishScan()
      devices.removeAll()
      descriptions.removeAll()
      if central.state == .poweredOff {
        result(FlutterError(code: "BLUETOOTH_DISABLED", message: "请开启手机蓝牙后再试", details: nil))
        return
      }
      if central.state == .unauthorized {
        result(FlutterError(code: "BLE_PERMISSION_REQUIRED", message: "允许相关权限后使用", details: nil))
        return
      }
      pendingScan = result
      beginScanIfReady()
      scanTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
        self?.finishScan()
      }
    case "stopScan":
      finishScan()
      result(nil)
    case "connect":
      guard pendingConnect == nil else {
        result(FlutterError(code: "CONNECT_IN_PROGRESS", message: "正在连接手表", details: nil))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let id = arguments["deviceId"] as? String,
        let peripheral = devices[id] else {
        result(FlutterError(code: "DEVICE_NOT_FOUND", message: "请重新搜索并选择手表", details: nil))
        return
      }
      finishScan()
      closeConnection()
      generation += 1
      let requestGeneration = generation
      pendingConnect = result
      whenRetired { [weak self] closed in
        guard let self, self.generation == requestGeneration, self.pendingConnect != nil else { return }
        guard closed else {
          self.pendingConnect = nil
          result(FlutterError(code: "DISCONNECT_PENDING", message: "手表连接尚未关闭，请稍后重试", details: nil))
          return
        }
        self.nativeID = id
        self.active = peripheral
        peripheral.delegate = self
        self.central.connect(peripheral, options: nil)
      }
    case "disconnect":
      closeConnection()
      whenRetired { closed in
        result(closed ? nil : FlutterError(code: "DISCONNECT_PENDING", message: "手表连接尚未关闭，请稍后重试", details: nil))
      }
    case "getDeviceDetails":
      result(details())
    case "writeFrame":
      let arguments = call.arguments as? [String: Any]
      let bytes = arguments?["bytes"] as? FlutterStandardTypedData
      if let command = bytes?.data.first, IOSWellnessPolicy.blockedEB1Commands.contains(command) {
        result(FlutterError(code: "IOS_WELLNESS_SCOPE", message: "Not available in this iOS edition.", details: nil))
        return
      }
      guard let peripheral = active, let characteristic = writer,
        let bytes, bytes.data.count == 16, pendingWrite == nil else {
        result(FlutterError(code: "WRITE_UNAVAILABLE", message: "手表暂时无响应，请重试", details: nil))
        return
      }
      pendingWrite = result
      peripheral.writeValue(bytes.data, for: characteristic, type: .withResponse)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func beginScanIfReady() {
    if central.state == .poweredOn && pendingScan != nil {
      central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
  }

  private func finishScan() {
    scanTimer?.invalidate()
    scanTimer = nil
    if central.isScanning { central.stopScan() }
    if let completion = pendingScan {
      pendingScan = nil
      completion(Array(descriptions.values))
    }
  }

  private func details() -> [String: Any]? {
    guard let id = nativeID, writer != nil else { return nil }
    var value = descriptions[id] ?? ["id": id, "name": "U19", "hardwareAddress": id]
    if let firmware { value["firmwareVersion"] = firmware }
    if let hardware { value["model"] = hardware }
    return value
  }

  private func closeConnection() {
    generation += 1
    pendingConnect?(FlutterError(code: "DISCONNECTED", message: "手表已断开连接", details: nil))
    pendingConnect = nil
    pendingWrite?(FlutterError(code: "DISCONNECTED", message: "手表已断开连接", details: nil))
    pendingWrite = nil
    let previous = active
    active = nil
    nativeID = nil
    writer = nil
    notify = nil
    firmware = nil
    hardware = nil
    if let peripheral = previous {
      peripheral.delegate = nil
      if peripheral.state != .disconnected {
        retiring[peripheral.identifier] = peripheral
        central.cancelPeripheralConnection(peripheral)
      }
    }
  }

  private func whenRetired(_ completion: @escaping (Bool) -> Void) {
    if retiring.isEmpty {
      completion(true)
      return
    }
    retirementWaiters.append(completion)
    guard retirementTimer == nil else { return }
    retirementTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
      guard let self else { return }
      self.retirementTimer = nil
      // CoreBluetooth has no close() primitive. A timeout must not pretend
      // that cancellation completed or allow a second connection to start.
      let waiters = self.retirementWaiters
      self.retirementWaiters.removeAll()
      waiters.forEach { $0(false) }
    }
  }

  @discardableResult
  private func finishRetirement(_ peripheral: CBPeripheral) -> Bool {
    guard retiring[peripheral.identifier] === peripheral else { return false }
    retiring.removeValue(forKey: peripheral.identifier)
    if retiring.isEmpty {
      retirementTimer?.invalidate()
      retirementTimer = nil
      let waiters = retirementWaiters
      retirementWaiters.removeAll()
      waiters.forEach { $0(true) }
    }
    return true
  }

  private func failConnection() {
    pendingConnect?(FlutterError(code: "CONNECT_FAILED", message: "暂时无法连接手表，请重试", details: nil))
    pendingConnect = nil
    closeConnection()
  }

  private func completeConnection() {
    guard let completion = pendingConnect, writer != nil, notify != nil else { return }
    pendingConnect = nil
    completion(["generation": generation])
    if let value = details() { sink?(["type": "deviceDetails", "payload": value]) }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      beginScanIfReady()
      return
    }
    if pendingScan != nil { finishScan() }
    if active != nil {
      let id = nativeID
      let ready = writer != nil
      closeConnection()
      if ready, let id {
        sink?(["type": "disconnected", "payload": ["deviceId": id]])
      }
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber) {
    guard let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else { return }
    let data = [UInt8](manufacturer)
    guard data.count >= 10, data[0] == 0x34, data[1] == 0x12,
      data[2] == 0xFE, data[3] == 0xE7 else { return }
    let id = data[4..<10].map { String(format: "%02X", $0) }.joined(separator: ":")
    let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
      ?? peripheral.name ?? "U19"
    let value: [String: Any] = ["id": id, "name": name,
      "hardwareAddress": id, "rssi": RSSI.intValue]
    devices[id] = peripheral
    descriptions[id] = value
    sink?(["type": "scanDevice", "payload": value])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    if retiring[peripheral.identifier] === peripheral {
      central.cancelPeripheralConnection(peripheral)
      return
    }
    guard peripheral === active else { return }
    peripheral.discoverServices([serviceID, infoID])
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    if finishRetirement(peripheral) { return }
    if peripheral === active { failConnection() }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    if finishRetirement(peripheral) { return }
    guard peripheral === active else { return }
    let id = nativeID
    let ready = writer != nil
    if pendingConnect != nil { failConnection() } else { closeConnection() }
    if ready, let id { sink?(["type": "disconnected", "payload": ["deviceId": id]]) }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard peripheral === active, error == nil,
      let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else {
      if peripheral === active { failConnection() }
      return
    }
    peripheral.discoverCharacteristics([writeID, notifyID], for: service)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard peripheral === active else { return }
    if service.uuid == serviceID {
      guard error == nil,
        let write = service.characteristics?.first(where: { $0.uuid == writeID }),
        let notification = service.characteristics?.first(where: { $0.uuid == notifyID }),
        write.properties.contains(.write), notification.properties.contains(.notify) else {
        failConnection()
        return
      }
      writer = write
      notify = notification
      peripheral.setNotifyValue(true, for: notification)
    } else if service.uuid == infoID {
      if let firmwareCharacteristic = service.characteristics?.first(where: { $0.uuid == firmwareID }) {
        peripheral.readValue(for: firmwareCharacteristic)
      } else if let hardwareCharacteristic = service.characteristics?.first(where: { $0.uuid == hardwareID }) {
        peripheral.readValue(for: hardwareCharacteristic)
      } else {
        completeConnection()
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?) {
    guard peripheral === active, characteristic.uuid == notifyID else { return }
    guard error == nil, characteristic.isNotifying else { failConnection(); return }
    if let info = peripheral.services?.first(where: { $0.uuid == infoID }) {
      peripheral.discoverCharacteristics([firmwareID, hardwareID], for: info)
    } else {
      completeConnection()
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard peripheral === active else { return }
    if characteristic.uuid == notifyID {
      guard error == nil, let bytes = characteristic.value, let id = nativeID else { return }
      sink?(["type": "bytes", "bytes": FlutterStandardTypedData(bytes: bytes),
        "deviceId": id, "generation": generation])
      return
    }
    if error == nil, let bytes = characteristic.value {
      let value = String(data: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
      if characteristic.uuid == firmwareID { firmware = value }
      if characteristic.uuid == hardwareID { hardware = value }
    }
    if characteristic.uuid == firmwareID,
      let info = peripheral.services?.first(where: { $0.uuid == infoID }),
      let hardwareCharacteristic = info.characteristics?.first(where: { $0.uuid == hardwareID }) {
      peripheral.readValue(for: hardwareCharacteristic)
    } else {
      completeConnection()
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    guard peripheral === active, characteristic.uuid == writeID, let completion = pendingWrite else { return }
    pendingWrite = nil
    if error == nil { completion(nil) }
    else { completion(FlutterError(code: "WRITE_FAILED", message: "手表暂时无响应，请重试", details: nil)) }
  }
}
