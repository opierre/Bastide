import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/text_size_preference.dart';
import '../session/current_user_provider.dart';
import 'tokens.dart';

/// The factor every text in the app is scaled by: the signed-in user's text
/// size, [AppTextScale.normal] before anyone signs in.
final textScaleProvider = Provider<double>((ref) {
  final preference = ref.watch(
    currentUserProvider.select((user) => user?.textSize),
  );
  return switch (preference) {
    TextSizePreference.large => AppTextScale.large,
    TextSizePreference.xlarge => AppTextScale.xlarge,
    TextSizePreference.normal || null => AppTextScale.normal,
  };
});

/// Scales [child]'s text by [factor] on top of the system's own text scale,
/// through [MediaQuery], so every [Text], field and chart label that reads
/// the ambient [TextScaler] grows together.
class AppTextScaleScope extends StatelessWidget {
  const AppTextScaleScope({
    super.key,
    required this.factor,
    required this.child,
  });

  final double factor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (factor == AppTextScale.normal) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: _ScaledTextScaler(media.textScaler, factor),
      ),
      child: child,
    );
  }
}

/// [base], then multiplied by [factor]: the user's choice composes with the
/// system's accessibility scale instead of replacing it.
@immutable
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
