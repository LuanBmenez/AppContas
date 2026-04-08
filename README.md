# AppContas

Aplicativo de finanças pessoais desenvolvido em **Flutter** com **Firebase**, focado no controle de **gastos**, **valores a receber**, **dashboard financeiro**, **importação de extratos** e **organização dos dados por usuário**.

## Sobre o projeto

O **AppContas** foi criado para facilitar o acompanhamento financeiro do dia a dia de forma simples, prática e visual.

O app permite registrar despesas, acompanhar cobranças, importar lançamentos de extratos e visualizar um painel com resumos e comparativos financeiros.

Além disso, o projeto já evolui com foco em:
- experiência visual mais refinada
- separação de dados por usuário
- dashboard com insights
- base preparada para novas automações financeiras

---

## Funcionalidades atuais

### Gestão de gastos
- Cadastro manual de gastos
- Organização por categorias
- Filtros por período, categoria e tipo
- Edição individual de categoria
- Exclusão por gesto
- Seleção em lote para ações em massa
- Regras automáticas de categorização
- Importação com prévia e deduplicação

### Importação de extratos
- Importação de extratos em CSV
- Pré-visualização antes de salvar
- Deduplicação por hash de importação
- Tentativa de categorização automática com base no histórico
- Regras de categoria para futuras importações

### Dashboard financeiro
- Resumo financeiro do período
- Saldo do período
- Comparativo com períodos anteriores
- Total de saídas
- Total a receber
- Distribuição de gastos por categoria
- Drill-down por categoria
- Exportação de relatório em PDF
- Cards de insights e comparativos visuais

### Contas a receber
- Cadastro de cobranças
- Controle de pendências e valores recebidos
- Busca por nome do devedor
- Alteração de status
- Seleção em lote
- Exclusão de cobranças

### Conta e autenticação
- Login com Firebase Authentication
- Separação de dados por usuário
- Perfil com informações da conta
- Logout

---

## Tecnologias utilizadas

- **Flutter**
- **Dart**
- **Firebase Core**
- **Firebase Authentication**
- **Cloud Firestore**
- **Intl**
- **RxDart**
- **File Picker**
- **PDF / Printing**
- **Share Plus**
- **Path Provider**

---

## Estrutura do projeto

```bash
lib/
├── core/
│   ├── theme/
│   └── utils/
├── data/
│   └── services/
├── domain/
│   ├── models/
│   └── repositories/
├── features/
├── screens/
├── services/
├── ui/
└── widgets/
