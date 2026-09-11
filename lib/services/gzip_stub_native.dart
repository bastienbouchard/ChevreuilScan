import 'dart:convert';
import 'dart:io';

Future<String> decompressGzip(List<int> bytes) async {
  return utf8.decode(gzip.decode(bytes));
}
