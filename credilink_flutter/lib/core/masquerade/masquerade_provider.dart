import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../repositories/providers.dart';

/// Admin “view as Store Owner” session (Firebase Auth stays Admin).
class MasqueradeSession {
  const MasqueradeSession({
    required this.storeOwnerId,
    required this.storeName,
    required this.ownerProfile,
  });

  final String storeOwnerId;
  final String storeName;
  final UserProfile ownerProfile;
}

class MasqueradeNotifier extends Notifier<MasqueradeSession?> {
  @override
  MasqueradeSession? build() => null;

  void start(MasqueradeSession session) => state = session;

  void clear() => state = null;
}

final masqueradeProvider =
    NotifierProvider<MasqueradeNotifier, MasqueradeSession?>(MasqueradeNotifier.new);

/// Profile used by Store Owner screens: masquerade target, else signed-in user.
final viewingProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  final mask = ref.watch(masqueradeProvider);
  if (mask != null) {
    return AsyncValue.data(mask.ownerProfile);
  }
  return ref.watch(currentProfileProvider);
});

void clearMasquerade(WidgetRef ref) {
  ref.read(masqueradeProvider.notifier).clear();
}

void clearMasqueradeFromRef(Ref ref) {
  ref.read(masqueradeProvider.notifier).clear();
}
