import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:v_chat_sdk/src/services/socket_service.dart';

import '../../../../../services/v_chat_app_service.dart';
import '../../../../../utils/custom_widgets/custom_alert_dialog.dart';
import '../../../../../utils/custom_widgets/rounded_container.dart';
import '../../../../../utils/v_chat_config.dart';
import 'attachment_picker_widget.dart';
import 'message_filed.dart';
import 'message_recored_view.dart';

class VChatMessageInput extends StatefulWidget {
  final Function() onReceiveText;
  final Function(String path, String duration) onReceiveRecord;

  final Function(String path) onReceiveImage;
  final Function(String path) onReceiveVideo;
  final Function(String path) onReceiveFile;
  final Function() onStartRecording;
  final Function() onCancelRecord;
  final TextEditingController controller;

  const VChatMessageInput({
    Key? key,
    required this.controller,
    required this.onReceiveText,
    required this.onReceiveRecord,
    required this.onStartRecording,
    required this.onCancelRecord,
    required this.onReceiveImage,
    required this.onReceiveFile,
    required this.onReceiveVideo,
  }) : super(key: key);

  @override
  _VChatMessageInputState createState() => _VChatMessageInputState();
}

class _VChatMessageInputState extends State<VChatMessageInput> {
  bool isRecording = false;
  bool isTyping = false;
  final getIt = GetIt.instance;

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      widget.onStartRecording();
      return MessageRecordView(
        onReceiveRecord: (path, duration) {
          widget.onReceiveRecord(path, duration);
          if (getIt.get<SocketService>().isConnected) {
            setState(() {
              isRecording = false;
              isTyping = false;
            });
          }
        },
        onCancel: () {
          setState(() {
            isRecording = false;
            isTyping = false;
          });
          widget.onCancelRecord();
        },
      );
    }

    return SafeArea(
      child: Row(
        children: [
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: VChatAppService.instance.vcBuilder
                    .messageInputBackgroundColor(context),
              ),
              child: MessageFiled(
                controller: widget.controller,
                onChangeText: (txt) {
                  if (txt.isEmpty) {
                    isTyping = false;
                  } else {
                    isTyping = true;
                  }
                  setState(() {});
                },
                onAttachmentPressed: () async {
                  final res = await showCupertinoModalPopup(
                    barrierDismissible: true,
                    semanticsDismissible: true,
                    context: context,
                    builder: (context) {
                      return const AttachmentPickerWidget();
                    },
                  );
                  if (res != null) {
                    final type = res['type'] as String;
                    final path = res['path'] as String;
                    if (type == "photo") {
                      widget.onReceiveImage(path);
                    } else if (type == "file") {
                      widget.onReceiveFile(path);
                    } else if (type == "video") {
                      widget.onReceiveVideo(path);
                    }
                  }
                },
                onCameraPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    final t = VChatAppService.instance.getTrans(context);
                    if (File(pickedFile.path).lengthSync() >
                        VChatConfig.maxMessageFileSize) {
                      File(pickedFile.path).deleteSync();
                      CustomAlert.error(msg: t.fileIsTooBig());
                    }
                    widget.onReceiveImage(pickedFile.path);
                  }
                },
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          if (isTyping)
            InkWell(
              onTap: () async {
                widget.onReceiveText();

                setState(() {
                  isTyping = false;
                });
              },
              child: RoundedContainer(
                boxShape: BoxShape.circle,
                color: VChatAppService.instance.vcBuilder.sendButtonColor(
                  context,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
                height: 50,
                width: 50,
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
            )
          else
            InkWell(
              onLongPress: () {
                setState(() {
                  isRecording = true;
                  isTyping = false;
                });
              },
              onTap: () async {
                if (Platform.isIOS) {
                  final isGranted = await Record().hasPermission();
                  if (isGranted) {
                    setState(() {
                      isRecording = true;
                      isTyping = false;
                    });
                  } else {
                    CustomAlert.error(
                      msg: VChatAppService.instance
                          .getTrans(context)
                          .youShouldAcceptMicrophoneToUseVoiceMessage(),
                    );
                    await Permission.microphone.request();
                  }
                } else {
                  final isGranted =
                      await Permission.microphone.request().isGranted;

                  final isLimited =
                      await Permission.microphone.request().isLimited;
                  if (isGranted || isLimited) {
                    setState(() {
                      isRecording = true;
                      isTyping = false;
                    });
                  } else {
                    CustomAlert.error(
                      msg: VChatAppService.instance
                          .getTrans(context)
                          .youShouldAcceptMicrophoneToUseVoiceMessage(),
                    );
                  }
                }
              },
              child: RoundedContainer(
                boxShape: BoxShape.circle,
                color: VChatAppService.instance.vcBuilder.sendButtonColor(
                  context,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
                height: 50,
                width: 50,
                child: const Icon(
                  Icons.keyboard_voice_outlined,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(
            width: 10,
          ),
        ],
      ),
    );
  }
}
