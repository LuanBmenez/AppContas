import 'dart:typed_data';

import 'package:paga_o_que_me_deve/core/utils/app_formatters.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:pdf/pdf.dart';
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

    // As fontes são carregadas assincronamente
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final categorias = relatorio.totalPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) {
          return <pw.Widget>[
            // Cabeçalho Principal
            pw.Header(level: 0, child: pw.Text('Relatório Mensal')),
            pw.Text(
              'Referência: ${relatorio.mesReferencia.month.toString().padLeft(2, '0')}/${relatorio.mesReferencia.year}',
            ),
            pw.SizedBox(height: 12),

            // Resumo
            pw.Text(
              'Total de Gastos: ${AppFormatters.moeda(relatorio.totalGastos)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Total de Pendências: ${AppFormatters.moeda(relatorio.totalPendencias)}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red800,
              ),
            ),
            pw.SizedBox(height: 24),

            // Secção de Categorias
            pw.Text(
              'Totais por Categoria',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (categorias.isEmpty)
              pw.Text(
                'Nenhum gasto registrado neste mês.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const <String>['Categoria', 'Valor'],
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                data: categorias
                    .map(
                      (entry) => <String>[
                        entry.key.label,
                        AppFormatters.moeda(entry.value),
                      ],
                    )
                    .toList(),
              ),

            pw.SizedBox(height: 24),

            // Secção de Pendências
            pw.Text(
              'Pendências a Receber',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (relatorio.contasPendentes.isEmpty)
              pw.Text(
                'Nenhuma pendência neste mês. Está tudo em dia!',
                style: const pw.TextStyle(color: PdfColors.grey600),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const <String>['Nome', 'Descrição', 'Valor'],
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                data: relatorio.contasPendentes
                    .map(
                      (conta) => <String>[
                        conta.nome,
                        if (conta.descricao.isEmpty) '-' else conta.descricao,
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
