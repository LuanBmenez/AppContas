import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart'
    show SugestaoRecorrenciaDespesa;
import 'package:paga_o_que_me_deve/domain/services/recorrencia_despesa_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';

class RecorrenciasService {
  RecorrenciasService({
    required FinanceRepository repository,
    RecorrenciaDespesaService recorrenciaDespesaService =
        const RecorrenciaDespesaService(),
  }) : _repository = repository,
       _recorrenciaDespesaService = recorrenciaDespesaService;

  final FinanceRepository _repository;
  final RecorrenciaDespesaService _recorrenciaDespesaService;

  Stream<List<RecorrenciaAtiva>> streamRecorrenciasAtivas() {
    return _repository.meusGastos.map((List<Gasto> gastos) {
      final DateTime hoje = _inicioHoje();
      final Map<String, List<Gasto>> grupos = <String, List<Gasto>>{};

      for (final Gasto gasto in gastos) {
        final String tituloNormalizado = TextNormalizer.normalizeForSearch(
          gasto.titulo,
        );
        if (tituloNormalizado.length < 3) {
          continue;
        }
        grupos.putIfAbsent(tituloNormalizado, () => <Gasto>[]).add(gasto);
      }

      final List<RecorrenciaAtiva> recorrencias = <RecorrenciaAtiva>[];
      for (final MapEntry<String, List<Gasto>> entry in grupos.entries) {
        final List<Gasto> grupo = entry.value..sort((a, b) => a.data.compareTo(b.data));
        final SugestaoRecorrenciaDespesa? sugestao =
            _recorrenciaDespesaService.detectarMensal(grupo);
        if (sugestao == null) {
          continue;
        }

        final List<Gasto> ativosDesdeHoje = grupo.where((Gasto gasto) {
          return !gasto.data.isBefore(hoje);
        }).toList();

        if (ativosDesdeHoje.isEmpty) {
          continue;
        }

        ativosDesdeHoje.sort((a, b) => a.data.compareTo(b.data));
        final Gasto proximo = ativosDesdeHoje.first;

        recorrencias.add(
          RecorrenciaAtiva(
            id: entry.key,
            titulo: proximo.titulo,
            valorMedio: sugestao.valorMedio,
            categoriaLabel: proximo.categoriaLabelExibicao,
            diaDoMes: sugestao.diaPreferencial,
            ativosDesdeHoje: ativosDesdeHoje,
          ),
        );
      }

      recorrencias.sort((a, b) => a.diaDoMes.compareTo(b.diaDoMes));
      return recorrencias;
    });
  }

  Future<void> removerRecorrencia(RecorrenciaAtiva recorrencia) async {
    for (final Gasto gasto in recorrencia.ativosDesdeHoje) {
      await _repository.deletarGasto(gasto.id);
    }
  }

  DateTime _inicioHoje() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
