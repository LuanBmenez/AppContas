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

  double _somarGuardados(Iterable<Guardado> itens) {
    double total = 0;
    for (final Guardado item in itens) {
      total += item.valor;
    }
    return total;
  }

  Map<GuardadoDestino, double> _agruparPorDestino(Iterable<Guardado> itens) {
    final Map<GuardadoDestino, double> totais = <GuardadoDestino, double>{
      for (final GuardadoDestino destino in GuardadoDestino.values) destino: 0,
    };

    for (final Guardado item in itens) {
      totais[item.destino] = (totais[item.destino] ?? 0) + item.valor;
    }

    return totais;
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

  Future<void> _abrirNovoGuardado(double disponivelMes) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController valorController = TextEditingController(
      text: disponivelMes > 0
          ? disponivelMes.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    final TextEditingController observacaoController = TextEditingController();

    GuardadoDestino destinoSelecionado = GuardadoDestino.semDestino;
    bool salvando = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            // <-- Renomeado para builderContext
            Future<void> salvar() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final double? valor = _parseValor(valorController.text);
              if (valor == null || valor <= 0) {
                return;
              }

              setModalState(() => salvando = true);

              try {
                final DateTime agora = DateTime.now();
                final int dia =
                    (agora.year == _mesSelecionado.year &&
                        agora.month == _mesSelecionado.month)
                    ? agora.day
                    : 1;

                final Guardado novoItem = Guardado(
                  id: '',
                  valor: valor,
                  data: DateTime(
                    _mesSelecionado.year,
                    _mesSelecionado.month,
                    dia,
                  ),
                  competencia: _competenciaSelecionada,
                  destino: destinoSelecionado,
                  observacao: observacaoController.text.trim().isEmpty
                      ? null
                      : observacaoController.text.trim(),
                );

                await _guardadoService.salvarGuardado(novoItem);

                // 1. Verifica o contexto do modal antes de fechar
                if (!modalContext.mounted) return;
                Navigator.of(modalContext).pop();

                // 2. Verifica o contexto da tela principal antes do SnackBar
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Valor guardado com sucesso.')),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao salvar guardado.')),
                );
              } finally {
                // 3. Verifica o contexto do construtor interno antes de mudar o estado
                if (builderContext.mounted) {
                  setModalState(() => salvando = false);
                }
              }
            }

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
                  children: <Widget>[
                    Text(
                      'Guardar valor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Escolha para onde foi a sobra deste mês.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(
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
                          setModalState(() => destinoSelecionado = value);
                        }
                      },
                    ),
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
                    const SizedBox(height: 16),
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

            final double totalGuardadoMes = _somarGuardados(guardadosMes);
            final double disponivelParaGuardar = math.max(
              0,
              saldoMes - totalGuardadoMes,
            );

            final Map<GuardadoDestino, double> totaisPorDestino =
                _agruparPorDestino(guardadosMes);

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
                  'Organize a sobra do mês e escolha o destino: caixinha, investimentos ou saldo livre.',
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
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Disponível para guardar',
                  valor: AppFormatters.moeda(disponivelParaGuardar),
                  descricao: 'Saldo do mês menos o que já foi destinado.',
                  icon: Icons.savings_outlined,
                  color: const Color(0xFF0F9D7A),
                  onTap: () => _abrirNovoGuardado(disponivelParaGuardar),
                ),
                const SizedBox(height: 12),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Saldo do mês',
                  valor: AppFormatters.moeda(saldoMes),
                  descricao: 'Recebido - gastos no mês selecionado.',
                  icon: Icons.account_balance_wallet_outlined,
                  color: saldoMes >= 0
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD64545),
                ),
                const SizedBox(height: 12),
                _buildResumoCard(
                  theme: theme,
                  titulo: 'Já destinado no mês',
                  valor: AppFormatters.moeda(totalGuardadoMes),
                  descricao:
                      'Quanto da sobra já foi enviado para algum destino.',
                  icon: Icons.call_split_outlined,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Text(
                      'Destinos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _abrirNovoGuardado(disponivelParaGuardar),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                    ),
                  ],
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
                      'Nenhum valor guardado neste mês ainda.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...guardadosMes.map((item) {
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: item.destino.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.destino.icon,
                            color: item.destino.color,
                          ),
                        ),
                        title: Text(
                          item.destino.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          item.observacao?.isNotEmpty == true
                              ? item.observacao!
                              : 'Sem observação',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'excluir') {
                              _excluirItem(item);
                            }
                          },
                          itemBuilder: (context) =>
                              const <PopupMenuEntry<String>>[
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
                                AppFormatters.moeda(item.valor),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppFormatters.dataCurta(item.data),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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
