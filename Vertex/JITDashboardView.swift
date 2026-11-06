import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// JIT setup dashboard. Pairing-file import is real; JIT is never reported
/// as enabled until a compatible helper confirms it for a target process.
struct JITDashboardView: View {
    @State private var toast: Toast?
    @State private var showingPairingImporter = false
    @State private var pairingFileStored = false

    private var supportsOnDevicePairing: Bool {
        if #available(iOS 27.0, *) { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.055, green: 0.065, blue: 0.12),
                             Color(red: 0.12, green: 0.075, blue: 0.22),
                             Color(uiColor: .systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        statusCard
                        pairingFileCard
                        compatibilityCard
                        requirementsCard
                        safetyNote
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Vertex JIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay(alignment: .top) {
                if let toast {
                    ToastBanner(toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
        }
        .fileImporter(
            isPresented: $showingPairingImporter,
            allowedContentTypes: [.propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    showToast(title: "Nenhum arquivo selecionado",
                              message: "Selecione um arquivo de pareamento .plist.")
                    return
                }
                importPairingFile(from: url)
            case .failure(let error):
                showToast(title: "Importação cancelada",
                          message: error.localizedDescription)
            }
        }
        .onAppear(perform: refreshPairingState)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundStyle(.cyan)
                Text("DEVELOPER TOOLKIT")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Text("JIT Engine")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Prepare o pareamento e confira o estado do ambiente de depuração.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("ESTADO DO JIT", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("NÃO ATIVADO")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(.orange.opacity(0.13)).frame(width: 58, height: 58)
                    Image(systemName: "pause.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aguardando helper StikJIT")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("O arquivo de pareamento é apenas uma credencial. Ele não ativa JIT sozinho.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showToast(title: "Helper ainda não integrado",
                          message: "O Vertex precisa do helper compatível e de uma confirmação real do processo antes de ativar JIT.")
            } label: {
                HStack {
                    Image(systemName: "stethoscope")
                    Text("Verificar ambiente")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(15)
                .background(
                    LinearGradient(colors: [.purple, .blue.opacity(0.85)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var pairingFileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Arquivo de pareamento", icon: "lock.shield")
            HStack(spacing: 10) {
                Image(systemName: pairingFileStored ? "checkmark.seal.fill" : "doc.badge.plus")
                    .font(.title2)
                    .foregroundStyle(pairingFileStored ? .green : .cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pairingFileStored ? "Arquivo guardado no Keychain" : "Nenhum arquivo importado")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(pairingFileStored
                         ? "Plist reconhecido e protegido neste iPhone. A validade para o helper ainda não foi testada."
                         : "Importe o RPPairing .plist gerado para este dispositivo.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showingPairingImporter = true
            } label: {
                Label(pairingFileStored ? "Substituir arquivo" : "Importar RPPairing .plist",
                      systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding(13)
                    .background(.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(.cyan)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if pairingFileStored {
                Button(role: .destructive) {
                    deletePairingFile()
                } label: {
                    Label("Apagar arquivo salvo", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var compatibilityCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Compatibilidade", icon: "iphone")
            infoRow("Versão do iOS", value: UIDevice.current.systemVersion,
                    symbol: "checkmark.circle.fill", color: .green)
            infoRow("Pareamento no próprio iPhone",
                    value: supportsOnDevicePairing ? "Requer integração PairableHost" : "Use arquivo de pareamento",
                    symbol: "info.circle.fill", color: .orange)
            infoRow("Arquivo RPPairing", value: pairingFileStored ? "Importado (não testado)" : "Não importado",
                    symbol: pairingFileStored ? "checkmark.circle.fill" : "minus.circle",
                    color: pairingFileStored ? .green : .gray)
            infoRow("Helper StikJIT", value: "Ainda não integrado",
                    symbol: "clock.fill", color: .orange)
            infoRow("Confirmação real do JIT", value: "Pendente",
                    symbol: "lock.fill", color: .gray)
        }
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Próximas integrações", icon: "square.stack.3d.up")
            requirement("Remote Pairing", detail: "Implementar o host PairableHost e o anúncio Bonjour no iOS 27+.")
            requirement("Helper StikJIT", detail: "Adicionar o framework compatível e a comunicação com o helper.")
            requirement("Canal do dispositivo", detail: "Configurar e verificar o transporte suportado.")
            requirement("JIT verificado", detail: "Só mostrar sucesso após o helper confirmar o processo selecionado.")
        }
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var safetyNote: some View {
        Label {
            Text("O arquivo é armazenado com proteção ThisDeviceOnly no Keychain. O Modo Desenvolvedor é separado e precisa ser habilitado pelo usuário nas Ajustes.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
        } icon: {
            Image(systemName: "info.circle.fill").foregroundStyle(.cyan)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.white)
    }

    private func infoRow(_ title: String, value: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            Text(title).foregroundStyle(.white.opacity(0.78))
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    private func requirement(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func refreshPairingState() {
        pairingFileStored = (try? PairingFileStore.load()) != nil
    }

    private func importPairingFile(from url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            try PairingFileStore.save(data)
            pairingFileStored = true
            showToast(title: "Arquivo protegido",
                      message: "O plist foi validado e salvo no Keychain deste iPhone. A compatibilidade com StikJIT ainda não foi testada.")
        } catch {
            showToast(title: "Não foi possível importar",
                      message: error.localizedDescription)
        }
    }

    private func deletePairingFile() {
        do {
            try PairingFileStore.delete()
            pairingFileStored = false
            showToast(title: "Arquivo apagado",
                      message: "A credencial de pareamento foi removida do Keychain.")
        } catch {
            showToast(title: "Falha ao apagar", message: error.localizedDescription)
        }
    }

    private func showToast(title: String, message: String) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            toast = Toast(title: title, message: message)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.4))
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}

private struct Toast: Equatable {
    let title: String
    let message: String
}

private struct ToastBanner: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(red: 0.28, green: 0.18, blue: 0.62),
                                    Color(red: 0.12, green: 0.30, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }
}
