import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/guardado/data/services/guardado_service.dart';

class GuardadoScreen extends StatefulWidget {
  const GuardadoScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<GuardadoScreen> createState() => _GuardadoScreenState();
}

class _GuardadoScreenState extends State<GuardadoScreen> {
  late final GuardadoService _guardadoService;

  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void initState() {
    super.initState();
    _guardadoService = GuardadoService(widget.db);
  }

  DateTime get _inicioMes =>
      DateTime(_mesSelecionado.year, _mesSelecionado.month, 1);

  DateTime get _fimMesExclusivo =>
      DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 1);

  String get _competenciaSelecionada =>
      Guardado.competenciaFromDate(_mesSelecionado);

  void _mesAnterior() {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month - 1,
        1,
      );
    });
  }

  void _proximoMes() {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + 1,
        1,
      );
    });
  }

  bool _estaNoMes(DateTime data) {
    return !data.isBefore(_inicioMes) && data.isBefore(_fimMesExclusivo);
  }

  DateTime _dataReferenciaConta(Conta conta) {
    return conta.recebidaEm ?? conta.data;
  }

  double _somarGastosMes(List<Gasto> gastos) {
    double total = 0;
    for (final Gasto gasto in gastos) {
      if (_estaNoMes(gasto.data)) {
        total += gasto.valor;
      }
    }
    return total;
  }

  double _somarRecebidoMes(List<Conta> contas) {
    double total = 0;
    for (final Conta conta in contas) {
      if (!conta.foiPago) {
        continue;
      }

      final DateTime dataReferencia = _dataReferenciaConta(conta);
      if (_estaNoMes(dataReferencia)) {
        total += conta.valor;
      }
    }
    return total;
  }

  double _somarValores(
    Iterable<Guardado> itens, {
    GuardadoTipoMovimentacao? somenteTipo,
  }) {
    double total = 0;
    for (final Guardado item in itens) {
      if (somenteTipo != null && item.tipoMovimentacao != somenteTipo) {
        continue;
      }
      total += item.valor;
    }
    return total;
  }

  double _somarLiquido(Iterable<Guardado> itens) {
    double total = 0;
    for (final Guardado item in itens) {
      total += item.valorAssinado;
    }
    return total;
  }

  Map<GuardadoDestino, double> _agruparPorDestino(Iterable<Guardado> itens) {
    final Map<GuardadoDestino, double> totais = <GuardadoDestino, double>{
      for (final GuardadoDestino destino in GuardadoDestino.values) destino: 0,
    };

    for (final Guardado item in itens) {
      totais[item.destino] = (totais[item.destino] ?? 0) + item.valorAssinado;
    }

    return totais;
  }

  Map<String, double> _agruparPorMeta(Iterable<Guardado> itens) {
    final Map<String, double> totais = <String, double>{};

    for (final Guardado item in itens) {
      final String meta = item.metaNome?.trim() ?? '';
      if (meta.isEmpty) {
        continue;
      }
      totais[meta] = (totais[meta] ?? 0) + item.valorAssinado;
    }

    final List<MapEntry<String, double>> entradas = totais.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map<String, double>.fromEntries(entradas);
  }

  List<String> _metasExistentes(List<Guardado> guardados) {
    final Set<String> metas = <String>{};
    for (final Guardado item in guardados) {
      final String meta = item.metaNome?.trim() ?? '';
      if (meta.isNotEmpty) {
        metas.add(meta);
      }
    }
    final List<String> lista = metas.toList()..sort();
    return lista;
  }

  String _formatarMes(DateTime data) {
    return AppFormatters.mesAno(data);
  }

  double? _parseValor(String texto) {
    final String normalizado = texto
        .trim()
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    if (normalizado.isEmpty) {
      return null;
    }

    return double.tryParse(normalizado);
  }

  String _valorFormatadoComSinal(Guardado item) {
    final String sinal =
        item.tipoMovimentacao == GuardadoTipoMovimentacao.aporte ? '+' : '-';
    return '$sinal ${AppFormatters.moeda(item.valor)}';
  }

  String _metaLabel(String? metaNome) {
    final String meta = metaNome?.trim() ?? '';
    return meta.isEmpty ? 'Sem meta' : meta;
  }

  Future<void> _selecionarDataMovimentacao({
    required DateTime dataAtual,
    required ValueChanged<DateTime> onSelecionada,
  }) async {
    final DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: dataAtual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Escolha a data da movimentação',
    );

    if (novaData != null) {
      onSelecionada(novaData);
    }
  }

  Future<void> _abrirFormularioGuardado({
    Guardado? existente,
    required GuardadoTipoMovimentacao tipoInicial,
    required double saldoMes,
    required double totalAportesMes,
    required double saldoGuardadoTotal,
    required List<String> metasExistentes,
  }) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController valorController = TextEditingController(
      text: existente != null
          ? existente.valor.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    final TextEditingController observacaoController = TextEditingController(
      text: existente?.observacao ?? '',
    );
    final TextEditingController metaController = TextEditingController(
      text: existente?.metaNome ?? '',
    );

    GuardadoDestino destinoSelecionado =
        existente?.destino ?? GuardadoDestino.semDestino;
    GuardadoTipoMovimentacao tipoSelecionado =
        existente?.tipoMovimentacao ?? tipoInicial;
    DateTime dataSelecionada =
        existente?.data ??
        DateTime(
          _mesSelecionado.year,
          _mesSelecionado.month,
          DateTime.now().year == _mesSelecionado.year &&
                  DateTime.now().month == _mesSelecionado.month
              ? DateTime.now().day
              : 1,
        );
    bool salvando = false;

    final double saldoGuardadoSemAtual =
        saldoGuardadoTotal - (existente?.valorAssinado ?? 0);
    final double saldoResgateDisponivel = math.max(0, saldoGuardadoSemAtual);
    final double aporteDisponivel = math.max(
      0,
      saldoMes -
          (totalAportesMes -
              ((existente?.tipoMovimentacao == GuardadoTipoMovimentacao.aporte)
                  ? (existente?.valor ?? 0)
                  : 0)),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> salvar() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final double? valor = _parseValor(valorController.text);
              if (valor == null || valor <= 0) {
                return;
              }

              if (tipoSelecionado == GuardadoTipoMovimentacao.resgate &&
                  valor > saldoResgateDisponivel + 0.001) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'O resgate não pode ser maior que o saldo guardado disponível.',
                    ),
                  ),
                );
                return;
              }

              setModalState(() => salvando = true);

              try {
                final Guardado item = Guardado(
                  id: existente?.id ?? '',
                  valor: valor,
                  data: dataSelecionada,
                  competencia: Guardado.competenciaFromDate(dataSelecionada),
                  destino: destinoSelecionado,
                  tipoMovimentacao: tipoSelecionado,
                  metaNome: metaController.text.trim().isEmpty
                      ? null
                      : metaController.text.trim(),
                  observacao: observacaoController.text.trim().isEmpty
                      ? null
                      : observacaoController.text.trim(),
                );

                if (existente == null) {
                  await _guardadoService.salvarGuardado(item);
                } else {
                  await _guardadoService.atualizarGuardado(item);
                }

                if (!mounted) return;
                Navigator.of(modalContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      existente == null
                          ? 'Movimentação salva com sucesso.'
                          : 'Movimentação atualizada com sucesso.',
                    ),
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao salvar movimentação.')),
                );
              } finally {
                if (mounted) {
                  setModalState(() => salvando = false);
                }
              }
            }

            final ThemeData theme = Theme.of(context);
            final String ajudaTipo =
                tipoSelecionado == GuardadoTipoMovimentacao.aporte
                ? 'Disponível para guardar neste mês: ${AppFormatters.moeda(aporteDisponivel)}'
                : 'Saldo total disponível para resgate: ${AppFormatters.moeda(saldoResgateDisponivel)}';

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              existente == null
                                  ? 'Nova movimentação'
                                  : 'Editar movimentação',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Guarde, resgate e vincule a uma meta escolhida por você.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: GuardadoTipoMovimentacao.values.map((
                                tipo,
                              ) {
                                return ChoiceChip(
                                  label: Text(tipo.label),
                                  selected: tipoSelecionado == tipo,
                                  avatar: Icon(
                                    tipo.icon,
                                    size: 18,
                                    color: tipo.color,
                                  ),
                                  onSelected: (_) {
                                    setModalState(() => tipoSelecionado = tipo);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              ajudaTipo,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: valorController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Valor',
                                border: OutlineInputBorder(),
                                hintText: 'Ex: 250,00',
                              ),
                              validator: (value) {
                                final double? valor = _parseValor(value ?? '');
                                if (valor == null || valor <= 0) {
                                  return 'Informe um valor válido';
                                }
                                if (tipoSelecionado ==
                                        GuardadoTipoMovimentacao.resgate &&
                                    valor > saldoResgateDisponivel + 0.001) {
                                  return 'Resgate maior que o saldo guardado disponível';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<GuardadoDestino>(
                              initialValue: destinoSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Destino',
                                border: OutlineInputBorder(),
                              ),
                              items: GuardadoDestino.values.map((destino) {
                                return DropdownMenuItem<GuardadoDestino>(
                                  value: destino,
                                  child: Text(destino.label),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(
                                    () => destinoSelecionado = value,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _selecionarDataMovimentacao(
                                dataAtual: dataSelecionada,
                                onSelecionada: (novaData) {
                                  setModalState(
                                    () => dataSelecionada = novaData,
                                  );
                                },
                              ),
                              child: Ink(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            'Mês de referência',
                                            style: theme.textTheme.labelMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppFormatters.dataCurta(
                                              dataSelecionada,
                                            ),
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: metaController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Meta',
                                border: OutlineInputBorder(),
                                hintText: 'Ex: reserva de emergência',
                              ),
                            ),
                            if (metasExistentes.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: metasExistentes.map((meta) {
                                  return ActionChip(
                                    label: Text(meta),
                                    onPressed: () {
                                      setModalState(
                                        () => metaController.text = meta,
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: observacaoController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Observação',
                                border: OutlineInputBorder(),
                                hintText: 'Opcional',
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: salvando ? null : salvar,
                        icon: const Icon(Icons.check),
                        label: Text(salvando ? 'Salvando...' : 'Salvar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    valorController.dispose();
    observacaoController.dispose();
    metaController.dispose();
  }

  Future<void> _excluirItem(Guardado item) async {
    try {
      await _guardadoService.deletarGuardado(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removido do guardado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao remover item.')));
    }
  }

  Widget _buildResumoCard({
    required ThemeData theme,
    required String titulo,
    required String valor,
    required String descricao,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final Widget child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titulo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  valor,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descricao,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: child,
    );
  }

  Widget _buildDestinoResumoCard(
    ThemeData theme,
    GuardadoDestino destino,
    double valor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destino.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: destino.color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: destino.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(destino.icon, color: destino.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              destino.label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            AppFormatters.moeda(valor),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaResumoCard(ThemeData theme, String meta, double valor) {
    final bool positivo = valor >= 0;
    final Color color = positivo
        ? const Color(0xFF2563EB)
        : const Color(0xFFC26A00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.flag_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              meta,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            AppFormatters.moeda(valor),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return StreamBuilder<DashboardResumo>(
      stream: widget.db.dashboardResumo,
      builder: (context, dashboardSnapshot) {
        final DashboardResumo dashboardResumo =
            dashboardSnapshot.data ??
            const DashboardResumo(<Gasto>[], <Conta>[]);

        return StreamBuilder<List<Guardado>>(
          stream: _guardadoService.guardados,
          builder: (context, guardadosSnapshot) {
            final List<Guardado> guardados =
                guardadosSnapshot.data ?? <Guardado>[];
            final List<String> metasExistentes = _metasExistentes(guardados);

            final double totalRecebidoMes = _somarRecebidoMes(
              dashboardResumo.contas,
            );
            final double totalGastosMes = _somarGastosMes(
              dashboardResumo.gastos,
            );
            final double saldoMes = totalRecebidoMes - totalGastosMes;

            final List<Guardado> guardadosMes = guardados
                .where((item) => item.competencia == _competenciaSelecionada)
                .toList();

            final double totalAportesMes = _somarValores(
              guardadosMes,
              somenteTipo: GuardadoTipoMovimentacao.aporte,
            );
            final double totalResgatesMes = _somarValores(
              guardadosMes,
              somenteTipo: GuardadoTipoMovimentacao.resgate,
            );
            final double saldoLiquidoMes = _somarLiquido(guardadosMes);
            final double saldoGuardadoTotal = _somarLiquido(guardados);
            final double disponivelParaGuardar = math.max(
              0,
              saldoMes - totalAportesMes,
            );
            final Map<GuardadoDestino, double> totaisPorDestino =
                _agruparPorDestino(guardados);
            final Map<String, double> totaisPorMeta = _agruparPorMeta(
              guardados,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                Text(
                  'Guardado',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Organize aportes, resgates e metas do dinheiro que você separou.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.42,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: _mesAnterior,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _formatarMes(_mesSelecionado),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _proximoMes,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _abrirFormularioGuardado(
                          tipoInicial: GuardadoTipoMovimentacao.aporte,
                          saldoMes: saldoMes,
                          totalAportesMes: totalAportesMes,
                          saldoGuardadoTotal: saldoGuardadoTotal,
                          metasExistentes: metasExistentes,
                        ),
                        icon: const Icon(Icons.arrow_downward_rounded),
                        label: const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saldoGuardadoTotal <= 0
                            ? null
                            : () => _abrirFormularioGuardado(
                                tipoInicial: GuardadoTipoMovimentacao.resgate,
                                saldoMes: saldoMes,
                                totalAportesMes: totalAportesMes,
                                saldoGuardadoTotal: saldoGuardadoTotal,
                                metasExistentes: metasExistentes,
                              ),
                        icon: const Icon(Icons.arrow_upward_rounded),
                        label: const Text('Resgatar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Disponível para guardar',
                  valor: AppFormatters.moeda(disponivelParaGuardar),
                  descricao:
                      'Saldo do mês menos os aportes já feitos neste mês.',
                  icon: Icons.savings_outlined,
                  color: const Color(0xFF0F9D7A),
                  onTap: () => _abrirFormularioGuardado(
                    tipoInicial: GuardadoTipoMovimentacao.aporte,
                    saldoMes: saldoMes,
                    totalAportesMes: totalAportesMes,
                    saldoGuardadoTotal: saldoGuardadoTotal,
                    metasExistentes: metasExistentes,
                  ),
                ),
                const SizedBox(height: 12),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Já guardado no mês',
                  valor: AppFormatters.moeda(totalAportesMes),
                  descricao: 'Total que você aportou no mês selecionado.',
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(height: 12),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Resgatado no mês',
                  valor: AppFormatters.moeda(totalResgatesMes),
                  descricao:
                      'Quanto voltou do guardado para uso livre neste mês.',
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFC26A00),
                ),
                const SizedBox(height: 12),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Saldo guardado total',
                  valor: AppFormatters.moeda(saldoGuardadoTotal),
                  descricao: 'Saldo acumulado considerando aportes e resgates.',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 12),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Saldo líquido do mês',
                  valor: AppFormatters.moeda(saldoLiquidoMes),
                  descricao: 'Aportes menos resgates no mês selecionado.',
                  icon: Icons.swap_horiz_rounded,
                  color: saldoLiquidoMes >= 0
                      ? const Color(0xFF0F9D7A)
                      : const Color(0xFFD64545),
                ),
                const SizedBox(height: 20),
                Text(
                  'Metas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (totaisPorMeta.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                    child: Text(
                      'Você ainda não vinculou nenhuma meta. Ao criar uma movimentação, informe a meta que quiser.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...totaisPorMeta.entries.take(6).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildMetaResumoCard(
                        theme,
                        entry.key,
                        entry.value,
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                Text(
                  'Destinos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...GuardadoDestino.values.map((destino) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDestinoResumoCard(
                      theme,
                      destino,
                      totaisPorDestino[destino] ?? 0,
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Text(
                  'Movimentações do mês',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (guardadosMes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                    child: Text(
                      'Nenhuma movimentação neste mês ainda.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...guardadosMes.map((item) {
                    final Color tipoColor = item.tipoMovimentacao.color;
                    final List<String> partes = <String>[
                      item.tipoMovimentacao.label,
                      item.destino.label,
                      _metaLabel(item.metaNome),
                    ];
                    if (item.observacao?.isNotEmpty == true) {
                      partes.add(item.observacao!);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.08,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tipoColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.tipoMovimentacao.icon,
                            color: tipoColor,
                          ),
                        ),
                        title: Text(
                          _metaLabel(item.metaNome),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: 4),
                            Text(partes.join(' • ')),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.dataCurta(item.data),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'editar') {
                              _abrirFormularioGuardado(
                                existente: item,
                                tipoInicial: item.tipoMovimentacao,
                                saldoMes: saldoMes,
                                totalAportesMes: totalAportesMes,
                                saldoGuardadoTotal: saldoGuardadoTotal,
                                metasExistentes: metasExistentes,
                              );
                            } else if (value == 'excluir') {
                              _excluirItem(item);
                            }
                          },
                          itemBuilder: (context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'excluir',
                                  child: Text('Excluir'),
                                ),
                              ],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                _valorFormatadoComSinal(item),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tipoColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}
