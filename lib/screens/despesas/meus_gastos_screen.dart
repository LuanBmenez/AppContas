import 'package:flutter/material.dart';

import '../../models/gasto_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_formatters.dart';
import '../../widgets/app_skeleton.dart';
import 'novo_gasto_screen.dart';

class MeusGastosScreen extends StatefulWidget {
  const MeusGastosScreen({super.key, required this.db});

  final DatabaseService db;

  @override
  State<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends State<MeusGastosScreen> {
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String _formatarMes(DateTime date) {
    return AppFormatters.mesAno(date);
  }

  bool _mesCorresponde(DateTime data) {
    return data.year == _mesSelecionado.year &&
        data.month == _mesSelecionado.month;
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
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir gasto'),
          content: Text('Deseja excluir "${gasto.titulo}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    return confirmado ?? false;
  }

  String _formatarValor(double valor) {
    return AppFormatters.moeda(valor);
  }

  String _buildSubtitle(Gasto gasto) {
    final List<String> partes = <String>[
      'Dia ${gasto.data.day.toString().padLeft(2, '0')}',
      gasto.categoria.label,
    ];

    if (gasto.origem == OrigemGasto.cartaoCredito) {
      partes.add('Cartao ${gasto.cartaoNome ?? ''}'.trim());
    }

    if (gasto.parcelaLabel != null) {
      partes.add('Parcela ${gasto.parcelaLabel}');
    }

    return partes.join(' • ');
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoria atualizada com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar categoria: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gasto>>(
      stream: widget.db.meusGastos,
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

        final List<Gasto> gastosFiltrados = (snapshot.data ?? [])
            .where((gasto) => _mesCorresponde(gasto.data))
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        const Text(
                          'Nenhum gasto neste mês',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        const Text(
                          'Registre um novo gasto para começar a acompanhar suas saídas.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NovoGastoScreen(db: widget.db),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar gasto'),
                        ),
                      ],
                    ),
                  ),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao excluir gasto: $e'),
                              backgroundColor: Colors.red,
                            ),
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
                          backgroundColor: gasto.categoria.color.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(
                            gasto.categoria.icon,
                            color: gasto.categoria.color,
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
