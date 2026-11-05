# Vertex

Aplicativo iOS para experimentos de compatibilidade e pareamento nativo.

## Pareamento nativo (iOS 27+)

O botão **Pair Vertex** inicia no próprio iPhone um serviço Remote Pairing compatível com a tela de Modo Desenvolvedor do iOS. Não requer Vertex Runner, Windows, cabo ou outro computador para realizar o pareamento.

1. Instale o Vertex em um dispositivo com iOS 27 ou superior.
2. Abra **Vertex → Pair Vertex** e permita o acesso à rede local.
3. No mesmo iPhone, abra **Ajustes → Privacidade e Segurança → Modo Desenvolvedor**.
4. Role até **Pair with Vertex**, toque nessa opção e informe o PIN mostrado pelo Vertex.
5. Aguarde a notificação de conclusão e volte ao Vertex.
6. Se precisar usar o arquivo de pareamento em outra ferramenta, toque em **Exportar arquivo de pareamento**.

O iOS pode limitar tarefas em segundo plano. O Vertex usa uma tarefa de processamento contínuo e oferece opções auxiliares de áudio/localização na tela de pareamento; essas opções são opcionais e exigem permissões do sistema.

## Compilação

O build precisa de macOS com Xcode 27 ou SDK iOS 27, Rust e XcodeGen. No macOS, execute os comandos abaixo:

    rustup target add aarch64-apple-ios aarch64-apple-ios-sim
    ./build-rust.sh
    xcodegen generate
    xcodebuild -project Vertex.xcodeproj -scheme Vertex -sdk iphoneos CODE_SIGNING_ALLOWED=NO build

O GitHub Actions compila o FFI Rust para dispositivo e simulador, gera o projeto Xcode, valida ambos os destinos e publica um IPA sem assinatura como artefato.

## Limitações

- Pareamento Remote Pairing não ativa JIT sozinho. JIT exige uma implementação auxiliar separada, permissões/ambiente de desenvolvedor e mecanismos próprios.
- A importação de .exe ainda só lista o arquivo. O iOS não executa executáveis Windows nativamente; o runtime de compatibilidade (por exemplo, FEX/Wine e componentes gráficos) ainda não está integrado.
- O IPA produzido pelo workflow é sem assinatura. É necessário assinar e instalar com um método compatível.

## Créditos e licença de terceiros

O FFI de pareamento Rust e os componentes Swift adaptados são derivados do projeto StikPair, de StephenDev0, e da biblioteca idevice. O aviso de licença StikPair está em ThirdPartyLicenses/StikPair-LICENSE.txt. A licença StikPair permite uso pessoal/não comercial; uso comercial requer autorização prévia do titular. Verifique a licença antes de redistribuir ou usar comercialmente.
