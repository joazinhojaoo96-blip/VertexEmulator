import SwiftUI

struct WindowsComponentsView: View {
    @StateObject private var manager = ComponentDownloadManager.shared

    private let groups = ["Visual C++", ".NET"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Biblioteca de componentes").font(.headline)
                            Text("Instaladores oficiais que podem ser guardados no Vertex.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "shippingbox").font(.title2).foregroundStyle(.purple)
                    }
                    .padding(.vertical, 4)
                }

                Section("Motor de execução") {
                    engineRow("Wine ARM64EC", detail: "Camada de compatibilidade Windows", symbol: "wineglass")
                    engineRow("FEX-Emu", detail: "Tradução de código x86/x64 para ARM64", symbol: "cpu")
                    engineRow("DXMT / Metal", detail: "Tradução gráfica DirectX para Metal", symbol: "display")
                }

                ForEach(groups, id: \.self) { group in
                    Section(group) {
                        ForEach(WindowsComponent.catalog.filter { $0.group == group }) { component in
                            componentRow(component)
                        }
                    }
                }

                Section {
                    Label("Os instaladores ficam na pasta privada do Vertex. Baixado não significa instalado: a instalação dentro do Wine e a execução de .exe ainda dependem da integração do motor Windows.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Componentes")
        }
    }

    private func engineRow(_ name: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Não integrado").font(.caption2.weight(.medium)).foregroundStyle(.orange)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func componentRow(_ component: WindowsComponent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: component.group == ".NET" ? "curlybraces" : "c.square")
                .font(.title2).foregroundStyle(.purple).frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(component.name).font(.subheadline.weight(.semibold))
                Text(component.detail).font(.caption).foregroundStyle(.secondary)

                switch manager.state(for: component) {
                case .notDownloaded:
                    Text("Não baixado").font(.caption2).foregroundStyle(.secondary)
                case .downloading:
                    ProgressView("Baixando…").font(.caption2)
                case .downloaded:
                    Label("Baixado · não instalado", systemImage: "checkmark.circle.fill")
                        .font(.caption2).foregroundStyle(.green)
                case .failed(let message):
                    Text(message).font(.caption2).foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            switch manager.state(for: component) {
            case .notDownloaded, .failed:
                Button {
                    Task { await manager.download(component) }
                } label: {
                    Image(systemName: "arrow.down.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Baixar \(component.name)")
            case .downloading:
                ProgressView()
            case .downloaded:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(.vertical, 5)
    }
}
