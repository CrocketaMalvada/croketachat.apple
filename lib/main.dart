import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

const String serverIP = "192.168.1.50";
const String apiURL = "https://chat.croketamalvada.com";
const double APP_VERSION = 1.0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
String? activeChatUserId;
ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(true);

final AudioPlayer chatAudioPlayer = AudioPlayer();

void playChatSound(String fileName) async {
  try {
    await chatAudioPlayer.setVolume(0.5);
    await chatAudioPlayer.play(AssetSource(fileName));
  } catch (e) {
    debugPrint("Error audio: $e");
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'reply_action' && response.input != null) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedUser = prefs.getString('user_data');
    if (savedUser != null && (response.payload ?? '').isNotEmpty) {
      Map userMap = jsonDecode(savedUser);
      IO.Socket bgSocket = IO.io(
        apiURL,
        IO.OptionBuilder().setTransports(['websocket']).build(),
      );
      bgSocket.onConnect((_) {
        bgSocket.emit('send_message', {
          'sender_id': userMap['uid'],
          'receiver_id': response.payload,
          'content': response.input!,
        });
        Future.delayed(const Duration(seconds: 1), () => bgSocket.disconnect());
      });
    }
  }
}

// ==========================================
// CACHÉ DE IMÁGENES (OPTIMIZACIÓN EXTREMA)
// ==========================================
class ImageCacheHelper {
  static final Map<int, Uint8List> _cache = {};

  static Uint8List? getBytes(String? base64Str) {
    if (base64Str == null || base64Str.length < 20 || base64Str == 'null')
      return null;
    int hash = base64Str.hashCode;
    if (_cache.containsKey(hash)) return _cache[hash];
    try {
      Uint8List bytes = base64Decode(base64Str);
      _cache[hash] = bytes;
      return bytes;
    } catch (e) {
      return null;
    }
  }

  static void clear() => _cache.clear();
}

// ==========================================
// CONSTANTES UI PREMIUM (MATERIAL 3 EXPRESSIVE)
// ==========================================
class UIConstants {
  static const double cardRadius = 24.0; // Proporción más elegante
  static const double pillRadius = 999.0;
  static const double dialogRadius = 28.0;
  static const Duration animDuration = Duration(milliseconds: 600);
  static const Curve animCurve = Curves.easeOutCubic;
  static const Curve bouncyCurve = Curves.easeOutBack;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/launcher_icon'),
  );
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    onDidReceiveNotificationResponse: (r) {
      if (r.actionId == 'reply_action' && r.input != null)
        notificationTapBackground(r);
    },
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedUser = prefs.getString('user_data');
  isDarkModeNotifier.value = prefs.getBool('isDarkMode') ?? true;

  Widget initialScreen = const AuthScreen();
  if (savedUser != null) {
    try {
      initialScreen = HomeScreen(myUser: jsonDecode(savedUser));
    } catch (e) {}
  }

  Animate.restartOnHotReload = true;

  runApp(
    ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            ColorScheme activeScheme = isDark
                ? (darkDynamic?.harmonized() ??
                      ColorScheme.fromSeed(
                        seedColor: const Color(0xFF6750A4),
                        brightness: Brightness.dark,
                      ))
                : (lightDynamic?.harmonized() ??
                      ColorScheme.fromSeed(
                        seedColor: const Color(0xFF6750A4),
                        brightness: Brightness.light,
                      ));

            return MaterialApp(
              title: 'CroketaChat',
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: activeScheme,
                scaffoldBackgroundColor: activeScheme.surfaceContainerLowest,
                textTheme:
                    GoogleFonts.plusJakartaSansTextTheme(
                      ThemeData(
                        brightness: isDark ? Brightness.dark : Brightness.light,
                      ).textTheme,
                    ).copyWith(
                      bodyLarge: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                      bodyMedium: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      titleLarge: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w500,
                      ),
                      headlineMedium: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        letterSpacing: -0.8,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      displaySmall: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        letterSpacing: -1.0,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                splashFactory: InkSparkle.splashFactory,
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: ZoomPageTransitionsBuilder(
                      allowEnterRouteSnapshotting: false,
                    ),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  },
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: activeScheme.surfaceContainerHigh.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UIConstants.pillRadius),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UIConstants.pillRadius),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UIConstants.pillRadius),
                    borderSide: BorderSide(
                      color: activeScheme.primary.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  labelStyle: TextStyle(
                    color: activeScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  hintStyle: TextStyle(
                    color: activeScheme.onSurfaceVariant.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                cardTheme: CardThemeData(
                  elevation: 0,
                  color: activeScheme.surfaceContainerLow.withOpacity(0.6),
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                    side: BorderSide(
                      color: activeScheme.outlineVariant.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                ),
                listTileTheme: ListTileThemeData(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                  ),
                ),
                dialogTheme: DialogThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      UIConstants.dialogRadius,
                    ),
                  ),
                  backgroundColor: activeScheme.surfaceContainerHigh
                      .withOpacity(0.9),
                ),
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
              ),
              home: initialScreen,
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    ),
  );
}

Widget _buildGlassmorphism({
  required Widget child,
  required Color color,
  double blur = 40,
}) {
  return ClipRRect(
    clipBehavior: Clip.hardEdge,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withOpacity(0.35),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 0.5,
            ),
          ),
        ),
        child: child,
      ),
    ),
  );
}

