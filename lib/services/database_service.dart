import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../models/cartao_credito_model.dart';
import '../models/conta_model.dart';
import '../models/gasto_model.dart';
import '../models/regra_categoria_importacao_model.dart';

class DashboardResumo {
  final List<Gasto> gastos;
  final List<Conta> contas;

  const DashboardResumo(this.gastos, this.contas);
}

class ResultadoImportacaoGastos {
  final int importados;
  final int duplicados;

  const ResultadoImportacaoGastos({
    required this.importados,
    required this.duplicados,
  });
}

class DatabaseService {
  final CollectionReference<Map<String, dynamic>> _receberCollection =
      FirebaseFirestore.instance.collection('a_receber');
  final CollectionReference<Map<String, dynamic>> _gastosCollection =
      FirebaseFirestore.instance.collection('meus_gastos');
  final CollectionReference<Map<String, dynamic>> _cartoesCollection =
      FirebaseFirestore.instance.collection('cartoes_credito');
  final CollectionReference<Map<String, dynamic>> _regrasCategoriaCollection =
      FirebaseFirestore.instance.collection('regras_categoria_importacao');

  Future<void> adicionarRecebivel(Conta conta) async {
    final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
        .doc();
    final Conta contaComId = conta.copyWith(id: docRef.id);

    await docRef.set(contaComId.toMap());
  }

  Stream<List<Conta>> get contasAReceber {
    return _receberCollection.orderBy('data', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => Conta.fromMap(doc.data(), doc.id))
            .toList();
      },
    );
  }

  Future<void> alternarStatusRecebivel(String id, bool statusAtual) async {
    await _receberCollection.doc(id).update({'foiPago': !statusAtual});
  }

  Future<void> deletarRecebivel(String id) async {
    await _receberCollection.doc(id).delete();
  }

  Future<void> atualizarRecebivel(Conta conta) async {
    await _receberCollection.doc(conta.id).set(conta.toMap());
  }

  Future<void> restaurarRecebivel(Conta conta) async {
    await _receberCollection.doc(conta.id).set(conta.toMap());
  }

  Future<void> adicionarGasto(Gasto gasto) async {
    final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
        .doc();
    final Gasto gastoComId = gasto.copyWith(id: docRef.id);

    await docRef.set(gastoComId.toMap());
  }

  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) async {
    if (gastos.isEmpty) {
      return const ResultadoImportacaoGastos(importados: 0, duplicados: 0);
    }

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    int importados = 0;
    int duplicados = 0;

    for (final Gasto gasto in gastos) {
      final String? hash = gasto.hashImportacao;
      if (hash == null || hash.isEmpty) {
        final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
            .doc();
        batch.set(docRef, gasto.copyWith(id: docRef.id).toMap());
        importados++;
        continue;
      }

      final QuerySnapshot<Map<String, dynamic>> existente =
          await _gastosCollection
              .where('hashImportacao', isEqualTo: hash)
              .limit(1)
              .get();

      if (existente.docs.isNotEmpty) {
        duplicados++;
        continue;
      }

      final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
          .doc();
      batch.set(docRef, gasto.copyWith(id: docRef.id).toMap());
      importados++;
    }

    if (importados > 0) {
      await batch.commit();
    }

    return ResultadoImportacaoGastos(
      importados: importados,
      duplicados: duplicados,
    );
  }

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

  Stream<List<Gasto>> get meusGastos {
    return _gastosCollection.orderBy('data', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<DashboardResumo> get dashboardResumo {
    return Rx.combineLatest2<List<Gasto>, List<Conta>, DashboardResumo>(
      meusGastos,
      contasAReceber,
      (gastos, contas) => DashboardResumo(gastos, contas),
    );
  }

  Future<void> deletarGasto(String id) async {
    await _gastosCollection.doc(id).delete();
  }

  Future<void> atualizarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  Future<void> restaurarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  Future<void> adicionarCartaoCredito(CartaoCredito cartao) async {
    final DocumentReference<Map<String, dynamic>> docRef = _cartoesCollection
        .doc();
    final CartaoCredito cartaoComId = cartao.copyWith(id: docRef.id);

    await docRef.set(cartaoComId.toMap());
  }

  Stream<List<CartaoCredito>> get cartoesCredito {
    return _cartoesCollection.orderBy('nome').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CartaoCredito.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> deletarCartaoCredito(String id) async {
    await _cartoesCollection.doc(id).delete();
  }

  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao {
    return _regrasCategoriaCollection.orderBy('termo').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => RegraCategoriaImportacao.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

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

  String _normalizarTextoBusca(String texto) {
    return texto
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÃÂ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÕÔ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛ]'), 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
