import BackgroundTasks
import Combine
import Foundation
import StikPairFFI
import UserNotifications

@MainActor
final class PairingController: NSObject, ObservableObject {

    static let shared = PairingController()
    static let taskIdentifier = (Bundle.main.bundleIdentifier ?? "com.vertex.emulator") + ".pairing"

    enum Phase: Equatable {
        case idle
        case waiting
        case advertising
        case showPin(String)
        case browsingAppleTV
        case enteringAppleTVPin(AppleTVDevice)
        case pairingAppleTV(String)
        case success(PairedDevice)
        case failed(String)
    }

    struct PairedDevice: Equatable {
        var name: String
        var model: String
        var udid: String
        var pairingFilePath: String
    }

    @Published var phase: Phase = .idle
    @Published private(set) var appleTVs: [AppleTVDevice] = []

    private let bindAddress = "0.0.0.0"
    private let hostName = "Vertex"

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let appleTVDiscovery = AppleTVDiscovery()
    private var discoverySubscription: AnyCancellable?
    private var appleTVSession: OpaquePointer?
    private var activeAppleTV: AppleTVDevice?
    private var appleTVCancelled = false

    private var bgTask: BGContinuedProcessingTask?
    private var pairingStarted = false
    private var taskFinished = false

    var isRunning: Bool {
        if pairingStarted { return true }
        switch phase {
        case .waiting, .advertising, .showPin, .enteringAppleTVPin, .pairingAppleTV: return true
        default: return false
        }
    }

    private override init() {
        super.init()
        discoverySubscription = appleTVDiscovery.$devices
            .sink { [weak self] devices in self?.appleTVs = devices }
    }

