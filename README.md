# Vertex

O Vertex usa o runtime Madeira como núcleo de execução de programas Windows no iPhone. A interface SwiftUI antiga deste repositório apenas importava e armazenava arquivos .exe; ela não executava programas Windows e não é o aplicativo de distribuição.

## Build oficial com execução Windows

O IPA de distribuição é compilado a partir do projeto nativo do runtime em Vendor/Madeira/app/Madeira.xcodeproj, com identidade Vertex. Não use o IPA do antigo target XcodeGen Vertex.xcodeproj: ele não contém Wine/FEX.

Em macOS com Xcode e Homebrew:

    git clone --recurse-submodules https://github.com/joazinhoja96-blip/VertexEmulator.git
    cd VertexEmulator
    ./tools/build-vertex-ipa.sh

O resultado validado é dist/Vertex.ipa. O script verifica as fontes, aplica nome/ícone/bundle ID/URL scheme Vertex de forma idempotente, compila o runtime nativo e valida o IPA antes de exportar.

A compilação iOS exige macOS/Xcode. No Windows, edite o código e use GitHub Actions; não tente executar o build nativo localmente.

## Como executar um programa

1. Instale o IPA do workflow Vertex Windows Runtime.
2. Configure JIT conforme as instruções do app. JIT só está pronto quando o helper confirmar o processo e o estado real.
3. Copie a pasta completa do programa/jogo para o armazenamento do app usando Arquivos, conforme o guia de biblioteca do runtime.
4. Na biblioteca, adicione o executável dessa pasta e toque em Play.

A compatibilidade varia por programa. Nem todo jogo Windows funciona; dependências como Visual C++/.NET e APIs gráficas podem ser necessárias. O runtime executa localmente no iPhone. O Vertex Runner Python é apenas um handshake LAN e não participa da execução.

## Componentes

- Vendor/Madeira: submódulo upstream fixado em commit revisado. Não faça commit de alterações internas nele sem revisar licença e origem.
- tools/brand-madeira-for-vertex.py: overlay idempotente de identidade Vertex.
- tools/build-vertex-ipa.sh: entrada oficial para compilar, validar e exportar dist/Vertex.ipa.
- Vertex/ e VertexRunner/: protótipo SwiftUI/pareamento LAN legado; não são o motor Windows.

## Licenças

Madeira é GPL-3.0-or-later com a Madeira Converter Exception. Wine, FEX, DXMT, StikJIT e demais componentes mantêm suas próprias licenças. Consulte os avisos em Vendor/Madeira antes de redistribuir.
