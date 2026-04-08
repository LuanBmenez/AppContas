import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/screens/dashboard_screen.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('exibe loading enquanto stream nao emite', (tester) async {
      final StreamController<DashboardResumo> controller =
          StreamController<DashboardResumo>();
      addTearDown(controller.close);

      final _TestFinanceRepository repo = _TestFinanceRepository(
        dashboardResumoStream: controller.stream,
      );

      await tester.pumpWidget(_buildTestApp(db: repo));

      expect(find.byType(AppSkeletonBox), findsWidgets);
    });

    testWidgets('exibe estado de erro quando stream falha', (tester) async {
      final _TestFinanceRepository repo = _TestFinanceRepository(
        dashboardResumoStream: Stream<DashboardResumo>.error(
          Exception('falha de teste'),
        ),
      );

      await tester.pumpWidget(_buildTestApp(db: repo));
      await tester.pumpAndSettle();

      expect(find.text('Erro ao carregar o painel.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('exibe estado vazio para categorias sem gastos', (
      tester,
    ) async {
      final _TestFinanceRepository repo = _TestFinanceRepository(
        dashboardResumoStream: Stream<DashboardResumo>.value(
          const DashboardResumo(<Gasto>[], <Conta>[]),
        ),
      );

      await tester.pumpWidget(_buildTestApp(db: repo));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem gastos no período para montar o gráfico.'),
        findsOneWidget,
      );
    });

    testWidgets('exibe dados completos e abre drill-down de categoria', (
      tester,
    ) async {
      final DateTime agora = DateTime.now();
      final Gasto gasto = Gasto(
        id: 'g1',
        titulo: 'Mercado',
        valor: 250,
        data: DateTime(agora.year, agora.month, 10),
        categoria: CategoriaGasto.comida,
        tipo: TipoGasto.variavel,
      );
      final Conta conta = Conta(
        id: 'c1',
        nome: 'Cliente A',
        descricao: 'Servico',
        valor: 500,
        data: DateTime(agora.year, agora.month, 8),
        foiPago: true,
      );

      final _TestFinanceRepository repo = _TestFinanceRepository(
        dashboardResumoStream: Stream<DashboardResumo>.value(
          DashboardResumo(<Gasto>[gasto], <Conta>[conta]),
        ),
      );

      await tester.pumpWidget(_buildTestApp(db: repo));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('Categorias de gastos'), findsOneWidget);
      final Finder categoriasCard = find.ancestor(
        of: find.text('Categorias de gastos'),
        matching: find.byType(Card),
      );
      final Finder comidaNoCard = find.descendant(
        of: categoriasCard,
        matching: find.text('Comida'),
      );
      expect(comidaNoCard, findsWidgets);
      expect(find.text('R\$ 250,00'), findsWidgets);
    });

    testWidgets('desabilita exportacao durante processamento', (tester) async {
      final Completer<void> completer = Completer<void>();
      int chamadas = 0;

      final _TestFinanceRepository repo = _TestFinanceRepository(
        dashboardResumoStream: Stream<DashboardResumo>.value(
          const DashboardResumo(<Gasto>[], <Conta>[]),
        ),
      );

      Future<void> exportador(DateTime _) {
        chamadas += 1;
        return completer.future;
      }

      await tester.pumpWidget(
        _buildTestApp(db: repo, exportadorRelatorio: exportador),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Exportar'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
      await tester.pump();

      expect(
        find.text('Gerando e compartilhando relatório...'),
        findsOneWidget,
      );
      final FilledButton botao = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gerando...'),
      );
      expect(botao.onPressed, isNull);
      expect(chamadas, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });
  });
}

Widget _buildTestApp({
  required FinanceRepository db,
  Future<void> Function(DateTime referencia)? exportadorRelatorio,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DashboardScreen(db: db, exportadorRelatorio: exportadorRelatorio),
    ),
  );
}

class _TestFinanceRepository implements FinanceRepository {
  _TestFinanceRepository({required this.dashboardResumoStream});

