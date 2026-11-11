import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Versioned, lossless chunks. Bounds apply before JSON parsing and inflation.
class RecordingChunkCodec {
  static const version = 1;
  static const maxRows = 1000;
  static const maxCompressedBytes = 1024 * 1024;
  static const maxDecodedBytes = 4 * 1024 * 1024;

  static Future<Uint8List> encodeAsync(List<Map<String, dynamic>> rows) =>
      compute(encode, rows);
  static Future<List<Map<String, dynamic>>> decodeAsync(
    Uint8List bytes, {
    required String expectedChecksum,
    required int expectedRows,
  }) => compute(_decodeRequest, {
    'bytes': bytes,
    'checksum': expectedChecksum,
    'count': expectedRows,
  });
  static List<Map<String, dynamic>> _decodeRequest(
    Map<String, dynamic> request,
  ) => decode(
    request['bytes'] as Uint8List,
    expectedChecksum: request['checksum'] as String,
    expectedRows: request['count'] as int,
  );

  static Uint8List encode(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty || rows.length > maxRows) {
      throw ArgumentError('A chunk must contain 1–1000 readings.');
    }
    final plain = utf8.encode(jsonEncode({'version': version, 'rows': rows}));
    if (plain.length > maxDecodedBytes) {
      throw ArgumentError('Recording chunk is too large.');
    }
    final result = Uint8List.fromList(gzip.encode(plain));
    if (result.length > maxCompressedBytes) {
      throw ArgumentError('Compressed recording chunk is too large.');
    }
    return result;
  }

  static String checksum(List<int> bytes) => sha256.convert(bytes).toString();

  static List<Map<String, dynamic>> decode(
    Uint8List bytes, {
    required String expectedChecksum,
    required int expectedRows,
  }) {
    if (bytes.length > maxCompressedBytes ||
        checksum(bytes) != expectedChecksum ||
        expectedRows < 1 ||
        expectedRows > maxRows) {
      throw const FormatException('Recording chunk failed integrity checks.');
    }
    // Chunked conversion rejects a zip bomb while it is expanding, before a
    // full decompressed allocation or JSON tree can be created.
    final output = _BoundedBytes(maxDecodedBytes);
    final decoder = gzip.decoder.startChunkedConversion(output);
    decoder.add(bytes);
    decoder.close();
    final data = jsonDecode(utf8.decode(output.bytes.takeBytes()));
    if (data is! Map || data['version'] != version || data['rows'] is! List) {
      throw const FormatException('Unknown recording chunk format.');
    }
    final rows = (data['rows'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rows.length != expectedRows) {
      throw const FormatException('Recording chunk sample count differs.');
    }
    return rows;
  }
}

class _BoundedBytes implements Sink<List<int>> {
  final int limit;
  final bytes = BytesBuilder(copy: false);
  int length = 0;
  _BoundedBytes(this.limit);
  @override
  void add(List<int> data) {
    length += data.length;
    if (length > limit) {
      throw const FormatException('Decompressed recording exceeds its limit.');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
