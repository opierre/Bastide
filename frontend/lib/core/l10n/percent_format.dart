import 'package:intl/intl.dart';

/// A share of a total, to one decimal — « 42,9 % ».
///
/// Rounding to whole percent collapses the tail of a list, where three
/// categories can all land on the same figure. Lives in `core` because the
/// dashboard's legend and the categories panel's spend-share column show the
/// same number and must round it the same way.
String formatSharePct(double pct, String locale) =>
    '${NumberFormat('0.0', locale).format(pct)} %';
