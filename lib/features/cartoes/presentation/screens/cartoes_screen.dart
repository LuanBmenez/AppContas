import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class CartoesScreen extends StatelessWidget {
  const CartoesScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartoes de Credito'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirNovoCartaoDialog(context),
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('Novo cartão'),
      ),
      body: StreamBuilder<List<CartaoCredito>>(
        stream: db.cartoesCredito,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Text('Erro ao carregar cartoes: ${snapshot.error}'),
              ),
            );
          }

          final List<CartaoCredito> cartoes =
              snapshot.data ?? <CartaoCredito>[];
          if (cartoes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.s24),
                child: Text(
                  'Nenhum cartao cadastrado ainda.\nToque em "Novo cartão" para começar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s16),
            itemCount: cartoes.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, index) {
              final CartaoCredito cartao = cartoes[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.credit_card)),
                  title: Text(cartao.label),
                  subtitle: Text(
                    'Fecha dia ${cartao.diaFechamento} • Vence dia ${cartao.diaVencimento}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmarExclusao(context, cartao),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    CartaoCredito cartao,
  ) async {
    final bool confirmar = await AppConfirmDialog.show(
      context,
      title: 'Excluir cartao',
      message: 'Deseja excluir ${cartao.label}?',
    );

    if (!confirmar || !context.mounted) {
      return;
    }

    await db.deletarCartaoCredito(cartao.id);
  }

  Future<void> _abrirNovoCartaoDialog(BuildContext context) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nomeController = TextEditingController();
    final TextEditingController finalController = TextEditingController();
    final TextEditingController fechamentoController = TextEditingController(
      text: '10',
    );
    final TextEditingController vencimentoController = TextEditingController(
      text: '20',
    );

    final bool? salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Novo cartão'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome do cartao.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: finalController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Final (4 digitos)',
                    ),
                    validator: (value) {
                      final String digits = (value ?? '').replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      if (digits.length != 4) {
                        return 'Informe exatamente 4 digitos.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: fechamentoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fechamento'),
                    validator: _validarDia,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextFormField(
                    controller: vencimentoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Vencimento'),
                    validator: _validarDia,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (salvar != true || !context.mounted) {
      return;
    }

    final CartaoCredito novo = CartaoCredito(
      id: '',
      nome: nomeController.text.trim(),
      finalCartao: finalController.text.replaceAll(RegExp(r'\D'), ''),
      diaFechamento: int.parse(fechamentoController.text),
      diaVencimento: int.parse(vencimentoController.text),
    );

    await db.adicionarCartaoCredito(novo);
  }

  String? _validarDia(String? value) {
    final int? dia = int.tryParse((value ?? '').trim());
    if (dia == null || dia < 1 || dia > 31) {
      return 'Dia deve ser 1..31.';
    }
    return null;
  }
}

typedef CartoesCreditoScreen = CartoesScreen;
