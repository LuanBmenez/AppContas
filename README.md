# Paga o que me deve

Aplicativo Flutter para controle financeiro pessoal com foco em previsibilidade de caixa e tomada de decisão.

## Visao do produto

Problema:

- pequenas entradas e saidas acabam espalhadas, sem contexto mensal claro

Solucao:

- centralizar gastos, recebiveis e insights em um dashboard unico
- apoiar rotina com filtros, busca, lote e relatorio em PDF

## Funcionalidades principais

- Dashboard com comparativos de periodo, distribuicao por categoria e drill-down
- Gestao de gastos por categoria/tipo
- Gestao de contas a receber com status e fluxo em lote
- Exportacao de relatorio mensal em PDF
- Navegacao por rotas nomeadas com parametros de consulta

## Stack tecnica

- Flutter 3 / Dart 3
- Firebase Core + Cloud Firestore
- Go Router
- PDF + Printing + Share Plus

## Arquitetura

Estrutura principal:

- lib/app: bootstrap da aplicacao e roteamento
- lib/domain: modelos e contratos
- lib/services: infraestrutura e regras de aplicacao
- lib/features: fluxos por contexto funcional
- lib/ui e lib/core: design system, utilitarios e componentes reaproveitaveis

Decisoes de implementacao:

- separacao por camadas para reduzir acoplamento
- contratos de repositorio no dominio para facilitar evolucao
- cache de resumo no dashboard com TTL, LRU e limpeza explicita
- telemetria com contrato de eventos e sanitizacao de parametros

## Firebase: seguranca e governanca

### Regras de seguranca

Este repositorio inclui regras versionadas:

- firestore.rules
- storage.rules

Publicar regras:

```bash
firebase deploy --only firestore:rules,storage
```

### App Check (producao)

O app ativa App Check no bootstrap com:

- Android: Play Integrity
- Apple: App Attest
- Web: ReCaptchaV3Provider

Para Web, passe a chave por dart-define:

```bash
flutter run -d chrome --dart-define=FIREBASE_RECAPTCHA_SITE_KEY=YOUR_SITE_KEY
```

### Ambientes (dev/stage/prod)

Recomendado usar um projeto Firebase por ambiente:

- app-contas-dev
- app-contas-stage
- app-contas-prod

Gerar opcoes por ambiente:

```bash
flutterfire configure --project=app-contas-dev
flutterfire configure --project=app-contas-stage
flutterfire configure --project=app-contas-prod
```

Boas praticas:

- manter regras equivalentes entre ambientes
- revisar permissao de leitura/escrita periodicamente
- habilitar App Check em todos os ambientes

## Observabilidade

Telemetria estruturada em:

- lib/services/app_telemetry_service.dart

Padroes aplicados:

- contrato de eventos
- allowlist de parametros por evento
- sanitizacao de campos sensiveis
- log local em modo nao release

## Como rodar

```bash
flutter pub get
flutter run
```

## Qualidade e testes

Analise estatica:

```bash
flutter analyze
```

Testes:

```bash
flutter test
```

Cobertura:

```bash
flutter test --coverage
```

Suites atuais:

- test/widget_test.dart
- test/services/extrato_csv_service_test.dart
- test/services/dashboard_summary_service_test.dart
- test/services/app_telemetry_service_test.dart
- test/features/inicio/dashboard_screen_test.dart

## CI automatizado

Pipeline GitHub Actions:

- analyze + test
- coleta de cobertura

Arquivos de workflow:

- .github/workflows/flutter-ci.yml

## Roadmap

- ampliar cobertura de testes para fluxos de lote em receber e despesas
- publicar badge de cobertura no README
- adicionar artefatos de build no CI para distribuicao interna
- evoluir observabilidade com provider externo (analytics/monitoring)

## Apresentacao para LinkedIn

Ao publicar, destaque:

- foco em arquitetura limpa e evolutiva
- qualidade com testes e pipeline automatizada
- seguranca e governanca no Firebase
- UX orientada a produtividade financeira
