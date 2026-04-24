import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/di/service_locator.dart';
import 'package:paga_o_que_me_deve/core/errors/app_exceptions.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/a_receber/data/services/recebiveis_service.dart';
import 'package:paga_o_que_me_deve/features/a_receber/presentation/screens/novo_recebivel_screen.dart';

class AReceberScreen extends StatefulWidget {
  const AReceberScreen({
    super.key,
    this.somentePendentes = false,
  });

  final bool somentePendentes;

  @override
  State<AReceberScreen> createState() => _AReceberScreenState();
}

class _AReceberScreenState extends State<AReceberScreen> {
  late final RecebiveisService _recebiveisService;
  final ScrollController _listController = ScrollController();
  Stream<List<Conta>>? _contasStream;
  final TextEditingController _buscaController = TextEditingController();

  Timer? _debounce;

  String _termoBusca = '';
  bool _selecionandoLote = false;
  bool _processandoLote = false;
  final Set<String> _idsSelecionados = <String>{};
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTime get _inicioMes =>
      DateTime(_mesSelecionado.year, _mesSelecionado.month);

  DateTime get _fimMesExclusivo =>
      DateTime(_mesSelecionado.year, _mesSelecionado.month + 1);

  @override
  void initState() {
    super.initState();
    final db = getIt<FinanceRepository>();
    _recebiveisService = RecebiveisService(db);
    _contasStream = _recebiveisService.contasAReceber;
    _buscaController.addListener(_onBuscaAlterada);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.removeListener(_onBuscaAlterada);
    _buscaController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onBuscaAlterada() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final novoTermo = _buscaController.text;
      if (novoTermo == _termoBusca) return;

      setState(() {
        _termoBusca = novoTermo;
      });
    });
  }

  Stream<List<Conta>> _obterContasStream() {
    return _contasStream ??= _recebiveisService.contasAReceber;
  }

  DateTime _dataReferenciaConta(Conta conta) {
    if (conta.foiPago) {
      return conta.recebidaEm ?? conta.data;
    }
    return conta.data;
  }

  bool _estaNoMes(DateTime data) {
    return !data.isBefore(_inicioMes) && data.isBefore(_fimMesExclusivo);
  }

  Future<void> _selecionarMes() async {
    final hoje = DateTime.now();
    var anoSelecionado = _mesSelecionado.year;
    var mesSelecionado = _mesSelecionado.month;

    final selecionado = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                AppSpacing.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecionar mês',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: mesSelecionado,
                          decoration: const InputDecoration(labelText: 'Mês'),
                          items: List<DropdownMenuItem<int>>.generate(
                            12,
                            (index) {
                              final month = index + 1;
                              return DropdownMenuItem<int>(
                                value: month,
                                child: Text(AppFormatters.nomeMes(month)),
                              );
                            },
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => mesSelecionado = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: anoSelecionado,
                          decoration: const InputDecoration(labelText: 'Ano'),
                          items: List<DropdownMenuItem<int>>.generate(
                            81,
                            (index) {
                              final year = 2020 + index;
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(year.toString()),
                              );
                            },
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => anoSelecionado = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          DateTime(anoSelecionado, mesSelecionado),
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, DateTime(hoje.year, hoje.month)),
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Ir para mês atual'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _mesSelecionado = DateTime(selecionado.year, selecionado.month);
      });
    }
  }

  void _setStatePreservandoScroll(VoidCallback fn) {
    final tinhaClientes = _listController.hasClients;
    final offsetAntes = tinhaClientes ? _listController.offset : 0;

    setState(fn);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) {
        return;
      }
      final max = _listController.position.maxScrollExtent;
      final destino = offsetAntes.clamp(0, max).toDouble();
      if ((_listController.offset - destino).abs() > 0.5) {
        _listController.jumpTo(destino);
      }
    });
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

  void _iniciarSelecaoLoteCom(String id) {
    _setStatePreservandoScroll(() {
      _selecionandoLote = true;
      _idsSelecionados.add(id);
    });
  }

  void _alternarSelecaoItem(String id) {
    _setStatePreservandoScroll(() {
      if (_idsSelecionados.contains(id)) {
        _idsSelecionados.remove(id);
      } else {
        _idsSelecionados.add(id);
      }

      if (_idsSelecionados.isEmpty) {
        _selecionandoLote = false;
      }
    });
  }

  void _encerrarSelecaoLote() {
    _setStatePreservandoScroll(() {
      _selecionandoLote = false;
      _idsSelecionados.clear();
    });
  }

  List<Conta> _selecionadosDe(List<Conta> contas) {
    return contas
        .where((conta) => _idsSelecionados.contains(conta.id))
        .toList();
  }

  Future<void> _excluirSelecionados(List<Conta> selecionados) async {
    if (selecionados.isEmpty || _processandoLote) {
      return;
    }

    final confirmar = await AppConfirmDialog.show(
      context,
      title: 'Excluir em lote',
      message: 'Deseja excluir ${selecionados.length} cobranças selecionadas?',
    );
    if (!confirmar) {
      return;
    }

    setState(() => _processandoLote = true);
    try {
      for (final conta in selecionados) {
        await _recebiveisService.deletarRecebivel(conta.id);
      }
      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        '${selecionados.length} cobranças excluídas.',
      );
      _encerrarSelecaoLote();
    } catch (e) {
      if (!mounted) return;
      final exception = AppException.from(e);
      AppFeedback.showError(context, exception.message);
    } finally {
      if (mounted) {
        setState(() => _processandoLote = false);
      }
    }
  }

  Future<void> _marcarSelecionadosComo(
    List<Conta> selecionados,
    bool pago,
  ) async {
    if (selecionados.isEmpty || _processandoLote) {
      return;
    }

    setState(() => _processandoLote = true);
    try {
      for (final conta in selecionados) {
        if (conta.foiPago != pago) {
          await _recebiveisService.alternarStatusRecebivel(
            conta.id,
            conta.foiPago,
          );
        }
      }
      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        pago
            ? 'Cobranças marcadas como recebidas.'
            : 'Cobranças marcadas como pendentes.',
      );
      _encerrarSelecaoLote();
    } catch (e) {
      if (!mounted) return;
      final exception = AppException.from(e);
      AppFeedback.showError(context, exception.message);
    } finally {
      if (mounted) {
        setState(() => _processandoLote = false);
      }
    }
  }

  void _abrirNovaCobranca() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NovoRecebivelScreen(),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.somentePendentes ? 'Contas pendentes' : 'A receber',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Organize entradas e acompanhe pagamentos por mês.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoFinanceiroCard({
    required ThemeData theme,
    required String titulo,
    required String valor,
    required Color cor,
    required IconData icon,
    bool destaque = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: destaque ? AppSpacing.s16 : AppSpacing.s12,
        vertical: destaque ? AppSpacing.s14 : AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: destaque ? 0.12 : 0.09),
        borderRadius: BorderRadius.circular(destaque ? 18 : 999),
        border: Border.all(
          color: cor.withValues(alpha: destaque ? 0.24 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: destaque ? 34 : 28,
            height: destaque ? 34 : 28,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cor, size: destaque ? 20 : 16),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  valor,
                  style:
                      (destaque
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.titleMedium)
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cor.withValues(alpha: 0.96),
                            letterSpacing: -0.2,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo({
    required ThemeData theme,
    required double totalRecebidoMes,
    required double totalPendenteMes,
    required double progresso,
  }) {
    final semantic = context.semanticColors;

    final base = theme.colorScheme.primaryContainer;
    final accent = theme.colorScheme.surfaceContainerHighest;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, theme.colorScheme.surface, 0.28) ?? base,
            Color.lerp(accent, base, 0.28) ?? accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.insights_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  'Resumo do mês',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _selecionarMes,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(AppFormatters.mesAno(_mesSelecionado)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Expanded(
                child: _buildResumoFinanceiroCard(
                  theme: theme,
                  titulo: 'Recebido no mês',
                  valor: AppFormatters.moeda(totalRecebidoMes),
                  cor: semantic.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _buildResumoFinanceiroCard(
                  theme: theme,
                  titulo: 'Pendente no mês',
                  valor: AppFormatters.moeda(totalPendenteMes),
                  cor: semantic.error,
                  icon: Icons.pending_actions_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(semantic.success),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildResumoPill(
                theme: theme,
                icon: Icons.calendar_today_outlined,
                label: AppFormatters.mesAno(_mesSelecionado),
              ),
              if (widget.somentePendentes)
                _buildResumoPill(
                  theme: theme,
                  icon: Icons.filter_alt_outlined,
                  label: 'Somente pendentes',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuscaField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: TextField(
        controller: _buscaController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por nome do devedor',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _termoBusca.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  onPressed: _buscaController.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildLoteCard({
    required ThemeData theme,
    required List<Conta> selecionados,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.done_all_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${selecionados.length} selecionado${selecionados.length == 1 ? '' : 's'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _processandoLote ? null : _encerrarSelecaoLote,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha uma ação para aplicar aos itens marcados.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: selecionados.isEmpty || _processandoLote
                        ? null
                        : () => _marcarSelecionadosComo(selecionados, true),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar recebido'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: selecionados.isEmpty || _processandoLote
                        ? null
                        : () => _marcarSelecionadosComo(selecionados, false),
                    icon: const Icon(Icons.pending_actions_outlined),
                    label: const Text('Marcar pendente'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: selecionados.isEmpty || _processandoLote
                        ? null
                        : () => _excluirSelecionados(selecionados),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Excluir'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({required ThemeData theme, required bool foiPago}) {
    final cor = foiPago ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        foiPago ? 'RECEBIDO' : 'PENDENTE',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _dataContaLabel(Conta conta) {
    final dataBase = _dataReferenciaConta(conta);
    return AppFormatters.dataCurta(dataBase);
  }

  Widget _buildContaTile({
    required ThemeData theme,
    required Conta conta,
    required bool selecionado,
  }) {
    final pago = conta.foiPago;
    final statusColor = pago ? Colors.green.shade700 : Colors.red.shade700;

    final Widget tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selecionado
              ? theme.colorScheme.primary.withValues(alpha: 0.26)
              : theme.colorScheme.outline.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () async {
          if (_selecionandoLote) {
            _alternarSelecaoItem(conta.id);
            return;
          }

          try {
            await _recebiveisService.alternarStatusRecebivel(
              conta.id,
              conta.foiPago,
            );
          } catch (e) {
            if (!mounted) return;
            final exception = AppException.from(e);
            AppFeedback.showError(context, exception.message);
          }
        },
        onLongPress: () {
          if (_selecionandoLote) {
            _alternarSelecaoItem(conta.id);
            return;
          }
          _iniciarSelecaoLoteCom(conta.id);
        },
        leading: _selecionandoLote
            ? Checkbox(
                value: selecionado,
                onChanged: (_) => _alternarSelecaoItem(conta.id),
              )
            : Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  pago ? Icons.check_rounded : Icons.schedule_rounded,
                  color: statusColor,
                ),
              ),
        title: Text(
          conta.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            decoration: pago ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conta.descricao.isEmpty ? 'Sem descrição' : conta.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dataContaLabel(conta),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatters.moeda(conta.valor),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusChip(theme: theme, foiPago: pago),
          ],
        ),
      ),
    );

    return Dismissible(
      key: Key(conta.id),
      direction: _selecionandoLote
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (_selecionandoLote) {
          return false;
        }
        return _confirmarExclusao(context, conta);
      },
      onDismissed: (direction) async {
        if (_selecionandoLote) {
          return;
        }
        try {
          await _recebiveisService.deletarRecebivel(conta.id);
        } catch (e) {
          if (!mounted) return;
          final exception = AppException.from(e);
          AppFeedback.showError(context, exception.message);
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: tile,
    );
  }

  Widget _buildEmptyActionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool buscando) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          children: [
            if (!buscando) ...[
              Row(
                children: [
                  _buildEmptyActionCard(
                    theme: theme,
                    icon: Icons.add_rounded,
                    title: 'Nova cobrança',
                    subtitle: 'Cadastre um novo valor a receber',
                    onTap: _abrirNovaCobranca,
                  ),
                  const SizedBox(width: 12),
                  _buildEmptyActionCard(
                    theme: theme,
                    icon: Icons.calendar_month_outlined,
                    title: 'Trocar mês',
                    subtitle: 'Veja recebimentos e pendências de outro mês',
                    onTap: _selecionarMes,
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      buscando
                          ? Icons.search_off_rounded
                          : Icons.attach_money_rounded,
                      size: 38,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    buscando
                        ? 'Nenhum devedor encontrado'
                        : (widget.somentePendentes
                              ? 'Nenhuma conta pendente neste mês'
                              : 'Nenhuma cobrança neste mês'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    buscando
                        ? 'Tente outro nome do devedor para encontrar a cobrança desejada.'
                        : 'Altere o mês selecionado ou cadastre uma nova cobrança.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (!buscando) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _abrirNovaCobranca,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar cobrança'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Conta>>(
      stream: _obterContasStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeleton();
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

        final todasAsContas = snapshot.data ?? <Conta>[];

        final contasDoMes = todasAsContas.where((conta) {
          return _estaNoMes(_dataReferenciaConta(conta));
        }).toList();

        final listaContas = widget.somentePendentes
            ? contasDoMes.where((conta) => !conta.foiPago).toList()
            : contasDoMes;

        final contasFiltradas = listaContas.where(_filtrarPorNome).toList();

        final selecionados = _selecionadosDe(contasFiltradas);

        double totalRecebidoMes = 0;
        double totalPendenteMes = 0;

        for (final conta in contasDoMes) {
          if (conta.foiPago) {
            totalRecebidoMes += conta.valor;
          } else {
            totalPendenteMes += conta.valor;
          }
        }

        final totalGeralMes = totalRecebidoMes + totalPendenteMes;
        final progresso = totalGeralMes == 0
            ? 0.0
            : totalRecebidoMes / totalGeralMes;
        final buscando = _termoBusca.trim().isNotEmpty;

        return ColoredBox(
          color: theme.colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(theme),
                if (!_selecionandoLote && !buscando)
                  _buildCardResumo(
                    theme: theme,
                    totalRecebidoMes: totalRecebidoMes,
                    totalPendenteMes: totalPendenteMes,
                    progresso: progresso,
                  ),
                _buildBuscaField(theme),
                if (_selecionandoLote)
                  _buildLoteCard(theme: theme, selecionados: selecionados),
                if (contasFiltradas.isEmpty)
                  _buildEmptyState(theme, buscando)
                else
                  Expanded(
                    child: ListView.builder(
                      controller: _listController,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: contasFiltradas.length,
                      itemBuilder: (context, index) {
                        final conta = contasFiltradas[index];
                        final selecionado = _idsSelecionados.contains(
                          conta.id,
                        );

                        return _buildContaTile(
                          theme: theme,
                          conta: conta,
                          selecionado: selecionado,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
