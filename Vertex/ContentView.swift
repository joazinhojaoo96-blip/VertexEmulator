import SwiftUI
import UniformTypeIdentifiers

struct WindowsProgram: Identifiable, Hashable {
    enum State: String { case imported = "Importado", preparing = "Preparando", ready = "Pronto", running = "Em execução" }
    let id = UUID()
    let name: String
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
                            Text("Adicione um .exe para aparecer aqui.")
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
                .toolbar { Button { showingImporter = true } label: { Label("Adicionar", systemImage: "plus.circle.fill") } }
            }
            .tabItem { Label("Programas", systemImage: "square.grid.2x2.fill") }

            VStack(spacing: 18) {
                Image("VertexMark").resizable().scaledToFit().frame(width: 112, height: 112)
                Text(paired ? "iPhone pareado" : "Pareamento do iPhone").font(.title3.bold())
                Text(paired
                     ? "O pareamento nativo foi concluído neste dispositivo."
                     : "Pareie este iPhone com o serviço de Modo Desenvolvedor do próprio iOS. Não é necessário um PC externo.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                Button(paired ? "Ver pareamento" : "Pair Vertex") { showingPair = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .tabItem { Label("Vertex", systemImage: "bolt.horizontal.circle.fill") }
        }
        .tint(.purple)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.windowsExecutable]) { result in
            guard case let .success(file) = result else { return }
            programs.insert(WindowsProgram(name: file.deletingPathExtension().lastPathComponent, state: .imported), at: 0)
        }
        .sheet(item: $selectedProgram) { program in
            ProgramSheet(paired: paired, program: program) { updated in
                guard let index = programs.firstIndex(where: { $0.id == updated.id }) else { return }
                programs[index] = updated
                selectedProgram = updated
            }
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
                Text("Executável Windows").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(program.state.rawValue).font(.caption.weight(.semibold)).foregroundStyle(.purple)
        }
    }
}

private struct ProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    let paired: Bool
    @State var program: WindowsProgram
    let onChange: (WindowsProgram) -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image("VertexMark").resizable().scaledToFit().frame(width: 112, height: 112)
                Text(program.name).font(.title2.bold())
                Text("A execução de programas Windows ainda não está implementada.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text(paired ? "O pareamento do iPhone está pronto, mas não executa arquivos .exe." : "Conclua primeiro o pareamento nativo do iPhone.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.top, 34).padding(.horizontal, 24)
            .navigationTitle("Programa").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
        }
    }
}

extension UTType {
    static let windowsExecutable = UTType(filenameExtension: "exe") ?? .data
}
