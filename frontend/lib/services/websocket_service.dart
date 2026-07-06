import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart'; 
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, kReleaseMode;

class WebSocketService with WidgetsBindingObserver {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  WebSocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  final SecureStorage _storage = SecureStorage();

  WebSocketChannel? _chatChannel;
  WebSocketChannel? _tasksChannel;
  WebSocketChannel? _userChannel;
  
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;
  Timer? _lifecycleReconnectTimer;
  
  int? _currentChatCompanyId;
  String? _currentChatToken;
  int? _currentTasksCompanyId;
  String? _currentTasksToken;
  int? _currentUserId;
  String? _currentUserToken;
  
  bool _isReconnecting = false;
  bool _isAppResuming = false;
  
  final _chatStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _taskStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _userStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get chatStream => _chatStreamController.stream;
  Stream<Map<String, dynamic>> get taskStream => _taskStreamController.stream;
  Stream<Map<String, dynamic>> get userStream => _userStreamController.stream;

  static String get _baseUrl {
    if (kIsWeb) {
      if (kReleaseMode) {
        return 'wss://pulse-yourmoney.com';
      }
      return 'ws://localhost:8000';
    }
    if (kReleaseMode) {
      return 'wss://pulse-yourmoney.com';
    }
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8000';
    }
    return 'ws://localhost:8000';
  }

  void connectChat(int companyId, String token) {
  if (_currentChatCompanyId == companyId && _chatChannel != null) {
    if (kDebugMode) print('✅ Already connected to chat company $companyId');
    return;
  }
  
  if (_chatChannel != null) {
    try {
      _chatChannel!.sink.close();
    } catch (e) {}
    _chatChannel = null;
  }
  
  _currentChatCompanyId = companyId;
  _currentChatToken = token;
  _shouldReconnect = true;

  final url = '$_baseUrl/ws/chat/$companyId?token=$token';
  if (kDebugMode) print('📡 WS Chat: Connecting to $url');

  try {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _chatChannel = channel;
    channel.stream.listen(
      (message) => _handleMessage(message, 'chat'),
      onDone: () => _handleDisconnect('chat'),
      onError: (error) => _handleDisconnect('chat'),
    );
  } catch (e) {
    _handleDisconnect('chat');
  }
}

  void connectTasks(int companyId, String token) {
  if (_currentTasksCompanyId == companyId && _tasksChannel != null) {
    if (kDebugMode) print('✅ Already connected to tasks company $companyId');
    return;
  }
  
  if (_tasksChannel != null) {
    try {
      _tasksChannel!.sink.close();
    } catch (e) {}
    _tasksChannel = null;
  }
  
  _currentTasksCompanyId = companyId;
  _currentTasksToken = token;
  _shouldReconnect = true;

  final url = '$_baseUrl/ws/tasks/$companyId?token=$token';
  if (kDebugMode) print('📡 WS Tasks: Connecting to $url');

  try {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _tasksChannel = channel;
    channel.stream.listen(
      (message) => _handleMessage(message, 'tasks'),
      onDone: () => _handleDisconnect('tasks'),
      onError: (error) => _handleDisconnect('tasks'),
    );
  } catch (e) {
    _handleDisconnect('tasks');
  }
}

 void connectUser(int userId, String token) {
  if (_userChannel != null && _currentUserId == userId) {
    return;
  }
  disconnectUser();
  _currentUserId = userId;
  _currentUserToken = token;
  _shouldReconnect = true;

  final url = '$_baseUrl/ws/user/$userId?token=$token';
  if (kDebugMode) print('📡 WS User: Connecting to $url');

  try {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _userChannel = channel;
    channel.stream.listen(
      (message) => _handleMessage(message, 'user'),
      onDone: () => _handleDisconnect('user'),
      onError: (error) => _handleDisconnect('user'),
    );
  } catch (e) {
    _handleDisconnect('user');
  }
}

  void _handleMessage(dynamic message, String type) {
    try {
      final data = jsonDecode(message.toString());
      if (kDebugMode) print('📥 WS $type received: $data');
      
      switch (type) {
        case 'chat':
          if (!_chatStreamController.isClosed) _chatStreamController.add(data);
          break;
        case 'tasks':
          if (!_taskStreamController.isClosed) _taskStreamController.add(data);
          break;
        case 'user':
          if (!_userStreamController.isClosed) _userStreamController.add(data);
          break;
      }
    } catch (e) {
      if (kDebugMode) print('❌ WS $type parse error: $e');
    }
  }

  void _handleDisconnect(String type) {
    if (type == 'chat') {
      if (_chatChannel != null) {
        try { _chatChannel!.sink.close(); } catch (e) {}
        _chatChannel = null;
      }
      if (kDebugMode) print('🔌 Chat WebSocket disconnected');
    }
    
    if (type == 'tasks') {
      if (_tasksChannel != null) {
        try { _tasksChannel!.sink.close(); } catch (e) {}
        _tasksChannel = null;
      }
      if (kDebugMode) print('🔌 Tasks WebSocket disconnected');
    }
    
    if (type == 'user') {
      if (_userChannel != null) {
        try { _userChannel!.sink.close(); } catch (e) {}
        _userChannel = null;
      }
      if (kDebugMode) print('🔌 User WebSocket disconnected');
    }
    
    if (!_shouldReconnect) {
      if (kDebugMode) print('⏸️ Reconnection disabled, skipping');
      return;
    }
    
    if (_isReconnecting) {
      if (kDebugMode) print('⏸️ Already reconnecting, skipping');
      return;
    }
    
    _isReconnecting = true;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _isReconnecting = false;
      if (!_shouldReconnect) return;
      
      if (kDebugMode) print('🔄 WS $type: Reconnecting...');
      
      if (type == 'chat' && _currentChatCompanyId != null && _currentChatToken != null) {
        connectChat(_currentChatCompanyId!, _currentChatToken!);
      } else if (type == 'tasks' && _currentTasksCompanyId != null && _currentTasksToken != null) {
        connectTasks(_currentTasksCompanyId!, _currentTasksToken!);
      } else if (type == 'user' && _currentUserId != null && _currentUserToken != null) {
        connectUser(_currentUserId!, _currentUserToken!);
      }
    });
  }

  void disconnectChat() {
    _shouldReconnect = false;
    if (_chatChannel != null) {
      try {
        _chatChannel!.sink.close(status.goingAway);
      } catch (e) {}
      _chatChannel = null;
    }
    _currentChatCompanyId = null;
    _currentChatToken = null;
    // После отключения возвращаем флаг для будущих подключений
    _shouldReconnect = true;
  }

  void disconnectTasks() {
    _shouldReconnect = false;
    if (_tasksChannel != null) {
      try {
        _tasksChannel!.sink.close(status.goingAway);
      } catch (e) {}
      _tasksChannel = null;
    }
    _currentTasksCompanyId = null;
    _currentTasksToken = null;
    _shouldReconnect = true;
  }

  void disconnectUser() {
    if (_userChannel != null) {
      try {
        _userChannel!.sink.close(status.goingAway);
      } catch (e) {}
      _userChannel = null;
    }
    _currentUserId = null;
    _currentUserToken = null;
    if (kDebugMode) print('🔌 WS User disconnected');
  }

  void disconnectAll() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _lifecycleReconnectTimer?.cancel();
    disconnectChat();
    disconnectTasks();
    disconnectUser();
    if (kDebugMode) print('🔌 WS: All connections closed');
  }
  
  Future<void> refreshAllConnections() async {
    if (_isAppResuming) return;
    
    _isAppResuming = true;
    await Future.delayed(const Duration(milliseconds: 800));
    
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      _isAppResuming = false;
      return;
    }
    
    if (kDebugMode) print('🔄 Refreshing all WebSocket connections...');
    
    if (_currentChatCompanyId != null && (_chatChannel == null)) {
      disconnectChat();
      connectChat(_currentChatCompanyId!, token);
    }
    if (_currentTasksCompanyId != null && (_tasksChannel == null)) {
      disconnectTasks();
      connectTasks(_currentTasksCompanyId!, token);
    }
    if (_currentUserId != null && (_userChannel == null)) {
      disconnectUser();
      connectUser(_currentUserId!, token);
    }
    
    _isAppResuming = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) print('📱 App lifecycle: $state');
    
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) print('🔄 App resumed, will refresh connections after delay...');
      
      _lifecycleReconnectTimer?.cancel();
      _lifecycleReconnectTimer = Timer(const Duration(milliseconds: 1500), () {
        if (kDebugMode) print('🔄 Executing delayed reconnect...');
        refreshAllConnections();
      });
    }
    
    if (state == AppLifecycleState.paused) {
      if (kDebugMode) print('📱 App paused, WebSockets will be checked on resume');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleReconnectTimer?.cancel();
    _reconnectTimer?.cancel();
    disconnectAll();
    _chatStreamController.close();
    _taskStreamController.close();
    _userStreamController.close();
    if (kDebugMode) print('🔌 WS: Service disposed');
  }
}