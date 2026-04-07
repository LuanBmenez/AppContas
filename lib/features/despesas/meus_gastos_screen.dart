import 'package:flutter/material.dart';

import '../../domain/repositories/finance_repository.dart';
import 'novo_gasto_screen.dart';
import '../../domain/models/models.dart';
import '../../ui/ui.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/utils.dart';

class MeusGastosScreen extends StatefulWidget {
  const MeusGastosScreen({super.key, required this.db, this.initialFilter});

  final FinanceRepository db;
  final DashboardDrillDownFilter? initialFilter;

  @override
  State<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends State<MeusGastosScreen> {
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
      AppFeedback.showSuccess(
        context,
        'Categoria atualizada com sucesso.',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'Erro ao atualizar categoria: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gasto>>(
      stream: widget.db.streamGastosPorPeriodo(
        inicio: _inicioMes,
        fimExclusivo: _fimMesExclusivo,
      ),
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

        if (gastosFiltrados.isEmpty) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Gasto no Mês',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      _formatarValor(0),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextButton.icon(
                      onPressed: _selecionarMes,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatarMes(_mesSelecionado)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppEmptyStateCta(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nenhum gasto neste mês',
                  description:
                      'Registre um novo gasto para começar a acompanhar suas saídas.',
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

        double totalGasto = 0;
        for (final gasto in gastosFiltrados) {
          totalGasto += gasto.valor;
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Gasto no Mês',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    _formatarValor(totalGasto),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextButton.icon(
                    onPressed: _selecionarMes,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_formatarMes(_mesSelecionado)),
                  ),
                  if (_filtroCategoriaPadrao != null ||
                      _filtroCategoriaPersonalizadaId != null ||
                      _filtroTipo != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (_filtroCategoriaPadrao != null)
                          InputChip(
                            label: Text(
                              'Categoria: ${_filtroCategoriaPadrao!.label}',
                            ),
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
            ),
            Expanded(
              child: ListView.builder(
                itemCount: gastosFiltrados.length,
                itemBuilder: (context, index) {
                  final Gasto gasto = gastosFiltrados[index];

                  return Dismissible(
                    key: Key(gasto.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return _confirmarExclusao(gasto);
                    },
                    onDismissed: (direction) async {
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
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        onTap: () => _editarCategoria(gasto),
                        leading: CircleAvatar(
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
