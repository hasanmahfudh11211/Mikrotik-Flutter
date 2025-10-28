import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';

class PPPProfilePage extends StatefulWidget {
  const PPPProfilePage({super.key});

  @override
  State<PPPProfilePage> createState() => _PPPProfilePageState();
}

class _PPPProfilePageState extends State<PPPProfilePage> {
  String _searchQuery = '';
  String _sortBy = 'Name (A-Z)';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Rate Limit (Highest)',
    'Rate Limit (Lowest)',
  ];

  // Helper function to convert rate to bytes
  int _convertToBytes(String rate) {
    if (rate.isEmpty) return 0;
    
    // Handle k and M suffixes
    int multiplier = 1;
    if (rate.endsWith('k')) {
      multiplier = 1024;
      rate = rate.substring(0, rate.length - 1);
    } else if (rate.endsWith('M')) {
      multiplier = 1024 * 1024;
      rate = rate.substring(0, rate.length - 1);
    }
    
    return (int.tryParse(rate) ?? 0) * multiplier;
  }

  // Helper function to get rate limit value for sorting
  int _getRateLimitValue(String rateLimit) {
    if (rateLimit == '-') return 0;
    
    // Get the first part before the space (e.g., "2M/2M" from "2M/2M 0/0 0/0 10/10 8 1024k/1024k")
    final firstPart = rateLimit.split(' ').first;
    
    // Split by '/' and get the first rate (upload rate)
    final rates = firstPart.split('/');
    if (rates.isEmpty) return 0;
    
    // Convert the rate to bytes for comparison
    return _convertToBytes(rates[0]);
  }

  List<Map<String, dynamic>> _sortProfiles(List<Map<String, dynamic>> profiles) {
    switch (_sortBy) {
      case 'Name (A-Z)':
        return List.from(profiles)
          ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      case 'Name (Z-A)':
        return List.from(profiles)
          ..sort((a, b) => (b['name'] ?? '').toString().compareTo((a['name'] ?? '').toString()));
      case 'Rate Limit (Highest)':
        return List.from(profiles)
          ..sort((a, b) {
            final aLimit = (a['rate-limit'] ?? '-').toString();
            final bLimit = (b['rate-limit'] ?? '-').toString();
            // If either is '-', put it at the end
            if (aLimit == '-') return 1;
            if (bLimit == '-') return -1;
            return _getRateLimitValue(bLimit).compareTo(_getRateLimitValue(aLimit));
          });
      case 'Rate Limit (Lowest)':
        return List.from(profiles)
          ..sort((a, b) {
            final aLimit = (a['rate-limit'] ?? '-').toString();
            final bLimit = (b['rate-limit'] ?? '-').toString();
            // If either is '-', put it at the end
            if (aLimit == '-') return 1;
            if (bLimit == '-') return -1;
            return _getRateLimitValue(aLimit).compareTo(_getRateLimitValue(bLimit));
          });
      default:
        return profiles;
    }
  }

  List<Map<String, dynamic>> _filterProfiles(List<Map<String, dynamic>> profiles) {
    if (_searchQuery.isEmpty) return profiles;
    
    return profiles.where((profile) {
      final name = profile['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  _sortOptions.length,
                  (index) => ListTile(
                    title: Text(_sortOptions[index]),
                    trailing: _sortBy == _sortOptions[index]
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _sortBy = _sortOptions[index]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'PPP Profiles',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final provider = context.read<MikrotikProvider>();
                provider.refreshData();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search profiles...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _showSortMenu,
                      color: Colors.grey.shade600,
                      iconSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            // List View
            Expanded(
              child: Consumer<MikrotikProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final profiles = provider.pppProfiles;

                  final filteredProfiles = _filterProfiles(profiles);
                  final sortedProfiles = _sortProfiles(filteredProfiles);

                  if (sortedProfiles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty ? Icons.account_box_outlined : Icons.search_off,
                            size: 64, 
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                                ? 'No PPP Profiles found'
                                : 'No matching profiles found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedProfiles.length,
                    itemBuilder: (context, index) {
                      final profile = sortedProfiles[index];
                      final isDefault = profile['default'] == 'true';
                      final isIsolir = profile['name']?.toString().toUpperCase() == 'ISOLIR';
                      final rateLimit = profile['rate-limit']?.toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _showProfileDetail(context, profile),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isIsolir 
                                    ? Colors.red 
                                    : isDefault 
                                      ? Colors.blue 
                                      : Colors.orange,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isIsolir 
                                          ? Icons.block_outlined
                                          : isDefault 
                                            ? Icons.verified_outlined
                                            : Icons.wifi,
                                        size: 20,
                                        color: isIsolir 
                                          ? Colors.red
                                          : isDefault 
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          profile['name']?.toString() ?? 'Unnamed Profile',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rateLimit != null && rateLimit != '-') ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.speed_rounded,
                                            size: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            rateLimit,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

  void _showProfileDetail(BuildContext context, Map<String, dynamic> profile) {
    final isDefault = profile['default'] == 'true';
    final isIsolir = profile['name']?.toString().toUpperCase() == 'ISOLIR';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isIsolir 
                              ? Colors.red.shade50
                              : isDefault 
                                ? Colors.blue.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isIsolir 
                              ? Icons.block_outlined
                              : isDefault 
                                ? Icons.verified_outlined
                                : Icons.wifi,
                            size: 24,
                            color: isIsolir 
                              ? Colors.red
                              : isDefault 
                                ? Colors.blue
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['name']?.toString() ?? 'Unnamed Profile',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Default Profile',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Rate Limit Section
                    if (profile['rate-limit'] != null) ...[
                      _buildDetailSection(
                        'Rate Limit',
                        [
                          _buildDetailRow(
                            Icons.speed,
                            profile['rate-limit']?.toString() ?? '-',
                            isHighlighted: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Network Settings Section
                    _buildDetailSection(
                      'Network Settings',
                      [
                        _buildDetailRow(
                          Icons.router,
                          'Local Address',
                          value: profile['local-address']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.public,
                          'Remote Address',
                          value: profile['remote-address']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.dns,
                          'DNS Server',
                          value: profile['dns-server']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.dns_outlined,
                          'WINS Server',
                          value: profile['wins-server']?.toString() ?? '-',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Additional Settings Section
                    _buildDetailSection(
                      'Additional Settings',
                      [
                        _buildDetailRow(
                          Icons.settings_ethernet,
                          'Bridge',
                          value: profile['bridge']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.sync_alt,
                          'Bridge Learning',
                          value: profile['bridge-learning']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.speed,
                          'Change TCP MSS',
                          value: profile['change-tcp-mss']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.language,
                          'Use IPv6',
                          value: profile['use-ipv6']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          Icons.person_outline,
                          'Only One',
                          value: profile['only-one']?.toString() ?? '-',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, {String? value, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted 
                ? Colors.blue.shade50 
                : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isHighlighted 
                ? Colors.blue 
                : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: value == null
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isHighlighted 
                      ? Colors.blue.shade700 
                      : Colors.black87,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
} 