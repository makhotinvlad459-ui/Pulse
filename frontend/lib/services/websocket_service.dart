import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _chatChannel;
  WebSocketChannel? _tasksChannel;
  WebSocketChannel? _userChannel;
  
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;
  
  int? _currentChatCompanyId;
  String? _currentChatToken;
  int? _currentTasksCompanyId;
  String? _currentTasksToken;
  int? _currentUserId;
  String? _currentUserToken;
  
  final _chatStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _taskStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _userStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get chatStream => _chatStreamController.stream;
  Stream<Map<String, dynamic>> get taskStream => _taskStreamController.stream;
  Stream<Map<String, dynamic>> get userStream => _userStreamController.stream;

  static String get _baseUrl {
    if (kIsWeb) {
      if (bool.fromEnvironment('dart.vm.product')) {
        return 'wss://pulse-yourmoney.com/api';
      }
      return 'ws://localhost:8000';
    }
    if (bool.fromEnvironment('dart.vm.product')) {
      return 'wss://pulse-yourmoney.com';
    }
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8000';
    }
    return 'ws://localhost:8000';
  }

  // ✅ ИСПРАВЛЕНО: добавлен /ws/ в путь
  void connectChat(int companyId, String token) {
    if (_chatChannel != null && _currentChatCompanyId == companyId) {
      return;
    }
    disconnectChat();
    _currentChatCompanyId = companyId;
    _currentChatToken = token;
    _shouldReconnect = true;

    final url = '$_baseUrl/ws/chat/$companyId?token=$token';
    if (kDebugMode) print('📡 WS Chat: Connecting to $url');

    try {
      _chatChannel = WebSocketChannel.connect(Uri.parse(url));
      _chatChannel!.stream.listen(
        (message) => _handleMessage(message, 'chat'),
        onDone: () => _handleDisconnect('chat'),
        onError: (error) => _handleDisconnect('chat'),
      );
    } catch (e) {
      _handleDisconnect('chat');
    }
  }

  // ✅ ИСПРАВЛЕНО: добавлен /ws/ в путь
  void connectTasks(int companyId, String token) {
    if (_tasksChannel != null && _currentTasksCompanyId == companyId) {
      return;
    }
    disconnectTasks();
    _currentTasksCompanyId = companyId;
    _currentTasksToken = token;
    _shouldReconnect = true;

    final url = '$_baseUrl/ws/tasks/$companyId?token=$token';
    if (kDebugMode) print('📡 WS Tasks: Connecting to $url');

    try {
      _tasksChannel = WebSocketChannel.connect(Uri.parse(url));
      _tasksChannel!.stream.listen(
        (message) => _handleMessage(message, 'tasks'),
        onDone: () => _handleDisconnect('tasks'),
        onError: (error) => _handleDisconnect('tasks'),
      );
    } catch (e) {
      _handleDisconnect('tasks');
    }
  }

  // ✅ ИСПРАВЛЕНО: добавлен /ws/ в путь
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
      _userChannel = WebSocketChannel.connect(Uri.parse(url));
      _userChannel!.stream.listen(
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
          _chatStreamController.add(data);
          break;
        case 'tasks':
          _taskStreamController.add(data);
          break;
        case 'user':
          _userStreamController.add(data);
          break;
      }
    } catch (e) {
      if (kDebugMode) print('❌ WS $type parse error: $e');
    }
  }

  void _handleDisconnect(String type) {
    if (type == 'chat') _chatChannel = null;
    if (type == 'tasks') _tasksChannel = null;
    if (type == 'user') _userChannel = null;
    
    if (!_shouldReconnect) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
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
    _chatChannel?.sink.close(status.goingAway);
    _chatChannel = null;
    _currentChatCompanyId = null;
    _currentChatToken = null;
  }

  void disconnectTasks() {
    _tasksChannel?.sink.close(status.goingAway);
    _tasksChannel = null;
    _currentTasksCompanyId = null;
    _currentTasksToken = null;
  }

  void disconnectUser() {
    _userChannel?.sink.close(status.goingAway);
    _userChannel = null;
    _currentUserId = null;
    _currentUserToken = null;
  }

  void disconnectAll() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    disconnectChat();
    disconnectTasks();
    disconnectUser();
    if (kDebugMode) print('🔌 WS: All connections closed');
  }

  void dispose() {
    disconnectAll();
    _chatStreamController.close();
    _taskStreamController.close();
    _userStreamController.close();
  }
}