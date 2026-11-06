import SwiftUI
import UniformTypeIdentifiers
import Network

struct WindowsProgram: Identifiable, Hashable, Codable {
    enum State: String, Codable {
        case imported = "Importado"
    }

    let id: UUID
    let name: String
    var state: State
    var storedFileName: String?

    init(id: UUID = UUID(), name: String, state: State = .imported, storedFileName: String? = nil) {
        self.id = id
        self.name = name
        self.state = state
        self.storedFileName = storedFileName
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("vertex.programs.v1") private var savedPrograms = "[]"
    @AppStorage("vertex.runner.paired.v1") private var paired = false
    @AppStorage("vertex.runner.name.v1") private var runnerName = ""

    @State private var programs: [WindowsProgram] = []
    @State private var selectedProgram: WindowsProgram?
    @State private var showingImporter = false
    @State private var showingPair = false
    @State private var importError: String?

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if programs.isEmpty {
                        ContentUnavailableView {
                            Image("VertexMark").resizable().scaledToFit().frame(width: 72, height: 72)
                        } description: {
                            Text("Importe um executável Windows para mantê-lo na sua biblioteca.")
                        } actions: {
                            Button("Importar .exe") { showingImporter = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        List {
                            ForEach(programs) { program in
                                Button { selectedProgram = program } label: {
                                    ProgramRow(program: program)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: deletePrograms)
                        }
                    }
                }
                .navigationTitle("Biblioteca")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !programs.isEmpty { EditButton() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingImporter = true } label: {
                            Label("Importar", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .tabItem { Label("Biblioteca", systemImage: "square.grid.2x2.fill") }

            NavigationStack {
                VStack(spacing: 18) {
                    Image("VertexMark").resizable().scaledToFit().frame(width: 104, height: 104)
                    Text(paired ? "Runner pareado" : "Conecte seu Runner")
                        .font(.title3.bold())
                    Text(paired
                         ? "Conexão autorizada com \(runnerName)."
                         : "Encontre o Vertex Runner no Windows pela rede local.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Button(paired ? "Gerenciar conexão" : "Parear computador") {
                        showingPair = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    if paired {
                        Button("Desconectar", role: .destructive) {
                            paired = false
                            runnerName = ""
                        }
                    }
                    Spacer()
                    Label("O pareamento não executa programas Windows.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding(.top, 28)
                .navigationTitle("Vertex")
            }
            .tabItem { Label("Conexão", systemImage: "bolt.horizontal.circle.fill") }
        }
        .tint(.purple)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.windowsExecutable]) { result in
            guard case let .success(url) = result else { return }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let name = url.deletingPathExtension().lastPathComponent
            guard !programs.contains(where: { $0.name == name }) else { return }
            do {
                let folder = try importedFilesDirectory()
                let destination = folder
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                try FileManager.default.copyItem(at: url, to: destination)
                programs.insert(
                    WindowsProgram(name: name, storedFileName: destination.lastPathComponent),
                    at: 0
                )
                persistPrograms()
            } catch {
                importError = error.localizedDescription
            }
        }
        .sheet(item: $selectedProgram) { program in
            ProgramSheet(program: program)
        }
        .sheet(isPresented: $showingPair) {
            PairSheet(isPaired: $paired, runnerName: $runnerName)
        }
        .alert("Falha ao importar arquivo", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Não foi possível copiar o arquivo.")
        }
        .onAppear(perform: restorePrograms)
        .onChange(of: scenePhase) { _, phase in
            // Keep user data and the pairing state in storage. Network browsing is
            // restarted by PairSheet when the app becomes active again.
            if phase == .active { restorePrograms() }
        }
    }

    private func restorePrograms() {
        guard let data = savedPrograms.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([WindowsProgram].self, from: data) else {
            programs = []
            return
        }
        programs = decoded
    }

    private func importedFilesDirectory() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("ImportedExecutables", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func persistPrograms() {
        guard let data = try? JSONEncoder().encode(programs),
              let value = String(data: data, encoding: .utf8) else { return }
        savedPrograms = value
    }

    private func deletePrograms(at offsets: IndexSet) {
        for index in offsets {
            guard let fileName = programs[index].storedFileName,
                  let folder = try? importedFilesDirectory() else { continue }
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(fileName))
        }
        programs.remove(atOffsets: offsets)
        persistPrograms()
    }
}

private struct ProgramRow: View {
    let program: WindowsProgram

    var body: some View {
        HStack(spacing: 13) {
            Image("VertexMark").resizable().scaledToFit().frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(program.name).font(.headline)
                Text("Executável Windows • armazenado na biblioteca")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(program.state.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
        }
        .padding(.vertical, 4)
    }
}

private struct ProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    let program: WindowsProgram

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image("VertexMark").resizable().scaledToFit().frame(width: 96, height: 96)
                Text(program.name).font(.title2.bold())
                Text("Arquivo importado")
                    .foregroundStyle(.secondary)
                ContentUnavailableView(
                    "Execução ainda não implementada",
                    systemImage: "pc",
                    description: Text("O iPhone não executa arquivos .exe. O Vertex atualmente importa e organiza os arquivos e permite parear o Runner; o motor de execução remota ainda precisa ser desenvolvido.")
                )
                Spacer()
            }
            .padding(24)
            .navigationTitle("Detalhes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
        }
    }
}

private struct PairSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Binding var isPaired: Bool
    @Binding var runnerName: String

    @State private var code = ""
    @State private var runners: [NWBrowser.Result] = []
    @State private var selected: NWBrowser.Result?
    @State private var browser: NWBrowser?
    @State private var connection: NWConnection?
    @State private var status = "Procurando Vertex Runner na rede local..."
    @State private var busy = false
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section("1. Inicie no Windows") {
                    Text("Execute VertexRunner.py no computador. Os dois dispositivos precisam estar na mesma rede Wi-Fi.")
                    Text("O Runner exibirá um código temporário de 6 dígitos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("2. Computador encontrado") {
                    if runners.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Procurando na rede local…").foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(Array(runners.enumerated()), id: \.offset) { item in
                            let result = item.element
                            Button { selected = result } label: {
                                HStack {
                                    Text(result.endpoint.debugDescription)
                                        .lineLimit(2)
                                    Spacer()
                                    if selected?.endpoint.debugDescription == result.endpoint.debugDescription {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.purple)
                                    }
                                }
                            }
                        }
                    }
                }
                Section("3. Código de pareamento") {
                    TextField("Código de 6 dígitos", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: code) { _, value in
                            code = String(value.filter(\.isNumber).prefix(6))
                        }
                    Button(busy ? "Conectando…" : "Conectar") { pair() }
                        .disabled(busy || selected == nil || code.count != 6)
                }
                Section("Status") {
                    Text(status).font(.footnote)
                }
                Section("Modo Desenvolvedor") {
                    Text("O Vertex não ativa esse recurso. Se necessário para desenvolvimento, habilite manualmente em Ajustes → Privacidade e Segurança → Modo Desenvolvedor.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Parear Runner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { stopNetworking(); dismiss() }
                }
            }
            .onAppear(perform: startDiscovery)
            .onDisappear(perform: stopNetworking)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    startDiscovery()
                } else if phase == .background || phase == .inactive {
                    // iOS suspends network activity in the background. Tear down
                    // transient browsing and restart cleanly on foreground.
                    stopNetworking()
                    status = "Pausado. A descoberta será retomada ao voltar ao app."
                }
            }
        }
    }

    private func stopNetworking() {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        busy = false
    }

    private func startDiscovery() {
        guard browser == nil else { return }
        status = "Procurando Vertex Runner na rede local…"
        let newBrowser = NWBrowser(
            for: .bonjour(type: "_vertex-runner._tcp", domain: "local."),
            using: .tcp
        )
        browser = newBrowser
        newBrowser.browseResultsChangedHandler = { results, _ in
            DispatchQueue.main.async {
                runners = Array(results)
                if let selected,
                   !results.contains(where: { $0.endpoint.debugDescription == selected.endpoint.debugDescription }) {
                    self.selected = nil
                }
                if self.selected == nil { self.selected = results.first }
                status = results.isEmpty
                    ? "Nenhum Runner encontrado. Confira Wi-Fi e firewall do Windows."
                    : "Runner encontrado. Digite o código exibido no Windows."
            }
        }
        newBrowser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                DispatchQueue.main.async {
                    status = "Falha na descoberta: \(error.localizedDescription)"
                    browser?.cancel()
                    browser = nil
                }
            }
        }
        newBrowser.start(queue: .main)
    }

    private func pair() {
        guard let selected, !busy else { return }
        busy = true
        status = "Conectando e validando o código…"
        let attempt = UUID()
        requestID = attempt
        let conn = NWConnection(to: selected.endpoint, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                guard requestID == attempt else { conn.cancel(); return }
                guard let payload = try? JSONSerialization.data(withJSONObject: ["code": code]) else {
                    finishFailure("Não foi possível preparar a solicitação.", attempt: attempt)
                    return
                }
                let headers = "POST /pair HTTP/1.1\r\nHost: vertex-runner\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
                conn.send(content: Data(headers.utf8) + payload, completion: .contentProcessed { error in
                    if let error {
                        finishFailure("Falha ao enviar: \(error.localizedDescription)", attempt: attempt)
                    } else {
                        receiveResponse(from: conn, buffer: Data(), attempt: attempt)
                    }
                })
            case .failed(let error):
                finishFailure("Não foi possível conectar: \(error.localizedDescription)", attempt: attempt)
            default:
                break
            }
        }
        conn.start(queue: .main)
    }

    private func receiveResponse(from conn: NWConnection, buffer: Data, attempt: UUID) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            var received = buffer
            if let data { received.append(data) }
            let response = String(data: received, encoding: .utf8) ?? ""
            let parts = response.components(separatedBy: "\r\n\r\n")
            let headers = parts.first ?? ""
            let body = parts.count > 1 ? parts.dropFirst().joined(separator: "\r\n\r\n") : ""
            let expectedLength = headers
                .components(separatedBy: "\r\n")
                .first(where: { $0.lowercased().hasPrefix("content-length:") })
                .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) }
            let bodyComplete = expectedLength.map { body.utf8.count >= $0 } ?? !body.isEmpty
            let headersComplete = parts.count > 1

            if (headersComplete && bodyComplete) || isComplete || error != nil {
                DispatchQueue.main.async {
                    guard requestID == attempt else { conn.cancel(); return }
                    busy = false
                    if response.contains("200 OK") && body.contains("\"ok\": true") {
                        isPaired = true
                        runnerName = selected?.endpoint.debugDescription ?? "Vertex Runner"
                        status = "Pareamento concluído."
                        connection = nil
                        conn.cancel()
                        dismiss()
                    } else if response.contains("401") {
                        status = "Código incorreto. Confira o código no Windows."
                        connection = nil
                        conn.cancel()
                    } else {
                        status = error.map { "Erro de conexão: \($0.localizedDescription)" }
                            ?? "Resposta incompleta do Runner. Tente novamente."
                        connection = nil
                        conn.cancel()
                    }
                }
            } else {
                receiveResponse(from: conn, buffer: received, attempt: attempt)
            }
        }
    }

    private func finishFailure(_ message: String, attempt: UUID) {
        DispatchQueue.main.async {
            guard requestID == attempt else { return }
            busy = false
            status = message
            connection?.cancel()
            connection = nil
        }
    }
}

extension UTType {
    static let windowsExecutable = UTType(filenameExtension: "exe") ?? .data
}
