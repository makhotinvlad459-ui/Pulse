import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/user.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'chat_tab_platform_interface.dart';
import 'chat_tab_platform_factory.dart';
// Условный импорт: на мобильные — mobile, на веб — web
import 'chat_tab_mobile.dart'
    if (dart.library.html) 'chat_tab_web.dart';

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

class _ChatTabState extends ConsumerState<ChatTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    // Регистрация платформенной реализации через фабрику
    ChatTabPlatformSingleton.register(createChatTabPlatform());
    _loadChatMessages();
    _connectWebSocket();
    _markChatRead();
    _lastVisit = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatChannel?.sink.close();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Приложение вернулось на передний план
      _reconnectWebSocket();
      _loadChatMessages();
    }
  }

  Future<void> _connectWebSocket() async {
  // Если уже есть активное соединение, не создаём новое
  if (_chatChannel != null) return;

  final api = ApiClient();
  final token = await api.getToken();
  if (token == null) return;

  final encodedToken = Uri.encodeComponent(token);
  final chatUrl = 'wss://pulse-yourmoney.com/api/ws/chat/${widget.companyId}?token=$encodedToken';
  print('🔌 Connecting to Chat WebSocket: $chatUrl');

  try {
    final channel = WebSocketChannel.connect(Uri.parse(chatUrl));
    await channel.ready;
    print('✅ WebSocket connected');

    // Сохраняем канал только после успешного подключения
    _chatChannel = channel;

    _chatChannel!.stream.listen(
      (data) {
        print('📨 WebSocket received: $data');
        _handleChatEvent(data);
      },
      onError: (error) {
        print('❌ Chat WS stream error: $error');
        _reconnectWebSocket();
      },
      onDone: () {
        print('🔌 WebSocket closed, reconnecting...');
        // Сбрасываем канал, чтобы при следующем подключении он был null
        _chatChannel = null;
        _reconnectWebSocket();
      },
    );
  } catch (e) {
    print('❌ Failed to connect chat WS: $e');
    _chatChannel = null;
    // Повторная попытка через 5 секунд
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _connectWebSocket();
    });
  }
}

