import 'dart:io';

import 'package:http/http.dart' as http;

bool isNetworkException(Object error) {
  return error is SocketException || error is http.ClientException;
}
