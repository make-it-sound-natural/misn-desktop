import 'package:flutter/material.dart';

/// Shared metrics for the two Rewrite columns.
///
/// Split out of `home_screen.dart` so the source and variants panels can live
/// in their own files without either owning the other's constants.

/// Opacity for de-emphasised inline chrome on the Rewrite screen.
const double rewriteSubtleAlpha = 0.7;

/// Diameter of the spinner inside the Process button.
const double rewriteProgressIndicatorSize = 12;

/// Padding inside the source and context fields.
///
/// The right inset clears the in-field clear affordance.
const EdgeInsets rewriteFieldPadding = EdgeInsets.fromLTRB(14, 12, 44, 12);

/// How many placeholder cards stand in for a run in progress.
const int skeletonCardCount = 4;

/// Height of the eyebrow row above each column.
///
/// Fixed so both columns start on the same line whether or not the section
/// carries a trailing control.
const double eyebrowRowHeight = 36;
