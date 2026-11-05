import SwiftUI

struct NativePairingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = PairingController.shared
    @AppStorage("vertex.nativePairingComplete") private var pairingComplete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image("VertexMark").resizable().scaledToFit().frame(width: 92, height: 92)
                Text("Pair Vertex").font(.title2.bold())
                pairingContent
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Pareamento nativo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } } }
            .onChange(of: controller.phase) { _, phase in
                if case .success = phase { pairingComplete = true }
            }
        }
    }

    @ViewBuilder
    private var pairingContent: some View {
        switch controller.phase {
        case .idle:
            VStack(spacing: 12) {
                Text("O Vertex anuncia o serviÃ§o de pareamento do prÃ³prio iPhone. Nenhum computador externo Ã© necessÃ¡rio.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Iniciar pareamento") { controller.start() }.buttonStyle(.borderedProminent)
            }
        case .waiting:
            VStack(alignment: .leading, spacing: 14) {
                ProgressView("Aguardando confirmaÃ§Ã£o nos Ajustesâ€¦")
                Text("No mesmo iPhone:").font(.headline)
                step(1, "Abra Ajustes.")
                step(2, "Entre em Privacidade e SeguranÃ§a.")
                step(3, "Abra Modo Desenvolvedor.")
                step(4, "Toque em â€œPair with Vertexâ€ e informe o PIN exibido aqui.")
                Text("Mantenha o Vertex aberto atÃ© o iOS concluir o pareamento.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .showPin(let pin):
            VStack(spacing: 14) {
                Text("Digite este PIN nos Ajustes do iPhone:").multilineTextAlignment(.center)
                Text(pin).font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit().tracking(6).textSelection(.enabled)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(.thinMaterial, in: Capsule())
                ProgressView("Aguardando o iOSâ€¦")
            }
        case .success(let device):
            VStack(spacing: 14) {
                Label("Pareamento concluÃ­do", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                if !device.name.isEmpty {
                    Text("\(device.name) Â· \(device.model)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ShareLink(item: URL(fileURLWithPath: device.pairingFilePath)) {
                    Label("Exportar arquivo de pareamento", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
                Button("Concluir") { controller.reset(); dismiss() }.buttonStyle(.bordered)
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Label("Falha no pareamento", systemImage: "xmark.octagon.fill")
                    .font(.headline).foregroundStyle(.red)
                Text(message).font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).textSelection(.enabled)
                Button("Tentar novamente") {
                    controller.reset()
                    controller.start()
                }.buttonStyle(.borderedProminent)
            }
        default:
            VStack(spacing: 12) {
                ProgressView()
                Text("Processando pareamentoâ€¦").foregroundStyle(.secondary)
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(number)).font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(.tint, in: Circle())
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
