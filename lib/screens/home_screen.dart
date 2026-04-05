import 'package:flutter/material.dart';

import '../models/conta_model.dart';
import 'meus_gastos_screen.dart';
import 'nova_conta_screen.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceAtual = 1;

  List<Widget> get _abas => const [MeusGastosScreen(), AReceberScreen()];

  String get _titulo {
    if (_indiceAtual == 0) {
      return 'Meus Gastos';
    }
    return 'A Receber';
  }

  Future<void> _onAdicionar() async {
    if (_indiceAtual == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NovoRecebivelScreen()),
      );
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro de gastos desativado nesta versao.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _abas[_indiceAtual],
      floatingActionButton: FloatingActionButton(
        onPressed: _onAdicionar,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (index) {
          setState(() => _indiceAtual = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Despesas',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'A Receber',
          ),
        ],
      ),
    );
  }
}

class AReceberScreen extends StatelessWidget {
  const AReceberScreen({super.key});

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
      stream: DatabaseService()
          .contasAReceber, // Certifique-se de que este método existe no seu DatabaseService
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

        final List<Conta> listaContas = snapshot.data ?? [];

        double totalReceber = 0;
        double totalPendente = 0;
        for (final conta in listaContas) {
          if (conta.foiPago) {
            totalReceber += conta.valor;
          } else {
            totalPendente += conta.valor;
          }
        }

        if (listaContas.isEmpty) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Resumo', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ResumoFinanceiroCard(
                            titulo: 'Recebido',
                            valor:
                                'R\$ ${totalReceber.toStringAsFixed(2).replaceAll('.', ',')}',
                            cor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResumoFinanceiroCard(
                            titulo: 'Pendente',
                            valor:
                                'R\$ ${totalPendente.toStringAsFixed(2).replaceAll('.', ',')}',
                            cor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    "Nenhuma conta pendente.\nClique no '+' para anotar quem te deve!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Resumo', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ResumoFinanceiroCard(
                          titulo: 'Recebido',
                          valor:
                              'R\$ ${totalReceber.toStringAsFixed(2).replaceAll('.', ',')}',
                          cor: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ResumoFinanceiroCard(
                          titulo: 'Pendente',
                          valor:
                              'R\$ ${totalPendente.toStringAsFixed(2).replaceAll('.', ',')}',
                          cor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: listaContas.length,
                itemBuilder: (context, index) {
                  final Conta conta = listaContas[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
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
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        tooltip: 'Excluir',
                        onPressed: () async {
                          final bool confirmado = await _confirmarExclusao(
                            context,
                            conta,
                          );

                          if (!confirmado) {
                            return;
                          }

                          try {
                            await DatabaseService().deletarRecebivel(conta.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao excluir: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      // Mostra valor e status sem apertar o trailing.
                      // O ListTile fica mais estável em telas pequenas.
                      minVerticalPadding: 8,
                      subtitleTextStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            conta.descricao.isEmpty
                                ? 'Sem descrição'
                                : conta.descricao,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'R\$ ${conta.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            conta.foiPago ? 'PAGO' : 'PENDENTE',
                            style: TextStyle(
                              color: conta.foiPago ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        try {
                          await DatabaseService().alternarStatusRecebivel(
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

// Classe mantida corretamente do lado de fora
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
          Text(titulo, style: TextStyle(color: cor, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
