import 'package:flutter/material.dart';

import '../../models/conta_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_formatters.dart';
import 'nova_conta_screen.dart';

class AReceberScreen extends StatelessWidget {
  AReceberScreen({super.key, required this.db, this.somentePendentes = false});

  final DatabaseService db;
  final bool somentePendentes;

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
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir item'),
          content: Text('Deseja excluir ${conta.nome}?\n${conta.descricao}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    return confirmado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Conta>>(
      stream: db.contasAReceber,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _mensagemErroFirestore(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Conta> todasAsContas = snapshot.data ?? [];
        final List<Conta> listaContas = somentePendentes
            ? todasAsContas.where((conta) => !conta.foiPago).toList()
            : todasAsContas;

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
          margin: const EdgeInsets.all(16),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ResumoFinanceiroCard(
                        titulo: 'Recebido',
                        valor: AppFormatters.moeda(totalReceber),
                        cor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ResumoFinanceiroCard(
                        titulo: 'Pendente',
                        valor: AppFormatters.moeda(totalPendente),
                        cor: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 8),
                Text(
                  '${(progresso * 100).toStringAsFixed(0)}% do valor recuperado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (somentePendentes) ...[
                  const SizedBox(height: 10),
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

        if (listaContas.isEmpty) {
          return Column(
            children: [
              cardResumo,
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Nenhuma conta pendente",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Registre uma nova cobrança para acompanhar quem ainda precisa te pagar.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NovoRecebivelScreen(db: db),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar cobrança'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            cardResumo,
            Expanded(
              child: ListView.builder(
                itemCount: listaContas.length,
                itemBuilder: (context, index) {
                  final Conta conta = listaContas[index];

                  return Dismissible(
                    key: Key(conta.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return _confirmarExclusao(context, conta);
                    },
                    onDismissed: (direction) async {
                      try {
                        await db.deletarRecebivel(conta.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    background: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
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
                            conta.foiPago ? Icons.check : Icons.pending_actions,
                            color: conta.foiPago ? Colors.green : Colors.red,
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
                            await db.alternarStatusRecebivel(
                              conta.id,
                              conta.foiPago,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao atualizar: $e'),
                                  backgroundColor: Colors.red,
                                ),
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
