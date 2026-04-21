import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/di/service_locator.dart';
import 'package:paga_o_que_me_deve/core/errors/app_exceptions.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';

class ComprasRecorrentesScreen extends StatefulWidget {
  const ComprasRecorrentesScreen({super.key});

  @override
  State<ComprasRecorrentesScreen> createState() =>
      _ComprasRecorrentesScreenState();
}

class _ComprasRecorrentesScreenState extends State<ComprasRecorrentesScreen> {
  late final RecorrenciasService _service;

  @override
  void initState() {
    super.initState();
    final db = getIt<FinanceRepository>();
    _service = RecorrenciasService(repository: db);
  }

  Future<void> _executar(
    Future<void> Function() action,
    String sucesso,
    String erro,
  ) async {
    try {
      await action();
      if (!mounted) return;
      AppFeedback.showSuccess(context, sucesso);
    } catch (e) {
      if (!mounted) return;
      final exception = AppException.from(e);
      AppFeedback.showError(context, '$erro: ${exception.message}');
    }
  }

  Future<void> _confirmarRecorrencia(RecorrenciaAtiva item) async {
    await _executar(
      () => _service.confirmarRecorrencia(item),
      'Recorrência confirmada com sucesso.',
      'Não foi possível confirmar a recorrência',
    );
  }

  Future<void> _pausarRecorrencia(RecorrenciaAtiva item) async {
    final confirmar = await AppConfirmDialog.show(
      context,
      title: 'Pausar recorrência',
      message:
          'Isso removerá os próximos lançamentos automáticos e deixará a recorrência pausada.',
      confirmText: 'Pausar',
    );
    if (!confirmar) return;

    await _executar(
      () => _service.pausarRecorrencia(item),
      'Recorrência pausada com sucesso.',
      'Não foi possível pausar a recorrência',
    );
  }

