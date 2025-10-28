import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/gradient_container.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'payment_summary_screen.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    double value = 0;
    try {
      value = double.parse(newValue.text.replaceAll('.', ''));
    } catch (e) {
      return newValue;
    }

    final formatter = NumberFormat("#,##0", "id_ID");
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  List<Map<String, dynamic>> _users = [];
  String? _error;
  final currencyFormat = NumberFormat('#,##0', 'id_ID');
  String _searchQuery = '';
  final TextEditingController _searchUserController = TextEditingController();
  
  // Filter bulan untuk pembayaran
  DateTime _selectedMonth = DateTime.now();
  bool _showAllPayments = false; // false = filter per bulan (default ke bulan saat ini)
  bool _showFilterPanel = false; // Tambahkan state untuk panel filter
  // Tambahkan state sementara untuk filter manual
  DateTime? _tempSelectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _tempSelectedMonth = null;
    // Set default to show current month payments only
    _showAllPayments = false;
    _loadUsers();
  }
  
  void _loadUsers() {
    setState(() {
      _error = null;
      // Clear cache when manually refreshing
      ApiService.clearCache();
      _usersFuture = ApiService.fetchAllUsersWithPayments().then((data) {
        _users = data;
        return data;
      }).catchError((e) {
        // Error loading users: $e
        _error = e.toString();
        // Show a more user-friendly error message
        if (e.toString().contains('Timeout')) {
          _error = 'Koneksi timeout. Silakan coba lagi.';
        } else if (e.toString().contains('Failed host lookup')) {
          _error = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        } else if (e.toString().contains('500')) {
          _error = 'Server error. Silakan coba lagi nanti.';
        }
        return <Map<String, dynamic>>[];
      });
    });
  }

  void _showBillingDetailSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        Future<void> showAddPaymentDialog() async {
          final formKey = GlobalKey<FormState>();
          final amountController = TextEditingController();
          String selectedMethod = 'Cash';
          DateTime paymentDate = DateTime.now();
          final noteController = TextEditingController();
          bool isSubmitting = false;
          
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Tambah Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Nominal (Rp)',
                                prefixText: 'Rp ',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Nominal wajib diisi' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedMethod,
                              items: const [
                                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                              ],
                              onChanged: (v) {
                                setDialogState(() {
                                  selectedMethod = v!;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Metode',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: paymentDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    paymentDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Tanggal Pembayaran',
                                  border: OutlineInputBorder(),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(paymentDate),
                                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: noteController,
                              decoration: const InputDecoration(
                                labelText: 'Catatan (opsional)',
                                border: OutlineInputBorder(),
                              ),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('BATAL'),
                      ),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                
                                setDialogState(() {
                                  isSubmitting = true;
                                });
                                
                                try {
                                  // Safe access to prevent null pointer exceptions
                                  final userId = user['id'];
                                  if (userId == null) {
                                    throw Exception('User ID tidak ditemukan');
                                  }
                                  
                                  final amountRaw = amountController.text.replaceAll('.', '').replaceAll(',', '');
                                  final amount = double.tryParse(amountRaw) ?? 0;
                                  final url = Uri.parse('${ApiService.baseUrl}/payment_operations.php?operation=add');
                                  final body = {
                                    'user_id': userId,
                                    'amount': amount,
                                    'payment_date': DateFormat('yyyy-MM-dd').format(paymentDate),
                                    'method': selectedMethod,
                                    'note': noteController.text,
                                    'created_by': 'Admin',
                                  };
                                  
                                  // Adding payment for user $userId
                                  // Payment data: $body
                                  
                                  final resp = await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode(body),
                                  );
                                  
                                  // Payment API response status: ${resp.statusCode}
                                  // Payment API response body: ${resp.body}
                                  
                                  final respData = jsonDecode(resp.body);
                                  if (respData['success'] == true) {
                                    Navigator.of(dialogContext).pop();
                                    if (context.mounted) {
                                      await showSuccessDialog(context, 'Pembayaran berhasil ditambahkan!');
                                      if (mounted) {
                                        // Refresh data setelah berhasil menambah pembayaran
                                        _loadUsers();
                                      }
                                    }
                                  } else {
                                    Navigator.of(dialogContext).pop();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Gagal: ${respData['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  Navigator.of(dialogContext).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  // Ensure the loading state is reset even if an error occurs
                                  if (dialogContext.mounted) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                    });
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('SIMPAN'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        }
        
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          if (user['profile'] != null)
                            Text(
                              'Profile: ${user['profile']}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.payments, color: Colors.green.shade700, size: 22),
                        const SizedBox(width: 10),
                        const Text('History Pembayaran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const Spacer(),
                      ],
                    ),
                    const Divider(),
                    // Payment summary
                    if (_filteredPayments(user).isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.analytics, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _showAllPayments ? 'Total Semua Pembayaran' : 'Total Pembayaran ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rp ${currencyFormat.format(_filteredPayments(user).fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0)))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_filteredPayments(user).length} pembayaran',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _filteredPayments(user).isEmpty
                        ? Column(
                            key: const ValueKey('empty'),
                            children: [
                              const SizedBox(height: 32),
                              Icon(Icons.receipt_long, color: Colors.grey, size: 54),
                              const SizedBox(height: 12),
                              Text(
                                !_showAllPayments 
                                  ? 'Tidak ada pembayaran di ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}.'
                                  : 'Belum ada pembayaran.',
                                style: const TextStyle(color: Colors.black54, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                !_showAllPayments 
                                  ? 'Coba pilih bulan lain atau tekan tombol "Semua" untuk melihat semua pembayaran.'
                                  : 'Tekan tombol di bawah untuk menambah pembayaran baru.',
                                style: const TextStyle(color: Colors.black38, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('list'),
                            children: _filteredPayments(user).map<Widget>((p) {
                              final amount = p['amount']?.toString() ?? '-';
                              final method = p['method']?.toString() ?? '-';
                              final paymentDate = p['payment_date']?.toString() ?? '-';
                              final createdBy = p['created_by']?.toString() ?? '';
                              final note = p['note']?.toString() ?? '';
                              final isCurrentMonth = () {
                                final dt = DateTime.tryParse(paymentDate);
                                return dt != null && dt.year == _selectedMonth.year && dt.month == _selectedMonth.month;
                              }();
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 380),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: isCurrentMonth
                                        ? BorderSide(color: Colors.blue.shade400, width: 2)
                                        : BorderSide(color: Colors.grey.shade200, width: 1),
                                    ),
                                    color: isCurrentMonth ? Colors.blue.shade50 : Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green, size: 22),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Rp ${currencyFormat.format(double.tryParse(amount) ?? 0)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                              ),
                                              _buildMethodChip(method),
                                              if (isCurrentMonth) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text('Bulan Ini', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (!_showAllPayments) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Filter: ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}',
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey.shade300),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Tanggal: ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(paymentDate))}',
                                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                          if (createdBy.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person, size: 15, color: Colors.blueGrey.shade300),
                                                  const SizedBox(width: 6),
                                                  Text('Oleh: $createdBy', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                                ],
                                              ),
                                            ),
                                          if (note.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.info_outline, size: 15, color: Colors.orange),
                                                  const SizedBox(width: 6),
                                                  Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Tooltip(
                                                message: 'Edit pembayaran',
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _showEditPaymentDialog(p, user),
                                                  icon: const Icon(Icons.edit, size: 18),
                                                  label: const Text('Edit'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue.shade50,
                                                    foregroundColor: Colors.blue.shade800,
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Tooltip(
                                                message: 'Hapus pembayaran',
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _confirmDeletePayment(p),
                                                  icon: const Icon(Icons.delete, size: 18),
                                                  label: const Text('Hapus'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red.shade50,
                                                    foregroundColor: Colors.red.shade800,
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: showAddPaymentDialog,
                          icon: const Icon(Icons.add_circle, color: Colors.white),
                          label: const Text('Tambah Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Tagihan/Billing',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadUsers,
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.white),
              tooltip: 'Ringkasan Pembayaran',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentSummaryScreen()),
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (_error != null) {
              final errorMsg = _error!;
              final isTimeout = errorMsg.toLowerCase().contains('timeout');
              final isServerError = errorMsg.toLowerCase().contains('server error');
              
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isServerError ? Icons.error_outline : Icons.wifi_off,
                        size: 64,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isTimeout
                            ? 'Timeout: Server tidak merespons dalam 10 detik.\nSilakan cek koneksi atau coba lagi.'
                            : isServerError
                                ? 'Server Error: API tidak tersedia saat ini.\nSilakan coba lagi nanti.'
                                : 'Error: $errorMsg',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada user ditemukan.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }
            final users = _filteredSortedUsers();
            return Column(
              children: [
                // FILTER GLOBAL
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar + tombol filter satu baris
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Cari...',
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                  border: InputBorder.none,
                                  isDense: true,
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchUserController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (v) {
                                  if (mounted) {
                                    setState(() => _searchQuery = v);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Tooltip(
                              message: _showFilterPanel ? 'Sembunyikan filter' : 'Tampilkan filter',
                              child: IconButton(
                                icon: Icon(_showFilterPanel ? Icons.filter_alt_off : Icons.filter_alt, color: Colors.blue.shade700, size: 24),
                                onPressed: () {
                                  setState(() {
                                    _showFilterPanel = !_showFilterPanel;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Panel filter (expand/collapse)
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _showFilterPanel ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        firstChild: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 2, bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade50,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Tombol kiri
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                    side: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _tempSelectedMonth = (_tempSelectedMonth ?? _selectedMonth).subtract(const Duration(days: 31));
                                      _tempSelectedMonth = DateTime(_tempSelectedMonth!.year, _tempSelectedMonth!.month, 1);
                                    });
                                  },
                                  child: const Icon(Icons.chevron_left, size: 16, color: Color(0xFF1976D2)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Picker bulan
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showMonthPicker(
                                    context: context,
                                    initialDate: _tempSelectedMonth ?? _selectedMonth,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(now.year + 1, 12, 31),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _tempSelectedMonth = DateTime(picked.year, picked.month, 1);
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    DateFormat('MMM yyyy', 'id_ID').format((_tempSelectedMonth ?? _selectedMonth)),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1976D2),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Tombol kanan
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                    side: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _tempSelectedMonth = (_tempSelectedMonth ?? _selectedMonth).add(const Duration(days: 31));
                                      _tempSelectedMonth = DateTime(_tempSelectedMonth!.year, _tempSelectedMonth!.month, 1);
                                    });
                                  },
                                  child: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF1976D2)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Tombol Apply
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_tempSelectedMonth != null) {
                                        _selectedMonth = _tempSelectedMonth!;
                                      }
                                      _showAllPayments = false; // Set to false when applying specific month
                                      _showFilterPanel = false; // Close the filter panel after applying
                                    });
                                  },
                                  child: const Text('Apply'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Tombol Show All
                              SizedBox(
                                height: 28,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    side: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showAllPayments = true;
                                      _showFilterPanel = false; // Close the filter panel after applying
                                    });
                                  },
                                  child: const Text('Semua', style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                // END FILTER GLOBAL
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _loadUsers(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final user = users[i];
                        // Status lunas/Belum harus sesuai bulan yang dipilih ATAU semua pembayaran jika showAllPayments true
                        bool hasPaid = false;
                        if (_showAllPayments) {
                          // Jika menampilkan semua, anggap user sudah bayar jika memiliki pembayaran apapun
                          hasPaid = (user['payments'] as List).isNotEmpty;
                        } else {
                          // Status lunas/Belum harus sesuai bulan yang dipilih
                          hasPaid = (user['payments'] as List).any((p) {
                            final paymentDate = DateTime.tryParse(p['payment_date'] ?? '');
                            return paymentDate != null &&
                              paymentDate.year == _selectedMonth.year &&
                              paymentDate.month == _selectedMonth.month;
                          });
                        }
                        
                        return GestureDetector(
                          onTap: () => _showBillingDetailSheet(user),
                          child: Card(
                            elevation: 2,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: _hasUserPaidForSelectedMonth(user) ? Colors.green.shade100 : Colors.red.shade100, width: 1.2),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: _hasUserPaidForSelectedMonth(user) ? Colors.green.shade50 : Colors.red.shade50,
                                    child: Icon(Icons.payments, color: _hasUserPaidForSelectedMonth(user) ? Colors.green : Colors.red, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user['username'] ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (user['profile'] != null)
                                          Text('Profile: ${user['profile']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                        if (user['nominal'] != null)
                                          Text('Tagihan: Rp ${currencyFormat.format(double.tryParse(user['nominal']) ?? 0)}',
                                            style: const TextStyle(fontSize: 13, color: Colors.deepOrange, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _hasUserPaidForSelectedMonth(user) ? Colors.green : Colors.red,
                                        child: Icon(
                                          _hasUserPaidForSelectedMonth(user) ? Icons.check : Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _hasUserPaidForSelectedMonth(user) ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _hasUserPaidForSelectedMonth(user) ? 'Lunas' : 'Belum',
                                          style: TextStyle(
                                            color: _hasUserPaidForSelectedMonth(user) ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Footer: jumlah user
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Total User: ${users.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method) {
    Color color = method.toLowerCase() == 'cash' ? Colors.green : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Future<void> showSuccessDialog(BuildContext context, String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Berhasil', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  void _showEditPaymentDialog(Map<String, dynamic> payment, Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: payment['amount']?.toString() ?? '');
    String selectedMethod = payment['method']?.toString() ?? 'Cash';
    DateTime paymentDate = DateTime.tryParse(payment['payment_date']?.toString() ?? '') ?? DateTime.now();
    final noteController = TextEditingController(text: payment['note']?.toString() ?? '');
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Nominal (Rp)',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Nominal wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedMethod,
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            selectedMethod = v!;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Metode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              paymentDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal Pembayaran',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(paymentDate),
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('BATAL'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          
                          try {
                            final paymentId = payment['id'];
                            final userId = user['id'];
                            final amountRaw = amountController.text.replaceAll('.', '').replaceAll(',', '');
                            final amount = double.tryParse(amountRaw) ?? 0;
                            final url = Uri.parse('${ApiService.baseUrl}/payment_operations.php?operation=update');
                            final body = {
                              'id': paymentId,
                              'user_id': userId,
                              'amount': amount,
                              'payment_date': DateFormat('yyyy-MM-dd').format(paymentDate),
                              'method': selectedMethod,
                              'note': noteController.text,
                              'created_by': 'Admin',
                            };
                            
                            final resp = await http.put(
                              url,
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode(body),
                            );
                            
                            final respData = jsonDecode(resp.body);
                            if (respData['success'] == true) {
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                await showSuccessDialog(context, 'Pembayaran berhasil diupdate!');
                                if (mounted) {
                                  // Refresh data setelah berhasil mengupdate pembayaran
                                  _loadUsers();
                                }
                              }
                            } else {
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: ${respData['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          } catch (e) {
                            Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            // Ensure the loading state is reset even if an error occurs
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                      },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SIMPAN'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _confirmDeletePayment(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text('Konfirmasi Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('Apakah Anda yakin ingin menghapus pembayaran ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  final paymentId = payment['id'];
                  final url = Uri.parse('${ApiService.baseUrl}/payment_operations.php?operation=delete');
                  final body = {'id': paymentId};
                  
                  final resp = await http.delete(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(body),
                  );
                  
                  final respData = jsonDecode(resp.body);
                  if (respData['success'] == true) {
                    Navigator.of(dialogContext).pop();
                    if (context.mounted) {
                      await showSuccessDialog(context, 'Pembayaran berhasil dihapus!');
                      if (mounted) {
                        // Refresh data setelah berhasil menghapus pembayaran
                        _loadUsers();
                      }
                    }
                  } else {
                    Navigator.of(dialogContext).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal: ${respData['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
                      );
                    }
                  }
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('HAPUS'),
            ),
          ],
        );
      },
    );
  }
  
  List<Map<String, dynamic>> _filteredPayments(Map<String, dynamic> user) {
    final payments = user['payments'] as List;
    if (_showAllPayments) {
      // Tampilkan semua pembayaran dengan urutan terbaru dulu
      final sortedPayments = payments.cast<Map<String, dynamic>>().toList();
      sortedPayments.sort((a, b) {
        final dateA = DateTime.tryParse(a['payment_date'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['payment_date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA); // Terbaru dulu
      });
      return sortedPayments;
    }
    
    // Filter berdasarkan bulan yang dipilih
    final filtered = payments.where((p) {
      final paymentDate = DateTime.tryParse(p['payment_date'] ?? '');
      return paymentDate != null &&
          paymentDate.year == _selectedMonth.year &&
          paymentDate.month == _selectedMonth.month;
    }).cast<Map<String, dynamic>>().toList();
    
    // Urutkan berdasarkan tanggal terbaru dulu
    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a['payment_date'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['payment_date'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA); // Terbaru dulu
    });
    
    return filtered;
  }
  
  List<Map<String, dynamic>> _filteredSortedUsers() {
    List<Map<String, dynamic>> filtered = _users;
    
    // Filter berdasarkan pencarian
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((u) {
        // Cek di username, profile, atau nominal
        return (u['username'] ?? '').toLowerCase().contains(q) ||
            (u['profile'] ?? '').toLowerCase().contains(q) ||
            (u['nominal'] ?? '').toString().toLowerCase().contains(q) ||
            // Cek juga di pembayaran
            (u['payments'] as List).any((p) {
              return (p['amount'] ?? '').toString().contains(q) ||
                  (p['method'] ?? '').toString().toLowerCase().contains(q) ||
                  (p['note'] ?? '').toString().toLowerCase().contains(q);
            });
      }).toList();
    }
    
    // Urutkan berdasarkan username A-Z
    filtered.sort((a, b) => (a['username'] ?? '').compareTo(b['username'] ?? ''));
    return filtered;
  }
  
  // Method to check if user has paid for the selected month
  bool _hasUserPaidForSelectedMonth(Map<String, dynamic> user) {
    if (_showAllPayments) {
      // If showing all payments, consider user as paid if they have any payment
      return (user['payments'] as List).isNotEmpty;
    }
    
    // Check if user has paid for the selected month
    return (user['payments'] as List).any((p) {
      final paymentDate = DateTime.tryParse(p['payment_date'] ?? '');
      return paymentDate != null &&
        paymentDate.year == _selectedMonth.year &&
        paymentDate.month == _selectedMonth.month;
    });
  }
  
  String formatLastLogout(String? lastLogout) {
    if (lastLogout == null || lastLogout.isEmpty) {
      return '-';
    }
    
    try {
      final dateTime = DateTime.parse(lastLogout);
      return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dateTime);
    } catch (e) {
      return lastLogout;
    }
  }
  
  String _getRealtimeUptime(String? uptime) {
    if (uptime == null || uptime.isEmpty) return '0s';
    
    // Parse uptime string like "1d2h3m4s"
    final regex = RegExp(r'((\d+)w)?((\d+)d)?((\d+)h)?((\d+)m)?((\d+)s)?');
    final match = regex.firstMatch(uptime);
    if (match == null) return uptime;
    
    int w = int.tryParse(match.group(2) ?? '0') ?? 0;
    int d = int.tryParse(match.group(4) ?? '0') ?? 0;
    int h = int.tryParse(match.group(6) ?? '0') ?? 0;
    int m = int.tryParse(match.group(8) ?? '0') ?? 0;
    int s = int.tryParse(match.group(10) ?? '0') ?? 0;
    
    // Convert to total seconds
    int totalSeconds = w * 604800 + d * 86400 + h * 3600 + m * 60 + s;
    
    // Add current session time
    final now = DateTime.now();
    // In a real app, you would track when the session started
    // For now, we'll just return the parsed uptime
    return uptime;
  }
  
  DateTime? _parseLogoutDate(String? logoutStr) {
    if (logoutStr == null || logoutStr.isEmpty) return null;
    try {
      return DateTime.parse(logoutStr);
    } catch (e) {
      return null;
    }
  }
  
  int _parseFlexibleUptime(String? uptime) {
    if (uptime == null || uptime.isEmpty) return 0;
    
    // Handle different uptime formats
    if (uptime.contains('w') || uptime.contains('d') || uptime.contains('h') || 
        uptime.contains('m') || uptime.contains('s')) {
      // Parse format like "1w2d3h4m5s"
      final regex = RegExp(r'((\d+)w)?((\d+)d)?((\d+)h)?((\d+)m)?((\d+)s)?');
      final match = regex.firstMatch(uptime);
      if (match == null) return 0;
      
      int w = int.tryParse(match.group(2) ?? '0') ?? 0;
      int d = int.tryParse(match.group(4) ?? '0') ?? 0;
      int h = int.tryParse(match.group(6) ?? '0') ?? 0;
      int m = int.tryParse(match.group(8) ?? '0') ?? 0;
      int s = int.tryParse(match.group(10) ?? '0') ?? 0;
      
      return w * 604800 + d * 86400 + h * 3600 + m * 60 + s;
    } else {
      // Try to parse as seconds
      return int.tryParse(uptime) ?? 0;
    }
  }
  
  @override
  void dispose() {
    _searchUserController.dispose();
    super.dispose();
  }
}
