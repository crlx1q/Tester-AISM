import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/ai_scan_note.dart';

class PdfExportService {
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;

  static Future<void> exportScanNoteToPdf(AiScanNote scanNote) async {
    final pdf = pw.Document();
    
    // Загружаем шрифт с поддержкой кириллицы (кэшируем для повторного использования)
    _cachedRegularFont ??= await _loadFont();
    _cachedBoldFont ??= await _loadFontBold();
    
    final fontRegular = _cachedRegularFont!;
    final fontBold = _cachedBoldFont!;

    // Форматирование даты
    final dateFormat = DateFormat('dd MMMM yyyy', 'ru');
    final createdAt = dateFormat.format(scanNote.createdAt);

    // Добавляем страницу
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Заголовок
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    scanNote.title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  if (scanNote.course.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      scanNote.course,
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                        font: fontRegular,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Создано: $createdAt',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                      font: fontRegular,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Краткое содержание
            if (scanNote.summary.isNotEmpty) ...[
              pw.Header(
                level: 1,
                  child: pw.Text(
                    'Краткое содержание',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                      font: fontBold,
                    ),
                  ),
              ),
              pw.SizedBox(height: 12),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 24),
                child: pw.Text(
                  scanNote.summary,
                  style: pw.TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    font: fontRegular,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Ключевые понятия
            if (scanNote.concepts.isNotEmpty) ...[
              pw.Header(
                level: 1,
                  child: pw.Text(
                    'Ключевые понятия',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple700,
                      font: fontBold,
                    ),
                  ),
              ),
              pw.SizedBox(height: 12),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: scanNote.concepts.map((concept) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 16,
                            height: 16,
                            margin: const pw.EdgeInsets.only(top: 2, right: 8),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.purple700,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Container(
                                width: 6,
                                height: 6,
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.white,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              concept,
                              style: pw.TextStyle(
                                fontSize: 12,
                                font: fontRegular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Формулы
            if (scanNote.formulas.isNotEmpty) ...[
              pw.Header(
                level: 1,
                  child: pw.Text(
                    'Формулы',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange700,
                      font: fontBold,
                    ),
                  ),
              ),
              pw.SizedBox(height: 12),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: scanNote.formulas.map((formula) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange100,
                        border: pw.Border.all(
                          color: PdfColors.orange300,
                          width: 1,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        formula,
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: fontRegular,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Вопросы ИИ
            if (scanNote.questions.isNotEmpty) ...[
              pw.Header(
                level: 1,
                  child: pw.Text(
                    'Вопросы для повторения',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                      font: fontBold,
                    ),
                  ),
              ),
              pw.SizedBox(height: 12),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: scanNote.questions.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final question = entry.value;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 12),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 24,
                            height: 24,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue700,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                '$index',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Text(
                              question,
                              style: pw.TextStyle(
                                fontSize: 12,
                                font: fontRegular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Мои заметки
            if (scanNote.manualNotes.isNotEmpty) ...[
              pw.Header(
                level: 1,
                  child: pw.Text(
                    'Мои заметки',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                      font: fontBold,
                    ),
                  ),
              ),
              pw.SizedBox(height: 12),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 24),
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(
                      color: PdfColors.green300,
                      width: 1,
                    ),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    scanNote.manualNotes,
                    style: pw.TextStyle(
                      fontSize: 12,
                      font: fontRegular,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Теги
            if (scanNote.tags.isNotEmpty) ...[
              pw.Header(
                level: 1,
                  child: pw.Text(
                    'Теги',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
              ),
              pw.SizedBox(height: 12),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: scanNote.tags.map((tag) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo100,
                      border: pw.Border.all(
                        color: PdfColors.indigo300,
                        width: 1,
                      ),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text(
                      tag,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.indigo700,
                        fontWeight: pw.FontWeight.bold,
                        font: fontBold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Футер
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Создано в AIStudyMate',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  font: fontRegular,
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Показываем диалог печати/сохранения
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Загрузка обычного шрифта с поддержкой кириллицы
  static Future<pw.Font> _loadFont() async {
    try {
      // Используем шрифты Google, встроенную поддержку в пакете pdf
      return await PdfGoogleFonts.notoSansRegular();
    } catch (_) {
      return pw.Font.courier();
    }
  }

  // Загрузка жирного шрифта с поддержкой кириллицы
  static Future<pw.Font> _loadFontBold() async {
    try {
      return await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      return pw.Font.courier();
    }
  }
}

