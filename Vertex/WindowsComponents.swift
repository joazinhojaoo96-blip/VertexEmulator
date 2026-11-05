import Foundation
import Combine

struct WindowsComponent: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let fileName: String
    let downloadURL: URL
    let group: String

    static let catalog: [WindowsComponent] = [
        .init(id: "vc14-x64", name: "Visual C++ Redistributable (x64)",
              detail: "Bibliotecas MSVC para aplicativos Windows de 64 bits.",
              fileName: "vc_redist.x64.exe",
              downloadURL: URL(string: "https://aka.ms/vc14/vc_redist.x64.exe")!,
              group: "Visual C++"),
        .init(id: "vc14-x86", name: "Visual C++ Redistributable (x86)",
              detail: "Bibliotecas MSVC para aplicativos Windows de 32 bits.",
              fileName: "vc_redist.x86.exe",
              downloadURL: URL(string: "https://aka.ms/vc14/vc_redist.x86.exe")!,
              group: "Visual C++"),
        .init(id: "dotnet10-x64", name: ".NET Desktop Runtime 10 (x64)",
              detail: "Runtime para aplicativos desktop modernos .NET de 64 bits.",
              fileName: "windowsdesktop-runtime-10-x64.exe",
              downloadURL: URL(string: "https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x64.exe")!,
              group: ".NET"),
        .init(id: "dotnet10-x86", name: ".NET Desktop Runtime 10 (x86)",
              detail: "Runtime para aplicativos desktop modernos .NET de 32 bits.",
              fileName: "windowsdesktop-runtime-10-x86.exe",
              downloadURL: URL(string: "https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x86.exe")!,
              group: ".NET")
    ]
}

@MainActor
final class ComponentDownloadManager: ObservableObject {
    static let shared = ComponentDownloadManager()

    enum State: Equatable {
        case notDownloaded
        case downloading
        case downloaded(URL)
        case failed(String)
    }

    @Published private(set) var states: [String: State] = [:]
    private let directory: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("Vertex/Components", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for component in WindowsComponent.catalog {
            let file = directory.appendingPathComponent(component.fileName)
            states[component.id] = FileManager.default.fileExists(atPath: file.path)
                ? .downloaded(file)
                : .notDownloaded
        }
    }

    func state(for component: WindowsComponent) -> State {
        states[component.id] ?? .notDownloaded
    }

    func download(_ component: WindowsComponent) async {
        guard state(for: component) != .downloading else { return }
        states[component.id] = .downloading

        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: component.downloadURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw DownloadError.httpStatus(http.statusCode)
            }

            let finalHost = response.url?.host?.lowercased() ?? ""
            guard finalHost == "microsoft.com" || finalHost.hasSuffix(".microsoft.com") else {
                throw DownloadError.untrustedSource
            }

            let destination = directory.appendingPathComponent(component.fileName)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)

            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard byteCount > 2 else { throw DownloadError.emptyFile }
            let signature = try Data(contentsOf: destination, options: .mappedIfSafe).prefix(2)
            guard signature == Data([0x4D, 0x5A]) else { throw DownloadError.invalidInstaller }

            states[component.id] = .downloaded(destination)
        } catch {
            states[component.id] = .failed(error.localizedDescription)
        }
    }

    enum DownloadError: LocalizedError {
        case httpStatus(Int)
        case emptyFile
        case untrustedSource
        case invalidInstaller

        var errorDescription: String? {
            switch self {
            case .httpStatus(let code): return "O servidor respondeu HTTP \(code)."
            case .emptyFile: return "O arquivo baixado está vazio."
            case .untrustedSource: return "O download não terminou em um domínio oficial da Microsoft."
            case .invalidInstaller: return "O arquivo recebido não parece ser um instalador Windows válido."
            }
        }
    }
}
