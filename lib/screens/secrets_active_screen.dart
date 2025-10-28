import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/mikrotik_provider.dart';
import '../services/mikrotik_service.dart';
import '../widgets/gradient_container.dart';
import '../screens/edit_screen.dart';

class SecretsActiveScreen extends StatefulWidget {
  const SecretsActiveScreen({Key? key}) : super(key: key);

  @override
  State<SecretsActiveScreen> createState() => _SecretsActiveScreenState();
}

class _SecretsActiveScreenState extends State<SecretsActiveScreen> {
  String? _lastDataHash;
  DateTime? _fetchTime;
  Timer? _timer;

  String _searchQuery = '';
  String _sortOption = 'Uptime (Shortest)';
  String _statusFilter = 'Semua';
  final List<String> _sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Uptime (Longest)',
    'Uptime (Shortest)',
    'IP Address (A-Z)',
    'IP Address (Z-A)',
  ];
  final List<String> _statusOptions = ['Semua', 'Online', 'Offline'];
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _interfaces = [];
  bool _loadingInterface = false;

  int _itemsPerPage = 50;
  int _currentMax = 50;
  late ScrollController _scrollController;

  Future<void> _fetchInterfaces(MikrotikService service) async {
    setState(() => _loadingInterface = true);
    try {
      final data = await service.getInterface();
      if (mounted) setState(() => _interfaces = data);
    } catch (e) {
      // ignore error, just show 0B
    } finally {
      if (mounted) setState(() => _loadingInterface = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        setState(() {
          if (_currentMax < provider.pppSecrets.length) {
            _currentMax += _itemsPerPage;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('Filter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _sortOption,
              items: _sortOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _sortOption = v!),
              decoration: const InputDecoration(labelText: 'Shortlist'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statusFilter,
              items: _statusOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
              decoration: const InputDecoration(labelText: 'Status Koneksi'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(BuildContext parentContext, Map<String, dynamic> user) {
    final isOnline = user['isOnline'] == true;
    final profile = user['profile-info'] ?? {};
    // Create a timer to update the UI
    Timer? timer;
    
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        // Start the timer when the bottom sheet is shown
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (bottomSheetContext.mounted) {
            // Force rebuild of the bottom sheet
            (bottomSheetContext as Element).markNeedsBuild();
          }
        });
        
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(parentContext).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
            child: Column(
            children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      // User header with status
                      Row(
                children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.blue.shade700,
                            ),
                  ),
                          const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                Text(
                                  user['name'] ?? '-',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user['profile'] ?? '-',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                            ),
                          ],
                        ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isOnline ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(parentContext).brightness == Brightness.dark 
                              ? Colors.grey[800]!.withAlpha(128) 
                              : Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(parentContext).brightness == Brightness.dark
                              ? Colors.grey[900]!.withAlpha(77)
                              : Colors.grey[50]!,
                        ),
                  child: Column(
                    children: [
                            _buildDetailItem(Icons.person_outline, 'Name', user['name'] ?? '-', canCopy: true),
                            _buildDivider(),
                            _buildDetailItem(Icons.lock_outline, 'Password', user['password'] ?? '-', isPassword: true),
                            _buildDivider(),
                            _buildDetailItem(Icons.settings_outlined, 'Service', user['service'] ?? '-'),
                            _buildDivider(),
                            _buildDetailItem(Icons.wifi_outlined, 'IP', user['address'] ?? '-', canCopy: true),
                            _buildDivider(),
                            StatefulBuilder(
                              builder: (context, setState) {
                                return _buildDetailItem(
                                  Icons.timer_outlined, 
                                  'Uptime', 
                                  _getRealtimeUptime(user['uptime'])
                                );
                              }
                            ),
                            if (user['caller-id'] != null && user['caller-id'].toString().isNotEmpty) ...[
                              _buildDivider(),
                              _buildDetailItem(Icons.perm_device_info, 'MAC Address', user['caller-id'] ?? '-', canCopy: true),
                            ],
                            _buildDivider(),
                            _buildDetailItem(Icons.logout_outlined, 'Last logout', formatLastLogout(user['last-logged-out'] ?? user['last_logout'])),
                            _buildDivider(),
                            _buildDetailItem(Icons.link_off_outlined, 'Last disconnect', user['last-disconnect-reason'] ?? '-'),
                            _buildDivider(),
                            _buildDetailItem(Icons.block_outlined, 'Disabled', user['disabled'] ?? 'false'),
                            _buildDivider(),
                            _buildDetailItem(Icons.route_outlined, 'Routes', user['routes'] ?? '-'),
                    ],
                  ),
                ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'PPP Profile',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        const SizedBox(height: 8),
                        Text(
                              'Rate Limit: ${profile['rate-limit'] ?? '-'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        Text(
                              'DNS Server: ${profile['dns-server'] ?? '-'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        Text(
                              'Local Address: ${profile['local-address'] ?? '-'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        Text(
                              'Remote Address: ${profile['remote-address'] ?? '-'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (profile['parent-queue'] != null) Text(
                              'Parent Queue: ${profile['parent-queue']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                      ],
                    ),
                  ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                final provider = Provider.of<MikrotikProvider>(parentContext, listen: false);
                                Navigator.push(
                                  parentContext,
                                  MaterialPageRoute(
                                    builder: (context) => ChangeNotifierProvider.value(
                                      value: provider,
                                      child: EditScreen(user: user),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                _showDeleteConfirmation(parentContext, user);
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Cancel the timer when the bottom sheet is closed
      timer?.cancel();
    });
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {bool isPassword = false, bool canCopy = false}) {
    final ValueNotifier<bool> passwordVisible = ValueNotifier<bool>(false);
    final Color themeColor = Theme.of(context).brightness == Brightness.dark ? Colors.blue[300]! : Colors.blue[700]!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: themeColor),
          ),
          const SizedBox(width: 8),
          Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
                      children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: isPassword
                        ? ValueListenableBuilder<bool>(
                            valueListenable: passwordVisible,
                            builder: (context, isVisible, _) {
                              return Text(
                                isVisible ? value : '••••••••',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              );
                            },
                          )
                        : Text(
                            value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                    ),
                    if (isPassword)
                      GestureDetector(
                        onTap: () => passwordVisible.value = !passwordVisible.value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            passwordVisible.value ? Icons.visibility_off : Icons.visibility,
                            size: 16,
                            color: themeColor,
                          ),
                        ),
                      )
                    else if (canCopy)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$label copied to clipboard'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: themeColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).brightness == Brightness.dark 
        ? Colors.grey[800]!.withAlpha(128) 
        : Colors.grey[200],
    );
  }

  void _showDeleteConfirmation(BuildContext parentContext, Map<String, dynamic> user) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Delete',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete user "${user['name']}"?',
              style: const TextStyle(fontSize: 16),
            ),
                        const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final provider = Provider.of<MikrotikProvider>(parentContext, listen: false);
                await provider.service.deletePPPSecret(user['.id']);
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  // Show success snackbar
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('User ${user['name']} berhasil dihapus'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                  // Refresh the data
                  provider.refreshData();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Gagal menghapus user ${user['name']}'),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Cari username...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
                          const SizedBox(width: 8),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _statusFilter != 'Semua' || _sortOption != 'Uptime (Shortest)'
                      ? Colors.blue.shade800
                      : Colors.grey.shade600,
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
                  ),
                ),
          ),
            ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'PPP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final provider =
                    Provider.of<MikrotikProvider>(context, listen: false);
                await provider.refreshData(forceRefresh: true);
                await _fetchInterfaces(provider.service);
                setState(() {
                  _currentMax = _itemsPerPage;
                });
              },
            ),
          ),
        ],
      ),
      body: Consumer<MikrotikProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          // Fetch interface jika belum
          if (_interfaces.isEmpty && !_loadingInterface) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchInterfaces(provider.service);
            });
          }

          // Set waktu fetch saat data pppSessions berubah
          final dataHash = provider.pppSessions
              .map((e) => (e['name'] ?? '') + (e['uptime'] ?? ''))
              .join(',');
          if (_lastDataHash != dataHash) {
            _lastDataHash = dataHash;
            _fetchTime = DateTime.now();
          }

          // Gabungkan secrets dan active
          final profiles = provider.pppProfiles;
          final activeMap = {for (var s in provider.pppSessions) s['name']: s};
          final users = provider.pppSecrets.map((secret) {
            final session = activeMap[secret['name']];
            final profileInfo = profiles.firstWhere(
              (p) => p['name'] == secret['profile'],
              orElse: () => {},
            );
            return {
              ...secret,
              if (session != null) ...session,
              'isOnline': session != null,
              'profile-info': profileInfo,
            };
          }).toList();

                      // Filtering
                      List<Map<String, dynamic>> filtered = users.where((u) {
                        final q = _searchQuery.toLowerCase();
                        if (_statusFilter == 'Online' && !u['isOnline']) {
                          return false;
                        }
                        if (_statusFilter == 'Offline' && u['isOnline']) {
                          return false;
                        }
                        return (u['name'] ?? '').toLowerCase().contains(q) ||
                            (u['address'] ?? '').toLowerCase().contains(q) ||
                            (u['profile'] ?? '').toLowerCase().contains(q);
                      }).toList();

                      // Sorting
                      switch (_sortOption) {
                        case 'Name (A-Z)':
                          filtered.sort((a, b) =>
                              (a['name'] ?? '').compareTo(b['name'] ?? ''));
                          break;
                        case 'Name (Z-A)':
                          filtered.sort((a, b) =>
                              (b['name'] ?? '').compareTo(a['name'] ?? ''));
                          break;
                        case 'Uptime (Longest)':
                          filtered.sort((a, b) =>
                              _parseFlexibleUptime(b['uptime']).compareTo(
                                  _parseFlexibleUptime(a['uptime'])));
                          break;
                        case 'Uptime (Shortest)':
                          filtered.sort((a, b) =>
                              _parseFlexibleUptime(a['uptime']).compareTo(
                                  _parseFlexibleUptime(b['uptime'])));
                          break;
                        case 'IP Address (A-Z)':
                          filtered.sort((a, b) => (a['address'] ?? '')
                              .compareTo(b['address'] ?? ''));
                          break;
                        case 'IP Address (Z-A)':
                          filtered.sort((a, b) => (b['address'] ?? '')
                              .compareTo(a['address'] ?? ''));
                          break;
                      }

          // Pisahkan offline dan online, sort offline by last-logged-out DESC
          final offline = filtered.where((u) => u['isOnline'] != true).toList();
          final online = filtered.where((u) => u['isOnline'] == true).toList();
          offline.sort((a, b) {
            final aLogout = _parseLogoutDate(a['last-logged-out'] ?? a['last_logout']);
            final bLogout = _parseLogoutDate(b['last-logged-out'] ?? b['last_logout']);
            if (aLogout == null && bLogout == null) return 0;
            if (aLogout == null) return 1;
            if (bLogout == null) return -1;
            return bLogout.compareTo(aLogout); // DESCENDING: terbaru di atas
          });
          final displayList = [...offline, ...online];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _buildSearchBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final provider = Provider.of<MikrotikProvider>(context, listen: false);
                    await provider.refreshData(forceRefresh: true);
                    await _fetchInterfaces(provider.service);
                    setState(() {
                      _currentMax = _itemsPerPage;
                    });
                  },
                  child: Builder(
                    builder: (context) {
                      final filteredTotal = filtered.length;
                      final filteredActive =
                          filtered.where((u) => u['isOnline'] == true).length;
                      final filteredOffline = filteredTotal - filteredActive;
                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              itemCount: displayList.length > _currentMax ? _currentMax + 1 : displayList.length,
                              itemBuilder: (context, i) {
                                if (i == _currentMax && displayList.length > _currentMax) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: CircularProgressIndicator(),
                                  ));
                                }
                                final user = displayList[i];
                                final isOnline = user['isOnline'] == true;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.white
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isOnline
                                          ? Colors.blue.shade200
                                          : Colors.red.shade200,
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    dense: true,
                                    leading: Stack(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isOnline
                                              ? Colors.blue[50]
                                              : Colors.red[50],
                                          radius: 14,
                                          child: Icon(Icons.person,
                                              color: isOnline
                                                  ? Colors.blue[700]
                                                  : Colors.red[400],
                                              size: 16),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: CircleAvatar(
                                            radius: 5,
                                            backgroundColor: Colors.white,
                                            child: Icon(
                                              isOnline
                                                  ? Icons.circle
                                                  : Icons.cancel,
                                              color: isOnline
                                                  ? Colors.green
                                                  : Colors.red,
                                              size: 7,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      user['name'] ?? '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 0.1,
                                        color: isOnline
                                            ? Colors.blue[800]
                                            : Colors.red[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    subtitle: isOnline
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(user['profile'] ?? '-',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue[400]),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1),
                                              const SizedBox(height: 1),
                                              Row(
                                                children: [
                                                  Icon(Icons.location_on,
                                                      size: 11,
                                                      color: Colors.blue[300]),
                                                  const SizedBox(width: 2),
                                                  Flexible(
                                                    child: Text(
                                                        user['address'] ?? '-',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .blue[400]),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.access_time,
                                                      size: 11,
                                                      color: Colors.blue[300]),
                                                  const SizedBox(width: 2),
                                                  Flexible(
                                                    child: Text(
                                                        _getRealtimeUptime(
                                                            user['uptime']),
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .blue[400]),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(user['profile'] ?? '-',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.red[400]),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 1),
                                                child: Text(
                                                    'Last logout: ' +
                                                        formatLastLogout(user['last-logged-out'] ?? user['last_logout']),
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.red[300]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1),
                                              ),
                                            ],
                                          ),
                                    trailing: isOnline
                                        ? (() {
                                            final ifaceName =
                                                'pppoe-${user['name']}';
                                            final iface =
                                                _interfaces.firstWhere(
                                              (iface) => ((iface['name'] ?? '')
                                                      .replaceAll(
                                                          RegExp(r'[<>]'),
                                                          '') ==
                                                  ifaceName),
                                              orElse: () => <String, dynamic>{},
                                            );
                                            final rx = iface['rx-byte'] ?? '0';
                                            final tx = iface['tx-byte'] ?? '0';
                                            return SizedBox(
                                              width: 54,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.topRight,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      _formatBytes(rx),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.blue,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      textAlign:
                                                          TextAlign.right,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      _formatBytes(tx),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      textAlign:
                                                          TextAlign.right,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          })()
                                        : null,
                                    onTap: () => _showUserDetail(context, user),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people,
                                    color: Colors.black54, size: 18),
                                const SizedBox(width: 4),
                                Text('$filteredTotal total',
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 14)),
                                const Text(' | ',
                                    style: TextStyle(fontSize: 14)),
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 4),
                                Text('$filteredActive active',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                const Text(' | ',
                                    style: TextStyle(fontSize: 14)),
                                const Icon(Icons.cancel, color: Colors.red, size: 18),
                                const SizedBox(width: 4),
                                Text('$filteredOffline offline',
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  String _getRealtimeUptime(String? baseUptime) {
    if (baseUptime == null || _fetchTime == null) return '-';
    
    // Parse base uptime ke detik
    final baseSeconds = _parseUptimeToSeconds(baseUptime);
    
    // Hitung selisih waktu sejak terakhir fetch
    final diffSeconds = DateTime.now().difference(_fetchTime!).inSeconds;
    
    // Total uptime dalam detik
    final totalSeconds = baseSeconds + diffSeconds;
    
    // Format hasil
    return _formatUptime(totalSeconds);
  }

  int _parseUptimeToSeconds(String uptime) {
    final regex = RegExp(r'((\d+)w)?((\d+)d)?((\d+)h)?((\d+)m)?((\d+)s)?');
    final match = regex.firstMatch(uptime);
    if (match == null) return 0;
    
    int w = int.tryParse(match.group(2) ?? '') ?? 0;
    int d = int.tryParse(match.group(4) ?? '') ?? 0;
    int h = int.tryParse(match.group(6) ?? '') ?? 0;
    int m = int.tryParse(match.group(8) ?? '') ?? 0;
    int s = int.tryParse(match.group(10) ?? '') ?? 0;
    
    return w * 604800 + d * 86400 + h * 3600 + m * 60 + s;
  }

  String _formatUptime(int seconds) {
    int w = seconds ~/ 604800;
    int d = (seconds % 604800) ~/ 86400;
    int h = (seconds % 86400) ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    
    List<String> parts = [];
    if (w > 0) parts.add('${w}w');
    if (d > 0) parts.add('${d}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0 || parts.isEmpty) parts.add('${s}s');
    
    return parts.join('');
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '-';
    int val = 0;
    try {
      val = int.parse(bytes.toString());
    } catch (_) {
      return '-';
    }
    if (val >= 1073741824) {
      return '${(val / 1073741824).toStringAsFixed(2)} GB';
    } else if (val >= 1048576) {
      return '${(val / 1048576).toStringAsFixed(2)} MB';
    } else if (val >= 1024) {
      return '${(val / 1024).toStringAsFixed(2)} KB';
    } else {
      return '$val B';
    }
  }

  Duration _parseFlexibleUptime(String? uptime) {
    if (uptime == null) return Duration.zero;
    return Duration(seconds: _parseUptimeToSeconds(uptime));
  }

  String formatLastLogout(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'jan/01/1970 00:00:00') return '-';
    const bulanMap = {
      'jan': [1, 'Januari'], 'feb': [2, 'Februari'], 'mar': [3, 'Maret'],
      'apr': [4, 'April'], 'may': [5, 'Mei'], 'jun': [6, 'Juni'],
      'jul': [7, 'Juli'], 'aug': [8, 'Agustus'], 'sep': [9, 'September'],
      'oct': [10, 'Oktober'], 'nov': [11, 'November'], 'dec': [12, 'Desember'],
    };
    const hariMap = [
      'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'
    ];
    try {
      DateTime date;
      String jam = '';
      // Cek format ISO (2025-06-24 16:14:53)
      final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$').firstMatch(dateStr);
      if (isoMatch != null) {
        date = DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
          int.parse(isoMatch.group(4)!),
          int.parse(isoMatch.group(5)!),
          int.parse(isoMatch.group(6)!),
        );
        jam = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      } else {
        // Format Mikrotik: jun/24/2025 00:59:54
        final parts = dateStr.split(' ');
        final tgl = parts[0].split('/');
        final bulanInfo = bulanMap[tgl[0].toLowerCase()];
        if (bulanInfo == null) return dateStr;
        date = DateTime(
          int.parse(tgl[2]),
          bulanInfo[0] as int,
          int.parse(tgl[1]),
          int.parse(parts[1].split(':')[0]),
          int.parse(parts[1].split(':')[1]),
          int.parse(parts[1].split(':')[2]),
        );
        jam = parts[1];
      }
      final hari = hariMap[date.weekday % 7];
      final bulanNama = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ][date.month];
      return '$hari, ${date.day} $bulanNama ${date.year} $jam';
    } catch (_) {
      return dateStr;
    }
  }

  DateTime? _parseLogoutDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'jan/01/1970 00:00:00') return null;
    try {
      // ISO format: 2025-06-24 16:14:53
      final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$').firstMatch(dateStr);
      if (isoMatch != null) {
        return DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
          int.parse(isoMatch.group(4)!),
          int.parse(isoMatch.group(5)!),
          int.parse(isoMatch.group(6)!),
        );
      } else {
        // Mikrotik format: jun/24/2025 00:59:54
        final parts = dateStr.split(' ');
        final tgl = parts[0].split('/');
        const bulanMap = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        final bulan = bulanMap[tgl[0].toLowerCase()];
        if (bulan == null) return null;
        return DateTime(
          int.parse(tgl[2]),
          bulan,
          int.parse(tgl[1]),
          int.parse(parts[1].split(':')[0]),
          int.parse(parts[1].split(':')[1]),
          int.parse(parts[1].split(':')[2]),
        );
      }
    } catch (_) {
      return null;
    }
  }
}
