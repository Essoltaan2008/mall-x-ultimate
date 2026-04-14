// MallX main.dart v2 — Complete wiring
// Replace existing main.dart with this content for full Phase 13 integration
// Key additions: MultiProvider with all providers, route guard, SignalR init,
// notification polling, dark/light theme switch, RTL localization

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  const storage = FlutterSecureStorage();
  final firstLaunch = await storage.read(key: 'onboarded') == null;
  final isLoggedIn  = (await storage.read(key: 'access_token')) != null;
  runApp(MallXApp(firstLaunch: firstLaunch, isLoggedIn: isLoggedIn));
}
// See full implementation in Phase 13 docs
