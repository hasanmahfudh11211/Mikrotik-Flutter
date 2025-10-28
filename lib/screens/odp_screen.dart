import 'package:flutter/material.dart';
import '../widgets/gradient_container.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'tambah_odp_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ODPScreen extends StatefulWidget {
  const ODPScreen({Key? key}) : super(key: key);

  @override
  State<ODPScreen> createState() => _ODPScreenState();
}

class _ODPScreenState extends State<ODPScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _odpList = [];
  String _sortOrder = 'name_asc';
  String? _selectedType;
  
  // Filter options
  String _filterType = 'all'; // 'all', 'splitter', 'ratio'
  String _sortBy = 'name'; // 'name', 'type'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    setState(() => _isLoading = true);
    _loadODPList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadODPList() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/odp_operations.php'),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _odpList = List<Map<String, dynamic>>.from(data['odp_list']);
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Failed to load ODP list');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCopyOpenMapsDialog(String mapsLink) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text('Link Maps', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: SelectableText(
                mapsLink,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Salin'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mapsLink));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Link berhasil disalin!'),
                            backgroundColor: Colors.green),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Image.asset('assets/pngimg.com - google_maps_pin_PNG26.png', width: 20, height: 20),
                    label: const Text('Buka'),
                    onPressed: () {
                      Navigator.pop(context);
                      _launchMapsUrl(mapsLink);
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        titlePadding: const EdgeInsets.only(top: 24),
        actionsPadding: EdgeInsets.zero,
      ),
    );
  }

  // Fungsi untuk mengambil user berdasarkan ODP ID
  Future<List<dynamic>> _fetchUsersForOdp(int odpId) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/get_all_users.php?odp_id=$odpId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<dynamic>.from(data['users']);
      }
    }
    throw Exception('Gagal memuat pengguna');
  }

  void _showODPDetail(Map<String, dynamic> odp) {
    final type = odp['type']?.toString() ?? '';
    final name = odp['name']?.toString() ?? '';
    final location = odp['location']?.toString() ?? '';
    final mapsLink = odp['maps_link']?.toString();
    final splitterType = odp['splitter_type']?.toString() ?? '';
    final ratioUsed = odp['ratio_used']?.toString() ?? '0';
    final ratioTotal = odp['ratio_total']?.toString() ?? '0';
    final config = type == 'splitter'
        ? 'Splitter $splitterType'
        : 'Ratio $ratioUsed/$ratioTotal';
    final odpId = int.tryParse(odp['id'].toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                  children: [
                    Icon(
                      type == 'splitter' ? Icons.call_split : Icons.percent,
                      color: type == 'splitter' ? Colors.blue.shade700 : Colors.orange.shade700,
                        size: 32,
                    ),
                      const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(location, style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                          ],
                      ),
                    ),
                  ],
                ),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
                // User List
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: odpId != null ? _fetchUsersForOdp(odpId) : Future.value([]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final users = snapshot.data ?? [];
                      return ListView(
                        controller: controller,
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Text(
                              '${users.length} Pengguna Terhubung',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          if (users.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              child: Center(
                                child: Text('Belum ada pengguna yang terhubung.', style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(user['username'] ?? 'N/A'),
                                  subtitle: Text(user['profile'] ?? 'N/A'),
                                );
                              },
                            ),
                          const Divider(height: 1),
                          // Detail ODP lainnya jika perlu
                          _buildDetailRow(context, 'Konfigurasi', config),
                          if (mapsLink != null && mapsLink.isNotEmpty)
                            _buildDetailRow(context, 'Link Maps', mapsLink, isLink: true, onTap: () => _showCopyOpenMapsDialog(mapsLink)),
                ],
                      );
                    },
                  ),
                ),
                // Buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('HAPUS'),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteODP(odp);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('EDIT'),
                        onPressed: () {
                          Navigator.pop(context);
                          _editODP(odp);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String title, String value, {bool isLink = false, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: InkWell(
          onTap: onTap,
                  child: Text(
                    value,
                    style: TextStyle(
            color: isLink ? Theme.of(context).primaryColor : null,
                      decoration: isLink ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
    );
  }

  Future<void> _editODP(Map<String, dynamic> odp) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TambahODPScreen(odpToEdit: odp),
      ),
    );
    if (result == true) {
      setState(() => _isLoading = true);
      _loadODPList();
    }
  }

  Future<void> _deleteODP(Map<String, dynamic> odp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Konfirmasi Hapus'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus ODP ${odp['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
  try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/odp_operations.php?operation=delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': odp['id']}),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ODP berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        _loadODPList();
      } else {
        throw Exception(data['error'] ?? 'Gagal menghapus ODP');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchMapsUrl(String? url) async {
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link maps tidak tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi untuk ekstrak prefix dan angka dari nama ODP (regex benar, satu backslash)
  Map<String, dynamic> extractOdpPrefixAndNumber(String odpName) {
    final regex = RegExp(r'^(.*?)(\d+)$');
    final match = regex.firstMatch(odpName.trim());
  if (match != null) {
      return {
        'prefix': match.group(1)!.trim().toLowerCase(),
        'number': int.parse(match.group(2)!),
      };
    }
    return {
      'prefix': odpName.trim().toLowerCase(),
      'number': null,
    };
  }

  List<Map<String, dynamic>> _getFilteredAndSortedList() {
    var filteredList = _odpList.where((odp) {
      final searchTerm = _searchController.text.toLowerCase();
      final name = (odp['name'] ?? '').toString().toLowerCase();
      final location = (odp['location'] ?? '').toString().toLowerCase();
      final type = (odp['type'] ?? '').toString().toLowerCase();

      final matchesSearch = name.contains(searchTerm) || 
                          location.contains(searchTerm) ||
                          type.contains(searchTerm);

      if (_selectedType == null || _selectedType == 'all') {
        return matchesSearch;
      }
      return matchesSearch && type == _selectedType;
    }).toList();

    
    // Sort the list berdasarkan prefix lalu angka
    filteredList.sort((a, b) {
      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();

      final aData = extractOdpPrefixAndNumber(aName);
      final bData = extractOdpPrefixAndNumber(bName);

      // Urutkan berdasarkan prefix dulu
      final prefixCompare = aData['prefix'].compareTo(bData['prefix']);
      if (prefixCompare != 0) return _sortOrder == 'name_asc' ? prefixCompare : -prefixCompare;

      // Jika prefix sama dan ada angka, urutkan berdasarkan angka
      final aNum = aData['number'];
      final bNum = bData['number'];
      if (aNum != null && bNum != null) {
        return _sortOrder == 'name_asc' ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
      }
      // Jika hanya salah satu yang ada angka, yang ada angka di atas
      if (aNum != null) return -1;
      if (bNum != null) return 1;

      // Jika tidak ada angka, urutkan alfabet
      return _sortOrder == 'name_asc' 
          ? aName.toLowerCase().compareTo(bName.toLowerCase())
          : bName.toLowerCase().compareTo(aName.toLowerCase());
    });

    return filteredList;
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Filter & Urutkan',
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text('Urutkan Berdasarkan', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        CheckedPopupMenuItem(
          value: 'sort_name_asc',
          checked: _sortOrder == 'name_asc',
          child: const Text('Nama (A-Z)'),
        ),
        CheckedPopupMenuItem(
          value: 'sort_name_desc',
          checked: _sortOrder == 'name_desc',
          child: const Text('Nama (Z-A)'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text('Filter Tipe', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        CheckedPopupMenuItem(
          value: 'filter_all',
          checked: _selectedType == null || _selectedType == 'all',
          child: const Text('Semua Tipe'),
        ),
        CheckedPopupMenuItem(
          value: 'filter_splitter',
          checked: _selectedType == 'splitter',
          child: const Text('Hanya Splitter'),
        ),
        CheckedPopupMenuItem(
          value: 'filter_ratio',
          checked: _selectedType == 'ratio',
          child: const Text('Hanya Ratio'),
        ),
      ],
      onSelected: (value) {
        setState(() {
          if (value.startsWith('sort_')) {
            _sortOrder = value.split('_').sublist(1).join('_');
          } else if (value.startsWith('filter_')) {
            _selectedType = value.split('_')[1];
          }
        });
      },
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAndSortedList = _getFilteredAndSortedList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalCount = filteredAndSortedList.length;
    final splitterCount = filteredAndSortedList.where((odp) => odp['type'] == 'splitter').length;
    final ratioCount = totalCount - splitterCount;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Manajemen ODP'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, size: 28),
              tooltip: 'Tambah ODP',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TambahODPScreen()),
                );
                if (result == true) {
                  setState(() => _isLoading = true);
                  _loadODPList();
                }
              },
            ),
            _buildMenuButton(),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari ODP...',
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ),

            // ODP List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => _isLoading = true);
                  await _loadODPList();
                },
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredAndSortedList.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada ODP yang ditemukan',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  itemCount: filteredAndSortedList.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final odp = filteredAndSortedList[index];
                                    final type = odp['type']?.toString() ?? '';
                                    final name = odp['name']?.toString() ?? '';
                                    final location = odp['location']?.toString() ?? '';
                                    final mapsLink = odp['maps_link']?.toString();
                                    final splitterType = odp['splitter_type']?.toString() ?? '';
                                    final ratioUsed = odp['ratio_used']?.toString() ?? '0';
                                    final ratioTotal = odp['ratio_total']?.toString() ?? '0';

                                    return GestureDetector(
                                      onTap: () => _showODPDetail(odp),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        child: Card(
                                          elevation: 1,
                                          margin: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: type == 'splitter'
                                                      ? Colors.blue.shade50
                                                      : Colors.orange.shade50,
                                                  child: Icon(
                                                    type == 'splitter' ? Icons.call_split : Icons.percent,
                                                    color: type == 'splitter' ? Colors.blue.shade700 : Colors.orange.shade700,
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        location,
                                                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (mapsLink?.isNotEmpty == true) ...[
                                                        const SizedBox(height: 4),
                                                        GestureDetector(
                                                          onTap: () => _showCopyOpenMapsDialog(mapsLink!),
                                                          child: Row(
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              Image.asset(
                                                                'assets/pngimg.com - google_maps_pin_PNG26.png',
                                                                width: 16,
                                                                height: 16,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  mapsLink!,
                                                                  style: const TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.blue,
                                                                    decoration: TextDecoration.underline,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                // Tambahan konfigurasi di kanan
                                                if (type == 'splitter' || type == 'ratio')
                                                Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                      color: type == 'splitter' ? Colors.blue.shade100 : Colors.orange.shade100,
                                                      borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Text(
                                                    type == 'splitter'
                                                        ? splitterType
                                                        : '$ratioUsed/$ratioTotal',
                                                    style: TextStyle(
                                                        color: type == 'splitter' ? Colors.blue.shade800 : Colors.orange.shade800,
                                                      fontWeight: FontWeight.bold,
                                                        fontSize: 13,
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
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _buildStatItem(Icons.device_hub, '$totalCount ODP', Colors.green.shade700),
                                    if (splitterCount > 0 && ratioCount > 0) ...[
                                      const Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                      _buildStatItem(Icons.call_split, '$splitterCount Splitter', Colors.blue.shade700),
                                      const Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                      _buildStatItem(Icons.percent, '$ratioCount Ratio', Colors.orange.shade700),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final totalSplitter = _odpList.where((odp) => odp['type'] == 'splitter').length;
    final totalRatio = _odpList.where((odp) => odp['type'] == 'ratio').length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline, color: Colors.blueGrey.shade700, size: 18),
        const SizedBox(width: 4),
        Text('${_odpList.length} ODP', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Text('•', style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(width: 12),
        Icon(Icons.call_split, color: Colors.blue.shade700, size: 18),
        const SizedBox(width: 4),
        Text('$totalSplitter Splitter', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Text('•', style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(width: 12),
        Icon(Icons.percent, color: Colors.orange.shade700, size: 18),
        const SizedBox(width: 4),
        Text('$totalRatio Ratio', style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
} 