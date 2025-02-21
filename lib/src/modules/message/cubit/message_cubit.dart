import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:v_chat_sdk/src/enums/load_more_type.dart';
import 'package:v_chat_sdk/src/enums/room_type.dart';
import 'package:v_chat_sdk/src/services/notification_service.dart';
import '../../../enums/message_type.dart';
import '../../../enums/room_typing_type.dart';
import '../../../models/v_chat_message.dart';
import '../../../models/v_chat_message_attachment.dart';
import '../../../models/v_chat_room_typing.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/socket_service.dart';
import '../../../services/v_chat_app_service.dart';
import '../../../utils/api_utils/dio/custom_dio.dart';
import '../../../utils/custom_widgets/custom_alert_dialog.dart';
import '../../../utils/file_utils.dart';
import '../../rooms/cubit/room_cubit.dart';
import '../providers/message_provider.dart';
import '../providers/message_socket.dart';

part 'message_state.dart';

class MessageCubit extends Cubit<MessageState> with WidgetsBindingObserver {
  late MessageSocket _messageSocket;
  late String roomId;
  late bool isSingle;
  final getIt = GetIt.instance;

  ///init message socket to stop receive notifications from this user
  MessageCubit({required this.roomId}) : super(MessageInitial()) {
    getLocalMessages();
    _messageSocket = MessageSocket(
      currentRoomId: RoomCubit.instance.currentRoomId!,
      myId: VChatAppService.instance.vChatUser!.id,
      onNewMessage: onNewMessage,
      onAllMessages: onAllMessages,
    );
    textController.addListener(() {
      if (textController.text.isEmpty) {
        emitTypingChange(0);
      } else {
        emitTypingChange(1);
      }
    });
    WidgetsBinding.instance!.addObserver(this);
    NotificationService.instance.cancelAll();
    setListViewListener();
    isSingle =
        RoomCubit.instance.getRoomById(roomId).roomType == RoomType.single;
    urlPath = isSingle ? "message/single" : "message/group";

    // Helpers.vlog("MessageCubit init called room Id $roomId ${DateTime.now()}");
  }

  LoadMoreStatus loadingStatus = LoadMoreStatus.loaded;
  final textController = TextEditingController();
  bool isEmitTyping = false;
  final _messageApiProvider = MessageProvider();
  final messages = <VChatMessage>[];
  final scrollController = ScrollController();
  late String urlPath;

  ///get messages from sqlite
  Future<void> getLocalMessages() async {
    // Helpers.vlog("getLocalMessages Room Id is ${roomId}");
    final messages = await LocalStorageService.instance.getRoomMessages(roomId);
    if (messages.isEmpty) {
      emit(MessageLoading());
      return;
    }
    this.messages.clear();
    this.messages.addAll(messages);
    emit(MessageLoaded(messages));
  }

  ///lode more messages if top retched
  Future<void> loadMoreMessages() async {
    try {
      loadingStatus = LoadMoreStatus.loading;
      // final lastMsg = messages.reduce((curr, next) => curr.createdAt < next.createdAt? curr: next);
      final loadedMessages = await _messageApiProvider.loadMoreMessages(
        roomId,
        messages.last.id,
      );
      // Helpers.vlog("${messages.last.content}     From Load More");
      loadingStatus = LoadMoreStatus.loaded;
      if (loadedMessages.isEmpty) {
        ///if no more data stop the loading
        loadingStatus = LoadMoreStatus.completed;
      }
      messages.addAll(loadedMessages);
      emit(MessageLoaded(messages));
    } catch (err) {
      loadingStatus = LoadMoreStatus.completed;
    }
  }

  ///Emit text message to server
  Future sendTextMessage() async {
    try {
      if (!getIt.get<SocketService>().isConnected) {
        throw "Not connected to server yet";
      }
      unawaited(
        CustomDio().send(
          reqMethod: "POST",
          path: urlPath,
          body: {
            "type": MessageType.text.inString,
            "roomId": roomId,
            "content": textController.text
          },
        ),
      );

      textController.clear();
    } catch (err) {
      textController.text = textController.text;
      CustomAlert.error(msg: err.toString());
    }
  }

  /// insert new message to the list and update
  void onNewMessage(VChatMessage message) {
    if (messages.indexWhere((element) => element.id == message.id) == -1) {
      messages.insert(0, message);
      emit(MessageLoaded(messages));
    }
  }

  /// update all messages from server side last 20 message only
  void onAllMessages(List<VChatMessage> messages) {
    if (this.messages.isEmpty) {
      this.messages.addAll(messages);
    } else {
      for (final m in messages) {
        if (this.messages.indexWhere((element) => element.id == m.id) == -1) {
          this.messages.insert(0, m);
        }
      }
    }

    emit(MessageLoaded(messages));
  }

