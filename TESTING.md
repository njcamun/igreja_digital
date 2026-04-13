# Igreja Digital - Relatorio de Fecho da Fase Oração + FCM

Este documento consolida validacao, testes e checklists da fase de:
- modulo de pedidos de oração
- notificacoes push segmentadas com FCM
- Cloud Functions para envio seguro
- seguranca de acesso por perfil e congregacao
- compatibilidade Android com baseline para page sizes 16 KB

## A) Estrutura de ficheiros criados/alterados

### Dominio e dados (oracao)
- igreja_digital/lib/domain/entities/prayer_request_entity.dart
- igreja_digital/lib/domain/repositories/prayer_repository.dart
- igreja_digital/lib/data/models/prayer_request_model.dart
- igreja_digital/lib/data/repositories/prayer_repository_impl.dart

### Providers e UI (oracao)
- igreja_digital/lib/presentation/providers/prayer_provider.dart
- igreja_digital/lib/presentation/screens/prayers/prayer_list_screen.dart
- igreja_digital/lib/presentation/screens/prayers/prayer_detail_screen.dart
- igreja_digital/lib/presentation/screens/prayers/prayer_form_screen.dart

### FCM no cliente
- igreja_digital/lib/presentation/services/notification_service.dart
- igreja_digital/lib/presentation/providers/auth_provider.dart
- igreja_digital/lib/presentation/screens/main_navigation_screen.dart
- igreja_digital/lib/main.dart

### Backend e infraestrutura
- functions/index.js
- functions/package.json
- firebase.json
- igreja_digital/firebase.json
- igreja_digital/firestore.rules
- igreja_digital/firestore.indexes.json
- igreja_digital/android/app/build.gradle.kts
- igreja_digital/android/settings.gradle.kts

## B) Passos para testar o modulo de oracao

### 1. Criacao
1. Fazer login como membro.
2. Abrir Pedidos de Oração e tocar em Novo Pedido.
3. Preencher titulo e conteudo com validacao minima.
4. Testar combinacoes: publico, privado e anonimo.
5. Confirmar que o item aparece na lista por ordem de data recente.

### 2. Listagem e filtros
1. Validar filtros de visibilidade: Todos, Publicos, Privados, Anonimos.
2. Validar filtros por estado: open, praying, answered, archived.
3. Como admin/lider, validar filtro por congregacao.
4. Confirmar badge visual de pedido recente.
5. Validar empty state e error state.

### 3. Detalhe e intercessao
1. Abrir detalhe e confirmar titulo, conteudo, estado, data e congregacao.
2. Validar autor oculto quando anonimo.
3. Tocar em Estou a orar e confirmar incremento do contador.
4. Repetir com o mesmo utilizador e confirmar sem duplicacao.

### 4. Moderacao
1. Como admin/lider, alterar estado e arquivar pedido.
2. Como membro, confirmar impossibilidade de moderar pedidos de terceiros.

## C) Passos para testar FCM no Flutter

### 1. Inicializacao e token
1. Fazer login com utilizador autenticado (nao visitante).
2. Aceitar permissao de notificacao.
3. Confirmar no Firestore users/{uid}: fcmToken, fcmTokens, lastTokenUpdateAt.
4. Reinstalar app e confirmar refresh de token.

### 2. Rececao por estado da app
1. Foreground: deve aparecer notificacao local com titulo e corpo.
2. Background: tocar notificacao e abrir detalhe correto.
3. Terminated: abrir por notificacao e navegar para o ecrã da entidade.

### 3. Tipos obrigatorios
1. urgent_announcement -> detalhe do aviso.
2. new_sermon -> detalhe do sermao.
3. future_event -> detalhe do evento.
4. prayer_request -> detalhe do pedido de oracao.

## D) Passos para testar Cloud Functions/backend

### 1. Validar deploy
```bash
cd d:/Projectos Flutter/igreja_digital
firebase functions:list --project igreja-digita
```

