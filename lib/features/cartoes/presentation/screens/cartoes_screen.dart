import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/di/service_locator.dart';
import 'package:paga_o_que_me_deve/core/errors/app_exceptions.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/app_feedback.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/cartoes/data/services/cartoes_service.dart';

class CartoesScreen extends StatefulWidget {
  const CartoesScreen({super.key});

  @override
  State<CartoesScreen> createState() => _CartoesScreenState();
}

class _CartoesScreenState extends State<CartoesScreen> {
  late final CartoesService _cartoesService;

  @override
  void initState() {
    super.initState();
    // Injeção simplificada
    _cartoesService = CartoesService(getIt<FinanceRepository>());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões de Crédito'),
        // Removida a cor fixa para manter consistência com o tema global
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cartoes_add_fab',
        onPressed: () => _abrirNovoCartaoDialog(context),
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('Novo cartão'),
      ),
      body: StreamBuilder<List<CartaoCredito>>(
        stream: _cartoesService.cartoesCredito,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton(withHeader: false);
          }

          if (snapshot.hasError) {
            final exception = AppException.from(snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Text(
                  exception.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }

          final cartoes = snapshot.data ?? <CartaoCredito>[];
          if (cartoes.isEmpty) {
            return AppEmptyStateCta(
              icon: Icons.credit_card_off_outlined,
              title: 'Nenhum cartão',
              description:
                  'Cadastre os seus cartões para organizar as faturas.',
              buttonLabel: 'Adicionar agora',
              onPressed: () => _abrirNovoCartaoDialog(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s16),
            itemCount: cartoes.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, index) {
              final cartao = cartoes[index];

              return AppSectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.credit_card,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    cartao.nome,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Final ${cartao.finalCartao} • Fecha dia ${cartao.diaFechamento}',
                    style: theme.textTheme.bodySmall,
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
    final confirmar = await AppConfirmDialog.show(
      context,
      title: 'Excluir cartão',
      message: 'Deseja excluir ${cartao.nome} final ${cartao.finalCartao}?',
    );

    if (!confirmar || !context.mounted) return;

    try {
      await _cartoesService.deletarCartaoCredito(cartao.id);
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Cartão excluído com sucesso.');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, AppException.from(e).message);
      }
    }
  }

  Future<void> _abrirNovoCartaoDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final finalController = TextEditingController();
    final fechamentoController = TextEditingController(text: '10');
    final vencimentoController = TextEditingController(text: '20');

    final salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Novo cartão'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Cartão (Ex: Nubank)',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: finalController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '4 últimos dígitos',
                  ),
                  validator: (v) =>
                      (v?.length != 4) ? 'Informe 4 dígitos' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: fechamentoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dia Fecham.',
                        ),
                        validator: _validarDia,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: vencimentoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dia Venc.',
                        ),
                        validator: _validarDia,
                      ),
                    ),
                  ],
                ),
              ],
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

    if (salvar != true || !context.mounted) return;

    final novo = CartaoCredito(
      id: '',
      nome: nomeController.text.trim(),
      finalCartao: finalController.text.replaceAll(RegExp(r'\D'), ''),
      diaFechamento: int.tryParse(fechamentoController.text) ?? 10,
      diaVencimento: int.tryParse(vencimentoController.text) ?? 20,
    );

    try {
      await _cartoesService.adicionarCartaoCredito(novo);
      if (context.mounted) AppFeedback.showSuccess(context, 'Cartão salvo.');
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, AppException.from(e).message);
      }
    }
  }

  String? _validarDia(String? value) {
    final dia = int.tryParse((value ?? '').trim());
    if (dia == null || dia < 1 || dia > 31) return '1 a 31';
    return null;
  }
}