  ///Emit voice note
  Future sendVoiceNote(
    BuildContext context,
    String path,
    String duration,
  ) async {
    try {
      CustomAlert.customLoadingDialog(context: context);
      final voiceFile = File(path);
      final fileSize = FileUtils.getFileSize(voiceFile);
      if (!getIt.get<SocketService>().isConnected) {
        throw VChatAppService.instance
            .getTrans(context)
            .notConnectedToServerYet();
      }
      await FileUtils.uploadFile(
        [
          voiceFile,
        ],
        urlPath,
        body: {
          "roomId": roomId,
          "content": "This content voice 🎤",
          "type": MessageType.voice.inString,
          "attachment": jsonEncode(
            VChatMessageAttachment(
              fileSize: fileSize,
              fileDuration: duration,
            ).toMap(),
          )
        },
      );

      Navigator.pop(context);
    } catch (err) {
      Navigator.pop(context);
      CustomAlert.error(msg: err.toString());
      rethrow;
    }
  }

  /// 0 mean stop typing or recording
  /// 1 emit typing
  /// 2 emit recording
  void emitTypingChange(int type) {
    try {
      if (type == 0) {
        isEmitTyping = false;
      }
      if (!isEmitTyping) {
        final roomTyping = VChatRoomTyping(
          roomId: roomId,
          status: type == 0
              ? RoomTypingType.stop
              : type == 1
                  ? RoomTypingType.typing
                  : RoomTypingType.recording,
          name: VChatAppService.instance.vChatUser!.name,
        );
        getIt.get<SocketService>().emitTypingChange(roomTyping.toMap());
      }
      if (type == 1) {
        isEmitTyping = true;
      }
    } catch (err) {
      //
    }
  }

  ///Emit picked image after compress
  Future<void> sendImage(BuildContext context, String path) async {
    try {
      CustomAlert.customLoadingDialog(context: context);
      if (!getIt.get<SocketService>().isConnected) {
        throw "Not connected to server yet";
      }
      final _pickedImage = File(path);
      final compressedFile = await FileUtils.compressImage(_pickedImage);

      final properties =
          await FlutterNativeImage.getImageProperties(compressedFile.path);
      final fileSize = FileUtils.getFileSize(compressedFile);
      await FileUtils.uploadFile(
        [
          compressedFile,
        ],
        urlPath,
        body: {
          "roomId": roomId,
          "content": "This content image 📷",
          "type": MessageType.image.inString,
          "attachment": jsonEncode(
            VChatMessageAttachment(
              fileSize: fileSize,
              height: properties.height.toString(),
              width: properties.width.toString(),
            ).toMap(),
          )
        },
      );
      Navigator.pop(context);
    } catch (err) {
      Navigator.pop(context);
      CustomAlert.error(msg: err.toString());
      rethrow;
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _messageSocket.connectMessageSocket();
        break;
      case AppLifecycleState.inactive:
        _messageSocket.disconnect();
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void setListViewListener() {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final maxScrollExtent = scrollController.position.maxScrollExtent / 2;
    if (scrollController.offset > maxScrollExtent &&
        loadingStatus != LoadMoreStatus.loading &&
        loadingStatus != LoadMoreStatus.completed) {
      loadMoreMessages();
    }
  }

  ///close message name space socket so can receive notifications
  @override
  Future<void> close() async {
    _messageSocket.dispose();
    RoomCubit.instance.currentRoomId = null;
    scrollController.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    if (isEmitTyping) {
      emitTypingChange(0);
    }
    super.close();
  }

  Future<void> sendVideo(BuildContext context, String path) async {
    // final context = VChatAppService.instance.navKey!.currentContext!;
    try {
      CustomAlert.customLoadingDialog(context: context);
      final videoFile = File(path);
      final videoThumb = await FileUtils.getVideoThumb(videoFile);
      final properties =
          await FlutterNativeImage.getImageProperties(videoThumb.path);
      final d = await FileUtils.getVideoDuration(videoFile.path);
      final fileSize = FileUtils.getFileSize(videoFile);
      if (!getIt.get<SocketService>().isConnected) {
        throw VChatAppService.instance
            .getTrans(context)
            .notConnectedToServerYet();
      }
      await FileUtils.uploadFile(
        [videoThumb, videoFile],
        urlPath,
        body: {
          "roomId": roomId,
          "content": "This content video 📽",
          "type": MessageType.video.inString,
          "attachment": jsonEncode(
            VChatMessageAttachment(
              fileSize: fileSize,
              height: properties.height.toString(),
              width: properties.width.toString(),
              fileDuration: d,
            ).toMap(),
          )
        },
      );
      Navigator.pop(context);
      videoFile.deleteSync();
    } catch (err) {
      Navigator.pop(context);
      CustomAlert.error(msg: err.toString());
    }
  }

  Future<void> sendFile(BuildContext context, String path) async {
    try {
      CustomAlert.customLoadingDialog(context: context);

      final file = File(path);

      final fileSize = FileUtils.getFileSize(file);
      if (!getIt.get<SocketService>().isConnected) {
        throw VChatAppService.instance
            .getTrans(context)
            .notConnectedToServerYet();
      }
      await FileUtils.uploadFile(
        [
          file,
        ],
        urlPath,
        body: {
          "roomId": roomId,
          "content": "This content file 📁",
          "type": MessageType.file.inString,
          "attachment": jsonEncode(
            VChatMessageAttachment(
              fileSize: fileSize,
              linkTitle: basename(file.path),
            ).toMap(),
          )
        },
      );
      Navigator.pop(context);
      file.deleteSync();
    } catch (err) {
      Navigator.pop(context);
      CustomAlert.error(msg: err.toString());
    }
  }
}
