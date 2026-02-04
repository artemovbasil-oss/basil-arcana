import 'package:http/http.dart' as http;

bool isNetworkException(Object error) {
  return error is http.ClientException;
}
