import 'dart:io';

import 'package:image/image.dart';

void main() {
  final file = File('assets/app_icon.png');
  if (!file.existsSync()) {
    stdout.writeln('File not found');
    return;
  }

  final image = decodeImage(file.readAsBytesSync());
  if (image == null) {
    stdout.writeln('Could not decode image');
    return;
  }

  int maxDim = image.width > image.height ? image.width : image.height;

  // Create a new blank square image with transparent background
  final newImage = Image(width: maxDim, height: maxDim, numChannels: 4);

  // Calculate offsets to center the original image
  int offsetX = (maxDim - image.width) ~/ 2;
  int offsetY = (maxDim - image.height) ~/ 2;

  // Composite the original image onto the center of the new image
  compositeImage(newImage, image, dstX: offsetX, dstY: offsetY);

  file.writeAsBytesSync(encodePng(newImage));
  stdout.writeln('Image padded successfully to \${maxDim}x\${maxDim}');
}
