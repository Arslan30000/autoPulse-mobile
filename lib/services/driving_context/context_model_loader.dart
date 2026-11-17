import 'dart:convert';

import 'package:flutter/services.dart';

import 'context_evaluator.dart';

/// Only packaged, explicitly selected artifacts can replace the rules baseline.
/// Training/experimental outputs are never discovered from arbitrary disk paths.
class ContextModelLoader {
  static Future<ForestContextEvaluator?> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final registry = jsonDecode(
      await assets.loadString('assets/ml/registry.json'),
    ) as Map<String, dynamic>;
    if (registry['schema_version'] != 1) {
      throw const FormatException('Invalid ML registry');
    }
    final path = registry['driving_context'];
    if (path == null) return null;
    if (path is! String ||
        !RegExp(r'^assets/ml/driving_context/[a-zA-Z0-9_-]+\.json$')
            .hasMatch(path)) {
      throw const FormatException('Invalid context asset path');
    }
    final json = await assets.loadString(path);
    final metadata = jsonDecode(json) as Map<String, dynamic>;
    final provenance = metadata['provenance'];
    if (provenance is! Map ||
        provenance['synthetic_test_only'] == true ||
        provenance['not_for_deployment'] == true) {
      throw const FormatException('Test artifacts cannot be deployed');
    }
    return ForestContextEvaluator.fromJson(
      json,
      allowExperimental: registry['allow_experimental_driving_context'] == true,
    );
  }
}
