import Foundation

struct ExecutableReport: Hashable {
    let architecture: String
    let importedLibraries: [String]
    let recommendations: [String]
    let notes: [String]
}

enum WindowsExecutableAnalyzer {
    static func analyze(_ url: URL) -> ExecutableReport {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return ExecutableReport(architecture: "Desconhecida", importedLibraries: [],
                                    recommendations: [], notes: ["Não foi possível ler o arquivo."])
        }

        let bytes = [UInt8](data)
        guard bytes.count >= 0x40, bytes[0] == 0x4D, bytes[1] == 0x5A,
              let peOffset = read32(bytes, 0x3C), Int(peOffset) + 24 <= bytes.count else {
            return ExecutableReport(architecture: "Formato inválido", importedLibraries: [],
                                    recommendations: [], notes: ["O arquivo não possui cabeçalho PE válido."])
        }

        let pe = Int(peOffset)
        guard bytes[pe] == 0x50, bytes[pe + 1] == 0x45,
              bytes[pe + 2] == 0, bytes[pe + 3] == 0,
              let machine = read16(bytes, pe + 4),
              let sectionCount = read16(bytes, pe + 6),
              let optionalSize = read16(bytes, pe + 20) else {
            return ExecutableReport(architecture: "Formato inválido", importedLibraries: [],
                                    recommendations: [], notes: ["Cabeçalho PE inválido."])
        }

        let architecture: String
        switch machine {
        case 0x014C: architecture = "x86 (32 bits)"
        case 0x8664: architecture = "x64 (64 bits)"
        case 0xAA64: architecture = "ARM64"
        default: architecture = "Desconhecida"
        }

        let optional = pe + 24
        guard optional + Int(optionalSize) <= bytes.count,
              let magic = read16(bytes, optional) else {
            return ExecutableReport(architecture: architecture, importedLibraries: [],
                                    recommendations: [], notes: ["Cabeçalho opcional PE incompleto."])
        }

        let directoryBase: Int
        switch magic {
        case 0x10B: directoryBase = optional + 96
        case 0x20B: directoryBase = optional + 112
        default:
            return ExecutableReport(architecture: architecture, importedLibraries: [],
                                    recommendations: [], notes: ["Formato PE não reconhecido."])
        }

        let sectionBase = optional + Int(optionalSize)
        var sections: [(virtualAddress: UInt32, virtualSize: UInt32, rawOffset: UInt32, rawSize: UInt32)] = []
        for index in 0..<Int(sectionCount) {
            let offset = sectionBase + index * 40
            guard offset + 40 <= bytes.count,
                  let virtualSize = read32(bytes, offset + 8),
                  let virtualAddress = read32(bytes, offset + 12),
                  let rawSize = read32(bytes, offset + 16),
                  let rawOffset = read32(bytes, offset + 20) else { break }
            sections.append((virtualAddress, virtualSize, rawOffset, rawSize))
        }

        func fileOffset(for rva: UInt32) -> Int? {
            for section in sections {
                let span = max(section.virtualSize, section.rawSize)
                if rva >= section.virtualAddress && rva - section.virtualAddress < span {
                    let offset = section.rawOffset + (rva - section.virtualAddress)
                    return Int(offset) < bytes.count ? Int(offset) : nil
                }
            }
            return Int(rva) < bytes.count ? Int(rva) : nil
        }

        func readCString(at offset: Int) -> String? {
            guard offset >= 0, offset < bytes.count else { return nil }
            var end = offset
            while end < min(bytes.count, offset + 260), bytes[end] != 0 { end += 1 }
            guard end > offset, end < bytes.count,
                  let value = String(bytes: bytes[offset..<end], encoding: .ascii) else { return nil }
            return value
        }

        var imports: [String] = []
        let importDirectory = directoryBase + 8
        if let importRVA = read32(bytes, importDirectory), importRVA != 0,
           let importOffset = fileOffset(for: importRVA) {
            for index in 0..<4096 {
                let descriptor = importOffset + index * 20
                guard descriptor + 20 <= bytes.count,
                      let nameRVA = read32(bytes, descriptor + 12) else { break }
                if nameRVA == 0 { break }
                if let nameOffset = fileOffset(for: nameRVA), let name = readCString(at: nameOffset) {
                    imports.append(name.lowercased())
                }
            }
        }

        let lowerImports = Set(imports)
        var recommendations: [String] = []
        var notes: [String] = []

        let needsVC = lowerImports.contains { name in
            name.hasPrefix("vcruntime") || name.hasPrefix("msvcp") ||
            name.hasPrefix("msvcr") || name.hasPrefix("concrt") ||
            name.hasPrefix("api-ms-win-crt")
        }
        if needsVC {
            switch architecture {
            case "x86 (32 bits)":
                recommendations.append("Visual C++ Redistributable (x86)")
            case "x64 (64 bits)":
                recommendations.append("Visual C++ Redistributable (x64)")
            case "ARM64":
                notes.append("O executável é ARM64; o motor x86/x64 planejado para o Vertex não declara suporte a esse formato.")
            default:
                recommendations.append("Visual C++ Redistributable (x86 e x64)")
            }
        }

        if lowerImports.contains("hostfxr.dll") || lowerImports.contains("coreclr.dll") {
            recommendations.append(".NET Desktop Runtime (versão exigida pelo aplicativo)")
        }
        if lowerImports.contains("mscoree.dll") {
            notes.append("Foi detectado .NET Framework clássico. O .NET Desktop Runtime moderno não substitui o .NET Framework.")
        }
        if lowerImports.contains("d3d9.dll") || lowerImports.contains("d3d10.dll") ||
            lowerImports.contains("d3d11.dll") || lowerImports.contains("d3d12.dll") ||
            lowerImports.contains("dxgi.dll") {
            notes.append("O executável importa bibliotecas DirectX; a compatibilidade gráfica depende do DXMT/Metal no motor Windows.")
        }
        if recommendations.isEmpty {
            notes.append("Nenhuma dependência comum foi identificada nos imports. Isso não garante que o aplicativo não precise de runtimes adicionais.")
        }

        return ExecutableReport(architecture: architecture,
                                importedLibraries: imports.sorted(),
                                recommendations: recommendations,
                                notes: notes)
    }

    private static func read16(_ bytes: [UInt8], _ offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= bytes.count else { return nil }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func read32(_ bytes: [UInt8], _ offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }
}
