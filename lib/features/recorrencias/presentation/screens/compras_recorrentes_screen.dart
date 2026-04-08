import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';

class ComprasRecorrentesScreen extends StatefulWidget {
  const ComprasRecorrentesScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<ComprasRecorrentesScreen> createState() =>
      _ComprasRecorrentesScreenState();
}

class _ComprasRecorrentesScreenState extends State<ComprasRecorrentesScreen> {
  late final RecorrenciasService _service;

  @override
  void initState() {
    super.initState();
    _service = RecorrenciasService(repository: widget.db);
  }

  Future<void> _removerRecorrencia(RecorrenciaAtiva recorrencia) async {
    final bool confirmar = await AppConfirmDialog.show(
      context,
      title: 'Remover recorrência',
      message: 'Tem certeza que deseja remover essa recorrência?',
    );

    if (!confirmar) {
      return;
    }

    try {
      await _service.removerRecorrencia(recorrencia);
      if (!mounted) {
        return;
      }
      AppFeedback.showSuccess(context, 'Recorrência removida com sucesso.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        'Não foi possível remover recorrência: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Compras recorrentes')),
      body: StreamBuilder<List<RecorrenciaAtiva>>(
        stream: _service.streamRecorrenciasAtivas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Text(
                  'Erro ao carregar recorrências: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<RecorrenciaAtiva> recorrencias =
              snapshot.data ?? <RecorrenciaAtiva>[];

          if (recorrencias.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 42,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.s10),
                    const Text(
                      'Você não possui compras recorrentes ativas',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'As recorrências criadas aparecerão aqui.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s16),
            itemCount: recorrencias.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s10),
            itemBuilder: (context, index) {
              final RecorrenciaAtiva item = recorrencias[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.titulo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Ativa',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        AppFormatters.moeda(item.valorMedio),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        'Categoria: ${item.categoriaLabel} • Todo dia ${item.diaDoMes}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Próximos lançamentos automáticos: ${item.ativosDesdeHoje.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _removerRecorrencia(item),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
