import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/v_chat_message.dart';

import '../../../../utils/v_chat_config.dart';
import '../../../image_viewer/views/image_viewer_view.dart';

class MessageImageItem extends StatelessWidget {
  final VChatMessage _message;
  final bool isSender;

  const MessageImageItem(this._message, {Key? key, required this.isSender})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerView(
              VChatConfig.messagesMediaBaseUrl +
                  _message.messageAttachment!.imageUrl.toString(),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: isSender ? const Radius.circular(10) : Radius.zero,
          topRight: const Radius.circular(10),
          topLeft: const Radius.circular(10),
          bottomRight: isSender ? Radius.zero : const Radius.circular(10),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          height: double.parse(_message.messageAttachment!.height!),
          width: double.parse(_message.messageAttachment!.width!),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black26
              : Colors.grey[300],
          child: CachedNetworkImage(
            imageUrl: VChatConfig.messagesMediaBaseUrl +
                _message.messageAttachment!.imageUrl.toString(),
            fit: BoxFit.cover,
            progressIndicatorBuilder: (context, url, progress) =>
                const Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      ),
    );
  }
}
