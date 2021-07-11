

import 'dart:async';

import 'package:chatwoot_client_sdk/chatwoot_callbacks.dart';
import 'package:chatwoot_client_sdk/data/chatwoot_repository.dart';
import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_contact.dart';
import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_conversation.dart';
import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_message.dart';
import 'package:chatwoot_client_sdk/data/local/entity/chatwoot_user.dart';
import 'package:chatwoot_client_sdk/data/local/local_storage.dart';
import 'package:chatwoot_client_sdk/data/remote/chatwoot_client_exception.dart';
import 'package:chatwoot_client_sdk/data/remote/requests/chatwoot_new_message_request.dart';
import 'package:chatwoot_client_sdk/data/remote/service/chatwoot_client_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chatwoot_repository_test.mocks.dart';
import 'local/local_storage_test.mocks.dart';


@GenerateMocks([
  LocalStorage,
  ChatwootClientService,
  ChatwootCallbacks,
  WebSocketChannel
])
void main() {

  group("Local Storage Tests", (){
    final testContact = ChatwootContact(
        id: 0,
        contactIdentifier: "contactIdentifier",
        pubsubToken: "pubsubToken",
        name: "name",
        email: "email"
    );

    final testConversation = ChatwootConversation(
        id: 0,
        inboxId: "",
        messages: "",
        contact: ""
    );
    final testUser = ChatwootUser(
        identifier: "identifier",
        identifierHash: "identifierHash",
        name: "name",
        email: "email",
        avatarUrl: "avatarUrl",
        customAttributes: {}
    );
    final testMessage = ChatwootMessage(
        id: "id",
        content: "content",
        messageType: "messageType",
        contentType: "contentType",
        contentAttributes: "contentAttributes",
        createdAt: DateTime.now().toString(),
        conversationId: "conversationId",
        attachments: [],
        sender: "sender"
    );

    final mockLocalStorage = MockLocalStorage();
    final mockChatwootClientService = MockChatwootClientService();
    final mockChatwootCallbacks = MockChatwootCallbacks();
    final mockMessagesDao = MockChatwootMessagesDao();
    final mockContactDao = MockChatwootContactDao();
    final mockConversationDao = MockChatwootConversationDao();
    final mockUserDao = MockChatwootUserDao();
    StreamController mockWebSocketStream = StreamController.broadcast();
    final mockWebSocketChannel = MockWebSocketChannel();

    late final ChatwootRepository repo;

    setUpAll((){

      when(mockLocalStorage.messagesDao).thenReturn(mockMessagesDao);
      when(mockLocalStorage.contactDao).thenReturn(mockContactDao);
      when(mockLocalStorage.userDao).thenReturn(mockUserDao);
      when(mockLocalStorage.conversationDao).thenReturn(mockConversationDao);
      when(mockChatwootClientService.connection).thenReturn(mockWebSocketChannel);
      when(mockWebSocketChannel.stream).thenAnswer((_)=>mockWebSocketStream.stream);
      when(mockChatwootClientService.startWebSocketConnection(any)).thenAnswer((_)=>(){});

      repo = ChatwootRepositoryImpl(
        clientService: mockChatwootClientService,
        localStorage: mockLocalStorage,
        streamCallbacks: mockChatwootCallbacks
      );
    });

    setUp((){
      reset(mockChatwootCallbacks);
      reset(mockContactDao);
      reset(mockConversationDao);
      reset(mockUserDao);
      reset(mockMessagesDao);
      when(mockContactDao.getContact()).thenReturn(testContact);
      mockWebSocketStream = StreamController.broadcast();
      when(mockWebSocketChannel.stream).thenAnswer((_)=>mockWebSocketStream.stream);
    });

    test('Given messages are successfully fetched when getMessages is called, then callback should be called with fetched messages', () async{

      //GIVEN
      final testMessages = [testMessage];
      when(mockChatwootClientService.getAllMessages()).thenAnswer((_)=>Future.value(testMessages));
      when(mockChatwootCallbacks.onMessagesRetrieved).thenAnswer((_)=>(_){});
      when(mockMessagesDao.saveAllMessages(any)).thenAnswer((_)=>Future.microtask((){}));

      //WHEN
      await repo.getMessages();

      //THEN
      verify(mockChatwootClientService.getAllMessages());
      verify(mockChatwootCallbacks.onMessagesRetrieved?.call(testMessages));
      verify(mockMessagesDao.saveAllMessages(testMessages));
    });

    test('Given messages are fails to fetch when getMessages is called, then callback should be called with an error', () async{

      //GIVEN
      final testError = ChatwootClientException("error",ChatwootClientExceptionType.GET_MESSAGES_FAILED);
      when(mockChatwootClientService.getAllMessages()).thenThrow(testError);
      when(mockChatwootCallbacks.onError).thenAnswer((_)=>(_){});
      when(mockChatwootCallbacks.onMessagesRetrieved).thenAnswer((_)=>(_){});

      //WHEN
      await repo.getMessages();

      //THEN
      verify(mockChatwootClientService.getAllMessages());
      verifyNever(mockChatwootCallbacks.onMessagesRetrieved);
      verify(mockChatwootCallbacks.onError?.call(testError));
      verifyNever(mockMessagesDao.saveAllMessages(any));
    });

    test('Given persisted messages are successfully fetched when getPersitedMessages is called, then callback should be called with fetched messages', () async{

      //GIVEN
      final testMessages = [testMessage];
      when(mockMessagesDao.getMessages()).thenReturn(testMessages);
      when(mockChatwootCallbacks.onPersistedMessagesRetrieved).thenAnswer((_)=>(_){});

      //WHEN
      repo.getPersistedMessages();

      //THEN
      verifyNever(mockChatwootClientService.getAllMessages());
      verify(mockChatwootCallbacks.onPersistedMessagesRetrieved?.call(testMessages));
    });

    test('Given message is successfully sent when sendMessage is called, then callback should be called with sent message', () async{

      //GIVEN
      final messageRequest = ChatwootNewMessageRequest(content: "new message", echoId: "echoId");
      when(mockChatwootClientService.createMessage(any)).thenAnswer((_)=>Future.value(testMessage));
      when(mockChatwootCallbacks.onMessageSent).thenAnswer((_)=>(_,__){});
      when(mockMessagesDao.saveMessage(any)).thenAnswer((_)=>Future.microtask((){}));

      //WHEN
      await repo.sendMessage(messageRequest);

      //THEN
      verify(mockChatwootClientService.createMessage(messageRequest));
      verify(mockChatwootCallbacks.onMessageSent?.call(testMessage,messageRequest.echoId));
      verify(mockMessagesDao.saveMessage(testMessage));
    });

    test('Given message fails to send when sendMessage is called, then callback should be called with an error', () async{

      //GIVEN
      final testError = ChatwootClientException("error",ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
      final messageRequest = ChatwootNewMessageRequest(content: "new message", echoId: "echoId");
      when(mockChatwootClientService.createMessage(any)).thenThrow(testError);
      when(mockChatwootCallbacks.onError).thenAnswer((_)=>(_){});

      //WHEN
      await repo.sendMessage(messageRequest);

      //THEN
      verify(mockChatwootClientService.createMessage(messageRequest));
      verify(mockChatwootCallbacks.onError?.call(testError));
      verifyNever(mockMessagesDao.saveMessage(any));
    });

    test('Given repo is initialized successfully when initialize is called, then client should be properly initialized', () async{

      //GIVEN
      when(mockChatwootClientService.getContact()).thenAnswer((_)=>Future.value(testContact));
      when(mockContactDao.getContact()).thenReturn(testContact);
      when(mockChatwootClientService.getConversations()).thenAnswer((_)=>Future.value([testConversation]));
      when(mockUserDao.saveUser(any)).thenAnswer((_)=>Future.microtask((){}));
      when(mockContactDao.saveContact(any)).thenAnswer((_)=>Future.microtask((){}));
      when(mockConversationDao.saveConversation(any)).thenAnswer((_)=>Future.microtask((){}));
      when(mockChatwootClientService.startWebSocketConnection(any)).thenAnswer((_)=>(){});

      //WHEN
      await repo.initialize(testUser);

      //THEN
      verify(mockLocalStorage.openDB());
      verify(mockUserDao.saveUser(testUser));
      verify(mockContactDao.saveContact(testContact));
      verify(mockConversationDao.saveConversation(testConversation));
    });

    test('Given welcome event is received when listening for events, then callback welcome event should be triggered', () async{

      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});
      when(mockChatwootCallbacks.onWelcome).thenAnswer((_)=>(_){});
      final dynamic welcomeEvent = {
        "type":"welcome"
      };
      repo.listenForEvents();

      //WHEN
      repo.listenForEvents();
      mockWebSocketStream.add(welcomeEvent);
      await Future.delayed(Duration(seconds: 1));

      //THEN
      verify(mockChatwootCallbacks.onWelcome?.call(welcomeEvent));
      repo.dispose();
    });

    test('Given ping event is received when listening for events, then callback onPing event should be triggered', () async{

      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});
      when(mockChatwootCallbacks.onPing).thenAnswer((_)=>(_){});
      final dynamic pingEvent = {
        "type":"ping"
      };
      repo.listenForEvents();

      //WHEN
      mockWebSocketStream.add(pingEvent);
      await Future.delayed(Duration(seconds: 1));

      //THEN
      verify(mockChatwootCallbacks.onPing?.call(pingEvent));
      repo.dispose();
    });

    test('Given confirm subscription event is received when listening for events, then callback onConfirmSubscription event should be triggered', () async{

      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});
      when(mockChatwootCallbacks.onConfirmedSubscription).thenAnswer((_)=>(_){});
      final dynamic confirmSubscriptionEvent = {
        "type":"confirm_subscription"
      };
      repo.listenForEvents();

      //WHEN
      repo.listenForEvents();
      mockWebSocketStream.add(confirmSubscriptionEvent);
      await Future.delayed(Duration(seconds: 1));

      //THEN
      verify(mockChatwootCallbacks.onConfirmedSubscription?.call(confirmSubscriptionEvent));
      repo.dispose();
    });

    test('Given new message event is received when listening for events, then callback onMessageReceived event should be triggered', () async{

      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});
      when(mockChatwootCallbacks.onMessageReceived).thenAnswer((_)=>(_){});
      final dynamic messageReceivedEvent = {
        "type":"message",
        "message":{
          "event":"message.created",
          "data":{
            "id": "id",
            "content": "content",
            "message_type": "0",
            "content_type": "contentType",
            "content_attributes": "contentAttributes",
            "created_at": DateTime.now().toString(),
            "conversation_id": "conversationId",
            "attachments": [],
            "sender": "sender"
          }
        }
      };

      repo.listenForEvents();

      //WHEN
      repo.listenForEvents();
      mockWebSocketStream.add(messageReceivedEvent);
      await Future.delayed(Duration(seconds: 1));

      //THEN
      final message = ChatwootMessage.fromJson(messageReceivedEvent["message"]["data"]);
      verify(mockChatwootCallbacks.onMessageReceived?.call(message));
      repo.dispose();
    });

    test('Given new message event is sent when listening for events, then callback onMessageSent event should be triggered', () async{

      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});
      when(mockChatwootCallbacks.onMessageDelivered).thenAnswer((_)=>(_,__){});
      final dynamic messageSentEvent = {
        "type":"message",
        "message":{
          "event":"message.created",
          "echo_id": "echoId",
          "data":{
            "id": "id",
            "content": "content",
            "message_type": "1",
            "content_type": "contentType",
            "content_attributes": "contentAttributes",
            "created_at": DateTime.now().toString(),
            "conversation_id": "conversationId",
            "attachments": [],
            "sender": "sender"
          }
        }
      };

      repo.listenForEvents();

      //WHEN
      mockWebSocketStream.add(messageSentEvent);
      await Future.delayed(Duration(seconds: 1));

      //THEN
      final message = ChatwootMessage.fromJson(messageSentEvent["message"]["data"]);
      verify(mockChatwootCallbacks.onMessageDelivered?.call(message,messageSentEvent["message"]["echo_id"]));
      repo.dispose();
    });



    test('Given unknown event is received when listening for events, then no callback event should be triggered', () async{

      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});
      final dynamic welcomeEvent = {
        "type":"unknown"
      };
      repo.listenForEvents();

      //WHEN
      mockWebSocketStream.add(welcomeEvent);
      await Future.delayed(Duration(seconds: 1));

      //THEN
      verifyZeroInteractions(mockChatwootCallbacks);
      repo.dispose();
    });

    test('Given repository is successfully disposed when dispose is called, then localStorage should be disposed', () {
      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});

      //WHEN
      repo.dispose();

      //THEN
      verify(mockLocalStorage.dispose());
    });

    test('Given repository is successfully cleared when clear is called, then localStorage should be cleared', () {
      //GIVEN
      when(mockLocalStorage.dispose()).thenAnswer((_)=>(_){});

      //WHEN
      repo.clear();

      //THEN
      verify(mockLocalStorage.clear());
    });

    tearDown(()async{
      await mockWebSocketStream.close();
    });

  });


}