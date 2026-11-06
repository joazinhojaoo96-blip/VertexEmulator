# Integração do runtime Windows no Vertex

## Arquitetura de distribuição

O executável Windows não pode ser iniciado pelo SwiftUI antigo. O app de distribuição usa o projeto iOS completo em Vendor/Madeira/app/Madeira.xcodeproj, que contém o ciclo de vida do Wine, a tradução x86/x64 via FEX, ARM64EC/WoW64, gráficos Metal e integração JIT do runtime.

A pasta Vertex/ original permanece como protótipo legado e não é ligada ao runtime por um simples import. O Runner Python é somente um handshake LAN; não é executor.

## Build/exportação

A entrada oficial é tools/build-vertex-ipa.sh. Ela aplica a identidade Vertex ao submódulo sem mover o gitlink, compila com o script upstream e exporta dist/Vertex.ipa somente depois de validar o conteúdo do IPA e o bundle ID.

O workflow Vertex Windows Runtime usa a mesma entrada. O build exige macOS, Xcode, Homebrew, toolchains e submódulos recursivos. Windows não compila esse target iOS.

## Fluxo de uso

- Instalar o IPA de runtime, não o artefato antigo Vertex-unsigned-IPA.
- Concluir a configuração JIT no próprio runtime e verificar confirmação positiva do helper.
- Importar/copiar a pasta completa do programa; executáveis podem depender de DLLs, arquivos de dados e diretório de trabalho.
- Selecionar o executável na biblioteca e iniciar uma sessão.
- Diagnosticar incompatibilidades pelo log/sumário do runtime. Não prometer compatibilidade universal.

## Critério de aceite

Uma build CI bem-sucedida confirma que o IPA foi produzido e sua identidade foi validada. A execução só pode ser declarada habilitada após instalar em iPhone físico, confirmar JIT e iniciar um executável de teste localmente, verificando imagem, entrada, áudio e encerramento.
