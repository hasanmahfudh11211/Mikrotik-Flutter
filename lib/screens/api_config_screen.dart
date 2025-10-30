import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/gradient_container.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';

class ApiConfigScreen extends StatefulWidget {
  const ApiConfigScreen({Key? key}) : super(key: key);

  @override
  State<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends State<ApiConfigScreen> {
  final TextEditingController _apiUrlController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  String _initialBaseUrl = '';
  bool _isDirty = false;
  bool _testing = false;
  bool? _lastTestOk; // null: belum dites, true: ok, false: gagal
  Map<String, dynamic>? _testResult;
  String _currentBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _apiUrlController.addListener(() {
      final current = _apiUrlController.text.trim();
      final changed = current != _initialBaseUrl.trim();
      if (changed != _isDirty) {
        setState(() { _isDirty = changed; });
      }
    });
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    final baseUrl = await ConfigService.getBaseUrl();
    setState(() {
      _apiUrlController.text = baseUrl;
      _initialBaseUrl = baseUrl;
      _currentBaseUrl = baseUrl;
      _isDirty = false;
      _lastTestOk = null;
      _testResult = null;
    });
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    
    final normalized = ConfigService.normalizeBaseUrl(_apiUrlController.text);
    _apiUrlController.text = normalized;
    await ConfigService.setBaseUrl(normalized);
    ApiService.clearCache();
    await ApiService.refreshBaseUrlFromStorage();
    
    setState(() {
      _initialBaseUrl = normalized;
      _currentBaseUrl = normalized;
      _isDirty = false;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi API berhasil disimpan'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testApiConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    
    setState(() { 
      _testing = true; 
      _lastTestOk = null; 
      _testResult = null;
    });
    
    final normalized = ConfigService.normalizeBaseUrl(_apiUrlController.text);
    _apiUrlController.text = normalized;
    final result = await ConfigService.testConnectionDetailed(baseUrlOverride: normalized);
    
    if (!mounted) return;
    setState(() { 
      _testing = false; 
      _lastTestOk = result['success'];
      _testResult = result;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['success'] 
          ? 'Koneksi API berhasil! (${result['responseTime']}ms)' 
          : 'Gagal terhubung ke API'),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset ke Default'),
        content: const Text('Apakah Anda yakin ingin mengembalikan Base URL ke pengaturan default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
 
    if (confirmed == true) {
    await ConfigService.resetBaseUrl();
    await ApiService.refreshBaseUrlFromStorage();
      final defaultUrl = await ConfigService.getBaseUrl();
      
      _apiUrlController.text = defaultUrl;
      setState(() {
        _initialBaseUrl = defaultUrl;
        _currentBaseUrl = defaultUrl;
        _isDirty = false;
        _lastTestOk = null;
      });
      
    if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Base URL direset ke default'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Konfigurasi API',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        centerTitle: true,
          actions: [
            IconButton(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restore),
              tooltip: 'Reset ke Default',
            ),
          ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Configuration Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: isDark ? Colors.blue[200] : Colors.blue[800],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Konfigurasi Saat Ini',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Base URL Aktif:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentBaseUrl,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // API Configuration Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings,
                              color: isDark ? Colors.blue[200] : Colors.blue[800],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pengaturan API',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
              TextFormField(
                controller: _apiUrlController,
                decoration: InputDecoration(
                            labelText: 'Base URL',
                  hintText: 'https://example.com/api',
                  prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            helperText: 'Wajib menyertakan skema (http/https) dan tanpa slash di akhir',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                                  tooltip: 'Clear Field',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _apiUrlController.clear();
                                  },
                                ),
                              ],
                            ),
                ),
                keyboardType: TextInputType.url,
                autofillHints: const [AutofillHints.url],
                validator: (value) {
                  final v = (value ?? '').trim();
                            if (v.isEmpty) return 'Base URL tidak boleh kosong';
                  final candidate = v.contains('://') ? v : 'https://$v';
                  final ok = Uri.tryParse(candidate);
                            if (ok == null || ok.host.isEmpty) {
                              return 'Format URL tidak valid. Contoh: https://domain.com/api';
                            }
                  return null;
                },
              ),
              const SizedBox(height: 16),

                        // Status indicator
                        if (_lastTestOk != null && _testResult != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _lastTestOk == true 
                                ? Colors.green.withOpacity(0.1) 
                                : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _lastTestOk == true ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _lastTestOk == true ? Icons.check_circle_outline : Icons.error_outline,
                                      size: 20,
                                      color: _lastTestOk == true ? Colors.green[700]! : Colors.red[700]!,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _lastTestOk == true 
                                          ? 'Koneksi API berhasil' 
                                          : 'Gagal terhubung ke API',
                                        style: TextStyle(
                                          color: _lastTestOk == true ? Colors.green[700]! : Colors.red[700]!,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _lastTestOk == true ? Icons.wifi : Icons.wifi_off,
                                      size: 18,
                                      color: _lastTestOk == true ? Colors.green[700]! : Colors.red[700]!,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTestDetail('URL:', _testResult!['url'] ?? 'N/A', isDark),
                                _buildTestDetail('Status Code:', '${_testResult!['statusCode'] ?? 'N/A'}', isDark),
                                _buildTestDetail('Response Time:', '${_testResult!['responseTime'] ?? 0}ms', isDark),
                                if (_testResult!['contentType'] != null)
                                  _buildTestDetail('Content-Type:', _testResult!['contentType'], isDark),
                                if (_testResult!['dataPreview'] != null)
                                  _buildTestDetail('Data:', _testResult!['dataPreview'], isDark),
                                if (_testResult!['userCount'] != null && _testResult!['userCount'] > 0)
                                  _buildTestDetail('Users Found:', '${_testResult!['userCount']}', isDark),
                                if (_testResult!['error'] != null)
                                  _buildTestDetail('Error:', _testResult!['error'], isDark),
                                if (_testResult!['parseError'] != null)
                                  _buildTestDetail('Parse Error:', _testResult!['parseError'], isDark),
                              ],
                            ),
                          ),
                        if (_lastTestOk != null) const SizedBox(height: 16),

                        // Action buttons
                        Row(
                children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _testing ? null : _testApiConnection,
                                icon: _testing 
                                  ? const SizedBox(
                                      height: 16, 
                                      width: 16, 
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2, 
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.wifi_tethering),
                    label: Text(_testing ? 'Testing...' : 'Test Connection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _testing 
                                    ? Colors.grey[400] 
                                    : (isDark ? Colors.blue[700] : Colors.blue[800]),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: _testing ? 0 : 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _isDirty ? _saveSettings : null,
                                icon: Icon(_isDirty ? Icons.save : Icons.check),
                                label: Text(_isDirty ? 'Save' : 'Saved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isDirty ? Colors.green : Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: _isDirty ? 2 : 0,
                                ),
                              ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
                const SizedBox(height: 16),

                // Help Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: isDark ? Colors.blue[200] : Colors.blue[800],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bantuan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHelpItem(
                          'Format URL yang benar:',
                          'https://domain.com/api',
                          Icons.link,
                          isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildHelpItem(
                          'Test Connection:',
                          'Cek koneksi ke endpoint /get_all_users.php',
                          Icons.wifi_tethering,
                          isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildHelpItem(
                          'Reset Default:',
                          'Kembalikan ke URL default aplikasi',
                          Icons.restore,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestDetail(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.blue[200] : Colors.blue[800],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
