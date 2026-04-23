# AppContas 💰

Aplicativo de finanças pessoais desenvolvido em **Flutter** com **Firebase**, focado no controle de **gastos**, **valores a receber**, **dashboard financeiro**, **importação de extratos** e **organização dos dados por usuário**.

## 📖 Sobre o projeto

O **AppContas** foi criado para facilitar o acompanhamento financeiro do dia a dia de forma simples, prática e visual. O app permite registrar despesas, acompanhar cobranças, importar lançamentos de extratos bancários via CSV e visualizar um painel com resumos e comparativos financeiros.

O projeto evolui com foco constante em:
- Experiência visual refinada e fluida.
- Separação segura de dados por usuário na nuvem.
- Dashboard inteligente com insights automáticos.
- Base modular preparada para novas automações financeiras e integrações.

---

## ✨ Funcionalidades

### 📊 Dashboard e Insights
- Resumo financeiro e saldo do período atual.
- Comparativos visuais com períodos anteriores.
- Gráficos de distribuição de gastos por categoria (Drill-down por categoria).
- Cards de insights automáticos sobre o comportamento financeiro.
- Exportação de relatório completo em PDF.

### 💸 Gestão de Gastos e Orçamentos
- Cadastro manual de gastos e organização por categorias personalizadas.
- Definição e acompanhamento de **Orçamentos** por categoria.
- Filtros avançados por período, categoria e tipo.
- Ações em lote (seleção múltipla) e exclusão rápida por gesto (swipe).
- Gestão de **Compras Recorrentes** com alertas e sincronização de notificações.

### 📥 Importação de Extratos
- Importação de extratos bancários em formato CSV.
- Tela de pré-visualização para revisão antes de salvar.
- Sistema de deduplicação inteligente (evita lançamentos repetidos por hash).
- Categorização automática baseada no histórico de gastos.
- Criação de regras de categoria para futuras importações.

### 🤝 Contas a Receber e Guardado
- Cadastro de cobranças e controle de valores pendentes/recebidos.
- Área dedicada para controle de valores **Guardados** (metas/poupança).
- Alteração rápida de status de cobranças e busca por nome do devedor.

### 🔐 Conta e Autenticação
- Login e Autenticação seguros via Firebase Authentication.
- Dados 100% isolados por usuário no Cloud Firestore.
- Perfil de usuário configurável com preferências e logout.

---

## 🛠 Tecnologias e Pacotes Utilizados

O projeto utiliza uma arquitetura moderna baseada em *features*, com injeção de dependências e navegação declarativa:

- **Framework:** Flutter / Dart
- **Backend & Cloud:** Firebase Core, Authentication, Cloud Firestore, App Check e Analytics
- **Navegação:** Go Router
- **Gerenciamento de Estado & Injeção:** Provider, GetIt, RxDart
- **Manipulação de Arquivos:** File Picker, Path Provider
- **Geração de Documentos:** PDF, Printing, Share Plus
- **Notificações & Tempo:** Flutter Local Notifications, Timezone, Intl

---

## 📂 Estrutura do Projeto

A base de código segue uma arquitetura baseada em funcionalidades (*Feature-First*), facilitando a manutenção e escalabilidade:

```bash
lib/
├── app/                  # Configurações globais e rotas (GoRouter)
├── core/                 # Temas, tokens, utilitários e widgets globais genéricos
├── data/                 # Serviços base de infraestrutura (DatabaseService)
├── domain/               # Modelos de dados globais e abstrações de repositórios
└── features/             # Módulos independentes da aplicação
    ├── a_receber/        # Controle de cobranças
    ├── auth/             # Fluxos de login e autenticação
    ├── cartoes/          # Gestão de cartões de crédito
    ├── dashboard/        # Telas de resumo, gráficos e exportação de PDF
    ├── gastos/           # Lançamento e listagem de despesas
    ├── guardado/         # Controle de economias e metas
    ├── importacao/       # Lógica e UI para leitura de CSVs
    ├── insights/         # Geração de dicas e resumos baseados nos dados
    ├── orcamentos/       # Definição de limites de gastos
    ├── perfil/           # Configurações do usuário
    ├── recebimentos/     # Gestão de entradas
    └── recorrencias/     # Despesas fixas e lembretes locais
