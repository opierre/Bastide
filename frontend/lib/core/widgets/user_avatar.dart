import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../features/auth/domain/avatar_choice.dart';
import '../theme/tokens.dart';
import 'monogram_avatar.dart';

/// The user's avatar wherever it appears: the top-bar pill and Settings ›
/// Profil.
///
/// Renders the [avatar] the user chose. A picture with no [image] bytes yet
/// (still loading, or failed), or bytes that don't decode, falls back to the
/// monogram, so the slot is never empty or broken.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.avatar,
    this.image,
    this.size = 32,
  });

  final String name;
  final AvatarChoice avatar;
  final Uint8List? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final monogram = UserMonogram(name: name, size: size);
    return switch (avatar) {
      MonogramChoice() => monogram,
      PresetChoice(:final preset) => _InitialsPlate(
        name: name,
        hue: AvatarHues.byPreset[preset.name] ?? AppColors.iris,
        size: size,
      ),
      PictureChoice() when image != null => ClipRRect(
        key: const Key('userAvatarPicture'),
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.memory(
          image!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => monogram,
        ),
      ),
      PictureChoice() => monogram,
    };
  }
}

/// The initials on a plate of [hue], with the monogram's geometry.
class _InitialsPlate extends StatelessWidget {
  const _InitialsPlate({
    required this.name,
    required this.hue,
    required this.size,
  });

  final String name;
  final Color hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('userAvatarPreset'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        MonogramAvatar.initialsFor(name),
        style: TextStyle(
          color: hue,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
          fontFamily: AppFonts.geist,
        ),
      ),
    );
  }
}
