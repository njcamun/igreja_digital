# Igreja Digital

Aplicação Flutter para gestão e comunicação da igreja, com autenticação, permissões por perfil/congregação, agenda, avisos, sermões, congregações/mapas e módulo de pedidos de oração com notificações push.

## Módulo de Pedidos de Oração

### Funcionalidades implementadas

- listagem com ordenação por mais recentes e estados de loading/empty/error
- filtros por visibilidade, estado e congregação (admin/líder)
- criação de pedidos com validação, opção anónimo e público/privado
- detalhe com estado, autor, data, congregação, contador de intercessões e ação Estou a orar
- moderação por admin/líder (alterar estado e arquivar)
- prevenção de duplicação de intercessão por utilizador

### Modelo mínimo utilizado

Coleção: prayer_requests

- id
- title
- content
- userId
- userName
- congregationId
- isAnonymous
- isPrivate
- isPublic
- status (open, praying, answered, archived)
- prayerCount
- prayedByUserIds
- createdAt
- updatedAt
- isActive

## Notificações Push (FCM)

### Funcionalidades implementadas

- pedido de permissões no cliente
- tratamento foreground, background e terminated
- token FCM armazenado no perfil do utilizador
- suporte a fcmToken e fcmTokens
- navegação por payload para avisos, sermões, pedidos de oração e eventos
- tópicos preparados para global, congregation_{id}, role_{role}

### Payload padrão

- type
- entityId
- congregationId
- title
- body
- route
- createdAt

## Cloud Functions

Arquivo: ../functions/index.js

### Eventos cobertos

- aviso urgente criado
- sermão publicado (transição para isPublished = true)
- pedido de oração criado
- evento criado
- função callable para envio manual por admin

### Segurança e robustez

- validação de payload no callable
- envio apenas por backend para segmentação real
- deduplicação por eventId
- logs em notification_logs

## Regras Firestore

Arquivo: firestore.rules

- criação de pedido de oração limitada a membro/líder/admin autenticado
- leitura de pedidos protegida por visibilidade, autoria, congregação e perfil
- atualização de intercessão com validação de incremento e array
- restrição de alteração de tokens ao próprio utilizador (ou admin)

## Índices Firestore

Arquivo: firestore.indexes.json

Inclui índices para consultas de prayer_requests por:

- isActive + createdAt
- isActive + status + createdAt
- isActive + congregationId + status + createdAt
- combinações de visibilidade usadas na listagem

## Como testar

### 1. Módulo de oração por perfil

1. Login como membro e criar pedido público/privado/anónimo.
2. Validar que membro vê os próprios e públicos permitidos.
3. Login como líder e validar acesso a pedidos da congregação.
4. Login como admin e validar acesso global + moderação.
5. Em detalhe, clicar Estou a orar duas vezes com mesmo utilizador e confirmar que só conta uma.

### 2. FCM no Flutter

1. Fazer login e aceitar permissões de notificação.
2. Verificar no documento users/{uid} os campos fcmToken, fcmTokens e lastTokenUpdateAt.
3. Enviar push via Firebase Console para tópico global.
4. Validar receção em foreground e toque abrindo o detalhe correspondente.

### 3. Cloud Functions

1. Entrar na pasta functions.
2. Executar npm install.
3. Executar firebase deploy --only functions.
4. Criar aviso urgente em announcements e validar push/log.
5. Publicar sermão (isPublished false -> true) e validar push/log.

## Compatibilidade Android 16 KB (relatório desta fase)

### Estado atual

- projeto em AGP 8.11.1 e Gradle 8.14
- targetSdk 36, compileSdk 36
- firebase_messaging e stack Firebase em versões recentes
- sem inclusão intencional de dependências Android nativas legadas nesta fase

### Riscos potenciais

- plugins Flutter com bibliotecas nativas transitivas podem variar por versão
- atualizações futuras de plugins podem introduzir .so incompatíveis

### Como validar APK/AAB

1. Gerar build release:
	- flutter build appbundle
2. Inspecionar bibliotecas nativas do artefato:
	- unzip -l build/app/outputs/bundle/release/app-release.aab | findstr ".so"
3. Validar alinhamento/metadata ELF com ferramentas Android NDK no CI.
4. Testar instalação e execução em dispositivo/emulador Android 15+.

### Checklist rápido 16 KB

- AGP/Gradle modernos
- Firebase BOM atualizado
- sem libs nativas antigas adicionadas manualmente
- verificação de .so em cada release candidate

