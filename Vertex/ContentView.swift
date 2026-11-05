import SwiftUI
import UniformTypeIdentifiers
import Network

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
    @State private var runnerName = ""

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
                Text(paired ? "Conectado a \(runnerName).": "Encontre o Runner no Windows pela rede Wi-Fi local.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                Button(paired ? "Conectado" : "Pair Vertex") { showingPair = true }
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
        .sheet(isPresented: $showingPair) {
            PairSheet(isPaired: $paired, runnerName: $runnerName)
        }
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
    @Binding var runnerName: String
    @State private var code = ""
    @State private var runners: [NWBrowser.Result] = []
    @State private var selected: NWBrowser.Result?
    @State private var browser: NWBrowser?
    @State private var connection: NWConnection?
    @State private var status = "Procurando Vertex Runner na rede local..."
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("1. Inicie no Windows") {
                    Text("Execute o arquivo VertexRunner.py no computador. O iPhone e o Windows precisam estar na mesma rede Wi-Fi.")
                    Text("O Runner exibirá um código de 6 dígitos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("2. Computador encontrado") {
                    if runners.isEmpty {
                        Text("Procurando...").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(runners.enumerated()), id: \.offset) { item in
                            let result = item.element
                            Button {
                                selected = result
                            } label: {
                                HStack {
                                    Text(result.endpoint.debugDescription)
                                    Spacer()
                                    if selected?.endpoint.debugDescription == result.endpoint.debugDescription {
                                        Image(systemName: "checkmark").foregroundStyle(.purple)
                                    }
                                }
                            }
                        }
                    }
                }
                Section("3. Código de pareamento") {
                    TextField("Código de 6 dígitos", text: $code)
                        .keyboardType(.numberPad)
                    Button(busy ? "Conectando..." : "Conectar") { pair() }
                        .disabled(busy || selected == nil || code.count != 6)
                }
                Section("Status") {
                    Text(status).font(.footnote)
                }
                Section("Modo Desenvolvedor do iPhone") {
                    Text("O iOS não permite que aplicativos ativem esse modo automaticamente. Ative manualmente em Ajustes → Privacidade e Segurança → Modo Desenvolvedor e reinicie o iPhone se solicitado.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Pair Vertex")
            .toolbar { Button("Fechar") { browser?.cancel(); dismiss() } }
            .onAppear { startDiscovery() }
            .onDisappear { browser?.cancel(); connection?.cancel() }
        }
    }

    private func startDiscovery() {
        let b = NWBrowser(for: .bonjour(type: "_vertex-runner._tcp", domain: "local."), using: .tcp)
        browser = b
        b.browseResultsChangedHandler = { results, _ in
            DispatchQueue.main.async {
                runners = Array(results)
                if selected == nil { selected = results.first }
                status = results.isEmpty ? "Nenhum Runner encontrado. Confira a rede e o firewall do Windows." : "Runner encontrado. Digite o código mostrado no Windows."
            }
        }
        b.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                DispatchQueue.main.async { status = "Falha na descoberta: \(error.localizedDescription)" }
            }
        }
        b.start(queue: .main)
    }

    private func pair() {
        guard let selected else { return }
        busy = true
        status = "Validando código..."
        let conn = NWConnection(to: selected.endpoint, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let payload = try? JSONSerialization.data(withJSONObject: ["code": code])
                guard let payload else { return }
                let body = "POST /pair HTTP/1.1\r\nHost: vertex-runner\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
                conn.send(content: Data(body.utf8) + payload, completion: .contentProcessed { error in
                    if let error {
                        DispatchQueue.main.async { busy = false; status = "Falha ao enviar: \(error.localizedDescription)" }
                        conn.cancel()
                    } else {
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, receiveError in
                            let response = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                            DispatchQueue.main.async {
                                busy = false
                                if response.contains("200 OK") && response.contains("\"ok\": true") {
                                    isPaired = true
                                    runnerName = selected.endpoint.debugDescription
                                    status = "Pareamento concluído!"
                                    conn.cancel()
                                    dismiss()
                                } else if response.contains("401") {
                                    status = "Código incorreto. Confira o código no Windows."
                                } else {
                                    status = receiveError.map { "Erro de conexão: \($0.localizedDescription)" } ?? "O Runner recusou o pareamento. Tente novamente."
                                }
                            }
                            conn.cancel()
                        }
                    }
                })
            case .failed(let error):
                DispatchQueue.main.async { busy = false; status = "Não foi possível conectar: \(error.localizedDescription)" }
                conn.cancel()
            default: break
            }
        }
        conn.start(queue: .main)
    }
}

extension UTType {
    static let windowsExecutable = UTType(filenameExtension: "exe") ?? .data
}
