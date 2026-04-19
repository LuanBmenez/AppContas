import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/utils/app_formatters.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

enum DashboardPeriodoRapido { hoje, seteDias, mes, trimestre }

class DashboardCategoriaResumo {
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
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  final double valor;
  final bool custom;
  final CategoriaGasto? categoriaPadrao;
  final String? categoriaPersonalizadaId;
}

class DashboardResumoCalculado {
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
}

class DashboardSummaryService {
  DashboardSummaryService({
    int maxCacheEntries = 150,
    Duration cacheTtl = const Duration(minutes: 10),
  }) : _maxCacheEntries = maxCacheEntries,
       _cacheTtl = cacheTtl;

  final int _maxCacheEntries;
  final Duration _cacheTtl;
  final LinkedHashMap<String, _DashboardCacheEntry> _cacheLru =
      LinkedHashMap<String, _DashboardCacheEntry>();

  int get cacheEntryCount => _cacheLru.length;

  void clearCache() {
    _cacheLru.clear();
  }

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
    final referencia = agora ?? DateTime.now();
    _evictExpired(referencia);

    final faixaAtual = inicioOverride != null && fimExclusivoOverride != null
        ? (inicio: inicioOverride, fimExclusivo: fimExclusivoOverride)
        : _faixaAtual(periodo, referencia);

    final cacheKey = [
      identityHashCode(resumo),
      resumo.gastos.length,
      resumo.contas.length,
      periodo.name,
      faixaAtual.inicio.millisecondsSinceEpoch,
      faixaAtual.fimExclusivo.millisecondsSinceEpoch,
      filtroCategoriaPadrao?.name ?? '',
      filtroCategoriaPersonalizadaId ?? '',
      filtroTipo?.name ?? '',
    ].join('|');

    final cacheEntry = _cacheLru.remove(cacheKey);
    if (cacheEntry != null) {
      final expirado = referencia.difference(cacheEntry.criadoEm) > _cacheTtl;
      if (!expirado) {
        _cacheLru[cacheKey] = cacheEntry;
        return cacheEntry.valor;
      }
    }

    final faixaAnterior = _faixaAnterior(
      faixaAtual.inicio,
      faixaAtual.fimExclusivo,
    );

    double totalGastosPeriodo = 0;
    double totalGastosPeriodoAnterior = 0;

    for (final gasto in resumo.gastos) {
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

    for (final conta in resumo.contas) {
      if (!conta.foiPago) {
        totalPendente += conta.valor;
        continue;
      }

      final dataReferenciaRecebimento = _dataReferenciaConta(conta);

      if (_estaNaFaixa(
        dataReferenciaRecebimento,
        faixaAtual.inicio,
        faixaAtual.fimExclusivo,
      )) {
        totalRecebidoPeriodo += conta.valor;
      } else if (_estaNaFaixa(
        dataReferenciaRecebimento,
        faixaAnterior.inicio,
        faixaAnterior.fimExclusivo,
      )) {
        totalRecebidoPeriodoAnterior += conta.valor;
      }
    }

    final saldo = totalRecebidoPeriodo - totalGastosPeriodo;
    final saldoMesAnterior =
        totalRecebidoPeriodoAnterior - totalGastosPeriodoAnterior;
    final variacaoSaldo = _variacaoPercentual(saldo, saldoMesAnterior);
    final variacaoGastos = _variacaoPercentual(
      totalGastosPeriodo,
      totalGastosPeriodoAnterior,
    );

    final totaisPorCategoria = <String, DashboardCategoriaResumo>{};

    for (final gasto in resumo.gastos) {
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
        final custom = gasto.usaCategoriaPersonalizada;
        final id = custom
            ? 'custom:${gasto.categoriaPersonalizadaId ?? gasto.categoriaLabelExibicao}'
            : 'std:${gasto.categoria.name}';

        final atual =
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

    final categoriasOrdenadas = totaisPorCategoria.values.toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));

    final comparativoLabel = _labelComparativo(faixaAnterior.inicio);

    final calculado = DashboardResumoCalculado(
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

    _cacheLru[cacheKey] = _DashboardCacheEntry(calculado, referencia);
    _evictOverflow();
    return calculado;
  }

  DateTime _dataReferenciaConta(Conta conta) {
    return conta.recebidaEm ?? conta.data;
  }

  void _evictExpired(DateTime now) {
    if (_cacheLru.isEmpty) {
      return;
    }

    final expirados = <String>[];
    _cacheLru.forEach((key, entry) {
      if (now.difference(entry.criadoEm) > _cacheTtl) {
        expirados.add(key);
      }
    });

    expirados.forEach(_cacheLru.remove);
  }

  void _evictOverflow() {
    while (_cacheLru.length > _maxCacheEntries) {
      _cacheLru.remove(_cacheLru.keys.first);
    }
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
    final hoje = DateTime(agora.year, agora.month, agora.day);

    switch (periodo) {
      case DashboardPeriodoRapido.hoje:
        return (inicio: hoje, fimExclusivo: hoje.add(const Duration(days: 1)));
      case DashboardPeriodoRapido.seteDias:
        return (
          inicio: hoje.subtract(const Duration(days: 6)),
          fimExclusivo: hoje.add(const Duration(days: 1)),
        );
      case DashboardPeriodoRapido.mes:
        final inicioMes = DateTime(agora.year, agora.month);
        return (
          inicio: inicioMes,
          fimExclusivo: DateTime(inicioMes.year, inicioMes.month + 1),
        );
      case DashboardPeriodoRapido.trimestre:
        final inicioTrim = DateTime(agora.year, agora.month - 2);
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
    final duracao = fimAtualExclusivo.difference(inicioAtual);
    final fimAnterior = inicioAtual;
    final inicioAnterior = fimAnterior.subtract(duracao);
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

class _DashboardCacheEntry {
  _DashboardCacheEntry(this.valor, this.criadoEm);

  final DashboardResumoCalculado valor;
  final DateTime criadoEm;
}
