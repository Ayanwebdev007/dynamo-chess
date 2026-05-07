/// Stub for non-web platforms (Android/iOS) where dart:html is not available.
/// This file allows the code to compile on mobile by providing a no-op implementation.

void registerPieceImageFactories() {
  // No-op on mobile.
  // We don't use HtmlElementView on mobile, so we don't need to register factories.
}
