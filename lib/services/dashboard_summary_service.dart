import 'package:flutter/material.dart';

import '../domain/repositories/finance_repository.dart';
import '../domain/models/conta.dart';
import '../domain/models/gasto.dart';
import '../utils/app_formatters.dart';

enum DashboardPeriodoRapido { hoje, seteDias, mes, trimestre }

class DashboardCategoriaResumo {
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  final double valor;
  final bool custom;
  final CategoriaGasto? categoriaPadrao;
  final String? categoriaPersonalizadaId;

  const DashboardCategoriaResumo({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
    required this.valor,
    required this.custom,
    this.categoriaPadrao,
    this.categoriaPersonalizadaId,
  });
}

class DashboardResumoCalculado {
  final double totalGastosPeriodo;
  final double totalPendente;
  final double saldo;
  final bool saldoPositivo;
  final double variacaoSaldo;
  final double variacaoGastos;
  final String comparativoLabel;
  final List<DashboardCategoriaResumo> categoriasOrdenadas;
  final DashboardCategoriaResumo? categoriaMaisGasta;
  final DashboardCategoriaResumo? categoriaMenosGasta;

  const DashboardResumoCalculado({
    required this.totalGastosPeriodo,
    required this.totalPendente,
    required this.saldo,
    required this.saldoPositivo,
    required this.variacaoSaldo,
    required this.variacaoGastos,
    required this.comparativoLabel,
    required this.categoriasOrdenadas,
    required this.categoriaMaisGasta,
    required this.categoriaMenosGasta,
  });
}

class DashboardSummaryService {
  const DashboardSummaryService();

