import 'package:surf_practice_chat_flutter/features/chat/exceptions/invalid_message_exception.dart';
import 'package:surf_practice_chat_flutter/features/chat/exceptions/user_not_found_exception.dart';
import 'package:surf_practice_chat_flutter/features/chat/models/chat_geolocation_geolocation_dto.dart';
import 'package:surf_practice_chat_flutter/features/chat/models/chat_message_dto.dart';
import 'package:surf_practice_chat_flutter/features/chat/models/chat_message_location_dto.dart';
import 'package:surf_practice_chat_flutter/features/chat/models/chat_user_dto.dart';
import 'package:surf_practice_chat_flutter/features/chat/models/chat_user_local_dto.dart';
import 'package:surf_study_jam/surf_study_jam.dart';

/// Basic interface of chat features.
///
/// The only tool needed to implement the chat.
abstract class IChatRepository {
  /// Maximum length of one's message content,
  static const int maxMessageLength = 200;

  /// Returns messages [ChatMessageDto] from a source.
  ///
  /// Pay your attentions that there are two types of authors: [ChatUserDto]
  /// and [ChatUserLocalDto]. Second one representing message from user with
  /// the same name that you specified in [sendMessage].
  ///
  /// Throws an [Exception] when some error appears.
  Future<Iterable<ChatMessageDto>> getMessages(int? chatId);

  /// Sends the message by with [message] content.
  ///
  /// Returns actual messages [ChatMessageDto] from a source (given your sent
  /// [message]).
  ///
  ///
  /// [message] mustn't be empty and longer than [maxMessageLength]. Throws an
  /// [InvalidMessageException].
  Future<Iterable<ChatMessageDto>> sendMessage(String message, int? chatId);

  /// Sends the message by [location] contents. [message] is optional.
  ///
  /// Returns actual messages [ChatMessageDto] from a source (given your sent
  /// [message]). Message with location point returns as
  /// [ChatMessageGeolocationDto].
  ///
  /// Throws an [Exception] when some error appears.
  ///
  ///
  /// If [message] is non-null, content mustn't be empty and longer than
  /// [maxMessageLength]. Throws an [InvalidMessageException].
  Future<Iterable<ChatMessageDto>> sendGeolocationMessage({
    required ChatGeolocationDto location,
    String? message,
    required int chatId,
  });

  /// Retrieves chat's user via his [userId].
  ///
  ///
  /// Throws an [UserNotFoundException] if user does not exist.
  ///
  /// Throws an [Exception] when some error appears.
  Future<ChatUserDto> getUser(int userId);
}

class ChatRepository implements IChatRepository {
  ChatRepository(this._studyJamClient);

  final StudyJamClient _studyJamClient;

  @override
  Future<Iterable<ChatMessageDto>> getMessages(int? chatId) async {
    final Iterable<ChatMessageDto> messages = await _fetchAllMessages(chatId);

    return messages;
  }

  @override
  Future<Iterable<ChatMessageDto>> sendMessage(
    String message,
    int? chatId,
  ) async {
    if (message.length > IChatRepository.maxMessageLength) {
      throw InvalidMessageException('Message "$message" is too large.');
    }
    await _studyJamClient.sendMessage(
      SjMessageSendsDto(
        text: message,
        chatId: chatId,
      ),
    );

    final Iterable<ChatMessageDto> messages = await _fetchAllMessages(chatId);

    return messages;
  }

  @override
  Future<Iterable<ChatMessageDto>> sendGeolocationMessage({
    required ChatGeolocationDto location,
    String? message,
    int? chatId,
  }) async {
    if (message != null && message.length > IChatRepository.maxMessageLength) {
      throw InvalidMessageException('Message "$message" is too large.');
    }
    await _studyJamClient.sendMessage(
      SjMessageSendsDto(
        text: message,
        geopoint: location.toGeopoint(),
        chatId: chatId,
      ),
    );

    final Iterable<ChatMessageDto> messages = await _fetchAllMessages(chatId);

    return messages;
  }

  @override
  Future<ChatUserDto> getUser(int userId) async {
    final SjUserDto? user = await _studyJamClient.getUser(userId);
    if (user == null) {
      throw UserNotFoundException('User with id $userId had not been found.');
    }
    final SjUserDto? localUser = await _studyJamClient.getUser();
    return localUser?.id == user.id
        ? ChatUserLocalDto.fromSJClient(user)
        : ChatUserDto.fromSJClient(user);
  }

  Future<Iterable<ChatMessageDto>> _fetchAllMessages(int? chatId) async {
    final List<SjMessageDto> messages = <SjMessageDto>[];

    bool isLimitBroken = false;
    int lastMessageId = 0;

    // Chat is loaded in a 10 000 messages batches. It takes several batches to
    // load chat completely, especially if there's a lot of messages. Due to
    // API-request limitations, we can't load everything at one request, so
    // we're doing it in cycle.
    while (!isLimitBroken) {
      final List<SjMessageDto> batch = await _studyJamClient.getMessages(
        chatId: chatId,
        lastMessageId: lastMessageId,
        limit: 10000,
      );
      messages.addAll(batch);
      lastMessageId = batch.last.chatId;
      if (batch.length < 10000) {
        isLimitBroken = true;
      }
    }

    // Message ID : User ID
    final Map<int, int> messagesWithUsers = <int, int>{};
    for (final SjMessageDto message in messages) {
      messagesWithUsers[message.id] = message.userId;
    }
    final List<SjUserDto> users = await _studyJamClient
        .getUsers(messagesWithUsers.values.toSet().toList());
    final SjUserDto? localUser = await _studyJamClient.getUser();

    return messages
        .map(
          (SjMessageDto sjMessageDto) => sjMessageDto.geopoint == null
              ? ChatMessageDto.fromSJClient(
                  sjMessageDto: sjMessageDto,
                  sjUserDto: users.firstWhere(
                    (SjUserDto userDto) => userDto.id == sjMessageDto.userId,
                  ),
                  isUserLocal: users
                          .firstWhere(
                            (SjUserDto userDto) =>
                                userDto.id == sjMessageDto.userId,
                          )
                          .id ==
                      localUser?.id,
                )
              : ChatMessageGeolocationDto.fromSJClient(
                  sjMessageDto: sjMessageDto,
                  sjUserDto: users.firstWhere(
                    (SjUserDto userDto) => userDto.id == sjMessageDto.userId,
                  ),
                ),
        )
        .toList();
  }
}