    nonisolated func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PairingController.taskIdentifier,
            using: DispatchQueue.main
        ) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            MainActor.assumeIsolated {
                PairingController.shared.runPairing(task: task)
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        phase = .waiting

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        Task {
            guard await localNetwork.request() else {
                phase = .failed("A permissão de Rede Local é necessária. Ative-a em Ajustes > Apps > Vertex > Rede Local e tente novamente.")
                return
            }
            submitBackgroundTask()
        }
    }

    func browseForAppleTVs() {
        guard !isRunning else { return }
        phase = .browsingAppleTV
        Task {
            let authorized = await localNetwork.request()
            guard case .browsingAppleTV = phase else { return }
            guard authorized else {
                phase = .failed("A permissão de Rede Local é necessária. Ative-a em Ajustes > Apps > Vertex > Rede Local e tente novamente.")
                return
            }
            appleTVDiscovery.start()
        }
    }

    func pairAppleTV(_ device: AppleTVDevice) {
        guard !pairingStarted, let session = stikpair_apple_tv_session_new() else { return }
        appleTVDiscovery.stop()
        appleTVSession = session
        activeAppleTV = device
        appleTVCancelled = false
        pairingStarted = true
        phase = .pairingAppleTV(device.name)

        let name = hostName
        let outPath = Self.pairingFilePath()
        let sessionBits = UInt(bitPattern: session)
        let ctxBits = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
        DispatchQueue.global(qos: .userInitiated).async {
            guard let session = OpaquePointer(bitPattern: sessionBits) else { return }
            let ctx = UnsafeMutableRawPointer(bitPattern: ctxBits)
            var result = StikPairResult()
            let rc = device.host.withCString { hostC in
                name.withCString { nameC in
                    outPath.withCString { outC in
                        stikpair_apple_tv_session_run(
                            session, hostC, UInt16(device.port), nameC, outC,
                            appleTVPinCallback, ctx, &result)
                    }
                }
            }

            let outcome: Phase
            if rc == 0 {
                outcome = .success(PairedDevice(
                    name: cString(result.device_name),
                    model: cString(result.device_model),
                    udid: cString(result.device_udid),
                    pairingFilePath: cString(result.pairing_file_path)))
            } else {
                let message = cString(result.error)
                outcome = .failed(message.isEmpty ? "Apple TV pairing failed (code \(rc))" : message)
            }
            stikpair_result_free(&result)

            DispatchQueue.main.async {
                let cancelled = self.appleTVCancelled
                if self.appleTVSession == session {
                    self.appleTVSession = nil
                }
                stikpair_apple_tv_session_free(session)
                self.activeAppleTV = nil
                self.pairingStarted = false
                guard !cancelled else { return }
                self.phase = outcome
                if case .success = outcome {
                    self.postReturnNotification()
                }
            }
        }
    }

    func submitAppleTVPin(_ pin: String) {
        guard pin.count == 6, pin.allSatisfy(\.isNumber), let session = appleTVSession else { return }
        let rc = pin.withCString { stikpair_apple_tv_session_submit_pin(session, $0) }
        if rc == 0, let device = activeAppleTV {
            phase = .pairingAppleTV(device.name)
        }
    }

    func cancelAppleTVPairing() {
        appleTVCancelled = true
        if let session = appleTVSession {
            stikpair_apple_tv_session_cancel(session)
        }
        appleTVDiscovery.stop()
        phase = .idle
    }

    func reset() {
        guard !isRunning else { return }
        appleTVDiscovery.stop()
        phase = .idle
    }

    private func submitBackgroundTask() {
        let request = BGContinuedProcessingTaskRequest(
            identifier: PairingController.taskIdentifier,
            title: "Vertex",
            subtitle: "Waiting for a device to connect…")
        request.strategy = .queue

        do {
            try BGTaskScheduler.shared.submit(request)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, !self.pairingStarted else { return }
                self.runPairing(task: nil)
            }
        } catch {
            runPairing(task: nil)
        }
    }

    private func runPairing(task: BGContinuedProcessingTask?) {
        guard !pairingStarted else { return }
        pairingStarted = true
        taskFinished = false
        bgTask = task

        task?.progress.totalUnitCount = 100
        task?.progress.completedUnitCount = 5
        task?.expirationHandler = { [weak self] in
            guard let self else { return }
            self.finishTask(success: false)
            if self.isRunning {
                self.phase = .failed("Background time expired before a device connected. Tap Pair to try again.")
            }
        }

        let bind = bindAddress
        let name = hostName
        let outPath = Self.pairingFilePath()
        let ctxBits = UInt(bitPattern: Unmanaged.passRetained(self).toOpaque())

        DispatchQueue.global(qos: .userInitiated).async {
            let ctx = UnsafeMutableRawPointer(bitPattern: ctxBits)
            var result = StikPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    "Mac17,7".withCString { modelC in
                        outPath.withCString { outC in
                            stikpair_run_host(
                                bindC, 0, nameC, modelC, outC,
                                readyCallback, pinCallback, ctx, &result)
                        }
                    }
                }
            }

            let outcome: Phase
            if rc == 0 {
                outcome = .success(PairedDevice(
                    name: cString(result.device_name),
                    model: cString(result.device_model),
                    udid: cString(result.device_udid),
                    pairingFilePath: cString(result.pairing_file_path)))
            } else {
                let message = cString(result.error)
                outcome = .failed(message.isEmpty ? "Pairing failed (code \(rc))" : message)
            }
            stikpair_result_free(&result)
            if let ctx = ctx { Unmanaged<PairingController>.fromOpaque(ctx).release() }

            DispatchQueue.main.async {
                self.stopAdvertising()
                self.pairingStarted = false
                self.phase = outcome
                if case .success = outcome {
                    self.bgTask?.progress.completedUnitCount = 100
                    self.postReturnNotification()
                }
                self.finishTask(success: rc == 0)
            }
        }
    }

    private func finishTask(success: Bool) {
        guard !taskFinished else { return }
        taskFinished = true
        bgTask?.setTaskCompleted(success: success)
        bgTask = nil
    }

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port)
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.delegate = self
        service.publish()
        netService = service
    }

    fileprivate func presentPin(_ pin: String) {
        phase = .showPin(pin)
        bgTask?.progress.completedUnitCount = 50
        bgTask?.updateTitle("Vertex", subtitle: "Enter code \(pin) in Developer Mode")
        notify(id: "vertex.pin", title: "Vertex pairing code", body: "Digite o PIN \(pin) no Modo Desenvolvedor deste iPhone.")
    }

    fileprivate func presentAppleTVPin() {
        guard !appleTVCancelled, let device = activeAppleTV else { return }
        phase = .enteringAppleTVPin(device)
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }

    private func postReturnNotification() {
        notify(id: "vertex.done",
               title: "Pairing complete",
               body: "Return to Vertex to export the pairing file.")
    }

    private func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func pairingFilePath() -> String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("Vertex", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("RemotePairing.plist").path
    }
}

private let readyCallback: StikPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<Int(count) {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }

    DispatchQueue.main.async {
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let pinCallback: StikPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let pinString = String(cString: pin)
    DispatchQueue.main.async {
        controller.presentPin(pinString)
    }
}

private let appleTVPinCallback: StikPairAppleTvPinCb = { ctx in
    guard let ctx = ctx else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    DispatchQueue.main.async {
        controller.presentAppleTVPin()
    }
}

private func cString(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}

extension PairingController: NetServiceDelegate {
    nonisolated func netServiceDidPublish(_ sender: NetService) {
        Task { @MainActor in
            guard self.netService === sender else { return }
            self.phase = .advertising
        }
    }

    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        Task { @MainActor in
            guard self.netService === sender else { return }
            let code = errorDict[NetService.errorCode]?.intValue ?? -1
            self.stopAdvertising()
            self.phase = .failed("O iOS não conseguiu anunciar Pair with Vertex na rede local (erro \(code)). Verifique a permissão de Rede Local e tente novamente.")
        }
    }
}