import 'package:flutter/material.dart';

import '../../domain/repositories/finance_repository.dart';
import '../../domain/models/models.dart';
import '../../ui/ui.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/utils.dart';
import 'nova_conta_screen.dart';

class AReceberScreen extends StatefulWidget {
  const AReceberScreen({
    super.key,
    required this.db,
    this.somentePendentes = false,
  });

  final FinanceRepository db;
  final bool somentePendentes;

  @override
  State<AReceberScreen> createState() => _AReceberScreenState();
}

class _AReceberScreenState extends State<AReceberScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(_onBuscaAlterada);
  }

  @override
  void dispose() {
    _buscaController.removeListener(_onBuscaAlterada);
    _buscaController.dispose();
    super.dispose();
  }

  void _onBuscaAlterada() {
    final String novoTermo = _buscaController.text;
    if (novoTermo == _termoBusca) {
      return;
    }

    setState(() {
      _termoBusca = novoTermo;
    });
  }

  String _mensagemErroFirestore(Object? error) {
    final String erro = (error ?? '').toString().toLowerCase();
    if (erro.contains('firestore.googleapis.com') ||
        erro.contains('permission_denied')) {
      return 'Firestore sem permissão ou desativado no projeto.\n'
          'Ative o Cloud Firestore no Firebase Console e tente novamente.';
    }
    return 'Erro ao carregar as contas.';
  }

  Future<bool> _confirmarExclusao(BuildContext context, Conta conta) async {
    return AppConfirmDialog.show(
      context,
      title: 'Excluir item',
      message: 'Deseja excluir ${conta.nome}?\n${conta.descricao}',
    );
  }

  bool _filtrarPorNome(Conta conta) {
    if (_termoBusca.trim().isEmpty) {
      return true;
    }

    return conta.nome.toLowerCase().contains(_termoBusca.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Conta>>(
      stream: widget.db.contasAReceber,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Text(
                _mensagemErroFirestore(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Conta> todasAsContas = snapshot.data ?? [];
        final List<Conta> listaContas = widget.somentePendentes
            ? todasAsContas.where((conta) => !conta.foiPago).toList()
            : todasAsContas;
        final List<Conta> contasFiltradas = listaContas
            .where(_filtrarPorNome)
            .toList();

        double totalReceber = 0;
        double totalPendente = 0;
        for (final conta in todasAsContas) {
          if (conta.foiPago) {
            totalReceber += conta.valor;
          } else {
            totalPendente += conta.valor;
          }
        }

        final double totalGeral = totalReceber + totalPendente;
        final double progresso = totalGeral == 0
            ? 0
            : totalReceber / totalGeral;

        final Widget cardResumo = Card(
          elevation: 1,
          margin: const EdgeInsets.all(AppSpacing.s16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Resumo Financeiro',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: _ResumoFinanceiroCard(
                        titulo: 'Recebido',
                        valor: AppFormatters.moeda(totalReceber),
                        cor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _ResumoFinanceiroCard(
                        titulo: 'Pendente',
                        valor: AppFormatters.moeda(totalPendente),
                        cor: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progresso,
                    minHeight: 8,
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${(progresso * 100).toStringAsFixed(0)}% do valor recuperado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (widget.somentePendentes) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Filtro ativo: somente pendentes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        return Column(
          children: [
            cardResumo,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                AppSpacing.s12,
              ),
              child: TextField(
                controller: _buscaController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar por nome do devedor',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _termoBusca.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _buscaController.clear();
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: contasFiltradas.isEmpty
                  ? AppEmptyStateCta(
                      icon: Icons.search_off_outlined,
                      title: _termoBusca.trim().isEmpty
                          ? 'Nenhuma conta pendente'
                          : 'Nenhum devedor encontrado',
                      description: _termoBusca.trim().isEmpty
                          ? 'Registre uma nova cobrança para acompanhar quem ainda precisa te pagar.'
                          : 'Tente outro nome do devedor para encontrar a cobrança desejada.',
                      buttonLabel: 'Adicionar cobrança',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NovoRecebivelScreen(db: widget.db),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: contasFiltradas.length,
                      itemBuilder: (context, index) {
                        final Conta conta = contasFiltradas[index];

                        return Dismissible(
                          key: Key(conta.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return _confirmarExclusao(context, conta);
                          },
                          onDismissed: (direction) async {
                            try {
                              await widget.db.deletarRecebivel(conta.id);
                            } catch (e) {
                              if (context.mounted) {
                                AppFeedback.showError(context, 'Erro: $e');
                              }
                            }
                          },
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: conta.foiPago
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                child: Icon(
                                  conta.foiPago
                                      ? Icons.check
                                      : Icons.pending_actions,
                                  color: conta.foiPago
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              title: Text(
                                conta.nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  decoration: conta.foiPago
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                conta.descricao.isEmpty
                                    ? 'Sem descrição'
                                    : conta.descricao,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppFormatters.moeda(conta.valor),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: conta.foiPago
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      conta.foiPago ? 'PAGO' : 'PENDENTE',
                                      style: TextStyle(
                                        color: conta.foiPago
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                try {
                                  await widget.db.alternarStatusRecebivel(
                                    conta.id,
                                    conta.foiPago,
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    AppFeedback.showError(
                                      context,
                                      'Erro ao atualizar: $e',
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ResumoFinanceiroCard extends StatelessWidget {
  const _ResumoFinanceiroCard({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  final String titulo;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: cor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
