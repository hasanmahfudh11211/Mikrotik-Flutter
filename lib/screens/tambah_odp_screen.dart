import 'package:flutter/material.dart';
import '../widgets/gradient_container.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class TambahODPScreen extends StatefulWidget {
  final Map<String, dynamic>? odpToEdit;
  
  const TambahODPScreen({
    Key? key,
    this.odpToEdit,
  }) : super(key: key);

  @override
  State<TambahODPScreen> createState() => _TambahODPScreenState();
}

class _TambahODPScreenState extends State<TambahODPScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  String _selectedType = 'splitter';
  String _selectedSplitterType = '1:8';
  final _ratioUsedController = TextEditingController();
  final _ratioTotalController = TextEditingController();
  bool _isLoading = false;
  bool _isUpdatingFromListener = false;

  @override
  void initState() {
    super.initState();
    if (widget.odpToEdit != null) {
      // Populate form with existing data
      _nameController.text = widget.odpToEdit!['name'].toString();
      _locationController.text = widget.odpToEdit!['location'].toString();
      _mapsLinkController.text = widget.odpToEdit!['maps_link']?.toString() ?? '';
      _selectedType = widget.odpToEdit!['type'].toString();
      if (_selectedType == 'splitter') {
        _selectedSplitterType = widget.odpToEdit!['splitter_type'].toString();
      } else {
        _ratioUsedController.text = widget.odpToEdit!['ratio_used'].toString();
        _ratioTotalController.text = widget.odpToEdit!['ratio_total'].toString();
      }
    }
    _ratioUsedController.addListener(_onRatioUsedChanged);
  }

  void _onRatioUsedChanged() {
    if (_isUpdatingFromListener) return;

    final usedValue = int.tryParse(_ratioUsedController.text);
    if (usedValue != null && usedValue >= 0 && usedValue <= 100) {
      final totalValue = 100 - usedValue;
      _isUpdatingFromListener = true;
      _ratioTotalController.text = totalValue.toString();
      _isUpdatingFromListener = false;
    } else if (_ratioUsedController.text.isEmpty) {
      _isUpdatingFromListener = true;
      _ratioTotalController.text = '';
      _isUpdatingFromListener = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _mapsLinkController.dispose();
    _ratioUsedController.removeListener(_onRatioUsedChanged);
    _ratioUsedController.dispose();
    _ratioTotalController.dispose();
    super.dispose();
  }

  Future<void> _saveODP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'name': _nameController.text,
        'location': _locationController.text,
        'maps_link': _mapsLinkController.text,
        'type': _selectedType,
      };

      if (_selectedType == 'splitter') {
        data['splitter_type'] = _selectedSplitterType;
      } else {
        // Safe parsing to prevent null pointer exceptions
        final ratioUsedText = _ratioUsedController.text.trim();
        final ratioTotalText = _ratioTotalController.text.trim();
        
        if (ratioUsedText.isNotEmpty && ratioTotalText.isNotEmpty) {
          data['ratio_used'] = int.tryParse(ratioUsedText) ?? 0;
          data['ratio_total'] = int.tryParse(ratioTotalText) ?? 0;
        } else {
          throw Exception('Ratio values cannot be empty');
        }
      }

      if (widget.odpToEdit != null) {
        data['id'] = widget.odpToEdit!['id'];
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/odp_operations.php?operation=${widget.odpToEdit != null ? 'update' : 'add'}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // Save response status: ${response.statusCode}
      // Save response body: ${response.body}

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      if (responseData['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ODP berhasil ${widget.odpToEdit != null ? 'diperbarui' : 'ditambahkan'}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(responseData['error'] ?? 'Gagal menyimpan ODP');
      }
    } catch (e) {
      // Error saving ODP: ${e.toString()}
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

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.odpToEdit != null ? 'Edit ODP' : 'Tambah ODP',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.odpToEdit != null) ...[
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nama ODP: ${widget.odpToEdit!['name']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lokasi: ${widget.odpToEdit!['location']}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama ODP',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama ODP harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Lokasi',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lokasi harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mapsLinkController,
                          decoration: const InputDecoration(
                            labelText: 'Link Google Maps',
                            hintText: 'https://maps.google.com/...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Link Google Maps harus diisi';
                            }
                            if (!Uri.parse(value).isAbsolute) {
                               return 'Masukkan URL yang valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Tipe ODP',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'splitter',
                              child: Text('Splitter'),
                            ),
                            DropdownMenuItem(
                              value: 'ratio',
                              child: Text('Ratio'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedType = value!);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tipe ODP harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_selectedType == 'splitter')
                          DropdownButtonFormField<String>(
                            value: _selectedSplitterType,
                            decoration: const InputDecoration(
                              labelText: 'Tipe Splitter',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: '1:2', child: Text('1:2')),
                              DropdownMenuItem(value: '1:4', child: Text('1:4')),
                              DropdownMenuItem(value: '1:8', child: Text('1:8')),
                              DropdownMenuItem(value: '1:16', child: Text('1:16')),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedSplitterType = value!);
                            },
                            validator: (value) {
                              if (_selectedType == 'splitter' && (value == null || value.isEmpty)) {
                                return 'Tipe Splitter harus dipilih';
                              }
                              return null;
                            },
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ratioUsedController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ratio 1',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_selectedType == 'ratio') {
                                      if (value == null || value.isEmpty) {
                                        return 'Ratio terpakai harus diisi';
                                      }
                                      final number = int.tryParse(value);
                                      if (number == null || number < 0 || number > 100) {
                                        return 'Masukkan angka 0-100';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _ratioTotalController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: 'Ratio 2',
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                    ),
                                    fillColor: Colors.grey[200],
                                    filled: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_selectedType == 'ratio') {
                                      if (value == null || value.isEmpty) {
                                        return 'Isi dari kiri';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveODP,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isLoading
                      ? 'MENYIMPAN...'
                      : (widget.odpToEdit != null ? 'SIMPAN PERUBAHAN' : 'TAMBAH ODP'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 