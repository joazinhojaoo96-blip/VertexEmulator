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
    @State private var paired = false

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
                Text(paired ? "Vertex conectado" : "Conecte seu Vertex Runner").font(.title3.bold())
                Text(paired ? "Pronto para abrir sessões Windows." : "Pair Vertex conecta este iPhone ao seu runner.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                Button(paired ? "Conectado" : "Pair Vertex") { showingPair = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .tabItem { Label("Vertex", systemImage: "bolt.horizontal.circle.fill") }
        }
        .tint(.purple)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.windowsExecutable]) { result in
            guard case let .success(urls) = result, let file = urls.first else { return }
            programs.insert(WindowsProgram(name: file.deletingPathExtension().lastPathComponent, state: .imported), at: 0)
        }
        .sheet(item: $selectedProgram) { program in
            ProgramSheet(program: program, paired: paired) { updated in
                guard let index = programs.firstIndex(where: { $0.id == updated.id }) else { return }
                programs[index] = updated
                selectedProgram = updated
            }
        }
        .sheet(isPresented: $showingPair) { PairSheet(isPaired: $paired) }
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
                Text(program.state.rawValue).foregroundStyle(.secondary)
                Button("Baixar dependências") { prepare() }
                    .buttonStyle(.bordered).disabled(program.state == .preparing)
                Button("Iniciar") { program.state = .running; onChange(program) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!paired || program.state != .ready)
                if !paired { Text("Conecte o Vertex Runner para iniciar.").font(.caption).foregroundStyle(.secondary) }
                Spacer()
            }
            .padding(.top, 34).padding(.horizontal, 24)
            .navigationTitle("Programa").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
        }
    }

    private func prepare() {
        program.state = .preparing
        onChange(program)
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            program.state = .ready
            onChange(program)
        }
    }
}

private struct PairSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPaired: Bool
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Pair Vertex") {
                    Text("Digite o código do seu Vertex Runner.")
                    TextField("Código", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                }
                Button("Conectar") { isPaired = !code.isEmpty; if isPaired { dismiss() } }.disabled(code.isEmpty)
            }
            .navigationTitle("Pair Vertex")
            .toolbar { Button("Cancelar") { dismiss() } }
        }
    }
}

extension UTType {
    static let windowsExecutable = UTType(filenameExtension: "exe") ?? .data
}
