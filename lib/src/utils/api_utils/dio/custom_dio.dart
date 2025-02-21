import 'dart:io';
import 'package:dio/dio.dart';
import '../../../services/v_chat_app_service.dart';
import '../../helpers/helpers.dart';
import '../../v_chat_config.dart';
import 'v_chat_sdk_exception.dart';

class CustomDio {
  final vChatController = VChatAppService.instance;
  late Dio dio;

  CustomDio() {
    dio = Dio();
    dio.options.baseUrl = VChatConfig.serverBaseUrl;
    dio.options.validateStatus = (_) => true;
    dio.options.followRedirects = false;
    dio.options.headers = {
      'authorization': vChatController.vChatUser != null
          ? "Bearer ${vChatController.vChatUser!.accessToken}"
          : "Bearer xxx",
      "Accept-Language": vChatController.currentLocal
    };
    //  print(vChatController.vChatUser!.accessToken.toString());

    dio.options.sendTimeout = 10000;
    dio.options.receiveTimeout = 10000;
    dio.options.connectTimeout = 10000;
    // print("Send request ${vChatController.vChatUser!.accessToken}");
    // if (!kReleaseMode) {
    //   dio.interceptors.add(PrettyDioLogger(
    //     requestHeader: true,
    //     requestBody: true,
    //     responseBody: true,
    //     error: true,
    //
    //     maxWidth: 100,
    //   ));
    // }
  }

  Future<Response> uploadFile({
    required String apiEndPoint,
    required String filePath,
    bool isPost = true,
    void Function(int received, int total)? sendProgress,
    List<Map<String, String>>? body,
    CancelToken? cancelToken,
  }) async {
    final File file = File(filePath);
    final String fileName = Helpers.baseName(file.path);
    final FormData data = FormData.fromMap({
      "file": await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });
    if (body != null) {
      final x = body.map((e) => MapEntry(e.keys.first, e.values.first));
      data.fields.addAll(x);
    }
    late Response response;
    if (isPost) {
      response = await dio.post(
        apiEndPoint,
        data: data,
        onSendProgress: sendProgress,
        cancelToken: cancelToken,
      );
    } else {
      response = await dio.patch(
        apiEndPoint,
        data: data,
        onSendProgress: sendProgress,
        cancelToken: cancelToken,
      );
    }

    throwIfNoSuccess(response);
    return response;
  }

  Future<Response> send({
    required String reqMethod,
    required String path,
    Function(int count, int total)? onSendProgress,
    Function(int count, int total)? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
    String? saveDirPath,
  }) async {
    late Response res;

    final _body = {}..addAll(body);
    final _query = {}..addAll(query);

    try {
      switch (reqMethod.toUpperCase()) {
        case 'GET':
          res = await dio.get(
            path,
            cancelToken: cancelToken,
            queryParameters: _query.cast(),
          );
          break;
        case 'POST':
          res = await dio.post(
            path,
            data: _body.cast(),
            onReceiveProgress: onReceiveProgress,
            onSendProgress: onSendProgress,
            cancelToken: cancelToken,
            queryParameters: _query.cast(),
          );
          break;
        case 'PUT':
          res = await dio.put(
            path,
            data: _body.cast(),
            onSendProgress: onSendProgress,
            onReceiveProgress: onReceiveProgress,
            cancelToken: cancelToken,
            queryParameters: _query.cast(),
          );
          break;
        case 'PATCH':
          res = await dio.patch(
            path,
            data: _body.cast(),
            onSendProgress: onSendProgress,
            onReceiveProgress: onReceiveProgress,
            cancelToken: cancelToken,
            queryParameters: _query.cast(),
          );
          break;
        case 'DELETE':
          res = await dio.delete(
            path,
            data: _body.cast(),
            cancelToken: cancelToken,
            queryParameters: _query.cast(),
          );
          break;

        case 'DOWNLOAD':
          res = await dio.download(
            path,
            saveDirPath,
            cancelToken: cancelToken,
            onReceiveProgress: onReceiveProgress,
            queryParameters: _query.cast(),
          );

          break;
        default:
          throw "reqMethod Not available !";
      }

      throwIfNoSuccess(res);

      return res;
    } on DioError catch (err) {
      if (err.type == DioErrorType.other ||
          err.type == DioErrorType.connectTimeout ||
          err.type == DioErrorType.receiveTimeout) {
        throw VChatSdkException(
          "Check your internet connection and try again ",
        );
      } else {
        throw VChatSdkException(res.data.toString());
      }
    } catch (err) {
      rethrow;
    } finally {
      dio.close();
    }
  }

  void throwIfNoSuccess(Response response) {
    if (response.statusCode! > 300) {
      final errorMsg = response.data['data'].toString();
      throw VChatSdkException(errorMsg);
    }
  }

  Future<Response> download({
    required String path,
    void Function(int received, int total)? sendProgress,
    required String filePath,
    CancelToken? cancelToken,
  }) async {
    final res = await dio.download(
      path,
      filePath,
      cancelToken: cancelToken,
      onReceiveProgress: sendProgress,
    );
    return res;
  }
}
