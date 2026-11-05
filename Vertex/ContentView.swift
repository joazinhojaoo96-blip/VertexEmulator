import SwiftUI
import UniformTypeIdentifiers

struct WindowsProgram: Identifiable, Hashable {
    enum State: String { case imported = "Importado", preparing = "Preparando", ready = "Pronto", running = "Em execução" }
    let id = UUID()
    let name: String
    let report: ExecutableReport
    var state: State
}

struct ContentView: View {
    @State private var programs: [WindowsProgram] = []
    @State private var selectedProgram: WindowsProgram?
    @State private var showingImporter = false
    @State private var showingPair = false
    @AppStorage("vertex.nativePairingComplete") private var paired = false

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if programs.isEmpty {
                        ContentUnavailableView {
                            Image("VertexMark").resizable().scaledToFit().frame(width: 72, height: 72)
                        } description: {
                            Text("Adicione um arquivo .exe para analisar e adicionar à biblioteca.")
                        } actions: {
                            Button("Adicionar .exe") { showingImporter = true }.buttonStyle(.borderedProminent)
                        }
                    } else {
                        List(programs) { program in
                            Button { selectedProgram = program } label: { ProgramRow(program: program) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Programas")
                .toolbar {
                    Button { showingImporter = true } label: {
                        Label("Adicionar", systemImage: "plus.circle.fill")
                    }
                }
            }
            .tabItem { Label("Programas", systemImage: "square.grid.2x2.fill") }

            WindowsComponentsView()
                .tabItem { Label("Componentes", systemImage: "shippingbox.fill") }

            VStack(spacing: 18) {
                Image("VertexMark").resizable().scaledToFit().frame(width: 112, height: 112)
                Text(paired ? "iPhone pareado" : "Pareamento do iPhone").font(.title3.bold())
                Text(paired
                     ? "O pareamento nativo foi concluído neste dispositivo."
                     : "Ative o anúncio local do Vertex e selecione “Pair with Vertex” em Ajustes > Privacidade e Segurança > Modo Desenvolvedor.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                Button(paired ? "Ver pareamento" : "Pair Vertex") { showingPair = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .tabItem { Label("Vertex", systemImage: "bolt.horizontal.circle.fill") }
        }
        .tint(.blue)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.windowsExecutable]) { result in
            guard case let .success(file) = result else { return }
            let report = WindowsExecutableAnalyzer.analyze(file)
            programs.insert(
                WindowsProgram(name: file.deletingPathExtension().lastPathComponent,
                               report: report, state: .imported),
                at: 0
            )
        }
        .sheet(item: $selectedProgram) { program in
            ProgramSheet(program: program)
        }
        .sheet(isPresented: $showingPair) { NativePairingView() }
    }
}

private struct ProgramRow: View {
    let program: WindowsProgram

    var body: some View {
        HStack(spacing: 13) {
            Image("VertexMark").resizable().scaledToFit().frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(program.name).font(.headline)
                Text(program.report.architecture).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(program.state.rawValue).font(.caption.weight(.semibold)).foregroundStyle(.blue)
        }
    }
}

private struct ProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    let program: WindowsProgram

    var body: some View {
        NavigationStack {
            List {
                Section("Arquivo") {
                    LabeledContent("Programa", value: program.name)
                    LabeledContent("Arquitetura", value: program.report.architecture)
                    LabeledContent("Bibliotecas importadas", value: "\(program.report.importedLibraries.count)")
                }

                Section("Dependências identificadas") {
                    if program.report.recommendations.isEmpty {
                        Text("Nenhuma dependência conhecida foi detectada.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(program.report.recommendations, id: \.self) { item in
                            Label(item, systemImage: "shippingbox")
                        }
                        Text("Abra a aba Componentes para baixar os pacotes correspondentes.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if !program.report.notes.isEmpty {
                    Section("Observações") {
                        ForEach(program.report.notes, id: \.self) { note in
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Label("Motor Windows ainda não integrado", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline).foregroundStyle(.orange)
                    Text("A análise PE e o gerenciador de downloads já estão disponíveis. Para executar o .exe, ainda é necessário integrar Wine + FEX + DXMT/Metal e o suporte JIT.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {} label: {
                        Label("Executar", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .disabled(true)
                }
            }
            .navigationTitle("Detalhes do programa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
        }
    }
}

extension UTType {
    static let windowsExecutable = UTType(filenameExtension: "exe") ?? .data
}
