import SwiftUI

struct NativePairingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = PairingController.shared
    @AppStorage("vertex.nativePairingComplete") private var pairingComplete = false

    private let accent = Color.blue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    pairingContent
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Pair Vertex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .tint(accent)
            .onChange(of: controller.phase) { _, phase in
                if case .success = phase { pairingComplete = true }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.gradient).frame(width: 92, height: 92)
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Pareamento do iPhone")
                .font(.title2.bold())
            Text("Anuncie o Vertex para que ele apareça na opção “Pair with Vertex” do Modo Desenvolvedor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
    }

    @ViewBuilder
    private var pairingContent: some View {
        switch controller.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 16) {
                Label("Como iniciar", systemImage: "list.number")
                    .font(.headline)
                instruction(1, "Toque no botão azul abaixo para anunciar o Vertex na rede local.")
                instruction(2, "Abra Ajustes → Privacidade e Segurança → Modo Desenvolvedor.")
                instruction(3, "Na seção de pareamento, toque em “Pair with Vertex”.")
                instruction(4, "Volte ao Vertex e digite o PIN quando ele aparecer.")
                Button {
                    controller.start()
                } label: {
                    Label("Ativar Pair Vertex", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(accent)
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

        case .waiting:
            statusCard(symbol: "wifi", title: "Solicitando acesso à rede local", detail: "O iOS precisa autorizar a descoberta Bonjour antes de o Vertex poder aparecer no Modo Desenvolvedor.", color: .blue) {
                ProgressView("Aguardando permissão…")
                    .font(.footnote)
                Text("Se o iOS mostrar um pedido de acesso à rede local, toque em Permitir.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .advertising:
            statusCard(symbol: "dot.radiowaves.left.and.right", title: "Vertex anunciado", detail: "O serviço Pair Vertex foi publicado na rede local. Agora abra os Ajustes do iPhone.", color: .blue) {
                instruction(1, "Ajustes")
                instruction(2, "Privacidade e Segurança")
                instruction(3, "Modo Desenvolvedor")
                instruction(4, "Pair with Vertex")
                Text("Deixe esta tela aberta. O PIN será exibido aqui quando o iOS iniciar a conexão.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

        case .showPin(let pin):
            statusCard(symbol: "lock.open.fill", title: "Digite o código de pareamento", detail: "Nos Ajustes, selecione Pair with Vertex e informe este PIN.", color: .blue) {
                Text(pin)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
                ProgressView("Aguardando confirmação do iOS…")
                    .font(.footnote)
            }

        case .success(let device):
            statusCard(symbol: "checkmark.seal.fill", title: "Pareamento concluído", detail: "O dispositivo foi pareado com sucesso.", color: .green) {
                if !device.name.isEmpty {
                    LabeledContent("Dispositivo", value: device.name)
                    LabeledContent("Modelo", value: device.model)
                }
                ShareLink(item: URL(fileURLWithPath: device.pairingFilePath)) {
                    Label("Exportar arquivo de pareamento", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                Button("Concluir") { controller.reset(); dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }

        case .failed(let message):
            statusCard(symbol: "exclamationmark.triangle.fill", title: "Não foi possível parear", detail: message, color: .red) {
                Button {
                    controller.retry()
                } label: {
                    Label("Tentar novamente", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }

        default:
            statusCard(symbol: "gearshape.2.fill", title: "Conectando", detail: "O Vertex está processando o pareamento.", color: .blue) {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(accent, in: Circle())
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func statusCard<Content: View>(
        symbol: String,
        title: String,
        detail: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(color)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
