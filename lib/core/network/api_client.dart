import 'package:carcare_service/core/network/token_interceptor.dart';
import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        responseType: ResponseType.json,
        baseUrl: dotenv.env['BASE_URL']!,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ),
    );

    _dio.interceptors.add(TokenInterceptor(dio));
    _dio.interceptors.add(WorkingBranchInterceptor());
    if (kDebugMode) _dio.interceptors.add(_DebugLogInterceptor());
  }
  Dio get dio => _dio;
}

Future<Response?> api(
  Api method,
  String endpoint, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
  bool skipAuthenticaor = true,
}) async {
  try {
    final apiService = ApiService.instance;
    return await apiService.dio.request(
      endpoint,
      data: body,
      options: Options(
        // validateStatus: (status) {
        //   if (status != null && status < 500) {
        //     return false;
        //   }
        //   return true;
        // },
        method: method.name.toUpperCase(),
      ),
    );
  } on DioException catch (e) {
    _handleDioError(e);
    return null;
  }
}

void _handleDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      print('Түр хүлээнэ үү!');
      break;

    case DioExceptionType.connectionError:
      print('Серверт холбогдож чадсангүй, Инфосистемс ХХК-д холбогдоно уу!');
      break;

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      print(e.response!.data);
      if (statusCode == 500) {
        messageError('Серверийн алдаа гарлаа!');
      } else if (statusCode == 400) {
        messageError(
          e.response != null
              ? (e.response!.data['error'] != null
                    ? e.response!.data['error'].toString()
                    : "Амжилтгүй")
              : "Амжилтгүй",
        );
      } else if (statusCode == 404) {
        if (e.response != null) {
          print(e.response!.data);
        }
        messageError('Мэдээлэл олдсонгүй!');
      } else if (statusCode == 405) {
        print(e.response?.data ?? "null res");
        messageError('Мэдээлэл олдсонгүй!');
      } else {
        if (e.requestOptions.uri.path.contains('logout')) {
          break;
        }
        // print(e.response!.data);
        messageWarning('${e.response?.data?['error'] ?? 'Алдаа гарлаа'}');
        // message('Bad response');
      }
      break;

    case DioExceptionType.cancel:
      // debugPrint('Request cancelled');
      break;

    default:
      messageError('Алдаа гарлаа: ${e.message}');
  }
}

enum Api { get, post, patch, delete, put }

// Error-г AppError болгон шидэнэ — repository-д ашиглана.
// api() дуудлагаас ялгаатай нь toast харуулахгүй.
Future<Response> apiOrThrow(Api method, String endpoint, {dynamic body}) async {
  try {
    return await ApiService.instance.dio.request(
      endpoint,
      data: body,
      options: Options(method: method.name.toUpperCase()),
    );
  } on DioException catch (e) {
    throw mapDioException(e);
  }
}

class _DebugLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    if (options.data != null) debugPrint('  body: ${options.data}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('  body: ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('✗ ${err.response?.statusCode} ${err.requestOptions.uri}');
    if (err.response?.data != null) debugPrint('  body: ${err.response?.data}');
    handler.next(err);
  }
}

// Future<void> toUrl(String url) async {
//   try {
//     await launchUrl(Uri.parse(url));
//   } catch (e) {
//     // final canLaunch = await canLaunchUrl(Uri.parse(url));
//     // if (!canLaunch) {

//     //   throw Exception('Could not launch $url');
//     // }
//     messageError('Холбоос олдсонгүй');
//   }
// }
