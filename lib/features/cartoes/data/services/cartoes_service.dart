import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class CartoesService {
  const CartoesService(this._repository);

  final FinanceRepository _repository;

  Stream<List<CartaoCredito>> get cartoesCredito => _repository.cartoesCredito;

  Future<void> adicionarCartaoCredito(CartaoCredito cartao) {
    return _repository.adicionarCartaoCredito(cartao);
  }

  Future<void> deletarCartaoCredito(String id) {
    return _repository.deletarCartaoCredito(id);
  }
}
