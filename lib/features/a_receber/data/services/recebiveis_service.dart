import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class RecebiveisService {
  const RecebiveisService(this._repository);

  final FinanceRepository _repository;

  Stream<List<Conta>> get contasAReceber => _repository.contasAReceber;

  Future<void> adicionarRecebivel(Conta conta) {
    return _repository.adicionarRecebivel(conta);
  }

  Future<void> alternarStatusRecebivel(String id, bool statusAtual) {
    return _repository.alternarStatusRecebivel(id, statusAtual);
  }

  Future<void> deletarRecebivel(String id) {
    return _repository.deletarRecebivel(id);
  }

  Future<void> atualizarRecebivel(Conta conta) {
    return _repository.atualizarRecebivel(conta);
  }

  Future<void> restaurarRecebivel(Conta conta) {
    return _repository.restaurarRecebivel(conta);
  }
}
