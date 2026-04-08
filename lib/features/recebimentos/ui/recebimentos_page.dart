import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';

import '../data/recebimentos_service.dart';
import 'widgets/recebimento_status_chip.dart';
import 'widgets/resumo_mensal_recebimentos.dart';

class RecebimentosPage extends StatefulWidget {
  const RecebimentosPage({super.key});

  @override
  State<RecebimentosPage> createState() => _RecebimentosPageState();
}

class _RecebimentosPageState extends State<RecebimentosPage> {
  late String competenciaSelecionada;
  late final RecebimentosService service;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    competenciaSelecionada =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    service = RecebimentosService();
  }

  List<String> _competenciasDisponiveis() {
    final DateTime now = DateTime.now();

    return List<String>.generate(12, (int index) {
      final DateTime date = DateTime(now.year, index + 1, 1);
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    });
  }

  String _formatarCompetencia(String competencia) {
    final List<String> partes = competencia.split('-');
    if (partes.length != 2) {
      return competencia;
    }

    final int? ano = int.tryParse(partes[0]);
    final int? mes = int.tryParse(partes[1]);

    if (ano == null || mes == null || mes < 1 || mes > 12) {
      return competencia;
    }

    try {
      return DateFormat.yMMM('pt_BR').format(DateTime(ano, mes, 1));
    } catch (_) {
      return '${mes.toString().padLeft(2, '0')}/$ano';
    }
  }

  String _formatarMoeda(double valor) {
    try {
      return NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
      ).format(valor);
    } catch (_) {
      return 'R\$ ${valor.toStringAsFixed(2)}';
    }
  }

  String _formatarData(DateTime data) {
    try {
      return DateFormat('dd/MM/yyyy', 'pt_BR').format(data);
    } catch (_) {
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> competencias = _competenciasDisponiveis();

    if (!competencias.contains(competenciaSelecionada) &&
        competencias.isNotEmpty) {
      competenciaSelecionada = competencias.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recebimentos'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: competenciaSelecionada,
                  borderRadius: BorderRadius.circular(12),
                  items: competencias.map((String competencia) {
                    return DropdownMenuItem<String>(
                      value: competencia,
                      child: Text(_formatarCompetencia(competencia)),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;

                    setState(() {
                      competenciaSelecionada = value;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Recebimento>>(
        stream: service.streamRecebimentosPorMes(competenciaSelecionada),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar recebimentos: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<Recebimento> recebimentos =
              snapshot.data ?? <Recebimento>[];

          return Column(
            children: [
              ResumoMensalRecebimentos(recebimentos: recebimentos),
              Expanded(
                child: recebimentos.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum recebimento encontrado para este mês.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: recebimentos.length,
                        itemBuilder: (context, index) {
                          final Recebimento r = recebimentos[index];

                          return ListTile(
                            title: Text(_formatarMoeda(r.valor)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Previsto: ${_formatarData(r.dataPrevista)}',
                                ),
                                if (r.dataRecebido != null)
                                  Text(
                                    'Recebido: ${_formatarData(r.dataRecebido!)}',
                                  ),
                              ],
                            ),
                            trailing: RecebimentoStatusChip(status: r.status),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
