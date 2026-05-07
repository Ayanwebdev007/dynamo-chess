// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Registers HTML image factories for all chess pieces.
/// This allows us to use HtmlElementView to render pieces as native <img> tags,
/// bypassing Flutter's Canvas/Skia rendering which is failing in CPU-only mode.
void registerPieceImageFactories() {
  final pieces = ['king', 'queen', 'rook', 'bishop', 'knight', 'pawn', 'missile'];
  final colors = ['w', 'b'];

  for (final type in pieces) {
    for (final color in colors) {
      final viewType = 'piece_${type}_${color}';
      final assetPath = 'assets/pieces/${type}_${color}.png';

      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final img = html.ImageElement();
        img.src = '$assetPath?v=5'; // Cache bust v5
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = 'contain';
        img.style.pointerEvents = 'none'; // Click-through to Flutter
        
        // Resize Missile pieces as they appear too small
        if (type == 'missile') {
          img.style.transform = 'scale(1.35)';
        }
        
        return img;
      });
    }
  }
  
  // Also register Logo
  ui_web.platformViewRegistry.registerViewFactory('dynamo_logo', (int viewId) {
    final img = html.ImageElement();
    img.src = 'assets/dynamo_logo.png?v=3';
    img.style.width = '100%';
    img.style.height = '100%';
    img.style.objectFit = 'contain';
    img.style.pointerEvents = 'none';
    return img;
  });
}
