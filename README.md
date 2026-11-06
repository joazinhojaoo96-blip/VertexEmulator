# Vertex

Aplicativo iOS SwiftUI e companheiro Vertex Runner para Windows.

## Pair Vertex (pareamento real na rede local)

1. No Windows, instale Python 3 e abra a pasta `VertexRunner`.
2. Execute:
   ```powershell
   py -m pip install -r requirements.txt
   py VertexRunner.py
   ```
3. Autorize Python no Firewall do Windows para redes privadas, se solicitado.
4. No iPhone e no Windows, conecte-se à mesma rede Wi-Fi.
5. Abra Vertex > Pair Vertex, selecione o computador encontrado e digite o código de 6 dígitos mostrado no Windows.

O iOS perguntará se o Vertex pode encontrar dispositivos na rede local. Permita para usar a descoberta Bonjour.

## Painel JIT

O app inclui uma aba **JIT** com painel visual, compatibilidade do iOS, componentes pendentes e notificações em estilo toast. Este painel é uma base de interface/diagnóstico; ele **não ativa JIT**.

O pareamento Python atual continua sendo apenas um handshake local com o Vertex Runner. O pareamento nativo Remote Pairing do iOS 27+ e a integração do helper StikJIT ainda precisam ser implementados e testados. Consulte [docs/NATIVE-JIT-IMPLEMENTATION.md](docs/NATIVE-JIT-IMPLEMENTATION.md) para os requisitos técnicos e critérios de conclusão.

## Modo Desenvolvedor

O iOS não permite que um app de terceiros ative Modo Desenvolvedor nem navegue diretamente até essa seção protegida. A ativação deve ser feita manualmente em Ajustes > Privacidade e Segurança > Modo Desenvolvedor.

## Limitações atuais

- O pareamento valida o código com o Vertex Runner por conexão TCP na rede local.
- A importação de .exe apenas guarda/mostra o arquivo no app. iOS não executa executáveis Windows nativamente.
- Os botões de preparação e início ainda são protótipos; o pareamento não significa que a execução remota esteja implementada.
- Use apenas em uma rede privada e confiável.
