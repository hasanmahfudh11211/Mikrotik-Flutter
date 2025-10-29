import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';
import '../services/router_image_service.dart';
import '../services/router_image_service_simple.dart';
import '../main.dart';
import 'dart:async';

class SystemResourceScreen extends StatefulWidget {
  const SystemResourceScreen({Key? key}) : super(key: key);

  @override
  State<SystemResourceScreen> createState() => _SystemResourceScreenState();
}

class _SystemResourceScreenState extends State<SystemResourceScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Force refresh data immediately on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MikrotikProvider>();
      provider.refreshData(forceRefresh: true);
    });
    
    // Auto-refresh every 3 seconds for realtime data
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<MikrotikProvider>();
      if (!provider.isLoading) {
        // Force refresh to get realtime data
        provider.refreshData(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildResourceCard(String title, String value, IconData icon, bool isDark) {
    return Card(
      elevation: isDark ? 2 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.blue[200] : Colors.blue[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouterImage(String? boardName, bool isDark) {
    final displayName = RouterImageService.getRouterDisplayName(boardName);
    
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Router Image with Future Builder
            Container(
              width: double.infinity,
              height: double.infinity,
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              child: FutureBuilder<String>(
                future: RouterImageServiceSimple.getRouterImageUrl(boardName),
                builder: (context, snapshot) {
                  print('SystemResourceScreen: FutureBuilder snapshot state: ${snapshot.connectionState}');
                  print('SystemResourceScreen: FutureBuilder hasData: ${snapshot.hasData}');
                  print('SystemResourceScreen: FutureBuilder data: ${snapshot.data}');
                  print('SystemResourceScreen: FutureBuilder error: ${snapshot.error}');
                
                  if (snapshot.hasError) {
                    print('SystemResourceScreen: Error loading router image: ${snapshot.error}');
                    // Show default.png when there's an error
                    return _buildCachedImage('assets/mikrotik_product_images/default.png', isDark, isAsset: true);
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    print('SystemResourceScreen: Loading router image...');
                    return Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: isDark ? Colors.blue[200] : Colors.blue[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading image...',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    print('SystemResourceScreen: Loading image with URL: ${snapshot.data}');
                    return _buildCachedImage(snapshot.data!, isDark);
                  } else {
                    print('SystemResourceScreen: No data or empty data, showing default image');
                    // Show default.png when no data is available
                    return _buildCachedImage('assets/mikrotik_product_images/default.png', isDark, isAsset: true);
                  }
                },
              ),
            ),
            // Router Name Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedImage(String imageUrl, bool isDark, {bool isAsset = false}) {
    if (isAsset) {
      // Handle asset images
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('SystemResourceScreen: Error loading asset image: $error');
          // Fallback to icon if asset also fails
          return Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.router,
                  size: 80,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    
    // Handle network images
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isDark ? Colors.blue[200] : Colors.blue[600],
              ),
              const SizedBox(height: 8),
              Text(
                'Loading image...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('SystemResourceScreen: Error loading cached image: $error');
        // Show default.png when network image fails
        return _buildCachedImage('assets/mikrotik_product_images/default.png', isDark, isAsset: true);
      },
    );
  }

  Widget _buildSystemOverview(Map<String, dynamic> resource, String identity, bool isDark) {
    return Card(
      elevation: isDark ? 2 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.router,
                    color: isDark ? Colors.blue[200] : Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'System Identity',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    resource['board-name'] ?? '-',
                    'Board Name',
                    Icons.developer_board,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetric(
                    resource['cpu-load'] != null ? '${resource['cpu-load']}%' : '0%',
                    'CPU Load',
                    Icons.speed,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    resource['cpu-count']?.toString() ?? '-',
                    'CPU Count',
                    Icons.confirmation_number,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetric(
                    resource['cpu-frequency'] != null ? '${resource['cpu-frequency']} MHz' : '-',
                    'CPU Frequency',
                    Icons.memory,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String value, String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isDark ? Colors.blue[200] : Colors.blue[600],
            size: 20,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMetricsRow(
    String value1, String label1, IconData icon1,
    String value2, String label2, IconData icon2,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetric(value1, label1, icon1, isDark),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetric(value2, label2, icon2, isDark),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('System Resource'),
          backgroundColor: Colors.transparent,
          elevation: 0,
      ),
      body: Consumer<MikrotikProvider>(
        builder: (context, provider, _) {
          final resource = provider.resource ?? {};
            final identity = provider.identity ?? 'RouterOS';

          return ListView(
              padding: const EdgeInsets.all(16),
            children: [
                // Router Image at the top
                _buildRouterImage(resource['board-name'], isDark),
                _buildSystemOverview(resource, identity, isDark),
                const SizedBox(height: 20),
                Text(
                  'System Details',
                    style: TextStyle(
                    fontSize: 18,
                        fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
              ),
                const SizedBox(height: 12),
                _buildResourceCard('Platform', resource['platform'] ?? '-', Icons.devices, isDark),
                _buildResourceCard('Uptime', resource['uptime'] ?? '-', Icons.access_time, isDark),
                _buildResourceCard('Version', resource['version'] ?? '-', Icons.verified, isDark),
                _buildResourceCard('Architecture', resource['architecture-name'] ?? '-', Icons.architecture, isDark),
                _buildResourceCard('CPU Model', resource['cpu'] ?? '-', Icons.memory, isDark),
                _buildResourceCard(
                  'Free Memory',
                  _formatMemory(resource['free-memory']),
                  Icons.sd_storage,
                  isDark,
                ),
                _buildResourceCard(
                  'Total Memory',
                  _formatMemory(resource['total-memory']),
                  Icons.sd_storage,
                  isDark,
                    ),
                _buildResourceCard(
                  'Free HDD Space',
                  _formatMemory(resource['free-hdd-space']),
                  Icons.storage,
                  isDark,
                    ),
                _buildResourceCard(
                  'Total HDD Space',
                  _formatMemory(resource['total-hdd-space']),
                  Icons.storage,
                  isDark,
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

String _formatMemory(dynamic bytes) {
  if (bytes == null) return '-';
  double gb = int.parse(bytes.toString()) / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(1)} GiB';
}