  final Stream<DashboardResumo> dashboardResumoStream;

  @override
  Stream<List<Conta>> get contasAReceber => const Stream<List<Conta>>.empty();

  @override
  Stream<List<Gasto>> get meusGastos => const Stream<List<Gasto>>.empty();

  @override
  Stream<DashboardResumo> get dashboardResumo => dashboardResumoStream;

  @override
  Stream<List<CartaoCredito>> get cartoesCredito =>
      const Stream<List<CartaoCredito>>.empty();

  @override
  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao =>
      const Stream<List<RegraCategoriaImportacao>>.empty();

  @override
  Stream<List<CategoriaPersonalizada>> get categoriasPersonalizadas =>
      const Stream<List<CategoriaPersonalizada>>.empty();

  @override
  Future<void> adicionarRecebivel(Conta conta) => throw UnimplementedError();

  @override
  Future<void> alternarStatusRecebivel(String id, bool statusAtual) =>
      throw UnimplementedError();

  @override
  Future<void> deletarRecebivel(String id) => throw UnimplementedError();

  @override
  Future<void> atualizarRecebivel(Conta conta) => throw UnimplementedError();

  @override
  Future<void> restaurarRecebivel(Conta conta) => throw UnimplementedError();

  @override
  Future<void> adicionarGasto(Gasto gasto) => throw UnimplementedError();

  @override
  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) => throw UnimplementedError();

  @override
  Future<int> contarDuplicadosPorHash(List<String> hashes) =>
      throw UnimplementedError();

  @override
  Stream<List<Gasto>> streamGastosPorPeriodo({
    required DateTime inicio,
    required DateTime fimExclusivo,
    int? limite,
  }) => throw UnimplementedError();

  @override
  Future<PaginaGastosResultado> buscarGastosPorPeriodoPaginado({
    required DateTime inicio,
    required DateTime fimExclusivo,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limite = 40,
  }) => throw UnimplementedError();

  @override
  Future<void> deletarGasto(String id) => throw UnimplementedError();

  @override
  Future<void> atualizarGasto(Gasto gasto) => throw UnimplementedError();

  @override
  Future<void> restaurarGasto(Gasto gasto) => throw UnimplementedError();

  @override
  Future<void> adicionarCartaoCredito(CartaoCredito cartao) =>
      throw UnimplementedError();

  @override
  Future<void> deletarCartaoCredito(String id) => throw UnimplementedError();

  @override
  Future<void> salvarCategoriaPersonalizada(CategoriaPersonalizada categoria) =>
      throw UnimplementedError();

  @override
  Future<void> arquivarCategoriaPersonalizada(String id, bool arquivada) =>
      throw UnimplementedError();

  @override
  Future<void> alternarFavoritaCategoriaPersonalizada(
    String id,
    bool favorita,
  ) => throw UnimplementedError();

  @override
  Future<void> deletarCategoriaPersonalizada(String id) =>
      throw UnimplementedError();

  @override
  Future<bool> categoriaPersonalizadaEmUso(String id) =>
      throw UnimplementedError();

  @override
  Future<PreferenciasNovoGasto> carregarPreferenciasNovoGasto() =>
      throw UnimplementedError();

  @override
  Future<void> registrarUsoNovoGasto({
    CategoriaGasto? categoriaPadrao,
    String? categoriaPersonalizadaId,
    required TipoGasto tipo,
  }) => throw UnimplementedError();

  @override
  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  }) => throw UnimplementedError();

  @override
  Future<SugestaoRecorrenciaDespesa?> sugerirRecorrenciaPorTitulo(
    String titulo,
  ) async {
    return null;
  }

  @override
  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(
    DateTime referencia,
  ) async {
    return RelatorioMensalFinanceiro(
      mesReferencia: referencia,
      gastosMes: const <Gasto>[],
      contasPendentes: const <Conta>[],
      totalPorCategoria: const <CategoriaGasto, double>{},
    );
  }
}
