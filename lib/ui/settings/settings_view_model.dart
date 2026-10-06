import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const developerEmail = 'du0788754@gmail.com';

final appVersionProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
