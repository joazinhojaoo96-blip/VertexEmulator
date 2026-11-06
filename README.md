# Vertex

Aplicativo iOS SwiftUI e companheiro Vertex Runner para Windows.

## Pair Vertex (pareamento do Runner na rede local)

1. No Windows, instale Python 3 e abra a pasta `VertexRunner`.
2. Execute:
   ```powershell
   py -m pip install -r requirements.txt
   py VertexRunner.py
   ```
3. Autorize Python no Firewall do Windows para redes privadas, se solicitado.
4. No iPhone e no Windows, conecte-se à mesma rede Wi-Fi.
5. Abra Vertex > Conexão, selecione o computador encontrado e digite o código de 6 dígitos mostrado no Windows.

O iOS perguntará se o Vertex pode encontrar dispositivos na rede local. Permita para usar a descoberta Bonjour.

## Painel JIT

A aba **JIT** agora permite importar um arquivo RPPairing no formato plist. O app verifica se o arquivo é um plist não vazio, limita o tamanho a 1 MiB e guarda os bytes no Keychain com a política `WhenUnlockedThisDeviceOnly`. É possível substituir ou apagar a credencial dentro do painel.

**Importante:** a validação atual confirma somente o contêiner plist. Ela não prova que o arquivo é um RPPairing válido, não estabelece o túnel do dispositivo e não ativa JIT. O painel informa isso explicitamente.

O pareamento Python atual continua sendo apenas um handshake local com o Vertex Runner. O host nativo Remote Pairing do iOS 27+ e a integração do helper StikJIT ainda precisam ser implementados e testados. Consulte [docs/NATIVE-JIT-IMPLEMENTATION.md](docs/NATIVE-JIT-IMPLEMENTATION.md) para os requisitos técnicos e critérios de conclusão.

## Modo Desenvolvedor

O iOS não permite que um app de terceiros ative Modo Desenvolvedor automaticamente. A ativação deve ser feita manualmente em Ajustes > Privacidade e Segurança > Modo Desenvolvedor.

## Limitações atuais

- O pareamento do Runner valida um código por conexão TCP na rede local; não é o protocolo Apple Remote Pairing.
- A importação de .exe apenas guarda/mostra o arquivo no app. iOS não executa executáveis Windows nativamente.
- O helper StikJIT e a confirmação real de JIT ainda não estão integrados.
- Use apenas em uma rede privada e confiável.
