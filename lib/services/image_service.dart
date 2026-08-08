import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndSaveImage() async {
    // Abrir la galería
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return null;

    // Obtener carpeta privada de la aplicación
    final Directory appDir = await getApplicationDocumentsDirectory();

    // Crear carpeta photos si no existe
    final Directory photosDir = Directory(p.join(appDir.path, 'photos'));

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // Nombre único para la fotografía
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';

    final String newPath = p.join(photosDir.path, fileName);

    // Copiar la fotografía
    final File copiedImage = await File(image.path).copy(newPath);

    return copiedImage.path;
  }
}