Widget _buildAuraBackground(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primary = Theme.of(context).colorScheme.primary;
  final tertiary = Theme.of(context).colorScheme.tertiary;
  final surface = Theme.of(context).colorScheme.surfaceContainerLowest;

  return Stack(
    children: [
      RepaintBoundary(
        child: Stack(
          children: [
            Container(color: surface),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.7),
                    radius: 2.0,
                    colors: [
                      primary.withOpacity(isDark ? 0.15 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, 1.3),
                    radius: 2.0,
                    colors: [
                      tertiary.withOpacity(isDark ? 0.10 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SafeArea(bottom: false, child: child),
    ],
  );
}

Widget _buildMD3Field(
  TextEditingController c,
  String l,
  IconData i, {
  bool isPass = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: TextFormField(
      controller: c,
      obscureText: isPass,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 12.0),
          child: Icon(i, size: 22),
        ),
      ),
    ),
  );
}

void _showRedPopup(BuildContext context, String message) {
  HapticFeedback.heavyImpact();
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      title: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 28,
          ).animate().shake(hz: 4, duration: 400.ms),
          const SizedBox(width: 12),
          Text(
            "Atención",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      ),
      actions: [
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
            foregroundColor: Theme.of(context).colorScheme.errorContainer,
            minimumSize: const Size(100, 44),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(c);
          },
          child: const Text("Entendido"),
        ),
      ],
    ).animate().scale(duration: 400.ms, curve: UIConstants.bouncyCurve),
  );
}

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Privacidad",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _buildAuraBackground(
        context,
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 32,
            16,
            60,
          ),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                )
                .animate()
                .scale(duration: 600.ms, curve: UIConstants.bouncyCurve)
                .then()
                .shimmer(duration: 1.5.seconds),
            const SizedBox(height: 24),
            Text(
              "Tu privacidad es\nnuestra prioridad",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Descubre cómo protegemos tus datos y conversaciones con cifrado de grado militar.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            ...[
                  _buildSection(
                    context,
                    "Cifrado de Alta Seguridad",
                    "Toda la comunicación entre tu dispositivo y nuestros servidores está protegida por protocolos de cifrado robustos. Nadie intercepta tu chat.",
                    Icons.lock_outline_rounded,
                  ),
                  _buildSection(
                    context,
                    "Privacidad Absoluta",
                    "CroketaChat tiene una política estricta de CERO comercialización. No vendemos, no alquilamos y no compartimos tus datos.",
                    Icons.visibility_off_outlined,
                  ),
                  _buildSection(
                    context,
                    "Protección Antimorbos",
                    "Las fotos marcadas como 'Efímeras' cuentan con una barrera de seguridad a nivel de sistema operativo que bloquea capturas.",
                    Icons.block_flipped,
                  ),
                ]
                .animate(interval: 100.ms)
                .fade(duration: 500.ms)
                .slideY(begin: 0.1, curve: UIConstants.animCurve),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool acceptedTerms = false;
  final nameC = TextEditingController(),
      nickC = TextEditingController(),
      passC = TextEditingController();

  _submit() async {
    HapticFeedback.mediumImpact();
    if (!isLogin && !acceptedTerms) {
      _showRedPopup(context, "Debes aceptar la política de uso y privacidad.");
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('$apiURL${isLogin ? '/login' : '/register'}'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(
          isLogin
              ? {'nickname': nickC.text.trim(), 'password': passC.text}
              : {
                  'name': nameC.text.trim(),
                  'nickname': nickC.text.trim(),
                  'password': passC.text,
                },
        ),
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', res.body);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => HomeScreen(myUser: jsonDecode(res.body)),
          ),
        );
      } else {
        _showRedPopup(
          context,
          jsonDecode(res.body)['error'] ?? "Error en el servidor",
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showRedPopup(context, "Error de conexión. Revisa tu internet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildAuraBackground(
        context,
        Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                      padding: const EdgeInsets.all(20),
                      decoration: ShapeDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                    .animate()
                    .scale(duration: 800.ms, curve: UIConstants.bouncyCurve)
                    .fade(),
                const SizedBox(height: 32),
                Text(
                      isLogin ? "Hola de\nnuevo." : "Crea tu\ncuenta.",
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                    .animate()
                    .fade(delay: 100.ms)
                    .slideX(begin: -0.05, curve: UIConstants.animCurve),
                const SizedBox(height: 8),
                Text(
                      isLogin
                          ? "Inicia sesión para continuar"
                          : "Únete a la plataforma más segura",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                    )
                    .animate()
                    .fade(delay: 200.ms)
                    .slideX(begin: -0.05, curve: UIConstants.animCurve),
                const SizedBox(height: 40),

                Column(
                      children: [
                        if (!isLogin)
                          _buildMD3Field(
                            nameC,
                            "Nombre",
                            Icons.person_outline_rounded,
                          ),
                        _buildMD3Field(
                          nickC,
                          "Usuario (@)",
                          Icons.alternate_email_rounded,
                        ),
                        _buildMD3Field(
                          passC,
                          "Contraseña",
                          Icons.lock_outline_rounded,
                          isPass: true,
                        ),

                        if (!isLogin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: ShapeDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  UIConstants.cardRadius,
                                ),
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: acceptedTerms,
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      setState(
                                        () => acceptedTerms = val ?? false,
                                      );
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Acepto la política de privacidad. Todo está cifrado.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        FilledButton(
                          onPressed: _submit,
                          child: Text(isLogin ? "Entrar" : "Comenzar"),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                isLogin = !isLogin;
                                acceptedTerms = false;
                              });
                            },
                            child: Text(
                              isLogin
                                  ? "Crear una cuenta nueva"
                                  : "Ya tengo una cuenta",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fade(delay: 300.ms)
                    .slideY(begin: 0.1, curve: UIConstants.animCurve),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final Map user;
  const ProfileScreen({super.key, required this.user});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameC, nickC, bioC;
  String? base64Image;
  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.user['name']);
    nickC = TextEditingController(text: widget.user['nickname']);
    String bioStr = widget.user['bio']?.toString() ?? '';
    if (bioStr == 'null') bioStr = '';
    bioC = TextEditingController(text: bioStr);
    base64Image = widget.user['avatar'];
  }

  _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => base64Image = base64Encode(bytes));
    }
  }

  _save() async {
    HapticFeedback.mediumImpact();
    try {
      final res = await http.put(
        Uri.parse('$apiURL/update-profile/${widget.user['uid']}'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameC.text.trim(),
          'nickname': nickC.text.trim(),
          'avatar': base64Image,
          'bio': bioC.text.trim(),
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', res.body);
        Navigator.pop(context, jsonDecode(res.body));
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes = ImageCacheHelper.getBytes(base64Image);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Tu Perfil",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _buildAuraBackground(
        context,
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 32,
            16,
            60,
          ),
          child: Column(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: ShapeDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: const CircleBorder(),
                        image: imageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(imageBytes),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageBytes == null
                          ? Icon(
                              Icons.face_retouching_natural_rounded,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(2.0),
                      child:
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: FloatingActionButton(
                              elevation: 2,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: const CircleBorder(),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _pickImage();
                              },
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                              ),
                            ),
                          ).animate().scale(
                            delay: 200.ms,
                            curve: UIConstants.bouncyCurve,
                          ),
                    ),
                  ],
                ).animate().fade().scale(curve: UIConstants.bouncyCurve),
              ),
              const SizedBox(height: 32),

              ...[
                    _buildMD3Field(
                      nameC,
                      "Nombre",
                      Icons.person_outline_rounded,
                    ),
                    _buildMD3Field(
                      nickC,
                      "Usuario",
                      Icons.alternate_email_rounded,
                    ),
                    _buildMD3Field(
                      bioC,
                      "Info / Estado",
                      Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 8),

                    Card(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        title: const Text(
                          "Tema Oscuro",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          "Ideal para la noche",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                        value: isDarkModeNotifier.value,
                        onChanged: (val) async {
                          HapticFeedback.selectionClick();
                          isDarkModeNotifier.value = val;
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('isDarkMode', val);
                          setState(() {});
                        },
                      ),
                    ),

                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: ShapeDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            shape: const CircleBorder(),
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          "Privacidad y Seguridad",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Text(
                            "Términos y cifrado",
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PrivacySecurityScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _save,
                      child: const Text("Guardar Cambios"),
                    ),
                  ]
                  .animate(interval: 50.ms)
                  .slideY(begin: 0.1, curve: UIConstants.animCurve)
                  .fade(),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  final Map myUser;
  final List users;
  const CreateGroupScreen({
    super.key,
    required this.myUser,
    required this.users,
  });
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final groupNameC = TextEditingController();
  List<String> selectedUids = [];

  _createGroup() async {
    if (groupNameC.text.isEmpty || selectedUids.isEmpty) return;
    HapticFeedback.mediumImpact();
    try {
      final res = await http.post(
        Uri.parse('$apiURL/create-group'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': groupNameC.text.trim(),
          'admin_id': widget.myUser['uid'].toString(),
          'members': selectedUids,
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error creating group: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Nuevo Grupo",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _buildAuraBackground(
        context,
        Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMD3Field(
                groupNameC,
                "Nombre del grupo",
                Icons.groups_outlined,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Invitar miembros",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.users.length,
                itemBuilder: (c, i) {
                  final user = widget.users[i];
                  String uidText = user['uid'].toString();
                  bool isSelected = selectedUids.contains(uidText);

                  String avatar = user['avatar']?.toString() ?? '';
                  if (avatar == 'null' || avatar.length < 20) avatar = '';
                  String name = user['name']?.toString() ?? '?';
                  if (name == 'null' || name.trim().isEmpty) name = '?';
                  Uint8List? imageBytes = ImageCacheHelper.getBytes(avatar);

                  return Card(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withOpacity(0.8)
                            : null,
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          value: isSelected,
                          checkboxShape: const CircleBorder(),
                          secondary: Container(
                            width: 44,
                            height: 44,
                            decoration: ShapeDecoration(
                              shape: const CircleBorder(),
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              image: imageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(imageBytes),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imageBytes == null
                                ? Center(
                                    child: Text(
                                      name[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (val == true) {
                                if (!selectedUids.contains(uidText))
                                  selectedUids.add(uidText);
                              } else {
                                selectedUids.remove(uidText);
                              }
                            });
                          },
                        ),
                      )
                      .animate()
                      .fade(delay: (i * 20).ms)
                      .slideX(begin: 0.05, curve: UIConstants.animCurve);
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text("Crear Grupo"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Map myUser;
  const HomeScreen({super.key, required this.myUser});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Map currentUser;
  List users = [], groups = [];
  Map<String, int> unreadCounts = {};
  Map<String, String> lastMessages = {};
  final searchC = TextEditingController();
  late IO.Socket socket;
  @override
  void initState() {
    super.initState();
    currentUser = widget.myUser;
    _load();
    _initSocket();
    _checkForUpdates();
  }

  _checkForUpdates() async {
    try {
      final res = await http.get(Uri.parse('$apiURL/check-version'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if ((data['version'] ?? 1.0).toDouble() > APP_VERSION)
          _showUpdateDialog(data['url'] ?? '');
      }
    } catch (e) {}
  }

  _showUpdateDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 32),
        title: const Text(
          "Actualización lista",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          "Hay una nueva versión de la app. Es necesario actualizar para seguir chateando con normalidad.",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Omitir",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(c);
              Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text("Descargar"),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotification(
    String title,
    String body,
    String senderId,
  ) async {
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      _cleanMessageFormat(body),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          'Mensajes',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'reply_action',
              'Responder',
              inputs: <AndroidNotificationActionInput>[
                AndroidNotificationActionInput(
                  label: 'Escribe tu respuesta...',
                ),
              ],
            ),
          ],
        ),
      ),
      payload: senderId,
    );
  }

  String _cleanMessageFormat(String content) {
    if (content.startsWith('[VIEW_ONCE]')) return "Foto efímera";
    if (content.startsWith('[AUDIO]')) return "Nota de voz";
    if (content.startsWith('[SYSTEM]')) return content.substring(8);
    if (content.startsWith('[REPLY:')) {
      int cb = content.indexOf(']');
      if (cb != -1) return content.substring(cb + 1);
    }
    return content;
  }

  _initSocket() {
    socket = IO.io(
      apiURL,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );
    socket.onConnect((_) {
      socket.emit('register_online', currentUser['uid']);
    });

    socket.on('added_to_group', (_) {
      if (mounted) _load();
    });

    socket.on('new_message', (data) {
      String senderId = data['sender_id'];
      if (!users.any((u) => u['uid'] == senderId)) _load();
      List muted = currentUser['muted_chats'] ?? [];
      if (mounted)
        setState(() {
          unreadCounts[senderId] = (unreadCounts[senderId] ?? 0) + 1;
          lastMessages[senderId] = _cleanMessageFormat(data['content']);
        });
      if (activeChatUserId != senderId && !muted.contains(senderId)) {
        String senderName = "Nuevo mensaje";
        try {
          senderName = users.firstWhere((u) => u['uid'] == senderId)['name'];
        } catch (e) {}
        _showNotification(senderName, data['content'], senderId);
      }
    });
    socket.on('new_group_message', (data) {
      String groupId = data['group_id'].toString();
      List muted = currentUser['muted_chats'] ?? [];
      if (data['sender_id'] != currentUser['uid']) {
        if (mounted)
          setState(() {
            unreadCounts[groupId] = (unreadCounts[groupId] ?? 0) + 1;
            lastMessages[groupId] =
                "${data['sender_name']}: ${_cleanMessageFormat(data['content'])}";
          });
        if (activeChatUserId != groupId && !muted.contains(groupId)) {
          String groupName = "Grupo";
          try {
            groupName = groups.firstWhere(
              (g) => g['id'].toString() == groupId,
            )['name'];
          } catch (e) {}
          _showNotification(
            "$groupName (${data['sender_name']})",
            data['content'],
            groupId,
          );
        }
      }
    });
  }

  _load() async {
    final res = await http.get(
      Uri.parse('$apiURL/contacts/${currentUser['uid']}'),
    );
    if (res.statusCode == 200 && mounted)
      setState(() => users = jsonDecode(res.body));
    final resGroups = await http.get(
      Uri.parse('$apiURL/groups/${currentUser['uid']}'),
    );
    if (resGroups.statusCode == 200 && mounted)
      setState(() => groups = jsonDecode(resGroups.body));
    for (var u in users) _fetchLastMsg(u['uid'], false);
    for (var g in groups) _fetchLastMsg(g['id'].toString(), true);
  }

  _fetchLastMsg(String id, bool isGroup) async {
    try {
      final res = await http.get(
        Uri.parse(
          isGroup
              ? '$apiURL/group-messages/$id'
              : '$apiURL/messages/${currentUser['uid']}/$id',
        ),
      );
      if (res.statusCode == 200) {
        List msgs = jsonDecode(res.body);
        if (msgs.isNotEmpty && mounted) {
          var last = msgs.last;
          String content = _cleanMessageFormat(last['content']);
          String prefix = "";
          if (isGroup &&
              last['sender_id'] != currentUser['uid'] &&
              last['sender_id'] != 'system')
            prefix = "${last['sender_name']}: ";
          else if (last['sender_id'] == currentUser['uid'])
            prefix = "Tú: ";
          setState(() => lastMessages[id] = "$prefix$content");
        }
      }
    } catch (e) {}
  }

  _add() async {
    final res = await http.post(
      Uri.parse('$apiURL/add-contact'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'my_uid': currentUser['uid'],
        'search_query': searchC.text.trim(),
      }),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      Navigator.pop(context);
      _load();
      searchC.clear();
    } else {
      _showRedPopup(context, "Usuario no encontrado.");
    }
  }

  _deleteChat(String peerUid) async {
    try {
      final res = await http.delete(
        Uri.parse('$apiURL/delete-chat/${currentUser['uid']}/$peerUid'),
      );
      if (res.statusCode == 200) _load();
    } catch (e) {}
  }

  _confirmDeleteChat(String peerUid, String peerName) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(
          Icons.delete_sweep_outlined,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: const Text(
          "¿Borrar chat?",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: const Text(
          "Esta acción eliminará la conversación permanentemente. ¿Continuar?",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Cancelar",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(c);
              _deleteChat(peerUid);
            },
            child: const Text("Borrar"),
          ),
        ],
      ),
    );
  }

  _logout() async {
    ImageCacheHelper.clear();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    socket.disconnect();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => const AuthScreen()),
    );
  }

  _goToProfile() async {
    HapticFeedback.lightImpact();
    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => ProfileScreen(user: currentUser)),
    );
    if (updatedUser != null && mounted)
      setState(() {
        currentUser = updatedUser;
        _load();
      });
  }

  _showAddDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassmorphism(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          blur: 40,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Añadir Contacto",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Busca a tu amigo por su usuario (@)",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: searchC,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: "Ej. croketa12",
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(c),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _add,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Añadir",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().scale(curve: UIConstants.bouncyCurve, duration: 400.ms),
    );
  }

  @override
  Widget build(BuildContext context) {
    String myAvatar = currentUser['avatar']?.toString() ?? '';
    if (myAvatar == 'null' || myAvatar.length < 20) myAvatar = '';
    Uint8List? myImageBytes = ImageCacheHelper.getBytes(myAvatar);
    List combinedList = [
      ...groups.map((g) => {...g, 'is_group': true}),
      ...users.map((u) => {...u, 'is_group': false}),
    ];

    List pinned = currentUser['pinned_chats'] ?? [];
    List muted = currentUser['muted_chats'] ?? [];
    combinedList.sort((a, b) {
      String idA = a['is_group'] ? a['id'].toString() : a['uid'].toString();
      String idB = b['is_group'] ? b['id'].toString() : b['uid'].toString();
      bool aPinned = pinned.contains(idA);
      bool bPinned = pinned.contains(idB);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: const Icon(Icons.person_add_alt_1_rounded, size: 24),
      ).animate().scale(delay: 500.ms, curve: UIConstants.bouncyCurve),
      body: _buildAuraBackground(
        context,
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              floating: false,
              pinned: true,
              expandedHeight: 150,
              stretch: true,
              flexibleSpace: RepaintBoundary(
                child: _buildGlassmorphism(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  blur: 40,
                  child: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    title: Text(
                      "CroketaChat",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.0,
                        fontSize: 24,
                      ),
                    ),
                    background: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 56),
                        child: Text(
                          "Hola, ${currentUser['name'].split(' ')[0]}!",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: _goToProfile,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 40,
                    height: 40,
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      image: myImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(myImageBytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: myImageBytes == null
                        ? Center(
                            child: Text(
                              currentUser['name'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                IconButton(
                  iconSize: 24,
                  tooltip: "Nuevo Grupo",
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    bool? created = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => CreateGroupScreen(
                          myUser: currentUser,
                          users: users,
                        ),
                      ),
                    );
                    if (created == true) _load();
                  },
                  icon: const Icon(Icons.group_add_outlined),
                ),
                IconButton(
                  iconSize: 24,
                  tooltip: "Cerrar sesión",
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _logout();
                  },
                  icon: Icon(
                    Icons.logout_rounded,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (combinedList.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ).animate().shake(delay: 1.seconds, hz: 2),
                      const SizedBox(height: 16),
                      Text(
                        "Tu bandeja está vacía",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Toca el icono para añadir amigos",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (combinedList.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final item = combinedList[i];
                    bool isGroup = item['is_group'];
                    String itemId = isGroup
                        ? item['id'].toString()
                        : item['uid'].toString();
                    String displayTitle = isGroup
                        ? (item['name']?.toString() ?? 'Grupo')
                        : "@${item['nickname']?.toString() ?? 'usuario'}";
                    String initial = isGroup
                        ? (item['name']?.toString() ?? 'G')[0].toUpperCase()
                        : (item['nickname']?.toString() ?? 'U')[0]
                              .toUpperCase();
                    String itemAvatar = item['avatar']?.toString() ?? '';
                    if (itemAvatar == 'null' || itemAvatar.length < 20)
                      itemAvatar = '';
                    Uint8List? imageBytes = ImageCacheHelper.getBytes(
                      itemAvatar,
                    );
                    int unread = unreadCounts[itemId] ?? 0;
                    String lastMsg =
                        lastMessages[itemId] ?? "Envía el primer mensaje...";

                    bool isPinned = pinned.contains(itemId);
                    bool isMuted = muted.contains(itemId);

                    return Card(
                          color: unread > 0
                              ? Theme.of(context).colorScheme.secondaryContainer
                                    .withOpacity(0.6)
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow
                                    .withOpacity(0.4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              UIConstants.cardRadius,
                            ),
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              if (!isGroup)
                                _confirmDeleteChat(itemId, displayTitle);
                            },
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => unreadCounts[itemId] = 0);
                              if (isGroup) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => GroupChatScreen(
                                      myUser: currentUser,
                                      group: item,
                                      socket: socket,
                                    ),
                                  ),
                                ).then((_) {
                                  setState(() => unreadCounts[itemId] = 0);
                                  _load();
                                });
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => ChatScreen(
                                      myUser: currentUser,
                                      peerUser: item,
                                      socket: socket,
                                    ),
                                  ),
                                ).then((newUserData) {
                                  setState(() {
                                    unreadCounts[itemId] = 0;
                                    if (newUserData != null &&
                                        newUserData is Map) {
                                      currentUser = newUserData;
                                    }
                                  });
                                  _load();
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'avatar_$itemId',
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: ShapeDecoration(
                                        shape: const CircleBorder(),
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        image: imageBytes != null
                                            ? DecorationImage(
                                                image: MemoryImage(imageBytes),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: imageBytes == null
                                          ? Center(
                                              child: (isGroup
                                                  ? Icon(
                                                      Icons.groups_rounded,
                                                      size: 24,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer,
                                                    )
                                                  : Text(
                                                      initial,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 18,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer,
                                                      ),
                                                    )),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayTitle,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  letterSpacing: -0.2,
                                                  color: unread > 0
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .onSecondaryContainer
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (isPinned)
                                              Icon(
                                                Icons.push_pin_rounded,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.8),
                                              ),
                                            if (isPinned && isMuted)
                                              const SizedBox(width: 4),
                                            if (isMuted)
                                              Icon(
                                                Icons.volume_off_rounded,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.5),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: unread > 0
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: unread > 0
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unread > 0)
                                    Badge(
                                      label: Text("$unread"),
                                      largeSize: 24,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      textColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ).animate().scale(
                                      curve: UIConstants.bouncyCurve,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fade(delay: (i * 20).ms)
                        .slideY(begin: 0.1, curve: UIConstants.animCurve);
                  }, childCount: combinedList.length),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class MDBubble extends StatelessWidget {
  final Widget child;
  final bool isMe;
  final Color themeColor;
  const MDBubble({
    super.key,
    required this.child,
    required this.isMe,
    required this.themeColor,
  });
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color myColor = isDark
        ? themeColor.withOpacity(0.25)
        : themeColor.withOpacity(0.12);
    Color peerColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.8)
        : Colors.white.withOpacity(0.9);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? myColor : peerColor,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.02),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
      ),
      child: child,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Map myUser, peerUser;
  final IO.Socket socket;
  const ChatScreen({
    super.key,
    required this.myUser,
    required this.peerUser,
    required this.socket,
  });
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List messages = [];
  final msgC = TextEditingController();
  final scrollC = ScrollController();
  Map? replyingTo;
  Color? chatThemeColor;
  List<String> viewedPhotos = [];
  bool _isRecording = false;
  late AudioRecorder _audioRecorder;

  String typingStatus = "";
  bool isTyping = false;
  bool _hasText = false;

  Timer? _typingTimer;
  Timer? _recordTimer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    activeChatUserId = widget.peerUser['uid'].toString();
    _loadTheme();
    _loadViewedPhotos();
    _history();
    _audioRecorder = AudioRecorder();

    msgC.addListener(() {
      bool currentHasText = msgC.text.trim().isNotEmpty;
      if (currentHasText != _hasText) {
        setState(() {
          _hasText = currentHasText;
        });
      }

      if (msgC.text.isNotEmpty && !isTyping) {
        isTyping = true;
        widget.socket.emit('typing', {
          'sender_id': widget.myUser['uid'],
          'receiver_id': widget.peerUser['uid'],
        });
      } else if (msgC.text.isEmpty && isTyping) {
        isTyping = false;
        widget.socket.emit('stop_typing', {
          'sender_id': widget.myUser['uid'],
          'receiver_id': widget.peerUser['uid'],
        });
      }
    });

    widget.socket.on('new_message', (data) {
      if (mounted && data['sender_id'] == widget.peerUser['uid']) {
        setState(() {
          messages.add(data);
          typingStatus = "";
        });
        _scroll();
        playChatSound('receive.mp3');
        HapticFeedback.lightImpact();
      }
    });

    widget.socket.on('user_typing', (data) {
      if (mounted &&
          data['sender_id'].toString() == widget.peerUser['uid'].toString()) {
        setState(() => typingStatus = "Escribiendo...");
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => typingStatus = "");
        });
      }
    });
    widget.socket.on('user_stop_typing', (data) {
      if (mounted &&
          data['sender_id'].toString() == widget.peerUser['uid'].toString()) {
        setState(() => typingStatus = "");
      }
    });
  }

  _loadViewedPhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() {
        viewedPhotos =
            prefs.getStringList('viewed_photos_${widget.myUser['uid']}') ?? [];
      });
  }

  _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('theme_${widget.peerUser['uid']}');
    if (colorValue != null && mounted) {
      setState(() {
        chatThemeColor = Color(colorValue);
      });
    }
  }

  _saveTheme(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_${widget.peerUser['uid']}', color.value);
    if (mounted)
      setState(() {
        chatThemeColor = color;
      });
  }

  _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => _buildGlassmorphism(
        color: Theme.of(context).colorScheme.surface,
        blur: 40,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Aura del Chat",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _themeIcon(const Color(0xFF6750A4)),
                  _themeIcon(const Color(0xFF006874)),
                  _themeIcon(const Color(0xFF984061)),
                  _themeIcon(const Color(0xFF386A20)),
                  _themeIcon(const Color(0xFF825500)),
                  _themeIcon(const Color(0xFF0061A4)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeIcon(Color c) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        _saveTheme(c);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ).animate().scale(curve: UIConstants.bouncyCurve),
    );
  }

  @override
  void dispose() {
    activeChatUserId = null;
    msgC.dispose();
    scrollC.dispose();
    _audioRecorder.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    super.dispose();
  }

  _scroll() => Future.delayed(
    const Duration(milliseconds: 100),
    () => {
      if (scrollC.hasClients)
        scrollC.animateTo(
          scrollC.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: UIConstants.animCurve,
        ),
    },
  );
  _history() async {
    final res = await http.get(
      Uri.parse(
        '$apiURL/messages/${widget.myUser['uid']}/${widget.peerUser['uid']}',
      ),
    );
    if (res.statusCode == 200 && mounted) {
      setState(() => messages = List.from(jsonDecode(res.body)));
      _scroll();
    }
  }

  String _getCleanText(String rawContent) {
    if (rawContent.startsWith('[REPLY:')) {
      int closeBracket = rawContent.indexOf(']');
      if (closeBracket != -1) return rawContent.substring(closeBracket + 1);
    }
    return rawContent;
  }

  String _formatRecordTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  _sendViewOncePhoto() async {
    HapticFeedback.lightImpact();
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      String base64Image = base64Encode(bytes);
      widget.socket.emit('send_message', {
        'sender_id': widget.myUser['uid'],
        'receiver_id': widget.peerUser['uid'],
        'content': '[VIEW_ONCE]$base64Image',
      });
      var newMsg = {
        'sender_id': widget.myUser['uid'],
        'receiver_id': widget.peerUser['uid'],
        'content': '[VIEW_ONCE]$base64Image',
      };
      if (mounted) setState(() => messages.add(newMsg));
      _scroll();
      playChatSound('send.mp3');
    }
  }

  void _openEphemeralPhoto(String base64Img, String photoHash) async {
    await ScreenProtector.preventScreenshotOn();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text(
              "Imagen Segura",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ),
          body: InteractiveViewer(
            child: Center(child: Image.memory(base64Decode(base64Img))),
          ),
        ),
      ),
    );
    await ScreenProtector.preventScreenshotOff();
    if (mounted)
      setState(() {
        viewedPhotos.add(photoHash);
      });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'viewed_photos_${widget.myUser['uid']}',
      viewedPhotos,
    );
  }

  _toggleRecording() async {
    HapticFeedback.heavyImpact();
    if (_isRecording) {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (mounted)
        setState(() {
          _isRecording = false;
          _recordDuration = 0;
        });
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        final base64String = base64Encode(bytes);
        _send('[AUDIO]$base64String');
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordDuration = 0;
          });
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) setState(() => _recordDuration++);
          });
        }
      } else {
        _showRedPopup(context, "Activa los permisos del micrófono.");
      }
    }
  }

  _send([String? customContent]) {
    String text = customContent ?? msgC.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    if (replyingTo != null && customContent == null) {
      String rName = replyingTo!['sender_id'] == widget.myUser['uid']
          ? 'Tú'
          : widget.peerUser['name'];
      String rText = _getCleanText(
        replyingTo!['content'],
      ).replaceAll('|', ' ').replaceAll(']', ' ');
      text = '[REPLY:$rName|$rText]$text';
    }
    var newMsg = {
      'sender_id': widget.myUser['uid'],
      'receiver_id': widget.peerUser['uid'],
      'content': text,
    };
    widget.socket.emit('send_message', newMsg);
    if (mounted) setState(() => messages.add(newMsg));
    if (customContent == null) msgC.clear();
    if (mounted)
      setState(() {
        replyingTo = null;
        isTyping = false;
        _hasText = false;
      });
    widget.socket.emit('stop_typing', {
      'sender_id': widget.myUser['uid'],
      'receiver_id': widget.peerUser['uid'],
    });
    _scroll();
    playChatSound('send.mp3');
  }

  _confirmDeleteInsideChat() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(
          Icons.delete_sweep_outlined,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: const Text(
          "¿Borrar chat?",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: const Text(
          "Esta acción eliminará la conversación permanentemente. ¿Continuar?",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Cancelar",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(c);
              try {
                final res = await http.delete(
                  Uri.parse(
                    '$apiURL/delete-chat/${widget.myUser['uid']}/${widget.peerUser['uid']}',
                  ),
                );
                if (res.statusCode == 200 && mounted) {
                  Navigator.pop(context, true);
                }
              } catch (e) {}
            },
            child: const Text("Borrar"),
          ),
        ],
      ).animate().scale(curve: UIConstants.bouncyCurve, duration: 400.ms),
    );
  }

  @override
  Widget build(BuildContext context) {
    String peerAvatar = widget.peerUser['avatar']?.toString() ?? '';
    if (peerAvatar == 'null' || peerAvatar.length < 20) peerAvatar = '';
    String peerName = widget.peerUser['name']?.toString() ?? 'Usuario';
    if (peerName == 'null' || peerName.isEmpty) peerName = 'Usuario';
    Color primaryColor =
        chatThemeColor ?? Theme.of(context).colorScheme.primary;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Uint8List? peerImageBytes = ImageCacheHelper.getBytes(peerAvatar);

    Widget chatBackground = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerLowest,
            primaryColor.withOpacity(isDark ? 0.05 : 0.02),
            Theme.of(context).colorScheme.surfaceContainerLowest,
          ],
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        flexibleSpace: RepaintBoundary(
          child: _buildGlassmorphism(
            child: const SizedBox.expand(),
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            blur: 40,
          ),
        ),
        title: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => PeerProfileScreen(user: widget.peerUser),
              ),
            );
          },
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.peerUser['uid']}',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: ShapeDecoration(
                    shape: const CircleBorder(),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    image: peerImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(peerImageBytes),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: peerImageBytes == null
                      ? Center(
                          child: Text(
                            peerName[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      typingStatus.isNotEmpty
                          ? typingStatus
                          : "@${widget.peerUser['nickname']}",
                      style: TextStyle(
                        fontSize: 13,
                        color: typingStatus.isNotEmpty
                            ? primaryColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: typingStatus.isNotEmpty
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.palette_outlined, color: primaryColor, size: 22),
            onPressed: _showThemePicker,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: primaryColor, size: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              HapticFeedback.lightImpact();
              if (value == 'delete') {
                _confirmDeleteInsideChat();
                return;
              }
              try {
                final res = await http.post(
                  Uri.parse('$apiURL/chat-action'),
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'my_uid': widget.myUser['uid'],
                    'peer_uid': widget.peerUser['uid'],
                    'action': value,
                  }),
                );
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  bool isActive = data['status'];

                  if (value == 'mute') {
                    List m = List.from(widget.myUser['muted_chats'] ?? []);
                    isActive
                        ? m.add(widget.peerUser['uid'])
                        : m.remove(widget.peerUser['uid']);
                    widget.myUser['muted_chats'] = m;
                  }
                  if (value == 'pin') {
                    List p = List.from(widget.myUser['pinned_chats'] ?? []);
                    isActive
                        ? p.add(widget.peerUser['uid'])
                        : p.remove(widget.peerUser['uid']);
                    widget.myUser['pinned_chats'] = p;
                  }
                  if (value == 'block') {
                    List b = List.from(widget.myUser['blocked_users'] ?? []);
                    isActive
                        ? b.add(widget.peerUser['uid'])
                        : b.remove(widget.peerUser['uid']);
                    widget.myUser['blocked_users'] = b;
                  }

                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setString('user_data', jsonEncode(widget.myUser));

                  String msj = "";
                  if (value == 'mute')
                    msj = isActive ? "Chat silenciado" : "Sonido activado";
                  if (value == 'pin')
                    msj = isActive ? "Chat fijado" : "Chat desfijado";
                  if (value == 'block')
                    msj = isActive
                        ? "Usuario bloqueado"
                        : "Usuario desbloqueado";
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        msj,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: const StadiumBorder(),
                    ),
                  );
                  if (value == 'block' && isActive) {
                    Navigator.pop(context, widget.myUser);
                  }
                }
              } catch (e) {}
            },
            itemBuilder: (BuildContext context) {
              List muted = widget.myUser['muted_chats'] ?? [];
              List pinned = widget.myUser['pinned_chats'] ?? [];
              List blocked = widget.myUser['blocked_users'] ?? [];
              bool isMuted = muted.contains(widget.peerUser['uid']);
              bool isPinned = pinned.contains(widget.peerUser['uid']);
              bool isBlocked = blocked.contains(widget.peerUser['uid']);

              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(
                        isMuted
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isMuted ? 'Quitar silencio' : 'Silenciar',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isPinned ? 'Desfijar chat' : 'Fijar chat',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        isBlocked ? 'Desbloquear' : 'Bloquear',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Colors.red,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Borrar chat',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          chatBackground,
          ListView.builder(
            physics: const BouncingScrollPhysics(),
            controller: scrollC,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
              bottom: 200,
            ),
            itemCount: messages.length,
            itemBuilder: (c, i) {
              bool isMe = messages[i]['sender_id'] == widget.myUser['uid'];
              String rawContent = messages[i]['content'];
              bool isReply = rawContent.startsWith('[REPLY:');
              String? replyName;
              String? replyText;
              String mainText = rawContent;
              if (isReply) {
                int closeBracket = rawContent.indexOf(']');
                if (closeBracket != -1) {
                  String replyData = rawContent.substring(7, closeBracket);
                  int separator = replyData.indexOf('|');
                  if (separator != -1) {
                    replyName = replyData.substring(0, separator);
                    replyText = replyData.substring(separator + 1);
                    mainText = rawContent.substring(closeBracket + 1);
                  }
                }
              }
              Widget bubble = Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Dismissible(
                  key: Key(messages[i].hashCode.toString() + i.toString()),
                  direction: DismissDirection.startToEnd,
                  onUpdate: (details) {
                    if (details.progress > 0.2 && details.progress < 0.22)
                      HapticFeedback.selectionClick();
                  },
                  confirmDismiss: (direction) async {
                    HapticFeedback.mediumImpact();
                    setState(() => replyingTo = messages[i]);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 24,
                      color: primaryColor,
                    ),
                  ),
                  child: GestureDetector(
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      setState(() => replyingTo = messages[i]);
                    },
                    child: MDBubble(
                      isMe: isMe,
                      themeColor: primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isReply)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.15 : 0.05,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide(
                                    color: isMe
                                        ? (isDark
                                              ? Colors.white.withOpacity(0.8)
                                              : primaryColor)
                                        : primaryColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    replyName ?? '',
                                    style: TextStyle(
                                      color: isMe
                                          ? (isDark
                                                ? Colors.white
                                                : primaryColor)
                                          : primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    replyText ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Builder(
                            builder: (context) {
                              if (mainText.startsWith('[VIEW_ONCE]')) {
                                String base64Img = mainText.substring(11);
                                String photoHash = mainText.hashCode.toString();
                                bool isViewed = viewedPhotos.contains(
                                  photoHash,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (!isViewed && !isMe) {
                                      _openEphemeralPhoto(base64Img, photoHash);
                                    } else if (isViewed && !isMe) {
                                      _showRedPopup(
                                        context,
                                        "Esta imagen ya fue vista y destruida.",
                                      );
                                    } else if (isMe) {
                                      _showRedPopup(
                                        context,
                                        "Las fotos efímeras que envías no se pueden previsualizar.",
                                      );
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isViewed
                                            ? Icons.check_circle_outline_rounded
                                            : Icons
                                                  .local_fire_department_outlined,
                                        color: isMe
                                            ? (isDark
                                                  ? Colors.white
                                                  : primaryColor)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isViewed
                                            ? "Visualizada"
                                            : (isMe
                                                  ? "Enviada"
                                                  : "Toca para revelar"),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (mainText.startsWith('[AUDIO]')) {
                                return VoiceNotePlayer(
                                  base64Audio: mainText.substring(7),
                                  isMe: isMe,
                                  themeColor: primaryColor,
                                );
                              } else {
                                return Text(
                                  mainText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (i >= messages.length - 1) {
                return bubble
                    .animate()
                    .scale(
                      alignment: isMe
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      curve: UIConstants.bouncyCurve,
                      duration: 500.ms,
                    )
                    .fade();
              }
              return bubble;
            },
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 12,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest.withOpacity(0.90),
                        Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyingTo != null)
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: ShapeDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.85),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          replyingTo!['sender_id'] ==
                                                  widget.myUser['uid']
                                              ? 'Tú'
                                              : peerName,
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getCleanText(replyingTo!['content']),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => replyingTo = null);
                                    },
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .slideY(begin: 1.0, curve: UIConstants.bouncyCurve)
                            .fade(),

                      Builder(
                        builder: (context) {
                          List blocked = widget.myUser['blocked_users'] ?? [];
                          if (blocked.contains(widget.peerUser['uid'])) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: ShapeDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                "Has bloqueado a este contacto",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }
                          return Container(
                            decoration: ShapeDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withOpacity(0.75),
                              shape: const StadiumBorder(),
                              shadows: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.04),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!_isRecording)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 4.0,
                                      left: 4.0,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 22,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.5),
                                        padding: const EdgeInsets.all(10),
                                      ),
                                      onPressed: _sendViewOncePhoto,
                                    ),
                                  ),
                                if (!_isRecording) const SizedBox(width: 4),

                                Expanded(
                                  child: _isRecording
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .errorContainer
                                                .withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(
                                              UIConstants.pillRadius,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error
                                                  .withOpacity(0.4),
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withOpacity(0.15),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: ShapeDecoration(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.error,
                                                      shape:
                                                          const CircleBorder(),
                                                    ),
                                                    child: const Icon(
                                                      Icons.mic_none_rounded,
                                                      size: 18,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                  .animate(
                                                    onPlay: (c) =>
                                                        c.repeat(reverse: true),
                                                  )
                                                  .scale(
                                                    begin: const Offset(1, 1),
                                                    end: const Offset(1.1, 1.1),
                                                    duration: 600.ms,
                                                  ),
                                              const SizedBox(width: 12),

                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "Grabando...",
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onErrorContainer,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      _formatRecordTime(
                                                        _recordDuration,
                                                      ),
                                                      style: TextStyle(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: List.generate(
                                                  4,
                                                  (index) =>
                                                      Container(
                                                            margin:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 2,
                                                                ),
                                                            width: 3,
                                                            height: 12,
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    2,
                                                                  ),
                                                            ),
                                                          )
                                                          .animate(
                                                            onPlay: (c) =>
                                                                c.repeat(
                                                                  reverse: true,
                                                                ),
                                                          )
                                                          .scaleY(
                                                            begin: 0.4,
                                                            end: 1.4,
                                                            delay: (index * 100)
                                                                .ms,
                                                            duration: 400.ms,
                                                          ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).animate().fade().slideX(begin: 0.1)
                                      : TextField(
                                          controller: msgC,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          maxLines: 4,
                                          minLines: 1,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: "Mensaje...",
                                            fillColor: Colors.transparent,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 14,
                                                ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 4.0,
                                    right: 4.0,
                                  ),
                                  child: FloatingActionButton(
                                    elevation: 0,
                                    mini: true,
                                    backgroundColor: _isRecording
                                        ? Theme.of(context).colorScheme.error
                                        : primaryColor,
                                    foregroundColor: Colors.white,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      msgC.text.trim().isEmpty
                                          ? _toggleRecording()
                                          : _send();
                                    },
                                    shape: const CircleBorder(),
                                    child: Icon(
                                      _isRecording
                                          ? Icons.stop_rounded
                                          : (_hasText
                                                ? Icons.send_rounded
                                                : Icons.mic_none_rounded),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupChatScreen extends StatefulWidget {
  final Map myUser, group;
  final IO.Socket socket;
  const GroupChatScreen({
    super.key,
    required this.myUser,
    required this.group,
    required this.socket,
  });
  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  List messages = [];
  final msgC = TextEditingController();
  final scrollC = ScrollController();
  Color? chatThemeColor;
  String membersNames = "Cargando...";
  List<String> viewedPhotos = [];
  bool _isRecording = false;
  late AudioRecorder _audioRecorder;

  Map? replyingTo;
  String typingUser = "";
  bool isTyping = false;
  bool _hasText = false;

  Timer? _typingTimer;
  Timer? _recordTimer;
  int _recordDuration = 0;

  Color _getNameColor(String name, bool isDark) {
    final colors = isDark
        ? [
            Colors.redAccent,
            Colors.orangeAccent,
            Colors.greenAccent,
            Colors.lightBlueAccent,
            Colors.purpleAccent,
            Colors.tealAccent,
          ]
        : [
            Colors.red.shade700,
            Colors.orange.shade800,
            Colors.green.shade700,
            Colors.blue.shade700,
            Colors.purple.shade700,
            Colors.teal.shade700,
          ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  void initState() {
    super.initState();
    activeChatUserId = widget.group['id'].toString();
    _loadTheme();
    _loadViewedPhotos();
    _loadMembersNames();
    _history();
    widget.socket.emit('join_group', widget.group['id']);
    _audioRecorder = AudioRecorder();

    msgC.addListener(() {
      bool currentHasText = msgC.text.trim().isNotEmpty;
      if (currentHasText != _hasText) {
        setState(() {
          _hasText = currentHasText;
        });
      }

      if (msgC.text.isNotEmpty && !isTyping) {
        isTyping = true;
        widget.socket.emit('typing_group', {
          'group_id': widget.group['id'],
          'sender_name': widget.myUser['name'],
        });
      } else if (msgC.text.isEmpty && isTyping) {
        isTyping = false;
        widget.socket.emit('stop_typing_group', {
          'group_id': widget.group['id'],
        });
      }
    });

    widget.socket.on('new_group_message', (data) {
      if (mounted &&
          data['group_id'].toString() == widget.group['id'].toString()) {
        if (data['sender_id'] != widget.myUser['uid']) {
          setState(() {
            messages.add(data);
            typingUser = "";
          });
          _scroll();
          playChatSound('receive.mp3');
          HapticFeedback.lightImpact();
        }
      }
    });

    widget.socket.on('user_typing_group', (data) {
      if (mounted &&
          data['group_id'].toString() == widget.group['id'].toString()) {
        setState(
          () => typingUser = "${data['sender_name']} está escribiendo...",
        );
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => typingUser = "");
        });
      }
    });
    widget.socket.on('user_stop_typing_group', (data) {
      if (mounted &&
          data['group_id'].toString() == widget.group['id'].toString()) {
        setState(() => typingUser = "");
      }
    });
  }

  _loadViewedPhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() {
        viewedPhotos =
            prefs.getStringList('viewed_photos_${widget.myUser['uid']}') ?? [];
      });
  }

  _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('theme_group_${widget.group['id']}');
    if (colorValue != null && mounted) {
      setState(() {
        chatThemeColor = Color(colorValue);
      });
    }
  }

  _saveTheme(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_group_${widget.group['id']}', color.value);
    if (mounted)
      setState(() {
        chatThemeColor = color;
      });
  }

  _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => _buildGlassmorphism(
        child: const SizedBox.expand(),
        color: Theme.of(context).colorScheme.surface,
        blur: 40,
      ),
    );
  }

  Widget _themeIcon(Color c) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        _saveTheme(c);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ).animate().scale(curve: UIConstants.bouncyCurve),
    );
  }

  _loadMembersNames() async {
    try {
      final res = await http.get(
        Uri.parse('$apiURL/group-members/${widget.group['id']}'),
      );
      if (res.statusCode == 200) {
        List data = jsonDecode(res.body);
        List<String> names = List<String>.from(
          data.map((m) {
            String n = m['name']?.toString() ?? 'Desconocido';
            if (n == 'null' || n.trim().isEmpty) n = 'Desconocido';
            return m['uid'].toString() == widget.myUser['uid'].toString()
                ? 'Tú'
                : n;
          }),
        );
        if (mounted) setState(() => membersNames = names.join(', '));
      }
    } catch (e) {
      if (mounted) setState(() => membersNames = "No se pudo cargar");
    }
  }

  _history() async {
    final res = await http.get(
      Uri.parse('$apiURL/group-messages/${widget.group['id']}'),
    );
    if (res.statusCode == 200 && mounted) {
      setState(() => messages = List.from(jsonDecode(res.body)));
      _scroll();
    }
  }

  _scroll() => Future.delayed(
    const Duration(milliseconds: 100),
    () => {
      if (scrollC.hasClients)
        scrollC.animateTo(
          scrollC.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: UIConstants.animCurve,
        ),
    },
  );
  _goToInfo() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) =>
            GroupInfoScreen(myUser: widget.myUser, group: widget.group),
      ),
    );
    _loadMembersNames();
    if (mounted) setState(() {});
  }

  String _getCleanText(String rawContent) {
    if (rawContent.startsWith('[REPLY:')) {
      int closeBracket = rawContent.indexOf(']');
      if (closeBracket != -1) return rawContent.substring(closeBracket + 1);
    }
    return rawContent;
  }

  String _formatRecordTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  _sendViewOncePhoto() async {
    HapticFeedback.lightImpact();
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      String base64Image = base64Encode(bytes);
      var newMsg = {
        'group_id': widget.group['id'],
        'sender_id': widget.myUser['uid'],
        'sender_name': widget.myUser['name'],
        'content': '[VIEW_ONCE]$base64Image',
      };
      widget.socket.emit('send_group_message', newMsg);
      if (mounted) setState(() => messages.add(newMsg));
      _scroll();
      playChatSound('send.mp3');
    }
  }

  void _openEphemeralPhoto(String base64Img, String photoHash) async {
    await ScreenProtector.preventScreenshotOn();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text(
              "Imagen Segura",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ),
          body: InteractiveViewer(
            child: Center(child: Image.memory(base64Decode(base64Img))),
          ),
        ),
      ),
    );
    await ScreenProtector.preventScreenshotOff();
    if (mounted)
      setState(() {
        viewedPhotos.add(photoHash);
      });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'viewed_photos_${widget.myUser['uid']}',
      viewedPhotos,
    );
  }

  _toggleRecording() async {
    HapticFeedback.heavyImpact();
    if (_isRecording) {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (mounted)
        setState(() {
          _isRecording = false;
          _recordDuration = 0;
        });
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        final base64String = base64Encode(bytes);
        _send('[AUDIO]$base64String');
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordDuration = 0;
          });
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) setState(() => _recordDuration++);
          });
        }
      } else {
        _showRedPopup(context, "Activa los permisos del micrófono.");
      }
    }
  }

  _send([String? customContent]) {
    String text = customContent ?? msgC.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    if (replyingTo != null && customContent == null) {
      String rName = replyingTo!['sender_id'] == widget.myUser['uid']
          ? 'Tú'
          : (replyingTo!['sender_name'] ?? 'Usuario');
      String rText = _getCleanText(
        replyingTo!['content'],
      ).replaceAll('|', ' ').replaceAll(']', ' ');
      text = '[REPLY:$rName|$rText]$text';
    }

    var newMsg = {
      'group_id': widget.group['id'],
      'sender_id': widget.myUser['uid'],
      'sender_name': widget.myUser['name'],
      'content': text,
    };
    widget.socket.emit('send_group_message', newMsg);
    if (mounted) setState(() => messages.add(newMsg));

    if (customContent == null) msgC.clear();
    if (mounted)
      setState(() {
        replyingTo = null;
        isTyping = false;
        _hasText = false;
      });
    widget.socket.emit('stop_typing_group', {'group_id': widget.group['id']});
    _scroll();
    playChatSound('send.mp3');
  }

  @override
  void dispose() {
    activeChatUserId = null;
    msgC.dispose();
    scrollC.dispose();
    _audioRecorder.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String groupAvatar = widget.group['avatar']?.toString() ?? '';
    if (groupAvatar == 'null' || groupAvatar.length < 20) groupAvatar = '';
    String groupName = widget.group['name']?.toString() ?? 'Grupo';
    if (groupName == 'null' || groupName.isEmpty) groupName = 'Grupo';
    Color primaryColor =
        chatThemeColor ?? Theme.of(context).colorScheme.primary;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Uint8List? groupImageBytes = ImageCacheHelper.getBytes(groupAvatar);

    Widget chatBackground = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerLowest,
            primaryColor.withOpacity(isDark ? 0.05 : 0.02),
            Theme.of(context).colorScheme.surfaceContainerLowest,
          ],
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        flexibleSpace: RepaintBoundary(
          child: _buildGlassmorphism(
            child: const SizedBox.expand(),
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            blur: 40,
          ),
        ),
        title: GestureDetector(
          onTap: _goToInfo,
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.group['id']}',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: ShapeDecoration(
                    shape: const CircleBorder(),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    image: groupImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(groupImageBytes),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: groupImageBytes == null
                      ? Icon(
                          Icons.groups_outlined,
                          size: 24,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      typingUser.isNotEmpty ? typingUser : membersNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: typingUser.isNotEmpty
                            ? primaryColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: typingUser.isNotEmpty
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.palette_outlined, color: primaryColor, size: 22),
            onPressed: _showThemePicker,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: primaryColor, size: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              HapticFeedback.lightImpact();
              try {
                final res = await http.post(
                  Uri.parse('$apiURL/chat-action'),
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'my_uid': widget.myUser['uid'],
                    'peer_uid': widget.group['id'].toString(),
                    'action': value,
                  }),
                );
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  bool isActive = data['status'];

                  if (value == 'mute') {
                    List m = List.from(widget.myUser['muted_chats'] ?? []);
                    isActive
                        ? m.add(widget.group['id'].toString())
                        : m.remove(widget.group['id'].toString());
                    widget.myUser['muted_chats'] = m;
                  }
                  if (value == 'pin') {
                    List p = List.from(widget.myUser['pinned_chats'] ?? []);
                    isActive
                        ? p.add(widget.group['id'].toString())
                        : p.remove(widget.group['id'].toString());
                    widget.myUser['pinned_chats'] = p;
                  }

                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setString('user_data', jsonEncode(widget.myUser));

                  String msj = "";
                  if (value == 'mute')
                    msj = isActive
                        ? "Tribu silenciada 🔕"
                        : "Sonido activado 🔔";
                  if (value == 'pin')
                    msj = isActive ? "Tribu fijada 📌" : "Tribu desfijada 📌";
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        msj,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: const StadiumBorder(),
                    ),
                  );
                }
              } catch (e) {}
            },
            itemBuilder: (BuildContext context) {
              List muted = widget.myUser['muted_chats'] ?? [];
              List pinned = widget.myUser['pinned_chats'] ?? [];
              bool isMuted = muted.contains(widget.group['id'].toString());
              bool isPinned = pinned.contains(widget.group['id'].toString());

              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(
                        isMuted
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isMuted ? 'Quitar silencio' : 'Silenciar',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isPinned ? 'Desfijar' : 'Fijar tribu',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          chatBackground,
          ListView.builder(
            physics: const BouncingScrollPhysics(),
            controller: scrollC,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
              bottom: 200,
            ),
            itemCount: messages.length,
            itemBuilder: (c, i) {
              bool isMe = messages[i]['sender_id'] == widget.myUser['uid'];
              String rawContent = messages[i]['content'];

              if (rawContent.startsWith('[SYSTEM]')) {
                String sysText = rawContent.substring(8);
                return Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      sysText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ).animate().fade().scale(curve: UIConstants.bouncyCurve);
              }

              String senderName =
                  messages[i]['sender_name']?.toString() ?? 'Usuario';
              if (senderName == 'null' || senderName.isEmpty)
                senderName = 'Usuario';

              bool isReply = rawContent.startsWith('[REPLY:');
              String? replyName;
              String? replyText;
              String mainText = rawContent;
              if (isReply) {
                int closeBracket = rawContent.indexOf(']');
                if (closeBracket != -1) {
                  String replyData = rawContent.substring(7, closeBracket);
                  int separator = replyData.indexOf('|');
                  if (separator != -1) {
                    replyName = replyData.substring(0, separator);
                    replyText = replyData.substring(separator + 1);
                    mainText = rawContent.substring(closeBracket + 1);
                  }
                }
              }

              Widget bubble = Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Dismissible(
                  key: Key(messages[i].hashCode.toString() + i.toString()),
                  direction: DismissDirection.startToEnd,
                  onUpdate: (details) {
                    if (details.progress > 0.2 && details.progress < 0.22)
                      HapticFeedback.selectionClick();
                  },
                  confirmDismiss: (direction) async {
                    HapticFeedback.mediumImpact();
                    setState(() => replyingTo = messages[i]);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 24,
                      color: primaryColor,
                    ),
                  ),
                  child: GestureDetector(
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      setState(() => replyingTo = messages[i]);
                    },
                    child: MDBubble(
                      isMe: isMe,
                      themeColor: primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              senderName,
                              style: TextStyle(
                                color: _getNameColor(senderName, isDark),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (!isMe) const SizedBox(height: 2),

                          if (isReply)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.15 : 0.05,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide(
                                    color: isMe
                                        ? (isDark
                                              ? Colors.white.withOpacity(0.8)
                                              : primaryColor)
                                        : primaryColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    replyName ?? '',
                                    style: TextStyle(
                                      color: isMe
                                          ? (isDark
                                                ? Colors.white
                                                : primaryColor)
                                          : primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    replyText ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Builder(
                            builder: (context) {
                              if (mainText.startsWith('[VIEW_ONCE]')) {
                                String base64Img = mainText.substring(11);
                                String photoHash = mainText.hashCode.toString();
                                bool isViewed = viewedPhotos.contains(
                                  photoHash,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (!isViewed && !isMe) {
                                      _openEphemeralPhoto(base64Img, photoHash);
                                    } else if (isViewed && !isMe) {
                                      _showRedPopup(
                                        context,
                                        "Esta imagen ya fue vista y destruida.",
                                      );
                                    } else if (isMe) {
                                      _showRedPopup(
                                        context,
                                        "Las fotos efímeras que envías no se pueden previsualizar.",
                                      );
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isViewed
                                            ? Icons.check_circle_outline_rounded
                                            : Icons
                                                  .local_fire_department_outlined,
                                        color: isMe
                                            ? (isDark
                                                  ? Colors.white
                                                  : primaryColor)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isViewed
                                            ? "Visualizada"
                                            : (isMe
                                                  ? "Enviada"
                                                  : "Toca para revelar"),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (mainText.startsWith('[AUDIO]')) {
                                return VoiceNotePlayer(
                                  base64Audio: mainText.substring(7),
                                  isMe: isMe,
                                  themeColor: primaryColor,
                                );
                              } else {
                                return Text(
                                  mainText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (i >= messages.length - 1) {
                return bubble
                    .animate()
                    .scale(
                      alignment: isMe
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      curve: UIConstants.bouncyCurve,
                      duration: 500.ms,
                    )
                    .fade();
              }
              return bubble;
            },
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 12,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest.withOpacity(0.90),
                        Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyingTo != null)
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: ShapeDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.85),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          replyingTo!['sender_id'] ==
                                                  widget.myUser['uid']
                                              ? 'Tú'
                                              : (replyingTo!['sender_name'] ??
                                                    'Usuario'),
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getCleanText(replyingTo!['content']),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => replyingTo = null);
                                    },
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .slideY(begin: 1.0, curve: UIConstants.bouncyCurve)
                            .fade(),

                      Container(
                        decoration: ShapeDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh.withOpacity(0.75),
                          shape: const StadiumBorder(),
                          shadows: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.04),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!_isRecording)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 4.0,
                                  left: 4.0,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 22,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.5),
                                    padding: const EdgeInsets.all(10),
                                  ),
                                  onPressed: _sendViewOncePhoto,
                                ),
                              ),
                            if (!_isRecording) const SizedBox(width: 4),

                            Expanded(
                              child: _isRecording
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer
                                            .withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(
                                          UIConstants.pillRadius,
                                        ),
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error.withOpacity(0.4),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withOpacity(0.15),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: ShapeDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                  shape: const CircleBorder(),
                                                ),
                                                child: const Icon(
                                                  Icons.mic_none_rounded,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                              )
                                              .animate(
                                                onPlay: (c) =>
                                                    c.repeat(reverse: true),
                                              )
                                              .scale(
                                                begin: const Offset(1, 1),
                                                end: const Offset(1.1, 1.1),
                                                duration: 600.ms,
                                              ),
                                          const SizedBox(width: 12),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Grabando...",
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onErrorContainer,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  _formatRecordTime(
                                                    _recordDuration,
                                                  ),
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(
                                              4,
                                              (index) =>
                                                  Container(
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 2,
                                                            ),
                                                        width: 3,
                                                        height: 12,
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                2,
                                                              ),
                                                        ),
                                                      )
                                                      .animate(
                                                        onPlay: (c) => c.repeat(
                                                          reverse: true,
                                                        ),
                                                      )
                                                      .scaleY(
                                                        begin: 0.4,
                                                        end: 1.4,
                                                        delay: (index * 100).ms,
                                                        duration: 400.ms,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ).animate().fade().slideX(begin: 0.1)
                                  : TextField(
                                      controller: msgC,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      maxLines: 4,
                                      minLines: 1,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: "Escribe a la tribu...",
                                        fillColor: Colors.transparent,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4.0,
                                right: 4.0,
                              ),
                              child: FloatingActionButton(
                                elevation: 0,
                                mini: true,
                                backgroundColor: _isRecording
                                    ? Theme.of(context).colorScheme.error
                                    : primaryColor,
                                foregroundColor: Colors.white,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  msgC.text.trim().isEmpty
                                      ? _toggleRecording()
                                      : _send();
                                },
                                shape: const CircleBorder(),
                                child: Icon(
                                  _isRecording
                                      ? Icons.stop_rounded
                                      : (_hasText
                                            ? Icons.send_rounded
                                            : Icons.mic_none_rounded),
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NOTAS DE VOZ
// ==========================================
class VoiceNotePlayer extends StatefulWidget {
  final String base64Audio;
  final bool isMe;
  final Color themeColor;
  const VoiceNotePlayer({
    super.key,
    required this.base64Audio,
    required this.isMe,
    required this.themeColor,
  });
  @override
  _VoiceNotePlayerState createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    int bytes = (widget.base64Audio.length * 0.75).toInt();
    int estimatedSeconds = bytes ~/ 16000;
    if (estimatedSeconds < 1) estimatedSeconds = 1;
    _duration = Duration(seconds: estimatedSeconds);
  }

  Future<void> _prepareAudio() async {
    setState(() => _isLoading = true);
    try {
      final bytes = base64Decode(widget.base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audio_${widget.base64Audio.hashCode}.m4a');
      if (!await file.exists()) {
        await file.writeAsBytes(bytes);
      }

      _durationSub = _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _positionSub = _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
      });
      _completeSub = _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
          _player.seek(Duration.zero);
        }
      });

      await _player.setSource(DeviceFileSource(file.path));
      _isInitialized = true;
    } catch (e) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String mins = (d.inMinutes % 60).toString().padLeft(2, '0');
    String secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    Color contentColor = widget.isMe
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 250,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: _isLoading
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: contentColor,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: contentColor,
                        size: 40,
                      )
                      .animate(target: _isPlaying ? 1 : 0)
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                      ),
            onPressed: () async {
              if (_isLoading) return;
              HapticFeedback.lightImpact();
              if (!_isInitialized) {
                await _prepareAudio();
                await _player.resume();
                return;
              }
              if (_isPlaying) {
                await _player.pause();
              } else {
                if (_position >= _duration && _duration > Duration.zero) {
                  await _player.seek(Duration.zero);
                }
                await _player.resume();
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                      elevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: contentColor,
                    inactiveTrackColor: contentColor.withOpacity(0.25),
                    thumbColor: contentColor,
                    trackHeight: 3,
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(
                      0.0,
                      _duration.inSeconds.toDouble() > 0
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                    ),
                    max: _duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    onChanged: (val) async {
                      HapticFeedback.selectionClick();
                      if (!_isInitialized) await _prepareAudio();
                      if (mounted)
                        setState(
                          () => _position = Duration(seconds: val.toInt()),
                        );
                      _player.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_position),
                        style: TextStyle(
                          color: contentColor.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _formatTime(_duration),
                        style: TextStyle(
                          color: contentColor.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GroupInfoScreen extends StatefulWidget {
  final Map myUser, group;
  const GroupInfoScreen({super.key, required this.myUser, required this.group});
  @override
  _GroupInfoScreenState createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  List members = [];
  List contacts = [];
  List<String> selectedToAdd = [];
  bool iAmAdmin = false;
  String? base64GroupImage;
  String createdAt = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    base64GroupImage = widget.group['avatar']?.toString();
    if (base64GroupImage == 'null' || (base64GroupImage?.length ?? 0) < 20) {
      base64GroupImage = null;
    }
    if (widget.group['created_at'] != null &&
        widget.group['created_at'].toString() != 'null') {
      try {
        DateTime dt = DateTime.parse(
          widget.group['created_at'].toString(),
        ).toLocal();
        createdAt = "${dt.day}/${dt.month}/${dt.year}";
      } catch (e) {}
    }
    _loadMembers();
    _loadContacts();
  }

  _loadContacts() async {
    try {
      final res = await http.get(
        Uri.parse('$apiURL/contacts/${widget.myUser['uid']}'),
      );
      if (res.statusCode == 200 && mounted)
        setState(() => contacts = jsonDecode(res.body));
    } catch (e) {}
  }

  _pickGroupImage() async {
    HapticFeedback.lightImpact();
    if (!iAmAdmin) {
      _showRedPopup(
        context,
        "Solo los administradores pueden cambiar la imagen.",
      );
      return;
    }
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        base64GroupImage = base64Encode(bytes);
        widget.group['avatar'] = base64GroupImage;
      });
      _saveGroupAvatar();
    }
  }

  _saveGroupAvatar() async {
    try {
      await http.put(
        Uri.parse('$apiURL/update-group/${widget.group['id']}'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'avatar': base64GroupImage}),
      );
    } catch (e) {}
  }

  _loadMembers() async {
    try {
      final res = await http.get(
        Uri.parse('$apiURL/group-members/${widget.group['id']}'),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        List data = List.from(jsonDecode(res.body));
        bool adminStatus = false;
        for (var m in data) {
          if (m['uid'].toString() == widget.myUser['uid'].toString()) {
            if (m['role'] == 'admin') adminStatus = true;
          }
        }
        setState(() {
          members = data;
          iAmAdmin = adminStatus;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          isLoading = false;
        });
    }
  }

  _showAddMemberDialog() {
    HapticFeedback.lightImpact();
    selectedToAdd.clear();
    List availableContacts = contacts
        .where(
          (c) =>
              !members.any((m) => m['uid'].toString() == c['uid'].toString()),
        )
        .toList();

    if (availableContacts.isEmpty) {
      _showRedPopup(
        context,
        "No tienes más contactos disponibles para añadir a esta tribu.",
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: _buildGlassmorphism(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                blur: 40,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: ShapeDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: const CircleBorder(),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Añadir a Tribu",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: availableContacts.length,
                          itemBuilder: (c, i) {
                            var contact = availableContacts[i];
                            String uidText = contact['uid'].toString();
                            bool isSelected = selectedToAdd.contains(uidText);

                            String avatarStr =
                                contact['avatar']?.toString() ?? '';
                            if (avatarStr == 'null' || avatarStr.length < 20)
                              avatarStr = '';
                            Uint8List? memberImageBytes =
                                ImageCacheHelper.getBytes(avatarStr);
                            String nameStr =
                                contact['name']?.toString() ?? 'Usuario';

                            return Card(
                              color: isSelected
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withOpacity(0.8)
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.3),
                              elevation: 0,
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                checkboxShape: const CircleBorder(),
                                secondary: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: ShapeDecoration(
                                    shape: const CircleBorder(),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                    image: memberImageBytes != null
                                        ? DecorationImage(
                                            image: MemoryImage(
                                              memberImageBytes,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: memberImageBytes == null
                                      ? Center(
                                          child: Text(
                                            nameStr[0].toUpperCase(),
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  nameStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                value: isSelected,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  setDialogState(() {
                                    if (val == true)
                                      selectedToAdd.add(uidText);
                                    else
                                      selectedToAdd.remove(uidText);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (selectedToAdd.isNotEmpty)
                                  _addSelectedMembers();
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                "Añadir",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(curve: UIConstants.bouncyCurve, duration: 400.ms);
          },
        );
      },
    );
  }

  _addSelectedMembers() async {
    if (selectedToAdd.isEmpty) return;
    HapticFeedback.mediumImpact();
    try {
      await http.post(
        Uri.parse('$apiURL/group-add-members'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'group_id': widget.group['id'],
          'admin_uid': widget.myUser['uid'],
          'members': selectedToAdd,
        }),
      );
      _loadMembers();
    } catch (e) {}
  }

  _promote(String targetUid) async {
    await http.post(
      Uri.parse('$apiURL/group-promote'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_id': widget.group['id'],
        'target_uid': targetUid,
        'admin_uid': widget.myUser['uid'],
      }),
    );
    _loadMembers();
  }

  _remove(String targetUid) async {
    await http.post(
      Uri.parse('$apiURL/group-remove'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_id': widget.group['id'],
        'target_uid': targetUid,
        'admin_uid': widget.myUser['uid'],
      }),
    );
    _loadMembers();
  }

  _leaveGroup() async {
    HapticFeedback.heavyImpact();
    await http.post(
      Uri.parse('$apiURL/group-leave'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_id': widget.group['id'],
        'uid': widget.myUser['uid'],
      }),
    );
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String groupName = widget.group['name']?.toString() ?? 'Grupo';
    if (groupName == 'null' || groupName.isEmpty) groupName = 'Grupo';
    Uint8List? groupImageBytes = ImageCacheHelper.getBytes(base64GroupImage);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Tribu",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _buildAuraBackground(
        context,
        Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            ),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: ShapeDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: const CircleBorder(),
                      image: groupImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(groupImageBytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: groupImageBytes == null
                        ? Icon(
                            Icons.groups_outlined,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  if (iAmAdmin)
                    Padding(
                      padding: const EdgeInsets.all(2.0),
                      child:
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: FloatingActionButton(
                              elevation: 2,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: const CircleBorder(),
                              onPressed: _pickGroupImage,
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                              ),
                            ),
                          ).animate().scale(
                            delay: 200.ms,
                            curve: UIConstants.bouncyCurve,
                          ),
                    ),
                ],
              ).animate().fade().scale(curve: UIConstants.bouncyCurve),
            ),
            const SizedBox(height: 16),
            Text(
              groupName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ).animate().fade().slideY(begin: 0.1),
            if (createdAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Creado el $createdAt",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Miembros (${members.length})",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (iAmAdmin)
                    FilledButton.tonalIcon(
                      onPressed: _showAddMemberDialog,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text(
                        "Añadir",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: members.length,
                      itemBuilder: (c, i) {
                        var m = members[i];
                        bool isAdmin = m['role'] == 'admin';
                        bool isMe =
                            m['uid'].toString() ==
                            widget.myUser['uid'].toString();
                        String avatarStr = m['avatar']?.toString() ?? '';
                        if (avatarStr == 'null' || avatarStr.length < 20)
                          avatarStr = '';
                        String nameStr = m['name']?.toString() ?? 'Desconocido';
                        if (nameStr == 'null' || nameStr.trim().isEmpty)
                          nameStr = 'Desconocido';
                        Uint8List? memberImageBytes = ImageCacheHelper.getBytes(
                          avatarStr,
                        );
                        return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                child: ListTile(
                                  leading: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: ShapeDecoration(
                                      shape: const CircleBorder(),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                      image: memberImageBytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(
                                                memberImageBytes,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: memberImageBytes == null
                                        ? Center(
                                            child: Text(
                                              nameStr[0].toUpperCase(),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    isMe ? "Tú" : nameStr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isAdmin ? "Administrador" : "Miembro",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isAdmin
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      fontWeight: isAdmin
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  trailing: (iAmAdmin && !isMe)
                                      ? PopupMenuButton(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            size: 22,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          itemBuilder: (context) => [
                                            if (!isAdmin)
                                              const PopupMenuItem(
                                                value: 'promote',
                                                child: Text(
                                                  "Hacer Administrador",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Text(
                                                "Expulsar de la tribu",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onSelected: (val) {
                                            if (val == 'promote')
                                              _promote(m['uid']);
                                            if (val == 'remove')
                                              _remove(m['uid']);
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            )
                            .animate()
                            .fade(delay: (i * 20).ms)
                            .slideX(begin: 0.05, curve: UIConstants.animCurve);
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer,
                  ),
                  onPressed: _leaveGroup,
                  child: const Text("SALIR DE LA TRIBU"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PeerProfileScreen extends StatelessWidget {
  final Map user;
  const PeerProfileScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    String avatar = user['avatar']?.toString() ?? '';
    if (avatar == 'null' || avatar.length < 20) avatar = '';
    String name = user['name']?.toString() ?? 'Usuario';
    if (name == 'null' || name.isEmpty) name = 'Usuario';

    String bio = user['bio']?.toString() ?? '';
    if (bio == 'null' || bio.trim().isEmpty)
      bio = '¡Hola! Estoy usando CroketaChat.';
    Uint8List? userImageBytes = ImageCacheHelper.getBytes(avatar);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Contacto",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _buildAuraBackground(
        context,
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 32,
            16,
            40,
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (userImageBytes != null) {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          body: Center(
                            child: InteractiveViewer(
                              child: Image.memory(userImageBytes),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Hero(
                  tag: 'avatar_${user['uid']}',
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: ShapeDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: const CircleBorder(),
                      image: userImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(userImageBytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: userImageBytes == null
                        ? Center(
                            child: Text(
                              name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 56,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ).animate().fade().slideY(begin: 0.1),
              const SizedBox(height: 4),
              Text(
                "@${user['nickname']}",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fade().slideY(begin: 0.1),
              const SizedBox(height: 40),

              ...[
                    Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: ShapeDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            shape: const CircleBorder(),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          "Acerca de",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            bio,
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: ShapeDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            shape: const CircleBorder(),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          "Chat cifrado",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Tus mensajes con esta persona están protegidos.",
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]
                  .animate(interval: 100.ms)
                  .fade()
                  .slideY(begin: 0.1, curve: UIConstants.bouncyCurve),
            ],
          ),
        ),
      ),
    );
  }
}