### 2. Disparadores automaticos
1. Criar aviso urgente (priority = urgente).
2. Publicar sermao (isPublished: false -> true).
3. Criar prayer_request.
4. Criar event.

### 3. Seguranca
1. Tentar callable sem autenticacao: deve falhar.
2. Tentar callable com nao-admin: deve falhar.
3. Tentar callable com admin: deve funcionar.

### 4. Logs e auditoria
```bash
firebase functions:log --project igreja-digita --only sendUrgentAnnouncementNotification --lines 30
firebase functions:log --project igreja-digita --only sendNewSermonNotification --lines 30
firebase functions:log --project igreja-digita --only sendPrayerRequestNotification --lines 30
firebase functions:log --project igreja-digita --only sendEventNotification --lines 30
```
Validar "Function execution started" e "finished with status: 'ok'".

## E) Checklist de permissoes por perfil

### Visitante
- nao cria pedido de oracao
- nao inicializa fluxo de notificacoes da fase

### Membro
- cria pedidos
- ve pedidos proprios + publicos permitidos
- pode interceder (sem duplicacao)
- nao modera pedidos de terceiros

### Lider
- ve pedidos publicos
- ve privados da propria congregacao
- pode moderar pedidos da propria congregacao
- nao gere pedidos de outras congregacoes

### Admin
- acesso global de leitura
- pode alterar estado e arquivar
- pode gerir envio manual via callable

## F) Checklist de compatibilidade Android 16 KB

### Baseline tecnico
- AGP moderno configurado
- Gradle wrapper moderno
- compileSdk e targetSdk atuais
- stack Firebase/FCM em versoes recentes
- sem introducao de dependencias Android legadas nesta fase

### Validacao recomendada de release
1. Gerar bundle release:
```bash
cd d:/Projectos Flutter/igreja_digital/igreja_digital
flutter build appbundle
```
2. Inspecionar libs nativas no artefato:
```bash
unzip -l build/app/outputs/bundle/release/app-release.aab | findstr ".so"
```
3. Validar em dispositivo Android 15+.
4. Repetir verificacao apos cada upgrade de plugin nativo.

## G) Pontos de atencao para fase seguinte

1. Consolidar testes e2e em dispositivo para navegacao por notificacao tocada.
2. Avaliar extrair _PrayerCard para widget reutilizavel dedicado.
3. Revisar estrategia de topicos por role para reduzir ruido de notificacoes.
4. Monitorar logs de notification_logs por erro/intermitencia de rede.
5. Considerar migracao gradual para Functions 2nd Gen quando oportuno.

## Exemplos de dados para teste

### Documento prayer_requests
```json
{
  "title": "Pedido de Cura",
  "content": "Por favor orem pela minha saude e recuperacao.",
  "userId": "user123",
  "userName": "Joao Silva",
  "congregationId": "cong1",
  "isAnonymous": false,
  "isPrivate": false,
  "isPublic": true,
  "status": "open",
  "prayerCount": 0,
  "prayedByUserIds": [],
  "createdAt": "2026-04-10T00:00:00Z",
  "updatedAt": "2026-04-10T00:00:00Z",
  "isActive": true
}
```

### Payload de notificacao (new_sermon)
```json
{
  "notification": {
    "title": "Novo Sermao",
    "body": "Sermao sobre Fe"
  },
  "data": {
    "type": "new_sermon",
    "entityId": "sermon123",
    "congregationId": "cong1",
    "title": "Fe Inabalavel",
    "body": "Conteudo do sermao",
    "route": "/sermons/sermon123",
    "createdAt": "2026-04-10T00:00:00Z"
  },
  "topic": "congregation_cong1"
}
```

## Modelo para envio de logs manuais

Quando concluir os testes no dispositivo, enviar:
- tipo de teste (urgent_announcement, prayer_request, future_event, new_sermon)
- estado da app (foreground/background/terminated)
- comportamento observado ao tocar
- trecho de log do app (se houver)
- trecho de log das functions correspondente