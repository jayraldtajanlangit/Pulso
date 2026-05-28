import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pulso/message/message_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'findOrCreateConversation inserts a new conversation without selecting it',
    () async {
      final httpClient = _MessagingHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: httpClient,
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final conversationId = await repository.findOrCreateConversation(
        currentUserId: 'current-user',
        otherUserId: 'other-user',
      );

      expect(conversationId, httpClient.createdConversationId);
      expect(httpClient.conversationInsertHadSelect, isFalse);
      expect(httpClient.createdConversationId, matches(_uuidV4Pattern));
      expect(httpClient.participantRows, [
        {'conversation_id': conversationId, 'user_id': 'current-user'},
        {'conversation_id': conversationId, 'user_id': 'other-user'},
      ]);
    },
  );

  test('fetchInbox omits conversations without a last message', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: _InboxHttpClient(),
      accessToken: () async => 'test-token',
    );
    final repository = SupabaseMessageRepository(client);

    final conversations = await repository.fetchInbox('current-user');

    expect(conversations, isEmpty);
  });

  test('fetchInbox includes conversations after a message exists', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: _InboxHttpClient(
        lastMessage: {
          'body': 'Hello from inbox',
          'sender_id': 'current-user',
          'shared_post_id': null,
        },
      ),
      accessToken: () async => 'test-token',
    );
    final repository = SupabaseMessageRepository(client);

    final conversations = await repository.fetchInbox('current-user');

    expect(conversations, hasLength(1));
    expect(conversations.single.otherUserId, 'other-user');
    expect(conversations.single.otherUsername, 'friend');
    expect(conversations.single.lastMessageBody, 'Hello from inbox');
    expect(conversations.single.lastMessageIsOwn, isTrue);
  });

  test('fetchInbox uses display name when username is missing', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: _InboxHttpClient(
        lastMessage: {
          'body': 'Hello from inbox',
          'sender_id': 'current-user',
          'shared_post_id': null,
        },
        profileUsername: null,
        profileDisplayName: 'Friend User',
      ),
      accessToken: () async => 'test-token',
    );
    final repository = SupabaseMessageRepository(client);

    final conversations = await repository.fetchInbox('current-user');

    expect(conversations.single.otherUsername, 'Friend User');
  });

  test('fetchInbox resolves profile when participant join is empty', () async {
    final httpClient = _InboxMissingProfileJoinHttpClient();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: httpClient,
      accessToken: () async => 'test-token',
    );
    final repository = SupabaseMessageRepository(client);

    final conversations = await repository.fetchInbox('current-user');

    expect(conversations, hasLength(1));
    expect(conversations.single.otherUserId, 'other-user');
    expect(conversations.single.otherUsername, 'direct-friend');
    expect(httpClient.profileLookupCount, 1);
  });

  test(
    'fetchInbox collapses duplicate rows for the same participant',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: _DuplicateInboxHttpClient(),
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final conversations = await repository.fetchInbox('current-user');

      expect(conversations, hasLength(1));
      expect(conversations.single.id, 'conv-new');
      expect(conversations.single.lastMessageBody, 'new message');
    },
  );

  test(
    'findOrCreateConversation reuses latest duplicate conversation',
    () async {
      final httpClient = _DuplicateLookupHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: httpClient,
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final conversationId = await repository.findOrCreateConversation(
        currentUserId: 'current-user',
        otherUserId: 'other-user',
      );

      expect(conversationId, 'conv-new');
      expect(httpClient.createdConversation, isFalse);
    },
  );

  test(
    'findOrCreateConversation prefers duplicate with messages over newer empty row',
    () async {
      final httpClient = _DuplicateLookupWithEmptyLatestHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: httpClient,
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final conversationId = await repository.findOrCreateConversation(
        currentUserId: 'current-user',
        otherUserId: 'other-user',
      );

      expect(conversationId, 'conv-with-messages');
      expect(httpClient.createdConversation, isFalse);
    },
  );

  test(
    'findExistingConversation returns null when no conversation exists',
    () async {
      final httpClient = _NoConversationHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: httpClient,
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final id = await repository.findExistingConversation(
        currentUserId: 'current-user',
        otherUserId: 'other-user',
      );

      expect(id, isNull);
      expect(httpClient.createdConversation, isFalse);
    },
  );

  test(
    'findExistingConversation returns the id when one exists',
    () async {
      final httpClient = _DuplicateLookupHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: httpClient,
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final id = await repository.findExistingConversation(
        currentUserId: 'current-user',
        otherUserId: 'other-user',
      );

      expect(id, 'conv-new');
      expect(httpClient.createdConversation, isFalse);
    },
  );

  test(
    'sendDirectMessage calls the atomic send_direct_message RPC',
    () async {
      final httpClient = _SendDirectMessageHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: httpClient,
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final result = await repository.sendDirectMessage(
        recipientUserId: 'recipient-id',
        body: 'hello',
      );

      expect(result.conversationId, 'conv-new');
      expect(result.message.id, 'msg-new');
      expect(result.message.body, 'hello');
      expect(httpClient.rpcCalls, 1);
      expect(httpClient.lastBody?['recipient_id'], 'recipient-id');
      expect(httpClient.lastBody?['message_body'], 'hello');
    },
  );

  test(
    'fetchMessages uses sender display name when username is missing',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: _MessagesHttpClient(),
        accessToken: () async => 'test-token',
      );
      final repository = SupabaseMessageRepository(client);

      final messages = await repository.fetchMessages('conv-1');

      expect(messages.single.senderUsername, 'Friend User');
    },
  );
}

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class _MessagingHttpClient extends http.BaseClient {
  bool conversationInsertHadSelect = false;
  String? createdConversationId;
  List<dynamic>? participantRows;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final path = request.url.path;

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      return _jsonResponse(request, 200, []);
    }

    if (request.method == 'POST' && path.endsWith('/conversations')) {
      conversationInsertHadSelect = request.url.queryParameters.containsKey(
        'select',
      );
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final id = payload['id'] as String?;
      if (conversationInsertHadSelect ||
          id == null ||
          !_uuidV4Pattern.hasMatch(id)) {
        return _jsonResponse(request, 400, {
          'message': 'conversation insert must be minimal and include an id',
        });
      }
      createdConversationId = id;
      return _emptyResponse(request);
    }

    if (request.method == 'POST' &&
        path.endsWith('/conversation_participants')) {
      participantRows = jsonDecode(body) as List<dynamic>;
      return _emptyResponse(request);
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _emptyResponse(http.BaseRequest request) {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      201,
      request: request,
    );
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Mock for fetchInbox tests.
///
/// The new fetchInbox makes these requests in order:
///   1. GET /conversation_participants?select=conversation_id  → list of conv IDs
///   2. GET /conversations                                     → conversation rows
///   3. For each conversation:
///      a. GET /messages                                       → last message
///      b. GET /conversation_participants?select=user_id       → other user's ID (maybeSingle)
///      c. GET /profiles                                       → other user's profile (maybeSingle)
class _InboxHttpClient extends http.BaseClient {
  _InboxHttpClient({
    this.lastMessage,
    this.profileUsername = 'friend',
    this.profileDisplayName,
  });

  final Map<String, dynamic>? lastMessage;
  final String? profileUsername;
  final String? profileDisplayName;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final select = request.url.queryParameters['select'] ?? '';

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      if (select == 'conversation_id') {
        // Step 1: current user's conversation IDs
        return _jsonResponse(request, 200, [
          {'conversation_id': 'conv-1'},
        ]);
      }
      // Step 3b: other participant's user_id (maybeSingle → single object)
      return _jsonResponse(request, 200, {'user_id': 'other-user'});
    }

    if (request.method == 'GET' && path.endsWith('/conversations')) {
      return _jsonResponse(request, 200, [
        {
          'id': 'conv-1',
          'last_message_at': '2024-01-02T00:00:00.000Z',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
      ]);
    }

    if (request.method == 'GET' && path.endsWith('/messages')) {
      final message = lastMessage;
      return _jsonResponse(request, 200, message == null ? [] : [message]);
    }

    if (request.method == 'GET' && path.endsWith('/profiles')) {
      // Step 3c: direct profile lookup (maybeSingle → single object)
      return _jsonResponse(request, 200, {
        'id': 'other-user',
        'username': profileUsername,
        'display_name': profileDisplayName,
        'avatar_url': null,
      });
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Tests that when the participant row has no embedded profile the code still
/// falls back to a direct profile lookup (profileLookupCount == 1).
class _InboxMissingProfileJoinHttpClient extends http.BaseClient {
  int profileLookupCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final select = request.url.queryParameters['select'] ?? '';

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      if (select == 'conversation_id') {
        return _jsonResponse(request, 200, [
          {'conversation_id': 'conv-1'},
        ]);
      }
      // Step 3b: other participant (maybeSingle → single object)
      return _jsonResponse(request, 200, {'user_id': 'other-user'});
    }

    if (request.method == 'GET' && path.endsWith('/conversations')) {
      return _jsonResponse(request, 200, [
        {
          'id': 'conv-1',
          'last_message_at': '2024-01-02T00:00:00.000Z',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
      ]);
    }

    if (request.method == 'GET' && path.endsWith('/messages')) {
      return _jsonResponse(request, 200, [
        {
          'body': 'Hello from inbox',
          'sender_id': 'current-user',
          'shared_post_id': null,
        },
      ]);
    }

    if (request.method == 'GET' && path.endsWith('/profiles')) {
      profileLookupCount++;
      return _jsonResponse(request, 200, {
        'id': 'other-user',
        'username': 'direct-friend',
        'display_name': 'Direct Friend',
        'avatar_url': null,
      });
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _DuplicateInboxHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final select = request.url.queryParameters['select'] ?? '';

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      if (select == 'conversation_id') {
        return _jsonResponse(request, 200, [
          {'conversation_id': 'conv-old'},
          {'conversation_id': 'conv-new'},
        ]);
      }
      // Step 3b: other participant for any conversation (maybeSingle)
      return _jsonResponse(request, 200, {'user_id': 'other-user'});
    }

    if (request.method == 'GET' && path.endsWith('/conversations')) {
      return _jsonResponse(request, 200, [
        {
          'id': 'conv-new',
          'last_message_at': '2024-01-03T00:00:00.000Z',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
        {
          'id': 'conv-old',
          'last_message_at': '2024-01-02T00:00:00.000Z',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
      ]);
    }

    if (request.method == 'GET' && path.endsWith('/messages')) {
      final conversationFilter =
          request.url.queryParameters['conversation_id'] ?? '';
      final isNew = conversationFilter == 'eq.conv-new';
      return _jsonResponse(request, 200, [
        {
          'body': isNew ? 'new message' : 'old message',
          'sender_id': isNew ? 'current-user' : 'other-user',
          'shared_post_id': null,
        },
      ]);
    }

    if (request.method == 'GET' && path.endsWith('/profiles')) {
      return _jsonResponse(request, 200, {
        'id': 'other-user',
        'username': 'friend',
        'display_name': null,
        'avatar_url': null,
      });
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _DuplicateLookupHttpClient extends http.BaseClient {
  bool createdConversation = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      final userFilter = request.url.queryParameters['user_id'];
      final hasLimit = request.url.queryParameters.containsKey('limit');
      if (userFilter == 'eq.current-user') {
        return _jsonResponse(request, 200, [
          {'conversation_id': 'conv-old'},
          {'conversation_id': 'conv-new'},
        ]);
      }
      if (userFilter == 'eq.other-user' && hasLimit) {
        return _jsonResponse(request, 200, {'conversation_id': 'conv-old'});
      }
      if (userFilter == 'eq.other-user') {
        return _jsonResponse(request, 200, [
          {'conversation_id': 'conv-old'},
          {'conversation_id': 'conv-new'},
        ]);
      }
    }

    if (request.method == 'GET' && path.endsWith('/conversations')) {
      return _jsonResponse(request, 200, {
        'id': 'conv-new',
        'last_message_at': '2024-01-03T00:00:00.000Z',
      });
    }

    if (request.method == 'GET' && path.endsWith('/messages')) {
      return _jsonResponse(request, 200, {'conversation_id': 'conv-new'});
    }

    if (request.method == 'POST' && path.endsWith('/conversations')) {
      createdConversation = true;
      return _jsonResponse(request, 500, {'message': 'should not insert'});
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _DuplicateLookupWithEmptyLatestHttpClient extends http.BaseClient {
  bool createdConversation = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      final userFilter = request.url.queryParameters['user_id'];
      if (userFilter == 'eq.current-user' || userFilter == 'eq.other-user') {
        return _jsonResponse(request, 200, [
          {'conversation_id': 'conv-with-messages'},
          {'conversation_id': 'conv-empty'},
        ]);
      }
    }

    if (request.method == 'GET' && path.endsWith('/messages')) {
      return _jsonResponse(request, 200, {
        'conversation_id': 'conv-with-messages',
      });
    }

    if (request.method == 'GET' && path.endsWith('/conversations')) {
      return _jsonResponse(request, 200, {
        'id': 'conv-empty',
        'last_message_at': '2024-01-04T00:00:00.000Z',
      });
    }

    if (request.method == 'POST' && path.endsWith('/conversations')) {
      createdConversation = true;
      return _jsonResponse(request, 500, {'message': 'should not insert'});
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _NoConversationHttpClient extends http.BaseClient {
  bool createdConversation = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (request.method == 'GET' &&
        path.endsWith('/conversation_participants')) {
      return _jsonResponse(request, 200, <Map<String, dynamic>>[]);
    }

    if (request.method == 'POST' && path.endsWith('/conversations')) {
      createdConversation = true;
      return _jsonResponse(request, 500, {'message': 'should not insert'});
    }

    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _SendDirectMessageHttpClient extends http.BaseClient {
  int rpcCalls = 0;
  Map<String, dynamic>? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/rpc/send_direct_message')) {
      rpcCalls++;
      final body = request is http.Request ? request.body : '';
      if (body.isNotEmpty) {
        lastBody = jsonDecode(body) as Map<String, dynamic>;
      }
      return _jsonResponse(request, 200, {
        'conversation_id': 'conv-new',
        'message': {
          'id': 'msg-new',
          'conversation_id': 'conv-new',
          'sender_id': 'current-user',
          'body': lastBody?['message_body'],
          'shared_post_id': null,
          'created_at': '2024-01-02T00:00:00.000Z',
        },
      });
    }
    return _jsonResponse(request, 404, {'message': 'unexpected request'});
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    int statusCode,
    Object body,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _MessagesHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final select = request.url.queryParameters['select'] ?? '';
    final sender = {
      'username': null,
      'avatar_url': null,
      if (select.contains('display_name')) 'display_name': 'Friend User',
    };

    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode([
            {
              'id': 'msg-1',
              'conversation_id': 'conv-1',
              'sender_id': 'other-user',
              'body': 'Hello',
              'shared_post_id': null,
              'created_at': '2024-01-02T00:00:00.000Z',
              'sender': sender,
              'shared_post': null,
            },
          ]),
        ),
      ),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
