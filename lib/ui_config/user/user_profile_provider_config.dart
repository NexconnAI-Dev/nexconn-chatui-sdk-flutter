import '../../providers/user_profile_provider.dart';

/// Default configuration for the Nexconn user profile provider.
class NexconnUserProfileProviderConfig {
  final NexconnUserProfileResolver? profileResolver;
  final NexconnUserProfileResolver? currentUserProfileResolver;
  final bool autoLoad;

  const NexconnUserProfileProviderConfig({
    this.profileResolver,
    this.currentUserProfileResolver,
    this.autoLoad = false,
  });
}
