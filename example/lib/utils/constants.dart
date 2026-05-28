const String nexconnTestAppKey = '';
const String nexconnTestServerURL = '';
const String nexconnTestNavServer = '';
const String nexconnTestFileServer = '';
const String nexconnTestStatsServer = '';
const String nexconnTestRegionNameKey = 'Custom';

const String nexconnAppKey = '';
const String nexconnServerURL = '';
const String nexconnNavServer = '';
const String nexconnFileServer = '';
const String nexconnStatsServer = '';
const String nexconnRegionNameKey = 'Custom';

class ExampleConstants {
  static bool isTestEnv = false;

  static String get appKey => isTestEnv ? nexconnTestAppKey : nexconnAppKey;
  static String get serverURL =>
      isTestEnv ? nexconnTestServerURL : nexconnServerURL;
  static String get navServer =>
      isTestEnv ? nexconnTestNavServer : nexconnNavServer;
  static String get fileServer =>
      isTestEnv ? nexconnTestFileServer : nexconnFileServer;
  static String get statsServer =>
      isTestEnv ? nexconnTestStatsServer : nexconnStatsServer;
  static String get regionNameKey =>
      isTestEnv ? nexconnTestRegionNameKey : nexconnRegionNameKey;

  static const token1 = '';
  static const token2 = '';
  static const token3 = '';

  static String tokenByShortcut(String input) {
    switch (input.trim()) {
      case '1':
        return token1;
      case '2':
        return token2;
      case '3':
        return token3;
      default:
        return input.trim();
    }
  }
}

const String nexconnRegistrationTerms = 'https://www.nexconn.ai/terms';
const String nexconnPrivacyPolicy = 'https://www.nexconn.ai/privacy';
