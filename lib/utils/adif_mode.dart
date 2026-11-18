/// Maps a mode label shown in the app to the ADIF MODE / SUBMODE pair
/// that Wavelog expects.
///
/// Some modes are ADIF submodes rather than modes of their own. FreeDV,
/// for example, is logged as MODE=DIGITALVOICE, SUBMODE=FREEDV.
class AdifMode {
  final String mode;
  final String? submode;

  const AdifMode(this.mode, [this.submode]);

  factory AdifMode.fromAppMode(String appMode) {
    switch (appMode) {
      case 'FreeDV':
        return const AdifMode('DIGITALVOICE', 'FREEDV');
      default:
        return AdifMode(appMode);
    }
  }
}
