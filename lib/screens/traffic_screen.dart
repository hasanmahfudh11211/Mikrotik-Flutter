import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/gradient_container.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({Key? key}) : super(key: key);

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  Timer? _timer;
  Map<String, dynamic>? _trafficData;
  String? _selectedInterfaceId;
  List<Map<String, dynamic>> _interfaces = [];
  Map<String, dynamic>? _selectedInterface;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInterfaces() async {
    final provider = Provider.of<MikrotikProvider>(context, listen: false);
    try {
      final interfaces = await provider.service.getInterface();
      setState(() {
        _interfaces = interfaces;
        if (interfaces.isNotEmpty) {
          _selectedInterfaceId = interfaces.first['.id'];
          _selectedInterface = interfaces.first;
          _startPolling();
        }
      });
    } catch (e) {
      debugPrint('Error loading interfaces: $e');
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchTrafficData();
    // Reduced polling frequency to prevent battery drain and memory leaks
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchTrafficData();
    });
  }

  Future<void> _fetchTrafficData() async {
    if (_selectedInterfaceId == null) return;
    
    final provider = Provider.of<MikrotikProvider>(context, listen: false);
    try {
      final trafficData = await provider.service.getTraffic(_selectedInterfaceId!);
      setState(() {
        _trafficData = trafficData;
      });
    } catch (e) {
      debugPrint('Error fetching traffic data: $e');
    }
  }

  String _formatRate(double rate) {
    if (rate < 1) {
      return '${(rate * 1000).toStringAsFixed(1)}';
    }
    return '${rate.toStringAsFixed(1)}';
  }

  String _formatRateUnit(double rate) {
    if (rate < 1) {
      return 'Kbps';
    }
    return 'Mbps';
  }

  String _formatPacketRate(int rate) {
    return '$rate p/s';
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Traffic Monitor'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main Card containing all content
                Card(
                  elevation: 0,
                  color: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Interface Selector
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedInterfaceId,
                              hint: const Text('Select Interface'),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              items: _interfaces.map((interface) {
                                return DropdownMenuItem<String>(
                                  value: interface['.id'],
                                  child: Text(
                                    interface['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedInterfaceId = newValue;
                                  _selectedInterface = _interfaces.firstWhere(
                                    (interface) => interface['.id'] == newValue,
                                    orElse: () => {},
                                  );
                                  _startPolling();
                                });
                              },
                            ),
                          ),
                        ),
                        if (_trafficData != null && _selectedInterface != null) ...[
                          const SizedBox(height: 16),
                          // Status Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedInterface!['running'] == "true"
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: _selectedInterface!['running'] == "true"
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedInterface!['running'] == "true"
                                      ? "Running"
                                      : "Stopped",
                                  style: TextStyle(
                                    color: _selectedInterface!['running'] == "true"
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Traffic Rate Display
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildRateInfo(
                                    'TX Rate',
                                    _formatRate(_trafficData!['tx-rate']),
                                    _formatRateUnit(_trafficData!['tx-rate']),
                                    _formatPacketRate(_trafficData!['tx-packet-rate']),
                                    Colors.deepOrange,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: VerticalDivider(
                                    color: Colors.grey[300],
                                    thickness: 1,
                                    indent: 10,
                                    endIndent: 10,
                                  ),
                                ),
                                Expanded(
                                  child: _buildRateInfo(
                                    'RX Rate',
                                    _formatRate(_trafficData!['rx-rate']),
                                    _formatRateUnit(_trafficData!['rx-rate']),
                                    _formatPacketRate(_trafficData!['rx-packet-rate']),
                                    Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(height: 1),
                          ),
                          // Interface Details
                          const Text(
                            'Interface Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Name', _selectedInterface!['name'] ?? '-'),
                          _buildDetailRow('Type', _selectedInterface!['type'] ?? '-'),
                          _buildDetailRow('MAC Address', _selectedInterface!['mac-address'] ?? '-'),
                          _buildDetailRow('MTU', _selectedInterface!['mtu'] ?? '-'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          // Total Traffic
                          const Text(
                            'Total Traffic',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Total TX', _formatBytes(_trafficData!['total-tx-byte']), isTotal: true),
                          _buildDetailRow('Total RX', _formatBytes(_trafficData!['total-rx-byte']), isTotal: true),
                          _buildDetailRow('TX Packets', _formatPackets(_trafficData!['total-tx-packet'])),
                          _buildDetailRow('RX Packets', _formatPackets(_trafficData!['total-rx-packet'])),
                        ] else ...[
                          const SizedBox(height: 100),
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ],
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

  Widget _buildRateInfo(String label, String rate, String unit, String packetRate, MaterialColor color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rate,
                style: TextStyle(
                  color: color,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          packetRate,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 15 : 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(String? bytes) {
    if (bytes == null) return '0 B';
    double byte = double.tryParse(bytes) ?? 0;
    
    // Convert to TB
    if (byte >= 1099511627776) {  // 1024^4
      double tb = byte / 1099511627776;
      return '${tb.toStringAsFixed(2)} TB';
    }

    // Convert to GB
    if (byte >= 1073741824) {  // 1024^3
      double gb = byte / 1073741824;
      // Jika lebih dari 100 GB, bulatkan ke GB terdekat
      if (gb >= 100) {
        return '${gb.round()} GB';
      }
      // Jika lebih dari 10 GB, gunakan 1 desimal
      if (gb >= 10) {
        return '${gb.toStringAsFixed(1)} GB';
      }
      // Dibawah 10 GB, gunakan 2 desimal
      return '${gb.toStringAsFixed(2)} GB';
    }
    
    // Convert to MB
    if (byte >= 1048576) {  // 1024^2
      double mb = byte / 1048576;
      // Jika lebih dari 100 MB, bulatkan ke MB terdekat
      if (mb >= 100) {
        return '${mb.round()} MB';
      }
      return '${mb.toStringAsFixed(1)} MB';
    }
    
    // Convert to KB
    if (byte >= 1024) {
      double kb = byte / 1024;
      if (kb >= 100) {
        return '${kb.round()} KB';
      }
      return '${kb.toStringAsFixed(1)} KB';
    }
    
    // Bytes
    return '${byte.round()} B';
  }

  String _formatPackets(String? packets) {
    if (packets == null) return '0';
    final num = double.tryParse(packets) ?? 0;
    
    // Convert to billions
    if (num >= 1000000000) {
      return '${(num / 1000000000).toStringAsFixed(2)}B';
    }
    
    // Convert to millions
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(2)}M';
    }
    
    // Convert to thousands
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(2)}K';
    }
    
    return num.round().toString();
  }
} 