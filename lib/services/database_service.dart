import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../domain/repositories/finance_repository.dart';
import '../models/cartao_credito_model.dart';
import '../models/conta_model.dart';
import '../models/gasto_model.dart';
import '../models/regra_categoria_importacao_model.dart';
import '../utils/text_normalizer.dart';

class DatabaseService implements FinanceRepository {
  final CollectionReference<Map<String, dynamic>> _receberCollection =
      FirebaseFirestore.instance.collection('a_receber');
  final CollectionReference<Map<String, dynamic>> _gastosCollection =
      FirebaseFirestore.instance.collection('meus_gastos');
  final CollectionReference<Map<String, dynamic>> _cartoesCollection =
      FirebaseFirestore.instance.collection('cartoes_credito');
  final CollectionReference<Map<String, dynamic>> _regrasCategoriaCollection =
      FirebaseFirestore.instance.collection('regras_categoria_importacao');

  @override
  Future<void> adicionarRecebivel(Conta conta) async {
    final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
        .doc();
    final Conta contaComId = conta.copyWith(id: docRef.id);

    await docRef.set(contaComId.toMap());
  }

  @override
  Stream<List<Conta>> get contasAReceber {
    return _receberCollection.orderBy('data', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => Conta.fromMap(doc.data(), doc.id))
            .toList();
      },
    );
  }

  @override
  Future<void> alternarStatusRecebivel(String id, bool statusAtual) async {
    await _receberCollection.doc(id).update({'foiPago': !statusAtual});
  }

  @override
  Future<void> deletarRecebivel(String id) async {
    await _receberCollection.doc(id).delete();
  }

  @override
  Future<void> atualizarRecebivel(Conta conta) async {
    await _receberCollection.doc(conta.id).set(conta.toMap());
  }

  @override
  Future<void> restaurarRecebivel(Conta conta) async {
    await _receberCollection.doc(conta.id).set(conta.toMap());
  }

  @override
  Future<void> adicionarGasto(Gasto gasto) async {
    final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
        .doc();
    final Gasto gastoComId = gasto.copyWith(id: docRef.id);

    await docRef.set(gastoComId.toMap());
  }

  @override
  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) async {
    if (gastos.isEmpty) {
      return const ResultadoImportacaoGastos(importados: 0, duplicados: 0);
    }

    final List<Gasto> semHash = <Gasto>[];
    final Map<String, Gasto> porHash = <String, Gasto>{};
    int importados = 0;
    int duplicados = 0;

    for (final Gasto gasto in gastos) {
      final String? hash = gasto.hashImportacao;
      if (hash == null || hash.isEmpty) {
        semHash.add(gasto);
        continue;
      }

      if (porHash.containsKey(hash)) {
        duplicados++;
        continue;
      }

      porHash[hash] = gasto;
    }

    importados += await _gravarGastosSemHash(semHash);

    final Set<String> hashesExistentes = await _buscarHashesExistentes(
      porHash.keys,
    );

    final List<MapEntry<String, Gasto>> paraInserir =
        <MapEntry<String, Gasto>>[];
    for (final MapEntry<String, Gasto> entry in porHash.entries) {
      if (hashesExistentes.contains(entry.key)) {
        duplicados++;
      } else {
        paraInserir.add(entry);
      }
    }

    if (paraInserir.isNotEmpty) {
      const int tamanhoLote = 200;

      for (int i = 0; i < paraInserir.length; i += tamanhoLote) {
        final int fim = (i + tamanhoLote < paraInserir.length)
            ? i + tamanhoLote
            : paraInserir.length;
        final List<MapEntry<String, Gasto>> lote = paraInserir.sublist(i, fim);

        final ResultadoImportacaoGastos parcial = await FirebaseFirestore
            .instance
            .runTransaction((transaction) async {
              int importadosLote = 0;
              int duplicadosLote = 0;

              for (final MapEntry<String, Gasto> entry in lote) {
                final DocumentReference<Map<String, dynamic>> docRef =
                    _gastosCollection.doc(
                      _idDeterministicoImportacao(entry.key),
                    );
                final DocumentSnapshot<Map<String, dynamic>> existente =
                    await transaction.get(docRef);

                if (existente.exists) {
                  duplicadosLote++;
                  continue;
                }

                transaction.set(
                  docRef,
                  entry.value.copyWith(id: docRef.id).toMap(),
                );
                importadosLote++;
              }

              return ResultadoImportacaoGastos(
                importados: importadosLote,
                duplicados: duplicadosLote,
              );
            });

        importados += parcial.importados;
        duplicados += parcial.duplicados;
      }
    }

    return ResultadoImportacaoGastos(
      importados: importados,
      duplicados: duplicados,
    );
  }

  @override
  Future<int> contarDuplicadosPorHash(List<String> hashes) async {
    final List<String> hashesValidos = hashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashesValidos.isEmpty) {
      return 0;
    }

    int duplicados = 0;
    for (int i = 0; i < hashesValidos.length; i += 10) {
      final int fim = (i + 10 < hashesValidos.length)
          ? i + 10
          : hashesValidos.length;
      final List<String> lote = hashesValidos.sublist(i, fim);

      final QuerySnapshot<Map<String, dynamic>> encontrados =
          await _gastosCollection.where('hashImportacao', whereIn: lote).get();
      duplicados += encontrados.docs.length;
    }

    return duplicados;
  }

  @override
  Stream<List<Gasto>> get meusGastos {
    return _gastosCollection.orderBy('data', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<List<Gasto>> streamGastosPorPeriodo({
    required DateTime inicio,
    required DateTime fimExclusivo,
    int? limite,
  }) {
    Query<Map<String, dynamic>> query = _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicio)
        .where('data', isLessThan: fimExclusivo)
        .orderBy('data', descending: true);

    if (limite != null && limite > 0) {
      query = query.limit(limite);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<PaginaGastosResultado> buscarGastosPorPeriodoPaginado({
    required DateTime inicio,
    required DateTime fimExclusivo,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limite = 80,
  }) async {
    Query<Map<String, dynamic>> query = _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicio)
        .where('data', isLessThan: fimExclusivo)
        .orderBy('data', descending: true)
        .limit(limite);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final List<Gasto> gastos = snapshot.docs
        .map((doc) => Gasto.fromMap(doc.data(), doc.id))
        .toList();

    return PaginaGastosResultado(
      gastos: gastos,
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : cursor,
      temMais: snapshot.docs.length == limite,
    );
  }

  @override
  Stream<DashboardResumo> get dashboardResumo {
    return Rx.combineLatest2<List<Gasto>, List<Conta>, DashboardResumo>(
      meusGastos,
      contasAReceber,
      (gastos, contas) => DashboardResumo(gastos, contas),
    );
  }

  @override
  Future<void> deletarGasto(String id) async {
    await _gastosCollection.doc(id).delete();
  }

  @override
  Future<void> atualizarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  @override
  Future<void> restaurarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  @override
  Future<void> adicionarCartaoCredito(CartaoCredito cartao) async {
    final DocumentReference<Map<String, dynamic>> docRef = _cartoesCollection
        .doc();
    final CartaoCredito cartaoComId = cartao.copyWith(id: docRef.id);

    await docRef.set(cartaoComId.toMap());
  }

  @override
  Stream<List<CartaoCredito>> get cartoesCredito {
    return _cartoesCollection.orderBy('nome').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CartaoCredito.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> deletarCartaoCredito(String id) async {
    await _cartoesCollection.doc(id).delete();
  }

  @override
  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao {
    return _regrasCategoriaCollection.orderBy('termo').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => RegraCategoriaImportacao.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  }) async {
    final String termoNormalizado = _normalizarTextoBusca(termo);
    if (termoNormalizado.isEmpty) {
      return;
    }

    await _regrasCategoriaCollection.doc(termoNormalizado).set({
      'termo': termoNormalizado,
      'categoria': categoria.name,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(
    DateTime referencia,
  ) async {
    final DateTime inicioMes = DateTime(referencia.year, referencia.month, 1);
    final DateTime fimMes = DateTime(referencia.year, referencia.month + 1, 1);

    final QuerySnapshot<Map<String, dynamic>> gastosSnapshot =
        await _gastosCollection
            .where('data', isGreaterThanOrEqualTo: inicioMes)
            .where('data', isLessThan: fimMes)
            .orderBy('data', descending: true)
            .get();

    final List<Gasto> gastos = gastosSnapshot.docs
        .map((doc) => Gasto.fromMap(doc.data(), doc.id))
        .toList();

    final QuerySnapshot<Map<String, dynamic>> pendentesSnapshot =
        await _receberCollection.where('foiPago', isEqualTo: false).get();
    final List<Conta> pendentes = pendentesSnapshot.docs
        .map((doc) => Conta.fromMap(doc.data(), doc.id))
        .toList();

    final Map<CategoriaGasto, double> totalPorCategoria =
        <CategoriaGasto, double>{};
    for (final Gasto gasto in gastos) {
      totalPorCategoria[gasto.categoria] =
          (totalPorCategoria[gasto.categoria] ?? 0) + gasto.valor;
    }

    return RelatorioMensalFinanceiro(
      mesReferencia: inicioMes,
      gastosMes: gastos,
      contasPendentes: pendentes,
      totalPorCategoria: totalPorCategoria,
    );
  }

  String _normalizarTextoBusca(String texto) =>
      TextNormalizer.normalizeForSearch(texto);

  Future<int> _gravarGastosSemHash(List<Gasto> gastos) async {
    if (gastos.isEmpty) {
      return 0;
    }

    int importados = 0;
    for (int i = 0; i < gastos.length; i += 450) {
      final int fim = (i + 450 < gastos.length) ? i + 450 : gastos.length;
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (final Gasto gasto in gastos.sublist(i, fim)) {
        final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
            .doc();
        batch.set(docRef, gasto.copyWith(id: docRef.id).toMap());
        importados++;
      }

      await batch.commit();
    }

    return importados;
  }

  Future<Set<String>> _buscarHashesExistentes(Iterable<String> hashes) async {
    final List<String> hashesValidos = hashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashesValidos.isEmpty) {
      return <String>{};
    }

    final Set<String> existentes = <String>{};
    for (int i = 0; i < hashesValidos.length; i += 10) {
      final int fim = (i + 10 < hashesValidos.length)
          ? i + 10
          : hashesValidos.length;
      final List<String> lote = hashesValidos.sublist(i, fim);

      final QuerySnapshot<Map<String, dynamic>> encontrados =
          await _gastosCollection.where('hashImportacao', whereIn: lote).get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in encontrados.docs) {
        final String hash = (doc.data()['hashImportacao'] ?? '').toString();
        if (hash.isNotEmpty) {
          existentes.add(hash);
        }
      }
    }

    return existentes;
  }

  String _idDeterministicoImportacao(String hash) {
    return 'imp_$hash';
  }
}