  DashboardResumoCalculado calcularResumo({
    required DashboardResumo resumo,
    required DashboardPeriodoRapido periodo,
    CategoriaGasto? filtroCategoriaPadrao,
    String? filtroCategoriaPersonalizadaId,
    TipoGasto? filtroTipo,
    DateTime? inicioOverride,
    DateTime? fimExclusivoOverride,
    DateTime? agora,
  }) {
    final DateTime referencia = agora ?? DateTime.now();
    final ({DateTime inicio, DateTime fimExclusivo}) faixaAtual =
        inicioOverride != null && fimExclusivoOverride != null
        ? (inicio: inicioOverride, fimExclusivo: fimExclusivoOverride)
        : _faixaAtual(periodo, referencia);
    final ({DateTime inicio, DateTime fimExclusivo}) faixaAnterior =
        _faixaAnterior(faixaAtual.inicio, faixaAtual.fimExclusivo);

    double totalGastosPeriodo = 0;
    double totalGastosPeriodoAnterior = 0;

    for (final Gasto gasto in resumo.gastos) {
      if (!_passaFiltroGasto(
        gasto,
        filtroCategoriaPadrao: filtroCategoriaPadrao,
        filtroCategoriaPersonalizadaId: filtroCategoriaPersonalizadaId,
        filtroTipo: filtroTipo,
      )) {
        continue;
      }

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
    for (final Conta conta in resumo.contas) {
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
    final double variacaoSaldo = _variacaoPercentual(saldo, saldoMesAnterior);
    final double variacaoGastos = _variacaoPercentual(
      totalGastosPeriodo,
      totalGastosPeriodoAnterior,
    );

    final Map<String, DashboardCategoriaResumo> totaisPorCategoria =
        <String, DashboardCategoriaResumo>{};
    for (final Gasto gasto in resumo.gastos) {
      if (!_passaFiltroGasto(
        gasto,
        filtroCategoriaPadrao: filtroCategoriaPadrao,
        filtroCategoriaPersonalizadaId: filtroCategoriaPersonalizadaId,
        filtroTipo: filtroTipo,
      )) {
        continue;
      }

      if (_estaNaFaixa(
        gasto.data,
        faixaAtual.inicio,
        faixaAtual.fimExclusivo,
      )) {
        final bool custom = gasto.usaCategoriaPersonalizada;
        final String id = custom
            ? 'custom:${gasto.categoriaPersonalizadaId ?? gasto.categoriaLabelExibicao}'
            : 'std:${gasto.categoria.name}';
        final DashboardCategoriaResumo atual =
            totaisPorCategoria[id] ??
            DashboardCategoriaResumo(
              id: id,
              label: gasto.categoriaLabelExibicao,
              color: gasto.categoriaCorExibicao,
              icon: gasto.categoriaIconeExibicao,
              valor: 0,
              custom: custom,
              categoriaPadrao: custom ? null : gasto.categoria,
              categoriaPersonalizadaId: custom
                  ? gasto.categoriaPersonalizadaId
                  : null,
            );
        totaisPorCategoria[id] = DashboardCategoriaResumo(
          id: atual.id,
          label: atual.label,
          color: atual.color,
          icon: atual.icon,
          valor: atual.valor + gasto.valor,
          custom: atual.custom,
          categoriaPadrao: atual.categoriaPadrao,
          categoriaPersonalizadaId: atual.categoriaPersonalizadaId,
        );
      }
    }

    final List<DashboardCategoriaResumo> categoriasOrdenadas =
        totaisPorCategoria.values.toList()
          ..sort((a, b) => b.valor.compareTo(a.valor));

    final String comparativoLabel = _labelComparativo(faixaAnterior.inicio);

    return DashboardResumoCalculado(
      totalGastosPeriodo: totalGastosPeriodo,
      totalPendente: totalPendente,
      saldo: saldo,
      saldoPositivo: saldo >= 0,
      variacaoSaldo: variacaoSaldo,
      variacaoGastos: variacaoGastos,
      comparativoLabel: comparativoLabel,
      categoriasOrdenadas: categoriasOrdenadas,
      categoriaMaisGasta: categoriasOrdenadas.isEmpty
          ? null
          : categoriasOrdenadas.first,
      categoriaMenosGasta: categoriasOrdenadas.isEmpty
          ? null
          : categoriasOrdenadas.last,
    );
  }

  ({DateTime inicio, DateTime fimExclusivo}) faixaAtual(
    DashboardPeriodoRapido periodo,
    DateTime agora,
  ) {
    return _faixaAtual(periodo, agora);
  }

  ({DateTime inicio, DateTime fimExclusivo}) _faixaAtual(
    DashboardPeriodoRapido periodo,
    DateTime agora,
  ) {
    final DateTime hoje = DateTime(agora.year, agora.month, agora.day);

    switch (periodo) {
      case DashboardPeriodoRapido.hoje:
        return (inicio: hoje, fimExclusivo: hoje.add(const Duration(days: 1)));
      case DashboardPeriodoRapido.seteDias:
        return (
          inicio: hoje.subtract(const Duration(days: 6)),
          fimExclusivo: hoje.add(const Duration(days: 1)),
        );
      case DashboardPeriodoRapido.mes:
        final DateTime inicioMes = DateTime(agora.year, agora.month, 1);
        return (
          inicio: inicioMes,
          fimExclusivo: DateTime(inicioMes.year, inicioMes.month + 1, 1),
        );
      case DashboardPeriodoRapido.trimestre:
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

  double _variacaoPercentual(double atual, double anterior) {
    if (anterior == 0) {
      return atual == 0 ? 0 : 100;
    }
    return ((atual - anterior) / anterior.abs()) * 100;
  }

  bool _passaFiltroGasto(
    Gasto gasto, {
    CategoriaGasto? filtroCategoriaPadrao,
    String? filtroCategoriaPersonalizadaId,
    TipoGasto? filtroTipo,
  }) {
    if (filtroTipo != null && gasto.tipo != filtroTipo) {
      return false;
    }

    if (filtroCategoriaPersonalizadaId != null &&
        filtroCategoriaPersonalizadaId.isNotEmpty) {
      return gasto.categoriaPersonalizadaId == filtroCategoriaPersonalizadaId;
    }

    if (filtroCategoriaPadrao != null) {
      return !gasto.usaCategoriaPersonalizada &&
          gasto.categoria == filtroCategoriaPadrao;
    }

    return true;
  }

  String _labelComparativo(DateTime referencia) {
    return AppFormatters.nomeMes(referencia.month);
  }
}
