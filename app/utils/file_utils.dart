import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:flutter_video_info/flutter_video_info.dart';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/vchat_message_attachment.dart';
import '../services/vchat_app_service.dart';
import 'api_utils/dio/custom_dio.dart';
import 'api_utils/server_config.dart';
import 'custom_widgets/custom_alert_dialog.dart';
import 'helpers/dir_helper.dart';

class FileUtils {
  static Future newDownloadFile(
      BuildContext context, VchatMessageAttachment attachment) async {
    final downloadFile = await DirHelper.downloadPath();
    final file = File(downloadFile + attachment.playUrl.toString());
    if (file.existsSync()) {
      await OpenFile.open(file.path);
    } else {
      try {
        if (!(await Permission.storage.isGranted)) {
          CustomAlert.customAlertDialog(
              context: context,
              errorMessage:
                  "App Need this permission to save downloaded files in device storage /download/${ServerConfig.appName}/",
              dismissible: false,
              onPress: () async {
                Navigator.pop(context);
                final Map<Permission, PermissionStatus> statuses = await [
                  Permission.storage,
                ].request();

                if (statuses[Permission.storage] == PermissionStatus.granted) {
                  final cancelToken = CancelToken();
                  CustomAlert.customLoadingDialog(context: context);
                  await CustomDio().download(
                      path: ServerConfig.MESSAGES_BASE_URL +
                          attachment.playUrl.toString(),
                      cancelToken: cancelToken,
                      filePath: file.path);
                  Navigator.pop(context);
                  CustomAlert.done(
                      msg:
                          "File saved on device /download/${ServerConfig.appName}");
                  await OpenFile.open(file.path);
                } else {
                  Navigator.pop(context);
                }
              });
        } else {
          final cancelToken = CancelToken();
          CustomAlert.customLoadingDialog(context: context);
          await CustomDio().download(
              path: ServerConfig.MESSAGES_BASE_URL +
                  attachment.playUrl.toString(),
              cancelToken: cancelToken,
              filePath: file.path);
          Navigator.pop(context);
          CustomAlert.done(
              msg: "File saved on device /download/${ServerConfig.appName}");
          await OpenFile.open(file.path);
        }
      } catch (err) {
        Navigator.pop(context);
        rethrow;
      }
    }
  }

  static Future compressImage(File file) async {
    final ImageProperties properties =
        await FlutterNativeImage.getImageProperties(file.path);
    File compressedFile = file;
    if (file.lengthSync() > 150 * 1000) {
      // compress only images bigger than 150 kb
      compressedFile = await FlutterNativeImage.compressImage(file.path,
          quality: 100,
          targetWidth: 700,
          targetHeight: (properties.height! * 700 / properties.width!).round());
    }

    //  final compressFile = await _copyTheCompressImage(compressedFile);
    // file.deleteSync();
    return compressedFile;
  }

  static String getFileSize(File file, {int decimals = 2}) {
    final int bytes = file.lengthSync();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    final i = (log(bytes) / log(1000)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  static Future<File> getVideoThumb(File file) async {
    final uint8list = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.PNG,
      quality: 50,
      maxHeight: 600,
      maxWidth: 800,
      timeMs: 1,
    );
    final t = (await getTemporaryDirectory()).path;
    final String fileName =
        "IMG_THUMB_${DateTime.now().microsecondsSinceEpoch}.png";
    final newFile = File("$t$fileName");
    return await newFile.writeAsBytes(uint8list!);
  }

  static Future<String> getVideoDuration(String path) async {
    final videoInfo = FlutterVideoInfo();
    final info = await videoInfo.getVideoInfo(path);
    //  final info = await VideoCompress.getMediaInfo(path);
    return _printDuration(Duration(milliseconds: info!.duration!.round()));
  }

  static Future<dynamic> uploadFile(List<File> files, String endPoint,
      {Map<String, String>? body}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ServerConfig.SERVER_IP}$endPoint'),
    );

    for (final file in files) {
      request.files.add(
        http.MultipartFile(
          'file',
          file.readAsBytes().asStream(),
          file.lengthSync(),
          filename: basename(file.path),
        ),
      );
    }

    request.headers.addAll({
      "authorization": VChatAppService.to.vChatUser!.accessToken.toString()
    });
    if (body != null) {
      request.fields.addAll(body);
    }
    final stream = await request.send();
    final responseData = await stream.stream.toBytes();
    final responseString = String.fromCharCodes(responseData);
    return jsonDecode(responseString)['data'];
  }
}