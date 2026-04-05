import 'package:flutter/material.dart';

import '../../models/conta_model.dart';
import '../../models/gasto_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_formatters.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({
    super.key,
    required this.db,
    this.onTapSaidas,
    this.onTapReceber,
  });

  final DatabaseService db;

  final VoidCallback? onTapSaidas;
  final VoidCallback? onTapReceber;

  double _variacaoPercentual(double atual, double anterior) {
    if (anterior == 0) {
      return atual == 0 ? 0 : 100;
    }
    return ((atual - anterior) / anterior.abs()) * 100;
  }

  String _mensagemErroDashboard(Object? error) {
    final String erro = (error ?? '').toString().toLowerCase();
    if (erro.contains('firestore.googleapis.com') ||
        erro.contains('permission_denied')) {
      return 'Firestore sem permissao ou desativado no projeto.\n'
          'Ative o Cloud Firestore no Firebase Console e tente novamente.';
    }
    return 'Erro ao carregar o painel.';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardResumo>(
      stream: db.dashboardResumo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _mensagemErroDashboard(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Gasto> gastos = snapshot.data?.gastos ?? [];
        final List<Conta> contas = snapshot.data?.contas ?? [];

        double totalGastosMes = 0;
        double totalGastosMesAnterior = 0;
        final int mesAtual = DateTime.now().month;
        final int anoAtual = DateTime.now().year;
        final DateTime mesAnteriorData = DateTime(anoAtual, mesAtual - 1);
        final int mesAnterior = mesAnteriorData.month;
        final int anoMesAnterior = mesAnteriorData.year;

        for (final gasto in gastos) {
          if (gasto.data.month == mesAtual && gasto.data.year == anoAtual) {
            totalGastosMes += gasto.valor;
          } else if (gasto.data.month == mesAnterior &&
              gasto.data.year == anoMesAnterior) {
            totalGastosMesAnterior += gasto.valor;
          }
        }

        double totalPendente = 0;
        double totalRecebidoMesAtual = 0;
        double totalRecebidoMesAnterior = 0;
        for (final conta in contas) {
          if (!conta.foiPago) {
            totalPendente += conta.valor;
          } else {
            if (conta.data.month == mesAtual && conta.data.year == anoAtual) {
              totalRecebidoMesAtual += conta.valor;
            }

            if (conta.data.month == mesAnterior &&
                conta.data.year == anoMesAnterior) {
              totalRecebidoMesAnterior += conta.valor;
            }
          }
        }

        final double saldo = totalRecebidoMesAtual - totalGastosMes;
        final double saldoMesAnterior =
            totalRecebidoMesAnterior - totalGastosMesAnterior;
        final bool saldoPositivo = saldo >= 0;
        final double variacaoSaldo = _variacaoPercentual(
          saldo,
          saldoMesAnterior,
        );
        final double variacaoGastos = _variacaoPercentual(
          totalGastosMes,
          totalGastosMesAnterior,
        );

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
                'Mês de ${AppFormatters.nomeMes(mesAtual)}',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                child: Container(
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
                        AppFormatters.moeda(saldo),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ComparativoChip(
                      titulo: 'Saldo vs mês anterior',
                      percentual: variacaoSaldo,
                      positivoEhBom: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ComparativoChip(
                      titulo: 'Gastos vs mês anterior',
                      percentual: variacaoGastos,
                      positivoEhBom: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _MiniSummaryCard(
                      titulo: 'Saídas',
                      valor: totalGastosMes,
                      cor: Colors.red,
                      icone: Icons.arrow_downward,
                      onTap: onTapSaidas,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniSummaryCard(
                      titulo: 'A Receber',
                      valor: totalPendente,
                      cor: Colors.orange,
                      icone: Icons.pending_actions,
                      onTap: onTapReceber,
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
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
    this.onTap,
  });

  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                AppFormatters.moeda(valor),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparativoChip extends StatelessWidget {
  const _ComparativoChip({
    required this.titulo,
    required this.percentual,
    required this.positivoEhBom,
  });

  final String titulo;
  final double percentual;
  final bool positivoEhBom;

  @override
  Widget build(BuildContext context) {
    final bool subiu = percentual >= 0;
    final bool bom = positivoEhBom ? subiu : !subiu;
    final Color cor = bom ? Colors.green : Colors.red;
    final IconData icone = subiu ? Icons.trending_up : Icons.trending_down;

    return Card(
      elevation: 0,
      color: cor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$titulo: ${percentual.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: cor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
