import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/domain/services/recorrencia_despesa_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_config_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_configuracao.dart';
import 'package:rxdart/rxdart.dart';

class RecorrenciasService {
  RecorrenciasService({required FinanceRepository repository, RecorrenciaDespesaService recorrenciaDespesaService = const RecorrenciaDespesaService(), RecorrenciasConfigService? configService}) : _repository = repository, _recorrenciaDespesaService = recorrenciaDespesaService, _configService = configService ?? RecorrenciasConfigService();

  final FinanceRepository _repository;
  final RecorrenciaDespesaService _recorrenciaDespesaService;
  final RecorrenciasConfigService _configService;

  Stream<List<RecorrenciaAtiva>> streamRecorrenciasAtivas() {
    return Rx.combineLatest2<List<Gasto>, List<RecorrenciaConfiguracao>, List<RecorrenciaAtiva>>(
      _repository.meusGastos,
      _configService.streamConfiguracoes(),
      (gastos, configuracoes) {
        final hoje = _inicioHoje();
        final configMap = {for (final c in configuracoes) c.recorrenciaId: c};
        final grupos = _agruparGastos(gastos);
        final recorrencias = <RecorrenciaAtiva>[];
        for (final entry in grupos.entries) {
          final config = configMap[entry.key];
          if (config?.ignorada ?? false) continue;
          final rec = _mapearGrupoParaRecorrencia(recorrenciaId: entry.key, grupo: entry.value, hoje: hoje, config: config);
          if (rec != null) recorrencias.add(rec);
        }
        recorrencias.sort((a, b) {
          if (a.status != b.status) return a.status == RecorrenciaStatus.ativa ? -1 : 1;
          return a.proximoVencimento.compareTo(b.proximoVencimento);
        });
        return recorrencias;
      },
    );
  }

  Future<void> confirmarRecorrencia(RecorrenciaAtiva recorrencia) => _configService.confirmarRecorrencia(recorrencia.id);

  Future<void> pausarRecorrencia(RecorrenciaAtiva recorrencia) async {
    await _removerGastos(recorrencia.ativosDesdeHoje);
    await _configService.pausarRecorrencia(recorrencia.id, pausada: true);
  }

  Future<void> reativarRecorrencia(RecorrenciaAtiva recorrencia, {int mesesFuturos = 3}) async {
    await _configService.pausarRecorrencia(recorrencia.id, pausada: false);
    await _configService.ignorarRecorrencia(recorrencia.id, ignorada: false);
    if (recorrencia.ativosDesdeHoje.isNotEmpty) return;
    final datas = _gerarProximasDatas(aPartirDe: _inicioHoje(), diaDoMes: recorrencia.diaDoMes, quantidade: mesesFuturos);
    for (final data in datas) {
      final novo = recorrencia.gastoReferencia.copyWith(id: '', data: data);
      await _repository.adicionarGasto(novo);
    }
  }

  Future<void> removerProximosLancamentos(RecorrenciaAtiva recorrencia) => _removerGastos(recorrencia.ativosDesdeHoje);

  Future<void> removerRecorrenciaCompletamente(RecorrenciaAtiva recorrencia) async {
    await _removerGastos(recorrencia.ativosDesdeHoje);
    await _configService.ignorarRecorrencia(recorrencia.id, ignorada: true);
  }

  Future<void> atualizarNotificacao({required RecorrenciaAtiva recorrencia, required bool ativa, required int diasAntes}) {
    return _configService.atualizarNotificacao(recorrenciaId: recorrencia.id, ativa: ativa, diasAntes: diasAntes);
  }

  Map<String, List<Gasto>> _agruparGastos(List<Gasto> gastos) {
    final grupos = <String, List<Gasto>>{};
    for (final gasto in gastos) {
      final titulo = TextNormalizer.normalizeForSearch(gasto.titulo).trim();
      if (titulo.length < 3) continue;
      final categoria = TextNormalizer.normalizeForSearch(gasto.categoriaLabelExibicao).trim();
      final chave = '$titulo|$categoria';
      grupos.putIfAbsent(chave, () => <Gasto>[]).add(gasto);
    }
    return grupos;
  }

  RecorrenciaAtiva? _mapearGrupoParaRecorrencia({required String recorrenciaId, required List<Gasto> grupo, required DateTime hoje, required RecorrenciaConfiguracao? config}) {
    final ordenado = List<Gasto>.from(grupo)..sort((a, b) => a.data.compareTo(b.data));
    final sugestao = _recorrenciaDespesaService.detectarMensal(ordenado);
    if (sugestao == null) return null;
    final ativosDesdeHoje = ordenado.where((g) => !g.data.isBefore(hoje)).toList()..sort((a, b) => a.data.compareTo(b.data));
    final pausada = config?.pausada ?? false;
    if (ativosDesdeHoje.isEmpty && !pausada) return null;
    final referencia = ordenado.last;
    final proximo = ativosDesdeHoje.isNotEmpty ? ativosDesdeHoje.first : null;
    final proximoVencimento = proximo?.data ?? _calcularProximoVencimento(hoje, sugestao.diaPreferencial);
    return RecorrenciaAtiva(
      id: recorrenciaId,
      titulo: proximo?.titulo ?? referencia.titulo,
      valorMedio: sugestao.valorMedio,
      ultimoValor: referencia.valor,
      variacaoValor: sugestao.valorMedio - referencia.valor,
      categoriaLabel: proximo?.categoriaLabelExibicao ?? referencia.categoriaLabelExibicao,
      diaDoMes: sugestao.diaPreferencial,
      proximoVencimento: proximoVencimento,
      origem: (config?.confirmada ?? false) ? RecorrenciaOrigem.manual : RecorrenciaOrigem.detectada,
      status: pausada ? RecorrenciaStatus.pausada : RecorrenciaStatus.ativa,
      notificacaoAtiva: config?.notificacaoAtiva ?? true,
      diasAntesNotificacao: config?.diasAntesNotificacao ?? 2,
      quantidadeHistorica: ordenado.length,
      ativosDesdeHoje: List<Gasto>.unmodifiable(ativosDesdeHoje),
      gastoReferencia: referencia,
    );
  }

  DateTime _calcularProximoVencimento(DateTime aPartirDe, int diaDoMes) {
    final candidatoAtual = _dataComDia(aPartirDe.year, aPartirDe.month, diaDoMes);
    if (!candidatoAtual.isBefore(aPartirDe)) return candidatoAtual;
    return _dataComDia(aPartirDe.year, aPartirDe.month + 1, diaDoMes);
  }

  List<DateTime> _gerarProximasDatas({required DateTime aPartirDe, required int diaDoMes, required int quantidade}) {
    final datas = <DateTime>[];
    var cursor = _calcularProximoVencimento(aPartirDe, diaDoMes);
    for (int i = 0; i < quantidade; i++) {
      datas.add(cursor);
      cursor = _dataComDia(cursor.year, cursor.month + 1, diaDoMes);
    }
    return datas;
  }

  DateTime _dataComDia(int year, int month, int day) {
    final ultimoDiaMes = DateTime(year, month + 1, 0);
    final diaSeguro = day > ultimoDiaMes.day ? ultimoDiaMes.day : day;
    return DateTime(year, month, diaSeguro);
  }

  Future<void> _removerGastos(List<Gasto> gastos) async {
    for (final gasto in gastos) {
      await _repository.deletarGasto(gasto.id);
    }
  }

  DateTime _inicioHoje() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
