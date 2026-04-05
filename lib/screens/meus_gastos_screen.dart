import 'package:flutter/material.dart';

import '../models/gasto_model.dart';
import '../services/database_service.dart';

class MeusGastosScreen extends StatefulWidget {
  const MeusGastosScreen({super.key});

  @override
  State<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends State<MeusGastosScreen> {
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String _formatarMes(DateTime date) {
    const List<String> meses = [
      'Janeiro',
      'Fevereiro',
      'Marco',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return '${meses[date.month - 1]} de ${date.year}';
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
      helpText: 'Escolha uma data para filtrar o mes',
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
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gasto>>(
      stream: DatabaseService().meusGastos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Gasto no Mes',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatarValor(0),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _selecionarMes,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatarMes(_mesSelecionado)),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Nenhum gasto neste mes.\nClique no + para adicionar.',
                    textAlign: TextAlign.center,
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
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Gasto no Mes',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatarValor(totalGasto),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.payments)),
                      title: Text(
                        gasto.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(gasto.categoria.name.toUpperCase()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatarValor(gasto.valor),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            tooltip: 'Excluir',
                            onPressed: () async {
                              final bool confirmado = await _confirmarExclusao(
                                gasto,
                              );
                              if (!confirmado) {
                                return;
                              }

                              try {
                                await DatabaseService().deletarGasto(gasto.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Erro ao excluir gasto: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
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
