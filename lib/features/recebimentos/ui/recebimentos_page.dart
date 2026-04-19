import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';

import 'package:paga_o_que_me_deve/features/recebimentos/data/recebimentos_service.dart';
import 'package:paga_o_que_me_deve/features/recebimentos/ui/widgets/recebimento_status_chip.dart';
import 'package:paga_o_que_me_deve/features/recebimentos/ui/widgets/resumo_mensal_recebimentos.dart';

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
    final now = DateTime.now();
    competenciaSelecionada =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    service = RecebimentosService();
  }

  List<String> _competenciasDisponiveis() {
    final now = DateTime.now();

    return List<String>.generate(12, (index) {
      final date = DateTime(now.year, index + 1);
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    });
  }

  String _formatarCompetencia(String competencia) {
    final partes = competencia.split('-');
    if (partes.length != 2) {
      return competencia;
    }

    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);

    if (ano == null || mes == null || mes < 1 || mes > 12) {
      return competencia;
    }

    return DateFormat.yMMM('pt_BR').format(DateTime(ano, mes));
  }

  String _formatarMoeda(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(valor);
  }

  @override
  Widget build(BuildContext context) {
    final competencias = _competenciasDisponiveis();

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
                  items: competencias.map((competencia) {
                    return DropdownMenuItem<String>(
                      value: competencia,
                      child: Text(_formatarCompetencia(competencia)),
                    );
                  }).toList(),
                  onChanged: (value) {
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

          final recebimentos =
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
                          final r = recebimentos[index];

                          return ListTile(
                            title: Text(_formatarMoeda(r.valor)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Previsto: ${DateFormat('dd/MM/yyyy').format(r.dataPrevista)}',
                                ),
                                if (r.dataRecebido != null)
                                  Text(
                                    'Recebido: ${DateFormat('dd/MM/yyyy').format(r.dataRecebido!)}',
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
