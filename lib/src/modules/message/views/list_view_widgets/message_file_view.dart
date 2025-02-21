import 'package:flutter/material.dart';
import '../../../../models/v_chat_message.dart';
import '../../../../services/v_chat_app_service.dart';
import '../../../../utils/file_utils.dart';

class MessageFileView extends StatelessWidget {
  final VChatMessage _message;
  final bool isSender;
  final myId = VChatAppService.instance.vChatUser!.id;

  MessageFileView(this._message, {Key? key, required this.isSender})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final att = _message.messageAttachment!;

    return InkWell(
      onTap: () {
        FileUtils.newDownloadFile(context, att);
      },
      child: isSender
          ? VChatAppService.instance.vcBuilder.senderFileMessageWidget(
              context,
              att.linkTitle!,
              att.fileSize!,
            )
          : VChatAppService.instance.vcBuilder.receiverFileMessageWidget(
              context,
              att.linkTitle!,
              att.fileSize!,
            ),
    );
  }
}
