import 'package:flutter/material.dart';

/// Renders an admin/courier-supplied image URL when present, otherwise
/// falls back to a bundled default asset — and falls back again to the
/// asset if the URL turns out to be broken/unreachable, so a bad image
/// link someone pastes can never blank out part of a live page.
///
/// Shared by the public landing page (Site Content editor) and the
/// per-courier customer login page (Customization tab) — anywhere a
/// user-supplied image URL with a safe fallback is needed.
class AdaptiveImage extends StatelessWidget {
  final String? url;
  final String assetPath;
  final BoxFit fit;
  const AdaptiveImage({
    super.key,
    required this.url,
    required this.assetPath,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return Image.asset(assetPath, fit: fit);
    }
    return Image.network(
      u,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.asset(assetPath, fit: fit),
    );
  }
}
