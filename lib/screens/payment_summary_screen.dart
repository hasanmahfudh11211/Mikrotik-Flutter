import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/gradient_container.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/router_session_provider.dart';

class PaymentSummaryScreen extends StatefulWidget {
  const PaymentSummaryScreen({super.key});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  late Future<List<Map<String, dynamic>>> _summaryFuture;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');
  bool showPrintPanel = false;
  bool isProcessing = false;

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> summaryList) async {
    setState(() => isProcessing = true);
    try {
      // Simpan file ke direktori dokumen aplikasi (default, tanpa permission khusus)
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ringkasan_pembayaran.xlsx');
      final excel = Excel.createExcel();
      final sheet = excel['Ringkasan'];
      // Header
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Bulan'),
        TextCellValue('Total Pembayaran'),
        TextCellValue('Jumlah Pembayaran')
      ]);
      // Data
      int totalCount = 0;
      double totalNominal = 0;
      for (var i = 0; i < summaryList.length; i++) {
        final item = summaryList[i];
        final month = item['month'] as int? ?? 0;
        final year = item['year'] as int? ?? 0;
        final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
        final count = (item['count'] ?? 0) as int? ?? 0;
        totalNominal += total;
        totalCount += count;
        final monthName = _getMonthName(month, year);
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(monthName),
          TextCellValue(_formatCurrency(total)),
          TextCellValue('$count pembayaran'),
        ]);
      }
      // Baris total
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Total'),
        TextCellValue(_formatCurrency(totalNominal)),
        TextCellValue('$totalCount pembayaran'),
      ]);
      await file.writeAsBytes(excel.encode()!);
      _showSnackBar('Berhasil mengekspor ke ${file.path}');
      await OpenFile.open(file.path);
    } catch (e) {
      _showSnackBar('Gagal ekspor Excel: $e', success: false);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _printSummary(List<Map<String, dynamic>> summaryList) async {
    final pdfDoc = await _buildPdfDocument(summaryList);
    await Printing.layoutPdf(
      onLayout: (format) => pdfDoc.save(),
    );
    _showSnackBar('Berhasil mengirim ke printer!');
  }

  Future<pw.Document> _buildPdfDocument(List<Map<String, dynamic>> summaryList) async {
    final pdf = pw.Document();
    final wmLogo = pw.MemoryImage((await rootBundle.load('assets/Mikrotik-logo.png')).buffer.asUint8List());
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final now = DateTime.now();
          final dateStr = DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(now);
          return pw.Stack(
            children: [
              // Watermark logo besar di tengah halaman
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.07, 
                    child: pw.Image(wmLogo, width: 350),
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Dicetak: $dateStr', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text('Ringkasan Pembayaran', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Table(
                    border: pw.TableBorder.symmetric(inside: pw.BorderSide(width: 0.7, color: PdfColors.grey400), outside: pw.BorderSide(width: 1, color: PdfColors.grey400)),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Bulan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Total Pembayaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Jumlah Pembayaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...summaryList.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final month = item['month'] as int? ?? 0;
                        final year = item['year'] as int? ?? 0;
                        final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
                        final count = (item['count'] ?? 0) as int? ?? 0;
                        final monthName = _getMonthName(month, year);
                        final totalFormatted = _formatCurrency(total);
                        return pw.TableRow(
                          decoration: const pw.BoxDecoration(),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${i + 1}'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(monthName),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(totalFormatted),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('$count pembayaran'),
                            ),
                          ],
                        );
                      }), // Convert to list to avoid potential issues
                      // Baris total
                      (() {
                        final totalNominal = summaryList.fold<double>(0.0, (sum, item) {
                          final total = (item['total'] ?? 0) is int ? (item['total'] ?? 0).toDouble() : (item['total'] ?? 0);
                          return sum + (total as num).toDouble();
                        });
                        final totalCount = summaryList.fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as int));
                        return pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(_formatCurrency(totalNominal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('$totalCount pembayaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        );
                      })(),
                    ],
                  ),
                  pw.SizedBox(height: 24),
                  pw.Divider(),
                  pw.Center(
                    child: pw.Text('Data diambil dari Aplikasi Mikrotik PPPoE Monitor', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  String _getMonthName(int month, int year) {
    if (month <= 0 || year <= 0) {
      return 'Invalid Date';
    }
    final date = DateTime(year, month);
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }

  String _formatCurrency(dynamic value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  Future<void> openManageAllFilesAccess() async {
    final intent = AndroidIntent(
      action: 'android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION',
      data: 'package:com.yahahahusein.mikrotikpppoemonitor',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  void _initSummaryFuture() {
    final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
    if (routerId == null) {
      setState(() {
        _summaryFuture = Future.error('Silakan login router ulang (serial-number tidak ditemukan)');
      });
    } else {
      setState(() {
        _summaryFuture = ApiService.fetchPaymentSummary(routerId: routerId);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initSummaryFuture(); // Ganti init/fetch dengan routerId dari Provider
  }

  @override
  Widget build(BuildContext context) {
    // Check if dark mode is enabled
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ringkasan Pembayaran'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print',
              onPressed: () {
                setState(() {
                  showPrintPanel = !showPrintPanel;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (showPrintPanel)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 2,
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.print),
                                label: const Text('Export PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: isProcessing ? null : () async {
                                  try {
                                    final data = await _summaryFuture;
                                    await _printSummary(data);
                                  } catch (e) {
                                    _showSnackBar('Gagal export PDF: $e', success: false);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.table_chart),
                                label: const Text('Export Excel'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: isProcessing ? null : () async {
                                  try {
                                    final data = await _summaryFuture;
                                    await _exportExcel(data);
                                  } catch (e) {
                                    _showSnackBar('Gagal export Excel: $e', success: false);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (isProcessing)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.blue[200] : Colors.blue[600],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 12),
                          Text('Gagal memuat data', 
                            style: TextStyle(
                              color: isDark ? Colors.red[200] : Colors.red,
                            )
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(), 
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _initSummaryFuture();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.grey[700] : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'Tidak ada data pembayaran.', 
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        )
                      )
                    );
                  }
                  final summaryList = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                    itemCount: summaryList.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = summaryList[i];
                      final month = item['month'] as int? ?? 0;
                      final year = item['year'] as int? ?? 0;
                      final monthName = _getMonthName(month, year);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MonthlyPaymentDetailScreen(
                                month: month,
                                year: year,
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: Colors.blueGrey.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, color: Colors.blue.shade400, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      monthName, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500, 
                                        fontSize: 15, 
                                        color: isDark ? Colors.blue[200] : const Color(0xFF1565C0)
                                      )
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: Rp ${currencyFormat.format(item['total'] ?? 0)}', 
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600, 
                                        color: isDark ? Colors.green[200] : const Color(0xFF388E3C), 
                                        fontSize: 14
                                      )
                                    ),
                                    Text(
                                      '${item['count'] ?? 0} pembayaran', 
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black45, 
                                        fontSize: 12
                                      )
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios, 
                                color: isDark ? Colors.grey[400] : const Color(0xFF90CAF9), 
                                size: 18
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthlyPaymentDetailScreen extends StatelessWidget {
  final int month;
  final int year;
  final bool isDark;
  
  const MonthlyPaymentDetailScreen({
    super.key, 
    required this.month, 
    required this.year,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final String monthYearTitle = DateFormat('MMMM yyyy', 'id_ID').format(DateTime(year, month));
    final currencyFormat = NumberFormat('#,##0', 'id_ID');
    final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
    if (routerId == null) {
      return GradientContainer(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(monthYearTitle), backgroundColor: Colors.transparent),
          body: const Center(child: Text('Silakan login router ulang')),
        ),
      );
    }
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(monthYearTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiService.fetchAllPaymentsForMonthYear(month, year, routerId: routerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.blue[200] : Colors.blue[600],
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat detail: ${snapshot.error}', 
                      style: TextStyle(
                        color: isDark ? Colors.red[200] : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Rebuild the widget to retry
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.grey[700] : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'Tidak ada pembayaran di bulan ini.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              );
            }
            final payments = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              itemCount: payments.length,
              itemBuilder: (context, i) {
                final p = payments[i];
                final username = (p['username'] ?? p['user_id'] ?? '-').toString();
                final nominal = double.tryParse(p['amount'].toString()) ?? 0;
                final method = (p['method'] ?? '-').toString();
                final paymentDate = p['payment_date'] ?? '-';
                final note = (p['note'] ?? '').toString();
                final avatarColor = Colors.primaries[username.hashCode % Colors.primaries.length].shade200;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: Colors.blueGrey.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarColor,
                        radius: 22,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    username,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600, 
                                      fontSize: 15, 
                                      color: isDark ? Colors.blue[200] : const Color(0xFF1565C0)
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rp ${currencyFormat.format(nominal)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16, 
                                    color: isDark ? Colors.green[200] : const Color(0xFF43A047)
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.grey[400] : Colors.blueGrey.shade300),
                                const SizedBox(width: 4),
                                Text(
                                  paymentDate, 
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: isDark ? Colors.white70 : Colors.black54
                                  )
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: method.toLowerCase() == 'cash' 
                                      ? (isDark ? Colors.green[900] : Colors.green.shade50) 
                                      : (isDark ? Colors.blue[900] : Colors.blue.shade50),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    method,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: method.toLowerCase() == 'cash' 
                                        ? (isDark ? Colors.green[200] : Colors.green.shade700) 
                                        : (isDark ? Colors.blue[200] : Colors.blue.shade700),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.sticky_note_2, size: 13, color: isDark ? Colors.orange[200] : Colors.orange.shade300),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        note, 
                                        style: TextStyle(
                                          fontSize: 12, 
                                          color: isDark ? Colors.white70 : Colors.black87
                                        )
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}