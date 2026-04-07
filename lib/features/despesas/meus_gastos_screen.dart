import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../ui/ui.dart';
import 'novo_gasto_screen.dart';

class MeusGastosScreen extends StatefulWidget {
  const MeusGastosScreen({super.key, required this.db, this.initialFilter});

  final FinanceRepository db;
  final DashboardDrillDownFilter? initialFilter;

  @override
  State<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends State<MeusGastosScreen> {
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

  Future<void> _selecionarMes() async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: _mesSelecionado,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Escolha uma data para filtrar o mês',
    );

    if (data != null) {
      setState(() {
        _mesSelecionado = DateTime(data.year, data.month);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Meus gastos',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Acompanhe e ajuste seus lancamentos do mes.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo({
    required double totalGasto,
    required int quantidade,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Total do mes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _selecionarMes,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(_formatarMes(_mesSelecionado)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _formatarValor(totalGasto),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Chip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text('$quantidade item${quantidade == 1 ? '' : 's'}'),
                visualDensity: VisualDensity.compact,
              ),
              if (_filtroCategoriaPadrao != null ||
                  _filtroCategoriaPersonalizadaId != null ||
                  _filtroTipo != null)
                const Chip(
                  avatar: Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text('Filtros ativos'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (_filtroCategoriaPadrao != null ||
              _filtroCategoriaPersonalizadaId != null ||
              _filtroTipo != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
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
                    label: const Text('Categoria custom'),
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildSubtitle(Gasto gasto) {
    final List<String> partes = <String>[
      'Dia ${gasto.data.day.toString().padLeft(2, '0')}',
      gasto.categoriaLabelExibicao,
    ];

    if (gasto.origem == OrigemGasto.cartaoCredito) {
      partes.add('Cartao ${gasto.cartaoNome ?? ''}'.trim());
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
        '${selecionados.length} gastos excluidos.',
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
          return Column(
            children: [
              _buildCabecalhoTela(),
              _buildCardResumo(totalGasto: 0, quantidade: 0),
              Expanded(
                child: AppEmptyStateCta(
                  icon: Icons.wallet_outlined,
                  title: 'Sem gastos neste periodo',
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
          );
        }

        return Column(
          children: [
            if (_selecionandoLote)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s16,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${selecionados.length} selecionados',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _processandoLote
                                  ? null
                                  : _encerrarSelecaoLote,
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed:
                                  _processandoLote ||
                                      gastosFiltrados.isEmpty ||
                                      selecionados.length ==
                                          gastosFiltrados.length
                                  ? null
                                  : () => _marcarTodos(gastosFiltrados),
                              child: const Text('Marcar todos'),
                            ),
                          ],
                        ),
                        const Text(
                          'As alteracoes so serao aplicadas apos escolher uma acao abaixo.',
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  selecionados.isEmpty || _processandoLote
                                  ? null
                                  : () => _alterarCategoriaSelecionados(
                                      selecionados,
                                    ),
                              icon: const Icon(Icons.category_outlined),
                              label: const Text('Mudar categoria'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  selecionados.isEmpty || _processandoLote
                                  ? null
                                  : () =>
                                        _alterarTipoSelecionados(selecionados),
                              icon: const Icon(Icons.tune),
                              label: const Text('Alterar tipo'),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  selecionados.isEmpty || _processandoLote
                                  ? null
                                  : () => _excluirSelecionados(selecionados),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Excluir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                  final bool selecionado = _idsSelecionados.contains(gasto.id);

                  final Widget tile = Card(
                    key: ValueKey<String>('gasto_tile_${gasto.id}'),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: 6,
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
                              onChanged: (_) => _alternarSelecaoItem(gasto.id),
                            )
                          : CircleAvatar(
                              backgroundColor: gasto.categoriaCorExibicao
                                  .withValues(alpha: 0.15),
                              child: Icon(
                                gasto.categoriaIconeExibicao,
                                color: gasto.categoriaCorExibicao,
                              ),
                            ),
                      title: Text(
                        gasto.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_buildSubtitle(gasto)),
                      trailing: Text(
                        _formatarValor(gasto.valor),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                    child: tile,
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
