import 'package:flutter/foundation.dart';

bool get supportsMobileRecordings =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
