import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/conta_model.dart';
import '../../models/gasto_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_formatters.dart';
import '../../widgets/app_skeleton.dart';

enum _PeriodoRapido { hoje, seteDias, mes, trimestre }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.db,
    this.onTapSaidas,
    this.onTapReceber,
  });

  final DatabaseService db;

  final VoidCallback? onTapSaidas;
  final VoidCallback? onTapReceber;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _PeriodoRapido _periodo = _PeriodoRapido.mes;

  ({DateTime inicio, DateTime fimExclusivo}) _faixaAtual(DateTime agora) {
    final DateTime hoje = DateTime(agora.year, agora.month, agora.day);

    switch (_periodo) {
      case _PeriodoRapido.hoje:
        return (inicio: hoje, fimExclusivo: hoje.add(const Duration(days: 1)));
      case _PeriodoRapido.seteDias:
        return (
          inicio: hoje.subtract(const Duration(days: 6)),
          fimExclusivo: hoje.add(const Duration(days: 1)),
        );
      case _PeriodoRapido.mes:
        final DateTime inicioMes = DateTime(agora.year, agora.month);
        return (
          inicio: inicioMes,
          fimExclusivo: DateTime(inicioMes.year, inicioMes.month + 1),
        );
      case _PeriodoRapido.trimestre:
        final DateTime inicioTrim = DateTime(agora.year, agora.month - 2, 1);
        return (
          inicio: inicioTrim,
          fimExclusivo: hoje.add(const Duration(days: 1)),
        );
    }
  }

  ({DateTime inicio, DateTime fimExclusivo}) _faixaAnterior(
    DateTime inicioAtual,
    DateTime fimAtualExclusivo,
  ) {
    final Duration duracao = fimAtualExclusivo.difference(inicioAtual);
    final DateTime fimAnterior = inicioAtual;
    final DateTime inicioAnterior = fimAnterior.subtract(duracao);
    return (inicio: inicioAnterior, fimExclusivo: fimAnterior);
  }

  bool _estaNaFaixa(DateTime data, DateTime inicio, DateTime fimExclusivo) {
    return !data.isBefore(inicio) && data.isBefore(fimExclusivo);
  }

  String _tituloPeriodo(DateTime agora) {
    switch (_periodo) {
      case _PeriodoRapido.hoje:
        return 'Hoje';
      case _PeriodoRapido.seteDias:
        return 'Últimos 7 dias';
      case _PeriodoRapido.mes:
        return 'Mês de ${AppFormatters.nomeMes(agora.month)}';
      case _PeriodoRapido.trimestre:
        return 'Últimos 3 meses';
    }
  }

  String _labelPeriodo(_PeriodoRapido periodo) {
    switch (periodo) {
      case _PeriodoRapido.hoje:
        return 'Hoje';
      case _PeriodoRapido.seteDias:
        return '7 dias';
      case _PeriodoRapido.mes:
        return 'Mês';
      case _PeriodoRapido.trimestre:
        return 'Trimestre';
    }
  }

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
      stream: widget.db.dashboardResumo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Text(
                _mensagemErroDashboard(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Gasto> gastos = snapshot.data?.gastos ?? [];
        final List<Conta> contas = snapshot.data?.contas ?? [];

        final DateTime agora = DateTime.now();
        final ({DateTime inicio, DateTime fimExclusivo}) faixaAtual =
            _faixaAtual(agora);
        final ({DateTime inicio, DateTime fimExclusivo}) faixaAnterior =
            _faixaAnterior(faixaAtual.inicio, faixaAtual.fimExclusivo);

        double totalGastosPeriodo = 0;
        double totalGastosPeriodoAnterior = 0;

        for (final gasto in gastos) {
          if (_estaNaFaixa(
            gasto.data,
            faixaAtual.inicio,
            faixaAtual.fimExclusivo,
          )) {
            totalGastosPeriodo += gasto.valor;
          } else if (_estaNaFaixa(
            gasto.data,
            faixaAnterior.inicio,
            faixaAnterior.fimExclusivo,
          )) {
            totalGastosPeriodoAnterior += gasto.valor;
          }
        }

        double totalPendente = 0;
        double totalRecebidoPeriodo = 0;
        double totalRecebidoPeriodoAnterior = 0;
        for (final conta in contas) {
          if (!conta.foiPago) {
            totalPendente += conta.valor;
          } else {
            if (_estaNaFaixa(
              conta.data,
              faixaAtual.inicio,
              faixaAtual.fimExclusivo,
            )) {
              totalRecebidoPeriodo += conta.valor;
            } else if (_estaNaFaixa(
              conta.data,
              faixaAnterior.inicio,
              faixaAnterior.fimExclusivo,
            )) {
              totalRecebidoPeriodoAnterior += conta.valor;
            }
          }
        }

        final double saldo = totalRecebidoPeriodo - totalGastosPeriodo;
        final double saldoMesAnterior =
            totalRecebidoPeriodoAnterior - totalGastosPeriodoAnterior;
        final bool saldoPositivo = saldo >= 0;
        final double variacaoSaldo = _variacaoPercentual(
          saldo,
          saldoMesAnterior,
        );
        final double variacaoGastos = _variacaoPercentual(
          totalGastosPeriodo,
          totalGastosPeriodoAnterior,
        );

        final Map<CategoriaGasto, double> totaisPorCategoria =
            <CategoriaGasto, double>{};
        for (final gasto in gastos) {
          if (_estaNaFaixa(
            gasto.data,
            faixaAtual.inicio,
            faixaAtual.fimExclusivo,
          )) {
            totaisPorCategoria[gasto.categoria] =
                (totaisPorCategoria[gasto.categoria] ?? 0) + gasto.valor;
          }
        }

        final List<MapEntry<CategoriaGasto, double>> categoriasOrdenadas =
            totaisPorCategoria.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        final MapEntry<CategoriaGasto, double>? categoriaMaisGasta =
            categoriasOrdenadas.isEmpty ? null : categoriasOrdenadas.first;
        final MapEntry<CategoriaGasto, double>? categoriaMenosGasta =
            categoriasOrdenadas.isEmpty ? null : categoriasOrdenadas.last;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: ListView(
            children: [
              const Text(
                'Resumo Financeiro',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _tituloPeriodo(agora),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: _PeriodoRapido.values.map((periodo) {
                  final bool selecionado = _periodo == periodo;
                  return ChoiceChip(
                    label: Text(_labelPeriodo(periodo)),
                    selected: selecionado,
                    onSelected: (_) {
                      setState(() {
                        _periodo = periodo;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.s24),
              _DashboardEntry(
                delayMs: 0,
                child: Card(
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s24),
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
                        const SizedBox(height: AppSpacing.s8),
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
              ),
              const SizedBox(height: AppSpacing.s12),
              _DashboardEntry(
                delayMs: 70,
                child: Row(
                  children: [
                    Expanded(
                      child: _ComparativoChip(
                        titulo: 'Saldo vs mês anterior',
                        percentual: variacaoSaldo,
                        positivoEhBom: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _ComparativoChip(
                        titulo: 'Gastos vs mês anterior',
                        percentual: variacaoGastos,
                        positivoEhBom: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              _DashboardEntry(
                delayMs: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniSummaryCard(
                        titulo: 'Saídas',
                        valor: totalGastosPeriodo,
                        cor: Colors.red,
                        icone: Icons.arrow_downward,
                        onTap: widget.onTapSaidas,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _MiniSummaryCard(
                        titulo: 'A Receber',
                        valor: totalPendente,
                        cor: Colors.orange,
                        icone: Icons.pending_actions,
                        onTap: widget.onTapReceber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              _DashboardEntry(
                delayMs: 180,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categorias de gastos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        if (categoriasOrdenadas.isEmpty)
                          const Text(
                            'Sem gastos no período para montar gráfico.',
                          )
                        else
                          Row(
                            children: [
                              SizedBox(
                                width: 130,
                                height: 130,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Ícone elegante no centro do Donut Chart
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.3),
                                      size: 36,
                                    ),
                                    SizedBox(
                                      width: 130,
                                      height: 130,
                                      child: CustomPaint(
                                        painter: _PieChartPainter(
                                          categoriasOrdenadas,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _CategoriaResumoLinha(
                                      titulo: '+ gasto',
                                      categoria: categoriaMaisGasta?.key,
                                      valor: categoriaMaisGasta?.value ?? 0,
                                    ),
                                    const SizedBox(height: AppSpacing.s12),
                                    _CategoriaResumoLinha(
                                      titulo: '- gasto',
                                      categoria: categoriaMenosGasta?.key,
                                      valor: categoriaMenosGasta?.value ?? 0,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              Center(
                child: Icon(
                  Icons.insights,
                  size: 100,
                  color: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
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
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, size: 16, color: cor),
                  const SizedBox(width: AppSpacing.s8),
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
              const SizedBox(height: AppSpacing.s12),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 16),
            const SizedBox(width: AppSpacing.s8),
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

class _DashboardEntry extends StatelessWidget {
  const _DashboardEntry({required this.child, required this.delayMs});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: AppMotion.fast.inMilliseconds + delayMs),
      curve: AppMotion.curve,
      builder: (context, value, _) {
        final double slide = (1 - value) * 0.04;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * slide),
            child: child,
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class _CategoriaResumoLinha extends StatelessWidget {
  const _CategoriaResumoLinha({
    required this.titulo,
    required this.categoria,
    required this.valor,
  });

  final String titulo;
  final CategoriaGasto? categoria;
  final double valor;

  @override
  Widget build(BuildContext context) {
    if (categoria == null) {
      return Text('$titulo: sem dados');
    }

    return Row(
      children: [
        CircleAvatar(radius: 7, backgroundColor: categoria!.color),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            '$titulo: ${categoria!.label}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(
          AppFormatters.moeda(valor),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ==========================================
// PINTOR DO GRÁFICO (PIE CHART MODERNO)
// ==========================================
class _PieChartPainter extends CustomPainter {
  _PieChartPainter(this.data);

  final List<MapEntry<CategoriaGasto, double>> data;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = data.fold(0, (sum, item) => sum + item.value);
    if (total <= 0) return;

    // Define a espessura da linha do gráfico
    const double strokeWidth = 22.0;

    // Ajusta o raio para que a linha não seja cortada (clipped) nas bordas
    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Trilha de fundo (Anel cinza clarinho)
    final Paint bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Cores das Categorias com pontas arredondadas
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round; // O segredo da beleza moderna está aqui!

    double startAngle = -math.pi / 2;

    // Adiciona um pequeno espaço entre as cores se houver mais de uma categoria
    final double gap = data.length > 1 ? 0.12 : 0.0;

    for (final item in data) {
      final double sweep = (item.value / total) * math.pi * 2;

      // Garante que o segmento seja visível mesmo subtraindo o gap
      final double actualSweep = math.max(0.01, sweep - gap);

      paint.color = item.key.color;

      // Desenha o segmento deslocando metade do gap para centralizar o espaço
      canvas.drawArc(rect, startAngle + (gap / 2), actualSweep, false, paint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
