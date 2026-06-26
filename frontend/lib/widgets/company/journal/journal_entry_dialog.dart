import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import '../../../l10n/app_localizations.dart';

class JournalEntryDialog extends StatefulWidget {
  final int companyId;
  final DateTime? initialDate;
  final dynamic initialEntry;
  final Set<String> permissions;
  final List<Map<String, dynamic>> members;

  const JournalEntryDialog({
    super.key,
    required this.companyId,
    this.initialDate,
    this.initialEntry,
    required this.permissions,
    required this.members,
  });

  @override
  State<JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<JournalEntryDialog> {
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _counterpartyController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loadingShowcase = false;
  List<Map<String, dynamic>> _showcaseItems = [];
  final TextEditingController _manualAmountController = TextEditingController();
  bool _isManualAmountEnabled = true;

  List<Map<String, dynamic>> _attachments = [];
  final List<({Uint8List bytes, String name})> _newFiles = [];
  bool _uploading = false;

  List<String> _existingCounterparties = [];
  bool _loadingCounterparties = false;
  
  int? _selectedMemberId;
  
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    
    if (widget.initialEntry != null) {
      _startDateTime = DateTime.parse(widget.initialEntry['datetime_start']).toLocal();
      _endDateTime = DateTime.parse(widget.initialEntry['datetime_end']).toLocal();
      _descriptionController.text = widget.initialEntry['description'] ?? '';
      final cp = widget.initialEntry['counterparty'] ?? '';
      _counterpartyController.text = cp;
      _selectedMemberId = widget.initialEntry['assigned_to_id'];
      
      if (widget.initialEntry['items'] != null) {
        _items = List<Map<String, dynamic>>.from(widget.initialEntry['items']).map((item) {
          final total = item['total'] ?? item['quantity'] * item['price_at_time'];
          return {
            'showcase_item_id': item['showcase_item_id'],
            'quantity': item['quantity'],
            'price_at_time': item['price_at_time'],
            'name': item['name'] ?? 'Без названия',
            'total': total.toDouble(),
          };
        }).toList();
      }
      final total = widget.initialEntry['total_amount'];
      _manualAmountController.text = (total != null ? (total as num).toDouble() : 0.0).toStringAsFixed(2);
      if (widget.initialEntry['attachments'] != null) {
        _attachments = List<Map<String, dynamic>>.from(widget.initialEntry['attachments']);
      }
    } else {
      final baseDate = widget.initialDate ?? DateTime.now();
      _startDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, 10, 0);
      _endDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, 11, 0);
      _manualAmountController.text = '0.00';
    }
    _loadShowcaseItems();
    _loadCounterparties();
    _updateManualAmountState(setStateFlag: false);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _manualAmountController.dispose();
    super.dispose();
  }

  void _updateManualAmountState({bool setStateFlag = true}) {
    if (_isDisposed) return;
    
    final hasServices = _items.isNotEmpty;
    final computed = _items.fold(0.0, (sum, item) => sum + ((item['total'] ?? 0.0) as double));
    if (setStateFlag) {
      if (mounted) {
        setState(() {
          _isManualAmountEnabled = !hasServices;
          if (hasServices) _manualAmountController.text = computed.toStringAsFixed(2);
        });
      }
    } else {
      _isManualAmountEnabled = !hasServices;
      if (hasServices) _manualAmountController.text = computed.toStringAsFixed(2);
    }
  }

  Future<void> _loadShowcaseItems() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loadingShowcase = true);
    try {
      final api = ApiClient();
      final res = await api.get('/showcase', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() {
        _showcaseItems = List<Map<String, dynamic>>.from(res.data);
        _loadingShowcase = false;
      });
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      setState(() => _loadingShowcase = false);
    }
  }

  Future<void> _loadCounterparties() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loadingCounterparties = true);
    final api = ApiClient();
    try {
      final res = await api.get('/statistics/counterparties', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() {
        _existingCounterparties = List<String>.from(res.data);
        _loadingCounterparties = false;
      });
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      setState(() => _loadingCounterparties = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    if (_isDisposed) return;
    
    final initialTime = TimeOfDay.fromDateTime(isStart ? _startDateTime : _endDateTime);
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDateTime = DateTime(
            _startDateTime.year, _startDateTime.month, _startDateTime.day,
            picked.hour, picked.minute,
          );
          if (_endDateTime.isBefore(_startDateTime)) {
            _endDateTime = _startDateTime.add(const Duration(hours: 1));
          }
        } else {
          _endDateTime = DateTime(
            _endDateTime.year, _endDateTime.month, _endDateTime.day,
            picked.hour, picked.minute,
          );
          if (_endDateTime.isBefore(_startDateTime)) {
            _endDateTime = _startDateTime.add(const Duration(hours: 1));
          }
        }
      });
    }
  }

  void _addService() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    final t = AppLocalizations.of(context)!;
    if (_loadingShowcase) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.loadingServices)));
      return;
    }
    if (_showcaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.noServicesAvailable)));
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.selectService),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _showcaseItems.length,
            itemBuilder: (context, index) {
              final item = _showcaseItems[index];
              return ListTile(
                title: Text(item['name']),
                subtitle: Text('${item['price']} ${t.currencySymbol}'),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
      ),
    );
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (selected != null) {
      setState(() {
        _items.add({
          'showcase_item_id': selected['id'],
          'name': selected['name'],
          'quantity': 1,
          'price_at_time': (selected['price'] as num).toDouble(),
          'total': (selected['price'] as num).toDouble(),
        });
        _updateManualAmountState();
      });
    }
  }

  void _removeService(int index) {
    if (!_isDisposed && mounted) {
      setState(() {
        _items.removeAt(index);
        _updateManualAmountState();
      });
    }
  }

  void _updateService(int index, {int? quantity, double? priceAtTime}) {
    if (!_isDisposed && mounted) {
      setState(() {
        if (quantity != null) _items[index]['quantity'] = quantity;
        if (priceAtTime != null) _items[index]['price_at_time'] = priceAtTime;
        final qty = _items[index]['quantity'] as int;
        final price = _items[index]['price_at_time'] as double;
        _items[index]['total'] = qty * price;
        _updateManualAmountState();
      });
    }
  }

  double get _finalAmount {
    if (_items.isNotEmpty) {
      return _items.fold(0.0, (sum, item) => sum + ((item['total'] ?? 0.0) as double));
    }
    return double.tryParse(_manualAmountController.text) ?? 0.0;
  }

  Future<void> _pickFiles() async {
    if (_isDisposed) return;
    
    final t = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      allowMultiple: true,
    );
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (result != null) {
      setState(() {
        for (final file in result.files) {
          Uint8List? fileBytes;
          if (file.bytes != null) {
            fileBytes = file.bytes;
          } else if (!kIsWeb && file.path != null) {
            fileBytes = File(file.path!).readAsBytesSync();
          }
          if (fileBytes != null) {
            _newFiles.add((bytes: fileBytes, name: file.name));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fileReadError)));
          }
        }
      });
    } else if (!kIsWeb && mounted) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (_isDisposed) return;
      if (!mounted) return;
      
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _newFiles.add((bytes: bytes, name: picked.name));
        });
      }
    }
  }

  void _removeNewFile(int index) {
    if (!_isDisposed && mounted) {
      setState(() {
        _newFiles.removeAt(index);
      });
    }
  }

  Future<void> _removeExistingAttachment(int attachmentId) async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteFileTitle),
        content: Text(t.deleteFileContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (confirm == true) {
      final api = ApiClient();
      try {
        await api.deleteJournalAttachment(attachmentId, widget.companyId);
        if (_isDisposed) return;
        if (!mounted) return;
        
        setState(() {
          _attachments.removeWhere((att) => att['id'] == attachmentId);
        });
      } catch (e) {
        if (_isDisposed) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  String _getUserDisplayName(Map<String, dynamic> member) {
    final fullName = member['full_name'] ?? '';
    final role = member['role'];
    if (role == 'founder' || fullName == 'Основатель') {
      final t = AppLocalizations.of(context)!;
      return t.founderRole;
    }
    return fullName;
  }

  Future<void> _save() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    final t = AppLocalizations.of(context)!;
    if (_endDateTime.isBefore(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.endTimeAfterStart)));
      return;
    }
    if (!mounted) return;
    setState(() => _uploading = true);
    final api = ApiClient();
    try {
      int? entryId;
      final List<Map<String, dynamic>> itemsToSend = _items.map((item) => {
        'showcase_item_id': item['showcase_item_id'],
        'quantity': item['quantity'],
        'price_at_time': item['price_at_time'],
        'name': item['name'],
      }).toList();

      if (widget.initialEntry != null) {
        await api.updateJournalEntry(
          widget.companyId,
          widget.initialEntry['id'],
          start: _startDateTime,
          end: _endDateTime,
          description: _descriptionController.text.trim(),
          counterparty: _counterpartyController.text.trim(),
          items: itemsToSend.isNotEmpty ? itemsToSend : null,
          totalAmount: _finalAmount,
          assignedToId: _selectedMemberId,
        );
        entryId = widget.initialEntry['id'];
      } else {
        final newEntry = await api.createJournalEntry(
          widget.companyId,
          start: _startDateTime,
          end: _endDateTime,
          description: _descriptionController.text.trim(),
          counterparty: _counterpartyController.text.trim(),
          items: itemsToSend.isNotEmpty ? itemsToSend : null,
          totalAmount: _finalAmount,
          assignedToId: _selectedMemberId,
        );
        entryId = newEntry.id;
      }

      if (entryId == null) throw Exception('Entry ID is null');

      for (final file in _newFiles) {
        Uint8List bytesToUpload = file.bytes;
        final ext = file.name.split('.').last.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
        if (isImage && !kIsWeb) {
          try {
            bytesToUpload = await ImageCompression.compressImage(file.bytes);
          } catch (e) {
            debugPrint("Ошибка сжатия: $e, отправляем оригинал");
          }
        }
        await api.uploadJournalAttachment(
          entryId: entryId,
          companyId: widget.companyId,
          bytes: bytesToUpload,
          filename: file.name,
        );
      }

      if (_isDisposed) return;
      if (!mounted) return;
      
      Navigator.pop(context, true);
    } catch (e, stack) {
      debugPrint("Ошибка сохранения: $e\n$stack");
      if (_isDisposed) return;
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.initialEntry != null;

    return AlertDialog(
      title: Text(isEdit ? t.editJournalEntry : t.newJournalEntry, style: TextStyle(color: colorScheme.onSurface)),
      content: _uploading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(t.dateLabel),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(_startDateTime)),
                  ),
                  ListTile(
                    title: Text(t.startTime),
                    trailing: Text(DateFormat('HH:mm').format(_startDateTime)),
                    onTap: () => _selectTime(true),
                  ),
                  ListTile(
                    title: Text(t.endTime),
                    trailing: Text(DateFormat('HH:mm').format(_endDateTime)),
                    onTap: () => _selectTime(false),
                  ),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: t.description),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final lower = textEditingValue.text.toLowerCase();
                      return _existingCounterparties.where((c) => c.toLowerCase().contains(lower));
                    },
                    onSelected: (String selection) {
                      _counterpartyController.text = selection;
                    },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                      textController.addListener(() {
                        if (_counterpartyController.text != textController.text) {
                          _counterpartyController.text = textController.text;
                        }
                      });
                      return TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: t.counterpartyOptional,
                          border: const OutlineInputBorder(),
                          suffixIcon: _loadingCounterparties
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    if (!_isDisposed && mounted) {
                                      _loadCounterparties();
                                    }
                                  },
                                  tooltip: t.refreshList,
                                ),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // ✅ ВЫБОР СОТРУДНИКА
                  DropdownButtonFormField<int?>(
                    decoration: InputDecoration(
                      labelText: t.assignResponsible,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedMemberId,
                    hint: Text(t.notAssigned),
                    items: [
                       DropdownMenuItem<int?>(
                        value: null,
                        child: Text(t.notAssigned),
                      ),
                      ...widget.members.map((member) {
                        final name = _getUserDisplayName(member);
                        return DropdownMenuItem<int?>(
                          value: member['id'],
                          child: Text(name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (!_isDisposed && mounted) {
                        setState(() => _selectedMemberId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(t.services, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _addService,
                        icon: const Icon(Icons.add),
                        label: Text(t.addService),
                      ),
                    ],
                  ),
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _removeService(idx),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['quantity'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: t.quantityLabel, isDense: true),
                                    onChanged: (value) {
                                      final qty = int.tryParse(value) ?? 1;
                                      _updateService(idx, quantity: qty);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['price_at_time'].toStringAsFixed(2),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: t.priceLabel, isDense: true),
                                    onChanged: (value) {
                                      final price = double.tryParse(value) ?? 0.0;
                                      _updateService(idx, priceAtTime: price);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '${(item['total'] ?? 0.0).toStringAsFixed(2)} ${t.currencySymbol}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t.noServicesAdded, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t.totalAmount,
                      prefixIcon: const Icon(Icons.attach_money),
                      enabled: _isManualAmountEnabled,
                    ),
                    onChanged: (value) {
                      if (_items.isEmpty && mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(t.attachmentsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file),
                        label: Text(t.addFiles),
                      ),
                    ],
                  ),
                  if (_newFiles.isNotEmpty)
                    Column(
                      children: _newFiles.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        return ListTile(
                          dense: true,
                          leading: _fileIcon(file.name),
                          title: Text(file.name, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _removeNewFile(idx),
                          ),
                        );
                      }).toList(),
                    ),
                  if (_attachments.isNotEmpty)
                    Column(
                      children: _attachments.map((att) {
                        final fileName = att['file_name'] ?? 'file';
                        return ListTile(
                          dense: true,
                          leading: _fileIcon(fileName),
                          title: Text(fileName, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeExistingAttachment(att['id']),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
          child: Text(t.cancel),
        ),
        ElevatedButton(
          onPressed: _uploading ? null : _save,
          child: Text(isEdit ? t.save : t.create),
        ),
      ],
    );
  }

  Widget _fileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    IconData iconData;
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      iconData = Icons.image;
    } else if (ext == 'pdf') {
      iconData = Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(ext)) {
      iconData = Icons.description;
    } else if (['xls', 'xlsx'].contains(ext)) {
      iconData = Icons.table_chart;
    } else if (ext == 'txt') {
      iconData = Icons.text_fields;
    } else {
      iconData = Icons.insert_drive_file;
    }
    return Icon(iconData, color: Colors.blue);
  }
}