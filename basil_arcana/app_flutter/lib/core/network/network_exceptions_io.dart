import 'dart:io';

bool isSocketExceptionImpl(Object error) => error is SocketException;
