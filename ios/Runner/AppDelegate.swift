import CoreBluetooth
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var obdBridge: ObdBleBridge?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AutoPulseOBDBLE") {
      obdBridge = ObdBleBridge(messenger: registrar.messenger())
    }
  }
}

/// ELM-compatible BLE UART. Known services are explicit so data is never
/// written to an unrelated characteristic on a nearby peripheral.
private final class ObdBleBridge: NSObject, CBCentralManagerDelegate,
    CBPeripheralDelegate, FlutterStreamHandler {
  private struct Profile {
    let service: CBUUID
    let receive: CBUUID
    let send: CBUUID

    init(_ service: String, _ receive: String, _ send: String) {
      self.service = CBUUID(string: service)
      self.receive = CBUUID(string: receive)
      self.send = CBUUID(string: send)
    }
  }

  private let profiles = [
    Profile("FFF0", "FFF1", "FFF2"),
    Profile("FFE0", "FFE1", "FFE1"),
    Profile("6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
            "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
            "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"),
  ]
  private var central: CBCentralManager?
  private var discovered: [UUID: CBPeripheral] = [:]
  private var peripheral: CBPeripheral?
  private var tx: CBCharacteristic?
  private var rx: CBCharacteristic?
  private var events: FlutterEventSink?
  private var permission: FlutterResult?
  private var scan: FlutterResult?
  private var connecting: FlutterResult?
  private var writing: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "autopulse/obd/methods", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, reply in
        guard let self = self else { reply(FlutterMethodNotImplemented); return }
        self.handle(call, reply)
      }
    FlutterEventChannel(name: "autopulse/obd/events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  private func issue(_ message: String) -> FlutterError {
    FlutterError(code: "obd_ble", message: message, details: nil)
  }

  private func handle(_ call: FlutterMethodCall, _ reply: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "permission":
      guard permission == nil else { reply(issue("Bluetooth permission request is pending.")); return }
      permission = reply
      if let manager = central {
        centralManagerDidUpdateState(manager)
      } else {
        central = CBCentralManager(delegate: self, queue: .main)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
        self?.permission?(false)
        self?.permission = nil
      }
    case "devices":
      guard let manager = central, manager.state == .poweredOn, scan == nil else {
        reply(issue("Turn on Bluetooth and allow access before scanning.")); return
      }
      discovered.removeAll()
      scan = reply
      manager.scanForPeripherals(withServices: profiles.map { $0.service }, options: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.finishScan() }
    case "connect":
      guard let manager = central, manager.state == .poweredOn,
        peripheral == nil, connecting == nil,
        let address = args?["address"] as? String,
        let id = UUID(uuidString: address), let device = discovered[id] else {
        reply(issue("Scan for the adapter again before connecting.")); return
      }
      peripheral = device
      connecting = reply
      device.delegate = self
      manager.connect(device, options: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self, weak device] in
        guard let self = self, self.peripheral === device, self.connecting != nil else { return }
        self.drop("BLE adapter did not expose a compatible serial service.", notify: false)
      }
    case "write":
      guard let device = peripheral, let tx = tx, connecting == nil,
        writing == nil, let bytes = args?["bytes"] as? FlutterStandardTypedData else {
        reply(issue("Adapter is not ready to send a command.")); return
      }
      let mode: CBCharacteristicWriteType =
        tx.properties.contains(.write) ? .withResponse : .withoutResponse
      guard bytes.data.count <= device.maximumWriteValueLength(for: mode),
        mode == .withResponse || device.canSendWriteWithoutResponse else {
        reply(issue("Adapter cannot accept this command right now.")); return
      }
      if mode == .withResponse { writing = reply }
      device.writeValue(bytes.data, for: tx, type: mode)
      if mode == .withoutResponse { reply(nil) }
    case "disconnect":
      drop("Adapter disconnected.", notify: false)
      reply(nil)
    case "settings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else { reply(nil); return }
      UIApplication.shared.open(url)
      reply(nil)
    default:
      reply(FlutterMethodNotImplemented)
    }
  }

  private func finishScan() {
    guard let reply = scan else { return }
    scan = nil
    central?.stopScan()
    reply(discovered.values.sorted { $0.identifier.uuidString < $1.identifier.uuidString }.map {
      ["name": $0.name ?? "BLE OBD adapter", "address": $0.identifier.uuidString]
    })
  }

  private func drop(_ message: String, notify: Bool) {
    let device = peripheral
    peripheral = nil
    tx = nil
    rx = nil
    let connectReply = connecting
    let writeReply = writing
    connecting = nil
    writing = nil
    if let device = device { central?.cancelPeripheralConnection(device) }
    connectReply?(issue(message))
    writeReply?(issue(message))
    if notify && device != nil { events?(["type": "disconnected"]) }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central.state != .unknown && central.state != .resetting else { return }
    let reply = permission
    permission = nil
    reply?(central.state == .poweredOn)
    if central.state != .poweredOn {
      finishScan()
      drop("Bluetooth is unavailable.", notify: true)
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String: Any], rssi RSSI: NSNumber) {
    if scan != nil { discovered[peripheral.identifier] = peripheral }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard self.peripheral === peripheral else { return }
    peripheral.discoverServices(profiles.map { $0.service })
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                      error: Error?) {
    if self.peripheral === peripheral { drop("Could not connect to the BLE adapter.", notify: true) }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                      error: Error?) {
    if self.peripheral === peripheral { drop("BLE adapter disconnected.", notify: true) }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard self.peripheral === peripheral else { return }
    guard error == nil,
      let profile = profiles.first(where: { p in peripheral.services?.contains { $0.uuid == p.service } == true }),
      let service = peripheral.services?.first(where: { $0.uuid == profile.service }) else {
      drop("This adapter has no supported BLE serial service.", notify: false); return
    }
    peripheral.discoverCharacteristics([profile.receive, profile.send], for: service)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                  error: Error?) {
    guard self.peripheral === peripheral else { return }
    guard error == nil, let profile = profiles.first(where: { $0.service == service.uuid }),
      let r = service.characteristics?.first(where: { $0.uuid == profile.receive }),
      let w = service.characteristics?.first(where: { $0.uuid == profile.send }),
      r.properties.contains(.notify) || r.properties.contains(.indicate),
      w.properties.contains(.write) || w.properties.contains(.writeWithoutResponse) else {
      drop("The adapter has incompatible BLE serial characteristics.", notify: false); return
    }
    tx = w
    rx = r
    peripheral.setNotifyValue(true, for: r)
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                  error: Error?) {
    guard self.peripheral === peripheral, rx === characteristic else { return }
    guard error == nil && characteristic.isNotifying else {
      drop("Could not receive readings from the BLE adapter.", notify: false); return
    }
    let reply = connecting
    connecting = nil
    reply?(nil)
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    guard self.peripheral === peripheral, rx === characteristic, error == nil,
      let bytes = characteristic.value else { return }
    events?(["type": "data", "bytes": FlutterStandardTypedData(bytes: bytes)])
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    guard self.peripheral === peripheral, tx === characteristic else { return }
    let reply = writing
    writing = nil
    reply?(error == nil ? nil : issue("The BLE adapter could not receive the command."))
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    events = nil
    return nil
  }
}
