import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:photo_view/photo_view.dart';
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/user.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'chat_tab_platform.dart';
import 'chat_tab_platform_interface.dart';

enum _MessageAction { edit, delete, cancel }

class ChatTab extends ConsumerStatefulWidget {
  final int companyId;
  final Function(int unreadMessages)? onUnreadMessagesChanged;

  const ChatTab({
    super.key,
    required this.companyId,
    this.onUnreadMessagesChanged,
  });

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastVisit;

  WebSocketChannel? _chatChannel;

  XFile? _attachmentFile;
  PlatformFile? _webFile;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    registerChatTabPlatform();
    _loadChatMessages();
    _connectWebSocket();
    _markChatRead();
    _lastVisit = DateTime.now();
  }

  @override
  void dispose() {
    _chatChannel?.sink.close();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    final api = ApiClient();
    final token = await api.getToken();
    if (token == null) return;

    final origin = Uri.base.origin;
    final wsScheme = origin.startsWith('https') ? 'wss' : 'ws';
    final wsBase = origin.replaceFirst(RegExp(r'^https?://'), '');
    final chatUrl = '$wsScheme://$wsBase/api/ws/chat/${widget.companyId}?token=$token';

    print('🔌 Connecting to Chat WebSocket: $chatUrl');

    try {
      _chatChannel = WebSocketChannel.connect(Uri.parse(chatUrl));
      _chatChannel!.stream.listen((data) {
        print('📨 WebSocket received: $data');
        _handleChatEvent(data);
      }, onError: (error) {
        print('❌ Chat WS error: $error');
      });
    } catch (e) {
      print('❌ Failed to connect chat WS: $e');
    }
  }

  void _handleChatEvent(dynamic rawData) {
    final data = rawData is String ? jsonDecode(rawData) : rawData;
    final type = data['type'];
    
    setState(() {
      switch (type) {
        case 'new_message':
          _messages.add(data['message']);
          break;
        case 'edit_message':
          final messageId = data['message_id'];
          final newText = data['new_message'];
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['message'] = newText;
            _messages[index]['edited'] = true;
            _messages[index]['updated_at'] = data['updated_at'];
          }
          break;
        case 'delete_message':
          final messageId = data['message_id'];
          _messages.removeWhere((m) => m['id'] == messageId);
          break;
        case 'clear_chat':
          _messages.clear();
          break;
      }
      _updateUnreadCount();
    });
  }

  void _updateUnreadCount() {
    int unread = 0;
    if (_lastVisit != null) {
      unread = _messages
          .where((msg) => DateTime.parse(msg['created_at']).isAfter(_lastVisit!))
          .length;
    }
    widget.onUnreadMessagesChanged?.call(unread);
  }

  Future<void> _markChatRead() async {
    final api = ApiClient();
    try {
      await api.post('/chat/company/${widget.companyId}/mark-read');
    } catch (e) {
      print('Error marking chat read: $e');
    }
  }

  Future<void> _loadChatMessages() async {
    final api = ApiClient();
    try {
      final res = await api.get('/chat/company/${widget.companyId}');
      final newMessages = List<Map<String, dynamic>>.from(res.data);
      setState(() {
        _messages = newMessages;
        _loadingMessages = false;
      });
      await _markChatRead();
      _lastVisit = DateTime.now();
      _updateUnreadCount();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _messages.isNotEmpty) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() => _loadingMessages = false);
      print('Error loading chat: $e');
    }
  }

  Future<void> _showAttachmentPicker(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(t.chooseFromGallery),
              onTap: () async {
                Navigator.pop(context);
                await _pickFile(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(t.takePhoto),
              onTap: () async {
                Navigator.pop(context);
                await _pickFile(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(t.chooseFile),
              onTap: () async {
                Navigator.pop(context);
                await _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile([ImageSource? source]) async {
    if (source != null && !kIsWeb) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _attachmentFile = picked;
          _webFile = null;
        });
      }
    } else {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _webFile = result.files.first;
          _attachmentFile = null;
        });
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentFile = null;
      _webFile = null;
    });
  }

  // Просмотр изображения с зумом
  Future<void> _showPhotoViewer(String url) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: NetworkImage(url),
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'Не удалось загрузить изображение',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black87),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Диалог выбора действия с файлом
  Future<void> _showFileOptions(String url, String filename) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Файл'),
        content: const Text('Выберите действие:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'open'),
            child: const Text('Открыть'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'download'),
            child: const Text('Скачать'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    
    if (action == null || action == 'cancel') return;
    
    if (action == 'open') {
      await _openFile(url, filename);
    } else {
      await _downloadFile(url, filename);
    }
  }

  // Открытие файла через API
  Future<void> _openFile(String url, String filename) async {
    final api = ApiClient();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final response = await api.getFile(url);
      final bytes = response.data as List<int>;
      
      if (mounted) Navigator.pop(context);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(blobUrl, '_blank');
        Future.delayed(const Duration(seconds: 5), () {
          html.Url.revokeObjectUrl(blobUrl);
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия: $e')),
        );
      }
    }
  }

  // Скачивание файла через API
  Future<void> _downloadFile(String url, String filename) async {
    final api = ApiClient();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final response = await api.getFile(url);
      final bytes = response.data as List<int>;
      
      if (mounted) Navigator.pop(context);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..download = filename;
        anchor.click();
        html.Url.revokeObjectUrl(blobUrl);
      } else {
        await ChatTabPlatformSingleton.instance.downloadFile(Uint8List.fromList(bytes), filename);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл сохранен')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final t = AppLocalizations.of(context)!;
    final text = _messageController.text.trim();
    final hasFile = _attachmentFile != null || _webFile != null;
    
    if (text.isEmpty && !hasFile) return;

    setState(() => _loadingMessages = true);
    final api = ApiClient();
    try {
      String? attachmentUrl;
      
      if (hasFile) {
        Uint8List fileBytes;
        String fileName;

        if (_attachmentFile != null) {
          fileBytes = await _attachmentFile!.readAsBytes();
          fileName = _attachmentFile!.name;
        } else {
          fileBytes = _webFile!.bytes!;
          fileName = _webFile!.name;
        }

        final compressedBytes = await ImageCompression.compressImage(fileBytes);

        final uploadRes = await api.uploadChatFile(
          companyId: widget.companyId,
          bytes: compressedBytes,
          filename: fileName,
        );
        attachmentUrl = uploadRes['url'];
      }

      await api.post('/chat/company/${widget.companyId}', data: {
        'message': text,
        'attachment_url': attachmentUrl,
      });

      _messageController.clear();
      setState(() {
        _attachmentFile = null;
        _webFile = null;
        _loadingMessages = false;
      });
      
      widget.onUnreadMessagesChanged?.call(0);
      await _markChatRead();
      _lastVisit = DateTime.now();
      
    } catch (e) {
      print('Error sending message: $e');
      setState(() => _loadingMessages = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.sendError}: $e')));
    }
  }

  Future<void> _clearChat() async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.clearChatTitle),
        content: Text(t.clearChatContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.clear, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/chat/company/${widget.companyId}/clear');
      await _loadChatMessages();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> msg) async {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showDialog<_MessageAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.messageActions, style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title: Text(t.edit, style: TextStyle(color: colorScheme.onSurface)),
              onTap: () => Navigator.pop(context, _MessageAction.edit),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text(t.delete, style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, _MessageAction.delete),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _MessageAction.cancel),
            child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
    if (action == _MessageAction.edit) {
      await _editMessageContent(msg);
    } else if (action == _MessageAction.delete) {
      await _deleteMessage(msg);
    }
  }

  Future<void> _editMessageContent(Map<String, dynamic> msg) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: msg['message']);
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editMessage, style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: t.newText, hintStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
          style: TextStyle(color: colorScheme.onSurface),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;
              final api = ApiClient();
              try {
                await api.patch('/chat/message/${msg['id']}', data: {'message': newText});
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: Text(t.save),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteMessageTitle),
        content: Text(t.deleteMessageContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final api = ApiClient();
    try {
      await api.delete('/chat/message/${msg['id']}');
      setState(() {
        _messages.removeWhere((m) => m['id'] == msg['id']);
      });
      _updateUnreadCount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final isFounder = currentUser?.role == UserRole.founder;
    final colorScheme = Theme.of(context).colorScheme;
    final hasAttachment = _attachmentFile != null || _webFile != null;

    return Column(
      children: [
        if (isFounder)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: _clearChat,
              tooltip: t.clearChatTooltip,
            ),
          ),
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['user_id'] == currentUser?.id;
                    final originalName = msg['user_full_name'];
                    final displayName = (originalName == 'Основатель')
                        ? t.founderRole
                        : originalName;
                    return _buildMessageBubble(isMe, displayName, msg, isFounder, colorScheme, t);
                  },
                ),
        ),
        // Превью вложения
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: hasAttachment ? 70 : 0,
          child: hasAttachment
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.attach_file),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _attachmentFile != null ? _attachmentFile!.name : _webFile!.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            if (_webFile != null)
                              Text(
                                '${(_webFile!.size ~/ 1024).toString()} KB',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (_attachmentFile != null)
                              FutureBuilder<int>(
                                future: _attachmentFile!.length(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      '${(snapshot.data! ~/ 1024).toString()} KB',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _removeAttachment,
                        color: colorScheme.error,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Поле ввода
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.attach_file, color: colorScheme.primary),
                onPressed: () => _showAttachmentPicker(context),
                tooltip: t.attachFileTooltip,
              ),
              if (!kIsWeb)
                IconButton(
                  icon: Icon(Icons.camera_alt, color: colorScheme.primary),
                  onPressed: () => _pickFile(ImageSource.camera),
                ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: t.enterMessageHint,
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: IconButton(
                  icon: Icon(Icons.send, color: colorScheme.onPrimaryContainer),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
      bool isMe, String displayName, Map<String, dynamic> msg, bool isFounder, ColorScheme colorScheme, AppLocalizations t) {
    final hasAttachment = msg['attachment_url'] != null && msg['attachment_url'].toString().isNotEmpty;
    final isImage = hasAttachment && msg['attachment_url'].toString().contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)', caseSensitive: false));
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isMe ? colorScheme.primary : colorScheme.primaryContainer,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: TextStyle(
                color: isMe ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isMe ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal()),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (msg['edited'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          t.editedLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasAttachment)
                        isImage
                            ? GestureDetector(
                                onTap: () => _showPhotoViewer(msg['attachment_url']),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    msg['attachment_url'],
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 200,
                                        color: Colors.grey.shade300,
                                        child: const Center(child: CircularProgressIndicator()),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.broken_image, size: 50),
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _showFileOptions(msg['attachment_url'], msg['attachment_url'].split('/').last),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.insert_drive_file, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg['attachment_url'].split('/').last,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      if (msg['message'] != null && msg['message'].toString().isNotEmpty)
                        Text(
                          msg['message'],
                          style: TextStyle(
                            color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe || isFounder)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurfaceVariant),
                onPressed: () => _showMessageActions(msg),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}