  Future<void> _reativarRecorrencia(RecorrenciaAtiva item) async {
    var meses = 3;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reativar recorrência'),
              content: DropdownButtonFormField<int>(
                initialValue: meses,
                decoration: const InputDecoration(
                  labelText: 'Próximos meses',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem(value: 2, child: Text('2 meses')),
                  DropdownMenuItem(value: 3, child: Text('3 meses')),
                  DropdownMenuItem(value: 6, child: Text('6 meses')),
                  DropdownMenuItem(value: 12, child: Text('12 meses')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => meses = value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Reativar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) return;

    await _executar(
      () => _service.reativarRecorrencia(item, mesesFuturos: meses),
      'Recorrência reativada com sucesso.',
      'Não foi possível reativar a recorrência',
    );
  }

  Future<void> _configurarNotificacao(RecorrenciaAtiva item) async {
    var ativa = item.notificacaoAtiva;
    var diasAntes = item.diasAntesNotificacao;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configurar aviso'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ativa,
                    onChanged: (value) => setDialogState(() => ativa = value),
                    title: const Text('Notificação ativa'),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  DropdownButtonFormField<int>(
                    initialValue: diasAntes,
                    decoration: const InputDecoration(
                      labelText: 'Avisar com antecedência',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(value: 1, child: Text('1 dia antes')),
                      DropdownMenuItem(value: 2, child: Text('2 dias antes')),
                      DropdownMenuItem(value: 3, child: Text('3 dias antes')),
                      DropdownMenuItem(value: 5, child: Text('5 dias antes')),
                      DropdownMenuItem(value: 7, child: Text('7 dias antes')),
                    ],
                    onChanged: ativa
                        ? (value) {
                            if (value != null) {
                              setDialogState(() => diasAntes = value);
                            }
                          }
                        : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) return;

    await _executar(
      () => _service.atualizarNotificacao(
        recorrencia: item,
        ativa: ativa,
        diasAntes: diasAntes,
      ),
      'Configuração de aviso atualizada com sucesso.',
      'Não foi possível atualizar o aviso',
    );
  }

  Future<void> _removerProximos(RecorrenciaAtiva item) async {
    final confirmar = await AppConfirmDialog.show(
      context,
      title: 'Remover próximos lançamentos',
      message:
          'Isso removerá somente os lançamentos futuros dessa recorrência.',
      confirmText: 'Remover',
    );
    if (!confirmar) return;

    await _executar(
      () => _service.removerProximosLancamentos(item),
      'Próximos lançamentos removidos com sucesso.',
      'Não foi possível remover os próximos lançamentos',
    );
  }

  Future<void> _removerCompleta(RecorrenciaAtiva item) async {
    final confirmar = await AppConfirmDialog.show(
      context,
      title: 'Remover recorrência',
      message:
          'Isso removerá os próximos lançamentos e esconderá essa recorrência da lista.',
      confirmText: 'Remover',
    );
    if (!confirmar) return;

    await _executar(
      () => _service.removerRecorrenciaCompletamente(item),
      'Recorrência removida com sucesso.',
      'Não foi possível remover a recorrência',
    );
  }

  Future<void> _abrirAcoesRecorrencia(RecorrenciaAtiva item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s8,
              AppSpacing.s8,
              AppSpacing.s8,
              AppSpacing.s16,
            ),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Configurar aviso'),
                  subtitle: Text(
                    item.notificacaoAtiva
                        ? 'Ativo • ${item.diasAntesNotificacao} dia(s) antes'
                        : 'Desativado',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _configurarNotificacao(item);
                  },
                ),
                if (item.origem == RecorrenciaOrigem.detectada)
                  ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Confirmar recorrência'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmarRecorrencia(item);
                    },
                  ),
                if (item.status == RecorrenciaStatus.ativa)
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline),
                    title: const Text('Pausar recorrência'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pausarRecorrencia(item);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Reativar recorrência'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reativarRecorrencia(item);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('Remover só próximos lançamentos'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removerProximos(item);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Remover recorrência',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removerCompleta(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(BuildContext context, RecorrenciaAtiva item) {
    if (item.status == RecorrenciaStatus.pausada) {
      return Theme.of(context).colorScheme.outline;
    }
    if (item.estaAtrasada) {
      return Theme.of(context).colorScheme.error;
    }
    if (item.venceEmBreve) {
      return Theme.of(context).colorScheme.tertiary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _statusResumo(RecorrenciaAtiva item) {
    if (item.status == RecorrenciaStatus.pausada) return 'Pausada';
    if (item.estaAtrasada) return 'Atrasada';
    if (item.venceHoje) return 'Vence hoje';
    if (item.venceEmDias == 1) return 'Vence amanhã';
    if (item.venceEmDias > 1) return 'Vence em ${item.venceEmDias} dias';
    return 'Ativa';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Compras recorrentes')),
      body: StreamBuilder<List<RecorrenciaAtiva>>(
        stream: _service.streamRecorrenciasAtivas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final exception = AppException.from(snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Text(
                  exception.message,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final recorrencias = snapshot.data ?? <RecorrenciaAtiva>[];

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
                      'As recorrências criadas ou detectadas aparecerão aqui.',
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
              final item = recorrencias[index];
              final statusColor = _statusColor(context, item);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.titulo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          IconButton(
                            onPressed: () => _abrirAcoesRecorrencia(item),
                            icon: const Icon(Icons.more_vert),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusResumo(item),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.origemLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.notificacaoAtiva
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.10,
                                    )
                                  : theme.colorScheme.outline.withValues(
                                      alpha: 0.10,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.notificacaoAtiva
                                  ? 'Aviso ${item.diasAntesNotificacao}d antes'
                                  : 'Sem aviso',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: item.notificacaoAtiva
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        AppFormatters.moeda(item.valorMedio),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Último valor: ${AppFormatters.moeda(item.ultimoValor)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (item.temVariacaoValor) ...[
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Variação em relação à média: ${AppFormatters.moeda(item.variacaoValor.abs())}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Categoria: ${item.categoriaLabel} • Todo dia ${item.diaDoMes}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Próximo vencimento: ${AppFormatters.dataCurta(item.proximoVencimento)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Histórico: ${item.quantidadeHistorica} • Próximos lançamentos: ${item.quantidadeFutura}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
