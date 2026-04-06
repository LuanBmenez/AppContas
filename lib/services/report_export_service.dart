import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/repositories/finance_repository.dart';
import '../models/gasto_model.dart';
import '../utils/app_formatters.dart';

class RelatorioExportado {
  final String nomeArquivoBase;
  final Uint8List pdfBytes;

  const RelatorioExportado({
    required this.nomeArquivoBase,
    required this.pdfBytes,
  });
}

class ReportExportService {
  const ReportExportService();

  Future<RelatorioExportado> gerarRelatorioMensal(
    RelatorioMensalFinanceiro relatorio,
  ) async {
    final String mes = relatorio.mesReferencia.month.toString().padLeft(2, '0');
    final String nomeBase = 'relatorio_${relatorio.mesReferencia.year}_$mes';

    final Uint8List pdf = await _gerarPdf(relatorio);

    return RelatorioExportado(nomeArquivoBase: nomeBase, pdfBytes: pdf);
  }

  Future<Uint8List> _gerarPdf(RelatorioMensalFinanceiro relatorio) async {
    final pw.Document doc = pw.Document();
    final pw.Font baseFont = await PdfGoogleFonts.notoSansRegular();
    final pw.Font boldFont = await PdfGoogleFonts.notoSansBold();

    final List<MapEntry<CategoriaGasto, double>> categorias =
        relatorio.totalPorCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (pw.Context context) {
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
