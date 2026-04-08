import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

import 'novo_gasto_screen.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key, required this.db, this.initialFilter});

  final FinanceRepository db;
  final DashboardDrillDownFilter? initialFilter;

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final ScrollController _listController = ScrollController();
  Stream<List<Gasto>>? _gastosStream;
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTime get _inicioMes =>
      DateTime(_mesSelecionado.year, _mesSelecionado.month, 1);

  DateTime get _fimMesExclusivo =>
      DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 1);

  CategoriaGasto? _filtroCategoriaPadrao;
  String? _filtroCategoriaPersonalizadaId;
  TipoGasto? _filtroTipo;
  bool _selecionandoLote = false;
  bool _processandoLote = false;
  final Set<String> _idsSelecionados = <String>{};

  static const AppSemanticColors _fallbackSemanticColors = AppSemanticColors(
    success: Color(0xFF0F9D7A),
    successContainer: Color(0xFFE5F6F2),
    warning: Color(0xFFC26A00),
    warningContainer: Color(0xFFFFEED9),
    error: Color(0xFFD64545),
    errorContainer: Color(0xFFFDE8E8),
  );

  @override
  void initState() {
    super.initState();
    final DashboardDrillDownFilter? filtro = widget.initialFilter;
    if (filtro != null) {
      _filtroCategoriaPadrao = filtro.categoriaPadrao;
      _filtroCategoriaPersonalizadaId = filtro.categoriaPersonalizadaId;
      _filtroTipo = filtro.tipo;
      if (filtro.mesReferencia != null) {
        _mesSelecionado = DateTime(
          filtro.mesReferencia!.year,
          filtro.mesReferencia!.month,
        );
      }
    }
    _recarregarGastosStream();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _setStatePreservandoScroll(VoidCallback fn) {
    final bool tinhaClientes = _listController.hasClients;
    final double offsetAntes = tinhaClientes ? _listController.offset : 0;

    setState(fn);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) {
        return;
      }
      final double max = _listController.position.maxScrollExtent;
      final double destino = offsetAntes.clamp(0, max).toDouble();
      if ((_listController.offset - destino).abs() > 0.5) {
        _listController.jumpTo(destino);
      }
    });
  }

  void _recarregarGastosStream() {
    _gastosStream = widget.db.streamGastosPorPeriodo(
      inicio: _inicioMes,
      fimExclusivo: _fimMesExclusivo,
    );
  }

  Stream<List<Gasto>> _obterGastosStream() {
    return _gastosStream ??= widget.db.streamGastosPorPeriodo(
      inicio: _inicioMes,
      fimExclusivo: _fimMesExclusivo,
    );
  }

  String _formatarMes(DateTime date) {
    return AppFormatters.mesAno(date);
  }

  AppSemanticColors _semanticColors(ThemeData theme) {
    return theme.extension<AppSemanticColors>() ?? _fallbackSemanticColors;
  }

  bool get _temFiltrosAtivos {
    return _filtroCategoriaPadrao != null ||
        _filtroCategoriaPersonalizadaId != null ||
        _filtroTipo != null;
  }

  Future<void> _selecionarMes() async {
    final DateTime hoje = DateTime.now();
    int anoSelecionado = _mesSelecionado.year;
    int mesSelecionado = _mesSelecionado.month;

    final DateTime? selecionado = await showModalBottomSheet<DateTime>(
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
                          items: List<DropdownMenuItem<int>>.generate(12, (
                            index,
                          ) {
                            final int month = index + 1;
                            return DropdownMenuItem<int>(
                              value: month,
                              child: Text(AppFormatters.nomeMes(month)),
                            );
                          }),
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
                          items: List<DropdownMenuItem<int>>.generate(81, (
                            index,
                          ) {
                            final int year = 2020 + index;
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
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
                        onPressed: () => Navigator.pop(context, null),
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
        _recarregarGastosStream();
      });
    }
  }

  Future<bool> _confirmarExclusao(Gasto gasto) async {
    return AppConfirmDialog.show(
      context,
      title: 'Excluir gasto',
      message: 'Deseja excluir "${gasto.titulo}"?',
    );
  }

  String _formatarValor(double valor) {
    return AppFormatters.moeda(valor);
  }

  Widget _buildCabecalhoTela() {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meus gastos', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Acompanhe e ajuste seus lançamentos do mês.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo({
    required double totalGasto,
    required int quantidade,
  }) {
    final List<Widget> chipsFiltros = <Widget>[
      if (_filtroCategoriaPadrao != null)
        InputChip(
          label: Text('Categoria: ${_filtroCategoriaPadrao!.label}'),
          onDeleted: () {
            setState(() {
              _filtroCategoriaPadrao = null;
            });
          },
        ),
      if (_filtroCategoriaPersonalizadaId != null)
        InputChip(
          label: const Text('Categoria personalizada'),
          onDeleted: () {
            setState(() {
              _filtroCategoriaPersonalizadaId = null;
            });
          },
        ),
      if (_filtroTipo != null)
        InputChip(
          label: Text('Tipo: ${_filtroTipo!.label}'),
          onDeleted: () {
            setState(() {
              _filtroTipo = null;
            });
          },
        ),
    ];

    return ExpenseSummaryCard(
      totalLabel: 'Total do mês',
      totalValue: _formatarValor(totalGasto),
      monthLabel: _formatarMes(_mesSelecionado),
      itemCount: quantidade,
      hasActiveFilters: _temFiltrosAtivos,
      filterChips: chipsFiltros,
      onSelectMonth: _selecionarMes,
    );
  }

  String _buildSubtitle(Gasto gasto) {
    final List<String> partes = <String>[
      'Dia ${gasto.data.day.toString().padLeft(2, '0')}',
      gasto.categoriaLabelExibicao,
    ];

    if (gasto.origem == OrigemGasto.cartaoCredito) {
      partes.add('Cartão ${gasto.cartaoNome ?? ''}'.trim());
    }

    if (gasto.parcelaLabel != null) {
      partes.add('Parcela ${gasto.parcelaLabel}');
    }

    return partes.join(' • ');
  }

  bool _passaFiltrosAtivos(Gasto gasto) {
    if (_filtroTipo != null && gasto.tipo != _filtroTipo) {
      return false;
    }
    if (_filtroCategoriaPersonalizadaId != null &&
        _filtroCategoriaPersonalizadaId!.isNotEmpty) {
      return gasto.categoriaPersonalizadaId == _filtroCategoriaPersonalizadaId;
    }
    if (_filtroCategoriaPadrao != null) {
      return !gasto.usaCategoriaPersonalizada &&
          gasto.categoria == _filtroCategoriaPadrao;
    }
    return true;
  }

  Future<void> _editarCategoria(Gasto gasto) async {
    CategoriaGasto categoriaSelecionada = gasto.categoria;
    bool aprenderRegra = gasto.origem == OrigemGasto.cartaoCredito;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar categoria'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gasto.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  DropdownButtonFormField<CategoriaGasto>(
                    initialValue: categoriaSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                    items: CategoriaGasto.values
                        .map(
                          (categoria) => DropdownMenuItem<CategoriaGasto>(
                            value: categoria,
                            child: Text(categoria.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => categoriaSelecionada = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: aprenderRegra,
                    onChanged: (value) {
                      setDialogState(() => aprenderRegra = value ?? false);
                    },
                    title: const Text(
                      'Aprender regra para próximas importações',
                    ),
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

    if (confirmar != true) {
      return;
    }

    try {
      final Gasto gastoAtualizado = gasto.copyWith(
        categoria: categoriaSelecionada,
      );
      await widget.db.atualizarGasto(gastoAtualizado);

      if (aprenderRegra) {
        await widget.db.salvarRegraCategoriaImportacao(
          termo: gasto.titulo,
          categoria: categoriaSelecionada,
        );
      }

      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Categoria atualizada com sucesso.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'Erro ao atualizar categoria: $e');
    }
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

  void _marcarTodos(List<Gasto> gastos) {
    if (gastos.isEmpty) {
      return;
    }

    _setStatePreservandoScroll(() {
      _selecionandoLote = true;
      _idsSelecionados
        ..clear()
        ..addAll(gastos.map((gasto) => gasto.id));
    });
  }

  List<Gasto> _selecionadosDe(List<Gasto> gastos) {
    return gastos.where((g) => _idsSelecionados.contains(g.id)).toList();
  }

  Future<void> _excluirSelecionados(List<Gasto> selecionados) async {
    if (selecionados.isEmpty || _processandoLote) {
      return;
    }

    final bool confirmar = await AppConfirmDialog.show(
      context,
      title: 'Excluir em lote',
      message: 'Deseja excluir ${selecionados.length} gastos selecionados?',
      confirmText: 'Excluir',
    );
    if (!confirmar) {
      return;
    }

    setState(() => _processandoLote = true);
    try {
      for (final Gasto gasto in selecionados) {
        await widget.db.deletarGasto(gasto.id);
      }
      if (!mounted) {
        return;
      }
      AppFeedback.showSuccess(
        context,
        '${selecionados.length} gastos excluídos.',
      );
      _encerrarSelecaoLote();
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(context, 'Erro ao excluir em lote: $e');
    } finally {
      if (mounted) {
        setState(() => _processandoLote = false);
      }
    }
  }

  Future<void> _alterarCategoriaSelecionados(List<Gasto> selecionados) async {
    if (selecionados.isEmpty || _processandoLote) {
      return;
    }

    CategoriaGasto categoriaSelecionada = CategoriaGasto.outros;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Categoria em lote'),
              content: DropdownButtonFormField<CategoriaGasto>(
                initialValue: categoriaSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: CategoriaGasto.values
                    .map(
                      (categoria) => DropdownMenuItem<CategoriaGasto>(
                        value: categoria,
                        child: Text(categoria.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => categoriaSelecionada = value);
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
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() => _processandoLote = true);
    try {
      for (final Gasto gasto in selecionados) {
        await widget.db.atualizarGasto(
          gasto.copyWith(categoria: categoriaSelecionada),
        );
      }
      if (!mounted) {
        return;
      }
      AppFeedback.showSuccess(
        context,
        'Categoria atualizada em ${selecionados.length} gastos.',
      );
      _encerrarSelecaoLote();
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(context, 'Erro ao alterar categoria em lote: $e');
    } finally {
      if (mounted) {
        setState(() => _processandoLote = false);
      }
    }
  }

  Future<void> _alterarTipoSelecionados(List<Gasto> selecionados) async {
    if (selecionados.isEmpty || _processandoLote) {
      return;
    }

    TipoGasto tipoSelecionado = TipoGasto.variavel;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tipo em lote'),
              content: DropdownButtonFormField<TipoGasto>(
                initialValue: tipoSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: TipoGasto.values
                    .map(
                      (tipo) => DropdownMenuItem<TipoGasto>(
                        value: tipo,
                        child: Text(tipo.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tipoSelecionado = value);
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
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() => _processandoLote = true);
    try {
      for (final Gasto gasto in selecionados) {
        await widget.db.atualizarGasto(gasto.copyWith(tipo: tipoSelecionado));
      }
      if (!mounted) {
        return;
      }
      AppFeedback.showSuccess(
        context,
        'Tipo atualizado em ${selecionados.length} gastos.',
      );
      _encerrarSelecaoLote();
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(context, 'Erro ao alterar tipo em lote: $e');
    } finally {
      if (mounted) {
        setState(() => _processandoLote = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = _semanticColors(theme);

    return StreamBuilder<List<Gasto>>(
      stream: _obterGastosStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Text(
                'Erro ao carregar gastos: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Gasto> gastosBrutos = snapshot.data ?? <Gasto>[];
        final List<Gasto> gastosFiltrados = gastosBrutos
            .where(_passaFiltrosAtivos)
            .toList();
        final List<Gasto> selecionados = _selecionadosDe(gastosFiltrados);

        double totalGasto = 0;
        for (final gasto in gastosFiltrados) {
          totalGasto += gasto.valor;
        }

        if (gastosFiltrados.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    children: [
                      _buildCabecalhoTela(),
                      _buildCardResumo(totalGasto: 0, quantidade: 0),
                      Expanded(
                        child: AppEmptyStateCta(
                          icon: Icons.wallet_outlined,
                          title: 'Sem gastos neste período',
                          description: 'Adicione um gasto para começar.',
                          buttonLabel: 'Adicionar gasto',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NovoGastoScreen(db: widget.db),
                              ),
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

        return LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: [
                    if (_selecionandoLote)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s16,
                          AppSpacing.s16,
                          AppSpacing.s16,
                          AppSpacing.s8,
                        ),
                        child: BulkActionBar(
                          selectedCount: selecionados.length,
                          isBusy: _processandoLote,
                          canSelectAll:
                              !_processandoLote &&
                              gastosFiltrados.isNotEmpty &&
                              selecionados.length != gastosFiltrados.length,
                          canActOnSelection:
                              !_processandoLote && selecionados.isNotEmpty,
                          onCancel: _encerrarSelecaoLote,
                          onSelectAll: () => _marcarTodos(gastosFiltrados),
                          onChangeCategory: () =>
                              _alterarCategoriaSelecionados(selecionados),
                          onChangeType: () =>
                              _alterarTipoSelecionados(selecionados),
                          onDelete: () => _excluirSelecionados(selecionados),
                        ),
                      ),
                    _buildCabecalhoTela(),
                    if (!_selecionandoLote)
                      _buildCardResumo(
                        totalGasto: totalGasto,
                        quantidade: gastosFiltrados.length,
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _listController,
                        itemCount: gastosFiltrados.length,
                        itemBuilder: (context, index) {
                          final Gasto gasto = gastosFiltrados[index];
                          final bool selecionado = _idsSelecionados.contains(
                            gasto.id,
                          );

                          final Widget tile = Card(
                            key: ValueKey<String>('gasto_tile_${gasto.id}'),
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: AppSpacing.s6,
                            ),
                            child: ListTile(
                              onTap: () {
                                if (_selecionandoLote) {
                                  _alternarSelecaoItem(gasto.id);
                                  return;
                                }
                                _editarCategoria(gasto);
                              },
                              onLongPress: () {
                                if (_selecionandoLote) {
                                  _alternarSelecaoItem(gasto.id);
                                  return;
                                }
                                _iniciarSelecaoLoteCom(gasto.id);
                              },
                              leading: _selecionandoLote
                                  ? Checkbox(
                                      value: selecionado,
                                      onChanged: (_) =>
                                          _alternarSelecaoItem(gasto.id),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: gasto
                                          .categoriaCorExibicao
                                          .withValues(alpha: 0.15),
                                      child: Icon(
                                        gasto.categoriaIconeExibicao,
                                        color: gasto.categoriaCorExibicao,
                                      ),
                                    ),
                              title: Text(
                                gasto.titulo,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                _buildSubtitle(gasto),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Text(
                                _formatarValor(gasto.valor),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: semantic.error,
                                ),
                              ),
                            ),
                          );

                          return Dismissible(
                            key: Key(gasto.id),
                            direction: _selecionandoLote
                                ? DismissDirection.none
                                : DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              if (_selecionandoLote) {
                                return false;
                              }
                              return _confirmarExclusao(gasto);
                            },
                            onDismissed: (direction) async {
                              if (_selecionandoLote) {
                                return;
                              }
                              try {
                                await widget.db.deletarGasto(gasto.id);
                              } catch (e) {
                                if (context.mounted) {
                                  AppFeedback.showError(
                                    context,
                                    'Erro ao excluir gasto: $e',
                                  );
                                }
                              }
                            },
                            background: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: AppSpacing.s6,
                              ),
                              decoration: BoxDecoration(
                                color: semantic.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(
                                right: AppSpacing.s20,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: tile,
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
      },
    );
  }
}

typedef MeusGastosScreen = GastosScreen;

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.totalLabel,
    required this.totalValue,
    required this.monthLabel,
    required this.itemCount,
    required this.hasActiveFilters,
    required this.filterChips,
    required this.onSelectMonth,
  });

  final String totalLabel;
  final String totalValue;
  final String monthLabel;
  final int itemCount;
  final bool hasActiveFilters;
  final List<Widget> filterChips;
  final VoidCallback onSelectMonth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.tertiaryContainer,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.s16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.s10),
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  color: colorScheme.tertiary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  totalLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onSelectMonth,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(monthLabel),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            totalValue,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Resumo do mês selecionado',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Chip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text('$itemCount item${itemCount == 1 ? '' : 's'}'),
                visualDensity: VisualDensity.compact,
              ),
              if (hasActiveFilters)
                const Chip(
                  avatar: Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text('Filtros ativos'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (filterChips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: filterChips,
            ),
          ],
        ],
      ),
    );
  }
}

class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.isBusy,
    required this.canSelectAll,
    required this.canActOnSelection,
    required this.onCancel,
    required this.onSelectAll,
    required this.onChangeCategory,
    required this.onChangeType,
    required this.onDelete,
  });

  final int selectedCount;
  final bool isBusy;
  final bool canSelectAll;
  final bool canActOnSelection;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onChangeCategory;
  final VoidCallback onChangeType;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$selectedCount selecionados',
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: isBusy ? null : onCancel,
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: canSelectAll ? onSelectAll : null,
                  child: const Text('Marcar todos'),
                ),
              ],
            ),
            Text(
              'As alterações só serão aplicadas após escolher uma ação abaixo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                OutlinedButton.icon(
                  onPressed: canActOnSelection ? onChangeCategory : null,
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Mudar categoria'),
                ),
                OutlinedButton.icon(
                  onPressed: canActOnSelection ? onChangeType : null,
                  icon: const Icon(Icons.tune),
                  label: const Text('Alterar tipo'),
                ),
                FilledButton.icon(
                  onPressed: canActOnSelection ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
