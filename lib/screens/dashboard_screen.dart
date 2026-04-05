import 'package:flutter/material.dart';

import '../models/conta_model.dart';
import '../models/gasto_model.dart';
import '../services/database_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gasto>>(
      stream: DatabaseService().meusGastos,
      builder: (context, snapshotGastos) {
        return StreamBuilder<List<Conta>>(
          stream: DatabaseService().contasAReceber,
          builder: (context, snapshotContas) {
            if (snapshotGastos.connectionState == ConnectionState.waiting ||
                snapshotContas.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<Gasto> gastos = snapshotGastos.data ?? [];
            final List<Conta> contas = snapshotContas.data ?? [];

            double totalGastosMes = 0;
            final int mesAtual = DateTime.now().month;
            final int anoAtual = DateTime.now().year;

            for (final gasto in gastos) {
              if (gasto.data.month == mesAtual && gasto.data.year == anoAtual) {
                totalGastosMes += gasto.valor;
              }
            }

            double totalPendente = 0;
            double totalRecebido = 0;
            for (final conta in contas) {
              if (!conta.foiPago) {
                totalPendente += conta.valor;
              } else {
                totalRecebido += conta.valor;
              }
            }

            final double saldo = totalRecebido - totalGastosMes;
            final bool saldoPositivo = saldo >= 0;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Resumo Financeiro',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mes de ${['Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'][mesAtual - 1]}',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: saldoPositivo
                            ? [Colors.green.shade400, Colors.teal.shade500]
                            : [Colors.red.shade400, Colors.deepOrange.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (saldoPositivo ? Colors.green : Colors.red)
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Saldo Mensal (Recebido - Gastos)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'R\$ ${saldo.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniSummaryCard(
                          titulo: 'Saidas',
                          valor: totalGastosMes,
                          cor: Colors.red,
                          icone: Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniSummaryCard(
                          titulo: 'A Receber',
                          valor: totalPendente,
                          cor: Colors.orange,
                          icone: Icons.pending_actions,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: Icon(
                      Icons.insights,
                      size: 100,
                      color: Colors.grey.shade200,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 16, color: cor),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 13,
                    color: cor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