Future<void> _reconnectWebSocket() async {
  // Если уже есть канал, закрываем его и ждём завершения
  if (_chatChannel != null) {
    await _chatChannel!.sink.close();
    _chatChannel = null;
  }
  // После этого запускаем новое подключение
  await _connectWebSocket();
}

  void _handleChatEvent(dynamic rawData) {
    try {
      final data = rawData is String ? jsonDecode(rawData) : rawData;

      // Если пришел не словарь, игнорируем
      if (data is! Map) return;

      final type = data['type'];

      // Игнорируем служебный ping, чтобы впустую не дергать setState и не нагружать UI
      if (type == 'ping') return;

      setState(() {
        switch (type) {
          case 'new_message':
            _messages.add(data['message']);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                );
              }
            });
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
    } catch (e) {
      print('Chat WS parse error: $e');
    }
  }

  void _updateUnreadCount() {
    int unread = 0;
    if (_lastVisit != null) {
      unread = _messages
          .where((msg) =>
              DateTime.parse(msg['created_at']).isAfter(_lastVisit!))
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

  // НОВЫЙ МЕТОД - загружает фото через API
  Future<void> _showPhotoViaApi(int messageId) async {
  final api = ApiClient();
  try {
    showDialog(
      context: context,
      barrierDismissible: true,  // чтобы можно было закрыть тапом по фону
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await api.getChatFile(messageId);
    final bytes = response.data is List<int>
        ? Uint8List.fromList(response.data as List<int>)
        : Uint8List.fromList((response.data as String).codeUnits);

    if (mounted) Navigator.pop(context);

    // Размер экрана
    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierDismissible: true,  // закрытие по тапу вне фото
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,   // полностью прозрачный фон
        insetPadding: EdgeInsets.zero,          // убираем внутренние отступы
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // Фото на весь экран
              Center(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              // Кнопка закрытия (верхний правый угол)
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Кнопка скачивания (нижний правый угол)
              Positioned(
                bottom: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.download, color: Colors.white, size: 30),
                  onPressed: () => _downloadFile(messageId, 'photo.jpg'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error load photo: $e')),
      );
    }
  }
}

  // Скачивание файла через API (по ID)
  Future<void> _downloadFile(int messageId, String filename) async {
    final api = ApiClient();
    try {
      final response = await api.getChatFile(messageId);
      final bytes = response.data is List<int>
          ? Uint8List.fromList(response.data as List<int>)
          : Uint8List.fromList((response.data as String).codeUnits);

      // Платформенная реализация (веб или мобилка)
      await ChatTabPlatformSingleton.instance.downloadFile(bytes, filename);

      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.fileSaved)),
        );
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('exception: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final t = AppLocalizations.of(context)!;
    final text = _messageController.text.trim();
    final hasFile = _attachmentFile != null || _webFile != null;

    if (text.isEmpty && !hasFile) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final api = ApiClient();
    try {
      String? attachmentUrl;

      if (hasFile) {
        Uint8List fileBytes;
        String fileName;
        bool isImage = false;

        if (_attachmentFile != null) {
          // Изображение из галереи/камеры
          fileBytes = await _attachmentFile!.readAsBytes();
          fileName = _attachmentFile!.name;
        } else {
          // Файл через FilePicker
          if (_webFile == null) throw Exception('No file selected');

          // Получаем байты (читаем из файла, если bytes null)
          if (_webFile!.bytes != null) {
            fileBytes = _webFile!.bytes!;
          } else if (_webFile!.path != null) {
            final file = File(_webFile!.path!);
            fileBytes = await file.readAsBytes();
          } else {
            throw Exception('Cannot read file bytes');
          }
          fileName = _webFile!.name;
        }

        // Проверяем, изображение ли это
        final ext = fileName.toLowerCase();
        isImage = ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.png') ||
            ext.endsWith('.gif') ||
            ext.endsWith('.webp');

        // Сжимаем только изображения
        final compressedBytes = isImage
            ? await ImageCompression.compressImage(fileBytes)
            : fileBytes;

        final uploadRes = await api.uploadChatFile(
          companyId: widget.companyId,
          bytes: compressedBytes,
          filename: fileName,
        );
        attachmentUrl = uploadRes['url'];
        if (attachmentUrl == null) throw Exception('Upload returned no URL');
      }

      await api.post('/chat/company/${widget.companyId}', data: {
        'message': text,
        'attachment_url': attachmentUrl,
      });

      _messageController.clear();
      setState(() {
        _attachmentFile = null;
        _webFile = null;
      });

      widget.onUnreadMessagesChanged?.call(0);
      await _markChatRead();
      _lastVisit = DateTime.now();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('Error sending message: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.sendError}: $e')));
    }
  }

  Future<Uint8List?> _getImageBytes(int messageId) async {
    final api = ApiClient();
    try {
      final response = await api.getChatFile(messageId);
      if (response.statusCode != 200) {
        print('Failed to load image $messageId: HTTP ${response.statusCode}');
        return null;
      }
      if (response.data is List<int>) {
        return Uint8List.fromList(response.data as List<int>);
      } else if (response.data is String) {
        return Uint8List.fromList((response.data as String).codeUnits);
      } else {
        print('Unexpected response data type: ${response.data.runtimeType}');
        return null;
      }
    } catch (e) {
      print('Error loading image $messageId: $e');
      return null;
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
        title: Text(t.messageActions,
            style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title:
                  Text(t.edit, style: TextStyle(color: colorScheme.onSurface)),
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
            child: Text(t.cancel,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
        title: Text(t.editMessage,
            style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
              hintText: t.newText,
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
          style: TextStyle(color: colorScheme.onSurface),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;
              final api = ApiClient();
              try {
                await api.patch('/chat/message/${msg['id']}',
                    data: {'message': newText});
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${t.error}: $e')));
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.delete, style: const TextStyle(color: Colors.red))),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
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
                    return _buildMessageBubble(
                        isMe, displayName, msg, isFounder, colorScheme, t);
                  },
                ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: hasAttachment ? 70 : 0,
          child: hasAttachment
              ? Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3)),
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
                              _attachmentFile != null
                                  ? _attachmentFile!.name
                                  : _webFile!.name,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            if (_webFile != null)
                              Text(
                                '${(_webFile!.size ~/ 1024).toString()} KB',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant),
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
                                          color: colorScheme.onSurfaceVariant),
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
                  icon: Icon(Icons.send,
                      color: colorScheme.onPrimaryContainer),
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
    bool isMe,
    String displayName,
    Map<String, dynamic> msg,
    bool isFounder,
    ColorScheme colorScheme,
    AppLocalizations t,
  ) {
    final hasAttachment = msg['attachment_url'] != null &&
        msg['attachment_url'].toString().isNotEmpty;
    final isImage = hasAttachment &&
        msg['attachment_url']
            .toString()
            .contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)',
                caseSensitive: false));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                isMe ? colorScheme.primary : colorScheme.primaryContainer,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: TextStyle(
                color: isMe
                    ? colorScheme.onPrimary
                    : colorScheme.onPrimaryContainer,
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
                          color: isMe
                              ? colorScheme.primary
                              : colorScheme.onSurface),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(
                          DateTime.parse(msg['created_at']).toLocal()),
                      style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    if (msg['edited'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(t.editedLabel,
                            style: TextStyle(
                                fontSize: 9,
                                color: colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasAttachment)
                        isImage
                            ? GestureDetector(
                                onTap: () => _showPhotoViaApi(msg['id']),
                                child: FutureBuilder<Uint8List?>(
                                  future: _getImageBytes(msg['id']),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: Colors.grey.shade300,
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      );
                                    }
                                    if (snapshot.hasError ||
                                        snapshot.data == null) {
                                      return Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image,
                                            size: 50),
                                      );
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        snapshot.data!,
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _downloadFile(
                                    msg['id'],
                                    msg['attachment_url'].split('/').last),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.insert_drive_file,
                                          color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg['attachment_url'].split('/').last,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      if (msg['message'] != null &&
                          msg['message'].toString().isNotEmpty)
                        Text(
                          msg['message'],
                          style: TextStyle(
                            color: isMe
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
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
                icon: Icon(Icons.more_vert,
                    size: 18, color: colorScheme.onSurfaceVariant),
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