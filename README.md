# Vertex

Projeto SwiftUI compacto: três arquivos Swift, um catálogo de assets e o ícone
neon violeta fornecido.

- **Programas**: importa um `.exe` e mostra o cartão do programa.
- **Baixar dependências**: estado visual de preparação.
- **Iniciar**: disponível depois do **Pair Vertex**.
- **Pair Vertex**: fluxo de pareamento por código.

O projeto usa apenas permissões públicas necessárias: importação de arquivos e
acesso à rede local para localizar o Vertex Runner. O limite de memória e a
execução de código são controlados pelo iOS; não existe entitlement público de
"raw memory" ou memória ilimitada para aplicativos iPhone.

Abra `project.yml` com XcodeGen em um Mac para gerar o projeto Xcode.
