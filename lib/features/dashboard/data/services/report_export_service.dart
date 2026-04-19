import 'dart:typed_data';

import 'package:paga_o_que_me_deve/core/utils/app_formatters.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RelatorioExportado {

  const RelatorioExportado({
    required this.nomeArquivoBase,
    required this.pdfBytes,
  });
  final String nomeArquivoBase;
  final Uint8List pdfBytes;
}

class ReportExportService {
  const ReportExportService();

  Future<RelatorioExportado> gerarRelatorioMensal(
    RelatorioMensalFinanceiro relatorio,
  ) async {
    final mes = relatorio.mesReferencia.month.toString().padLeft(2, '0');
    final nomeBase = 'relatorio_${relatorio.mesReferencia.year}_$mes';

    final pdf = await _gerarPdf(relatorio);

    return RelatorioExportado(nomeArquivoBase: nomeBase, pdfBytes: pdf);
  }

  Future<Uint8List> _gerarPdf(RelatorioMensalFinanceiro relatorio) async {
    final doc = pw.Document();
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final categorias =
        relatorio.totalPorCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) {
          return <pw.Widget>[
            pw.Header(level: 0, child: pw.Text('Relatorio Mensal')),
            pw.Text(
              'Referencia: ${relatorio.mesReferencia.month.toString().padLeft(2, '0')}/${relatorio.mesReferencia.year}',
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Total de Gastos: ${AppFormatters.moeda(relatorio.totalGastos)}',
            ),
            pw.Text(
              'Total de Pendencias: ${AppFormatters.moeda(relatorio.totalPendencias)}',
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Totais por categoria',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const <String>['Categoria', 'Valor'],
              data: categorias
                  .map(
                    (entry) => <String>[
                      entry.key.label,
                      AppFormatters.moeda(entry.value),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Pendencias a receber',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const <String>['Nome', 'Descricao', 'Valor'],
              data: relatorio.contasPendentes
                  .map(
                    (conta) => <String>[
                      conta.nome,
                      conta.descricao,
                      AppFormatters.moeda(conta.valor),
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    return Uint8List.fromList(await doc.save());
  }
}
