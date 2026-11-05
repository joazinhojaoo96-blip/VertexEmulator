# Vertex

Aplicativo iOS para experimentos de compatibilidade Windows e pareamento nativo.

## Biblioteca de programas

O Vertex importa arquivos `.exe` e faz uma análise estática básica do cabeçalho PE:
- identifica arquitetura x86, x64 ou ARM64;
- lê a tabela de DLLs importadas;
- procura sinais de dependências Visual C++ e .NET;
- destaca imports DirectX que dependem da camada gráfica.

A análise é heurística. Dependências carregadas dinamicamente, componentes opcionais e versões exatas do runtime podem não aparecer na tabela de imports.

## Gerenciador de componentes

A aba **Componentes** baixa instaladores oficiais da Microsoft:
- Visual C++ Redistributable x86 e x64;
- .NET Desktop Runtime 10 x86 e x64.

Os arquivos são guardados em `Application Support/Vertex/Components`. O estado **Baixado · não instalado** é intencional: sem o motor Windows, o Vertex não consegue executar esses instaladores dentro de um prefixo Wine. O .NET Desktop Runtime moderno também não substitui o .NET Framework clássico.

Os links Visual C++ apontam para os permalinks oficiais da Microsoft. Consulte a documentação para escolher a versão compatível com cada aplicativo.

## Estado da execução de .exe

A execução real ainda não está habilitada. O iOS não executa PE/Windows diretamente. O Vertex precisa integrar:
- Wine ARM64EC/WoW64 para as APIs e processos Windows;
- FEX-Emu para traduzir código x86/x64 em ARM64;
- DXMT e uma camada Metal para gráficos DirectX;
- suporte JIT/Memory+ compatível com o ambiente iOS.

A arquitetura segue o modelo técnico do projeto Madeira, mas o motor e seus submódulos ainda não fazem parte deste repositório. O botão **Executar** permanece desabilitado para não simular uma execução que não acontece.

## Pareamento nativo (iOS 27+)

1. Instale o Vertex em um dispositivo com iOS 27 ou superior.
2. Abra **Vertex → Pair Vertex** e permita o acesso à rede local.
3. No mesmo iPhone, abra **Ajustes → Privacidade e Segurança → Modo Desenvolvedor**.
4. Role até **Pair with Vertex**, toque nessa opção e informe o PIN mostrado pelo Vertex.
5. Aguarde a notificação de conclusão e volte ao Vertex.
6. Se precisar usar o arquivo de pareamento em outra ferramenta, toque em **Exportar arquivo de pareamento**.

O pareamento Remote Pairing não ativa JIT sozinho. JIT exige uma implementação auxiliar separada.

## Compilação

O build precisa de macOS com Xcode 27 ou SDK iOS 27, Rust e XcodeGen:

    rustup target add aarch64-apple-ios aarch64-apple-ios-sim
    ./build-rust.sh
    xcodegen generate
    xcodebuild -project Vertex.xcodeproj -scheme Vertex -sdk iphoneos CODE_SIGNING_ALLOWED=NO build

O GitHub Actions compila o FFI Rust para dispositivo e simulador, gera o projeto Xcode e publica um IPA sem assinatura como artefato.

## Créditos e licença de terceiros

O FFI de pareamento Rust e os componentes Swift adaptados são derivados do projeto StikPair e da biblioteca idevice. O aviso de licença StikPair está em `ThirdPartyLicenses/StikPair-LICENSE.txt`. A licença StikPair permite uso pessoal/não comercial; uso comercial requer autorização prévia do titular.

A integração futura do motor Madeira precisa respeitar a GPL-3.0-or-later e as licenças específicas de cada submódulo e runtime.
