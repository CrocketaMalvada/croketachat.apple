import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Configuración base de animaciones de flutter_animate
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
                // Tipografía Expressive: Plus Jakarta Sans
                textTheme: GoogleFonts.plusJakartaSansTextTheme(
                  ThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                  ).textTheme,
                ),
                // Toque visual de Android 14+ (Chispas)
                splashFactory: InkSparkle.splashFactory,
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
                  scrolledUnderElevation: 0,
                  backgroundColor:
                      Colors.transparent, // Transparente para el glassmorphism
                  elevation: 0,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: activeScheme.surfaceContainerHigh.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide(
                      color: activeScheme.outlineVariant.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide(
                      color: activeScheme.primary,
                      width: 2.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  labelStyle: TextStyle(
                    color: activeScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  hintStyle: TextStyle(
                    color: activeScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 64),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                cardTheme: CardThemeData(
                  elevation: 0,
                  color: activeScheme.surfaceContainerLow,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                listTileTheme: ListTileThemeData(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
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

// Widget utilitario para efecto Cristal
Widget _buildGlassmorphism({required Widget child, required Color color}) {
  return ClipRRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(color: color.withOpacity(0.6), child: child),
    ),
  );
}

Widget _buildMD3Field(
  TextEditingController c,
  String l,
  IconData i, {
  bool isPass = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24.0),
    child: TextFormField(
      controller: c,
      obscureText: isPass,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 8.0),
          child: Icon(i, size: 26),
        ),
      ),
    ),
  );
}

void _showRedPopup(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      title: Row(
        children: [
          Icon(
            Icons.error_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 32,
          ).animate().shake(),
          const SizedBox(width: 12),
          Text(
            "Atención",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
            foregroundColor: Theme.of(context).colorScheme.errorContainer,
            minimumSize: const Size(100, 48),
          ),
          onPressed: () => Navigator.pop(c),
          child: const Text("Entendido"),
        ),
      ],
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
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
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
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
          "Privacidad y Seguridad",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).padding.top + 32,
          24,
          40,
        ),
        children: [
          Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack)
              .then()
              .shimmer(),
          const SizedBox(height: 32),
          Text(
            "Tu privacidad es\nnuestra prioridad",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Descubre cómo protegemos tus datos y conversaciones.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 48),

          ...[
                _buildSection(
                  context,
                  "Cifrado de Alta Seguridad",
                  "Toda la comunicación entre tu dispositivo y nuestros servidores está protegida por protocolos de cifrado robustos...",
                  Icons.lock_rounded,
                ),
                _buildSection(
                  context,
                  "Privacidad Absoluta de Datos",
                  "CroketaChat tiene una política estricta de CERO comercialización. No vendemos, no alquilamos y no compartimos tus datos personales...",
                  Icons.visibility_off_rounded,
                ),
                _buildSection(
                  context,
                  "Protección Antimorbos",
                  "Las fotos marcadas como 'Efímeras' cuentan con una barrera de seguridad a nivel de sistema operativo...",
                  Icons.block_rounded,
                ),
              ]
              .animate(interval: 100.ms)
              .fade(duration: 400.ms)
              .slideY(begin: 0.2, curve: Curves.easeOutQuad),
        ],
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
    if (!isLogin && !acceptedTerms) {
      _showRedPopup(
        context,
        "Debes aceptar la política de uso y privacidad para poder crear tu cuenta.",
      );
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('$apiURL${isLogin ? '/login' : '/register'}'),
        headers: {'Content-Type': 'application/json'},
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
      _showRedPopup(context, "Error de conexión. Revisa tu internet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ).animate().slideY(begin: -0.5, curve: Curves.easeOutBack).fade(),
              const SizedBox(height: 40),
              Text(
                isLogin ? "Hola de nuevo." : "Crea tu cuenta.",
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ).animate().fade(delay: 100.ms).slideX(),
              const SizedBox(height: 12),
              Text(
                isLogin
                    ? "Inicia sesión para continuar"
                    : "Únete a la plataforma más segura",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fade(delay: 200.ms).slideX(),
              const SizedBox(height: 48),

              Column(
                children: [
                  if (!isLogin)
                    _buildMD3Field(nameC, "Nombre", Icons.person_rounded),
                  _buildMD3Field(
                    nickC,
                    "Usuario (@)",
                    Icons.alternate_email_rounded,
                  ),
                  _buildMD3Field(
                    passC,
                    "Contraseña",
                    Icons.lock_rounded,
                    isPass: true,
                  ),

                  if (!isLogin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: acceptedTerms,
                            onChanged: (val) =>
                                setState(() => acceptedTerms = val ?? false),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                right: 8.0,
                              ),
                              child: Text(
                                "Acepto la política de uso y privacidad. Todo está totalmente cifrado.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
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
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 64),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      onPressed: () {
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
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
            ],
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
  late TextEditingController nameC, nickC;
  String? base64Image;
  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.user['name']);
    nickC = TextEditingController(text: widget.user['nickname']);
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
    try {
      final res = await http.put(
        Uri.parse('$apiURL/update-profile/${widget.user['uid']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameC.text.trim(),
          'nickname': nickC.text.trim(),
          'avatar': base64Image,
        }),
      );
      if (res.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', res.body);
        Navigator.pop(context, jsonDecode(res.body));
      }
    } catch (e) {}
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
          "Tu Perfil",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).padding.top + 32,
          24,
          32,
        ),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(60), // Squircle
                      image: base64Image != null && base64Image!.isNotEmpty
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(base64Image!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: base64Image == null || base64Image!.isEmpty
                        ? Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 80,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: FloatingActionButton(
                      elevation: 4,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt_rounded, size: 28),
                    ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
                  ),
                ],
              ).animate().fade().scale(),
            ),
            const SizedBox(height: 48),

            ...[
              _buildMD3Field(nameC, "Nombre", Icons.person_rounded),
              _buildMD3Field(nickC, "Usuario", Icons.alternate_email_rounded),
              const SizedBox(height: 16),

              Card(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  title: const Text(
                    "Tema Oscuro",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  subtitle: const Text(
                    "Ideal para la noche",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: isDarkModeNotifier.value,
                  onChanged: (val) async {
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
                    horizontal: 28,
                    vertical: 16,
                  ),
                  leading: Icon(
                    Icons.security_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  title: const Text(
                    "Privacidad y Seguridad",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  subtitle: const Text(
                    "Términos, cifrado y protección",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacySecurityScreen(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
              FilledButton(
                onPressed: _save,
                child: const Text("Guardar Cambios"),
              ),
            ].animate(interval: 50.ms).slideY(begin: 0.1).fade(),
          ],
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
    try {
      final res = await http.post(
        Uri.parse('$apiURL/create-group'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': groupNameC.text.trim(),
          'admin_id': widget.myUser['uid'],
          'members': selectedUids,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201)
        Navigator.pop(context, true);
    } catch (e) {}
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
          "Nueva Tribu",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildMD3Field(
              groupNameC,
              "Nombre del grupo",
              Icons.groups_rounded,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Invitar miembros",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.users.length,
              itemBuilder: (c, i) {
                final user = widget.users[i];
                bool isSelected = selectedUids.contains(user['uid']);
                String avatar = user['avatar']?.toString() ?? '';
                if (avatar == 'null' || avatar.length < 20) avatar = '';
                String name = user['name']?.toString() ?? '?';
                if (name == 'null' || name.trim().isEmpty) name = '?';
                return Card(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    value: isSelected,
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    secondary: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        image: avatar.isNotEmpty
                            ? DecorationImage(
                                image: MemoryImage(base64Decode(avatar)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatar.isEmpty
                          ? Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true)
                          selectedUids.add(user['uid']);
                        else
                          selectedUids.remove(user['uid']);
                      });
                    },
                  ),
                ).animate().fade(delay: (i * 50).ms).slideX(begin: 0.1);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton.icon(
                onPressed: _createGroup,
                icon: const Icon(Icons.check_rounded, size: 28),
                label: const Text("Crear Grupo"),
              ),
            ),
          ),
        ],
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
        icon: const Icon(Icons.system_update_rounded, size: 40),
        title: const Text("Actualización lista"),
        content: const Text(
          "Hay una nueva versión de la app. Es necesario actualizar para seguir chateando con normalidad.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Omitir"),
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
    if (content.startsWith('[VIEW_ONCE]')) return "📸 Foto efímera";
    if (content.startsWith('[AUDIO]')) return "🎤 Nota de voz";
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
    socket.on('new_message', (data) {
      String senderId = data['sender_id'];
      if (!users.any((u) => u['uid'] == senderId)) _load();
      setState(() {
        unreadCounts[senderId] = (unreadCounts[senderId] ?? 0) + 1;
        lastMessages[senderId] = _cleanMessageFormat(data['content']);
      });
      if (activeChatUserId != senderId) {
        String senderName = "Nuevo mensaje";
        try {
          senderName = users.firstWhere((u) => u['uid'] == senderId)['name'];
        } catch (e) {}
        _showNotification(senderName, data['content'], senderId);
      }
    });
    socket.on('new_group_message', (data) {
      String groupId = data['group_id'].toString();
      if (data['sender_id'] != currentUser['uid']) {
        setState(() {
          unreadCounts[groupId] = (unreadCounts[groupId] ?? 0) + 1;
          lastMessages[groupId] =
              "${data['sender_name']}: ${_cleanMessageFormat(data['content'])}";
        });
        if (activeChatUserId != groupId) {
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
    if (res.statusCode == 200) setState(() => users = jsonDecode(res.body));
    final resGroups = await http.get(
      Uri.parse('$apiURL/groups/${currentUser['uid']}'),
    );
    if (resGroups.statusCode == 200)
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
          if (isGroup && last['sender_id'] != currentUser['uid'])
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'my_uid': currentUser['uid'],
        'search_query': searchC.text.trim(),
      }),
    );
    if (res.statusCode == 200) {
      Navigator.pop(context);
      _load();
      searchC.clear();
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
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(
          Icons.delete_sweep_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 40,
        ),
        title: const Text("¿Borrar chat?"),
        content: const Text(
          "Esta acción eliminará la conversación permanentemente. ¿Continuar?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancelar"),
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    socket.disconnect();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => const AuthScreen()),
    );
  }

  _goToProfile() async {
    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => ProfileScreen(user: currentUser)),
    );
    if (updatedUser != null)
      setState(() {
        currentUser = updatedUser;
      });
  }

  _showAddDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        icon: Icon(
          Icons.person_add_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          "Añadir Amigo",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: searchC,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          decoration: InputDecoration(
            labelText: "Usuario (@)",
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Cancelar",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            onPressed: _add,
            child: const Text(
              "Añadir",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String myAvatar = currentUser['avatar']?.toString() ?? '';
    if (myAvatar == 'null' || myAvatar.length < 20) myAvatar = '';
    List combinedList = [
      ...groups.map((g) => {...g, 'is_group': true}),
      ...users.map((u) => {...u, 'is_group': false}),
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton.large(
        onPressed: _showAddDialog,
        elevation: 6,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ), // Expressive Squircle
        child: const Icon(Icons.edit_rounded, size: 36),
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            floating: false,
            pinned: true,
            flexibleSpace: _buildGlassmorphism(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                title: Text(
                  "CroketaChat",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _goToProfile,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 2,
                    ),
                    image: myAvatar.isNotEmpty
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(myAvatar)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: myAvatar.isEmpty
                      ? Center(
                          child: Text(
                            currentUser['name'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              IconButton(
                iconSize: 28,
                tooltip: "Nuevo Grupo",
                onPressed: () async {
                  bool? created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) =>
                          CreateGroupScreen(myUser: currentUser, users: users),
                    ),
                  );
                  if (created == true) _load();
                },
                icon: const Icon(Icons.group_add_rounded),
              ),
              IconButton(
                iconSize: 28,
                tooltip: "Cerrar sesión",
                onPressed: _logout,
                icon: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
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
                      size: 96,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ).animate().shake(delay: 1.seconds),
                    const SizedBox(height: 24),
                    Text(
                      "Tu bandeja está vacía",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Toca el lápiz para añadir un contacto",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (combinedList.isNotEmpty)
            SliverList(
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
                    : (item['nickname']?.toString() ?? 'U')[0].toUpperCase();
                String itemAvatar = item['avatar']?.toString() ?? '';
                if (itemAvatar == 'null' || itemAvatar.length < 20)
                  itemAvatar = '';
                int unread = unreadCounts[itemId] ?? 0;
                String lastMsg =
                    lastMessages[itemId] ?? "Envía el primer mensaje...";
                return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        color: unread > 0
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          onLongPress: () {
                            if (!isGroup)
                              _confirmDeleteChat(itemId, displayTitle);
                          },
                          leading: Hero(
                            tag: 'avatar_$itemId',
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                  width: 1.5,
                                ),
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                image: itemAvatar.isNotEmpty
                                    ? DecorationImage(
                                        image: MemoryImage(
                                          base64Decode(itemAvatar),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: itemAvatar.isEmpty
                                  ? Center(
                                      child: (isGroup
                                          ? Icon(
                                              Icons.groups_rounded,
                                              size: 30,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            )
                                          : Text(
                                              initial,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 24,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            )),
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(
                            displayTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: unread > 0
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: unread > 0
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          trailing: unread > 0
                              ? Badge(
                                  label: Text("$unread"),
                                  largeSize: 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  textColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                )
                              : null,
                          onTap: () {
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
                              ).then((_) => _load());
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
                              ).then((_) => _load());
                            }
                          },
                        ),
                      ),
                    )
                    .animate()
                    .fade(delay: (i * 50).ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutQuad);
              }, childCount: combinedList.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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
        ? themeColor.withOpacity(0.4)
        : themeColor.withOpacity(0.15);
    Color peerColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isMe ? myColor : peerColor,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
        // Burbujas Expressive: Extremadamente redondeadas, excepto en el origen
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(32),
          topRight: const Radius.circular(32),
          bottomLeft: Radius.circular(isMe ? 32 : 8),
          bottomRight: Radius.circular(isMe ? 8 : 32),
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

  @override
  void initState() {
    super.initState();
    activeChatUserId = widget.peerUser['uid'].toString();
    _loadTheme();
    _loadViewedPhotos();
    _history();
    _audioRecorder = AudioRecorder();
    msgC.addListener(() {
      setState(() {});
    });
    widget.socket.on('new_message', (data) {
      if (mounted && data['sender_id'] == widget.peerUser['uid']) {
        setState(() => messages.add(data));
        _scroll();
        playChatSound('receive.mp3');
      }
    });
  }

  _loadViewedPhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      viewedPhotos =
          prefs.getStringList('viewed_photos_${widget.myUser['uid']}') ?? [];
    });
  }

  _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('theme_${widget.peerUser['uid']}');
    if (colorValue != null) {
      setState(() {
        chatThemeColor = Color(colorValue);
      });
    }
  }

  _saveTheme(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_${widget.peerUser['uid']}', color.value);
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
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Personaliza el Chat",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _themeIcon(const Color(0xFF6750A4)),
                  _themeIcon(const Color(0xFF006874)),
                  _themeIcon(const Color(0xFF984061)),
                  _themeIcon(const Color(0xFF386A20)),
                  _themeIcon(const Color(0xFF825500)),
                  _themeIcon(const Color(0xFF0061A4)),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeIcon(Color c) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _saveTheme(c);
      },
      child: CircleAvatar(
        backgroundColor: c,
        radius: 32,
      ).animate().scale(curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    activeChatUserId = null;
    msgC.dispose();
    scrollC.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  _scroll() => Future.delayed(
    const Duration(milliseconds: 100),
    () => scrollC.animateTo(
      scrollC.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ),
  );
  _history() async {
    final res = await http.get(
      Uri.parse(
        '$apiURL/messages/${widget.myUser['uid']}/${widget.peerUser['uid']}',
      ),
    );
    if (res.statusCode == 200) {
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

  _sendViewOncePhoto() async {
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
      setState(() => messages.add(newMsg));
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
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text(
              "Imagen Segura",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: InteractiveViewer(
            child: Center(child: Image.memory(base64Decode(base64Img))),
          ),
        ),
      ),
    );
    await ScreenProtector.preventScreenshotOff();
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
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
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
        setState(() => _isRecording = true);
      } else {
        _showRedPopup(context, "Activa los permisos del micrófono.");
      }
    }
  }

  _send([String? customContent]) {
    String text = customContent ?? msgC.text.trim();
    if (text.isEmpty) return;
    if (replyingTo != null && customContent == null) {
      String rName = replyingTo!['sender_id'] == widget.myUser['uid']
          ? 'Tú'
          : widget.peerUser['name'];
      String rText = _getCleanText(replyingTo!['content']);
      rText = rText.replaceAll('|', ' ').replaceAll(']', ' ');
      text = '[REPLY:$rName|$rText]$text';
    }
    var newMsg = {
      'sender_id': widget.myUser['uid'],
      'receiver_id': widget.peerUser['uid'],
      'content': text,
    };
    widget.socket.emit('send_message', newMsg);
    setState(() => messages.add(newMsg));
    if (customContent == null) msgC.clear();
    setState(() => replyingTo = null);
    _scroll();
    playChatSound('send.mp3');
  }

  _goToUserInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => PeerProfileScreen(user: widget.peerUser),
      ),
    );
  }

  _confirmDeleteInsideChat() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(
          Icons.delete_sweep_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        title: const Text(
          "¿Borrar chat?",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Esta acción eliminará la conversación permanentemente de tu dispositivo. ¿Continuar?",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Cancelar",
              style: TextStyle(fontWeight: FontWeight.w800),
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
                if (res.statusCode == 200) {
                  Navigator.pop(context, true);
                }
              } catch (e) {}
            },
            child: const Text("Borrar"),
          ),
        ],
      ),
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 0,
        flexibleSpace: _buildGlassmorphism(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: const SizedBox.expand(),
        ),
        title: GestureDetector(
          onTap: _goToUserInfo,
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.peerUser['uid']}',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    image: peerAvatar.isNotEmpty
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(peerAvatar)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: peerAvatar.isEmpty
                      ? Center(
                          child: Text(
                            peerName[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      "@${widget.peerUser['nickname']}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
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
            icon: Icon(Icons.palette_rounded, color: primaryColor, size: 28),
            onPressed: _showThemePicker,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: primaryColor, size: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            onSelected: (value) async {
              if (value == 'delete') {
                _confirmDeleteInsideChat();
                return;
              }
              try {
                final res = await http.post(
                  Uri.parse('$apiURL/chat-action'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'my_uid': widget.myUser['uid'],
                    'peer_uid': widget.peerUser['uid'],
                    'action': value,
                  }),
                );
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  bool isActive = data['status'];
                  String msj = "";
                  if (value == 'mute')
                    msj = isActive
                        ? "Chat silenciado 🔕"
                        : "Sonido activado 🔔";
                  if (value == 'pin')
                    msj = isActive ? "Chat fijado 📌" : "Chat desfijado 📌";
                  if (value == 'block')
                    msj = isActive
                        ? "Usuario bloqueado 🚫"
                        : "Usuario desbloqueado ✅";
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        msj,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                  if (value == 'block' && isActive) {
                    Navigator.pop(context, true);
                  }
                }
              } catch (e) {}
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(Icons.volume_off_rounded, size: 22),
                    SizedBox(width: 16),
                    Text(
                      'Silenciar chat',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(Icons.push_pin_rounded, size: 22),
                    SizedBox(width: 16),
                    Text(
                      'Fijar chat',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, size: 22),
                    SizedBox(width: 16),
                    Text(
                      'Bloquear chat',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, size: 22, color: Colors.red),
                    SizedBox(width: 16),
                    Text(
                      'Borrar conversación',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            controller: scrollC,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 100,
              bottom: 140,
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
                  key: Key(messages[i].hashCode.toString()),
                  direction: DismissDirection.startToEnd,
                  confirmDismiss: (direction) async {
                    setState(() => replyingTo = messages[i]);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.reply_rounded, size: 28),
                  ),
                  child: GestureDetector(
                    onLongPress: () => setState(() => replyingTo = messages[i]),
                    child: MDBubble(
                      isMe: isMe,
                      themeColor: primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isReply)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  left: BorderSide(
                                    color: isMe
                                        ? (isDark ? Colors.white : primaryColor)
                                        : primaryColor,
                                    width: 4,
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
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    replyText ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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
                                    if (!isViewed && !isMe) {
                                      _openEphemeralPhoto(base64Img, photoHash);
                                    } else if (isViewed && !isMe) {
                                      _showRedPopup(
                                        context,
                                        "Esta imagen ya fue vista y destruida por seguridad.",
                                      );
                                    } else if (isMe) {
                                      _showRedPopup(
                                        context,
                                        "Las fotos efímeras que envías no se pueden volver a previsualizar.",
                                      );
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isViewed
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .local_fire_department_rounded,
                                        color: isMe
                                            ? (isDark
                                                  ? Colors.white
                                                  : primaryColor)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isViewed
                                            ? "Visualizada"
                                            : (isMe
                                                  ? "Enviada"
                                                  : "Toca para revelar"),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
              // Animamos solo los últimos mensajes que van llegando
              if (i >= messages.length - 1) {
                return bubble
                    .animate()
                    .scale(
                      alignment: isMe
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      curve: Curves.easeOutBack,
                    )
                    .fade();
              }
              return bubble;
            },
          ),

          // Floating Input Expressive
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyingTo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    replyingTo!['sender_id'] ==
                                            widget.myUser['uid']
                                        ? 'Tú'
                                        : peerName,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getCleanText(replyingTo!['content']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 28),
                              onPressed: () =>
                                  setState(() => replyingTo = null),
                            ),
                          ],
                        ),
                      ).animate().slideY(begin: 1.0).fade(),

                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!_isRecording)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: IconButton.filledTonal(
                                      icon: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 26,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        padding: const EdgeInsets.all(14),
                                      ),
                                      onPressed: _sendViewOncePhoto,
                                    ),
                                  ),
                                if (!_isRecording) const SizedBox(width: 8),
                                Expanded(
                                  child: _isRecording
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(
                                              32,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                    Icons.mic_rounded,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                  )
                                                  .animate(
                                                    onPlay: (c) =>
                                                        c.repeat(reverse: true),
                                                  )
                                                  .scale(
                                                    begin: const Offset(1, 1),
                                                    end: const Offset(1.2, 1.2),
                                                  ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  "Grabando...",
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onErrorContainer,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : TextField(
                                          controller: msgC,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          maxLines: 4,
                                          minLines: 1,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: "Mensaje",
                                            fillColor: Colors.transparent,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 16,
                                                ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: FloatingActionButton(
                                    elevation: 0,
                                    backgroundColor: _isRecording
                                        ? Theme.of(context).colorScheme.error
                                        : primaryColor,
                                    foregroundColor: Colors.white,
                                    onPressed: () => msgC.text.trim().isEmpty
                                        ? _toggleRecording()
                                        : _send(),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Icon(
                                      _isRecording
                                          ? Icons.stop_rounded
                                          : (msgC.text.trim().isEmpty
                                                ? Icons.mic_rounded
                                                : Icons.send_rounded),
                                      size: 28,
                                    ),
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
      setState(() {});
    });
    widget.socket.on('new_group_message', (data) {
      if (mounted &&
          data['group_id'].toString() == widget.group['id'].toString()) {
        if (data['sender_id'] != widget.myUser['uid']) {
          setState(() => messages.add(data));
          _scroll();
          playChatSound('receive.mp3');
        }
      }
    });
  }

  _loadViewedPhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      viewedPhotos =
          prefs.getStringList('viewed_photos_${widget.myUser['uid']}') ?? [];
    });
  }

  _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('theme_group_${widget.group['id']}');
    if (colorValue != null) {
      setState(() {
        chatThemeColor = Color(colorValue);
      });
    }
  }

  _saveTheme(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_group_${widget.group['id']}', color.value);
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
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Personaliza el Chat",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _themeIcon(const Color(0xFF6750A4)),
                  _themeIcon(const Color(0xFF006874)),
                  _themeIcon(const Color(0xFF984061)),
                  _themeIcon(const Color(0xFF386A20)),
                  _themeIcon(const Color(0xFF825500)),
                  _themeIcon(const Color(0xFF0061A4)),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeIcon(Color c) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _saveTheme(c);
      },
      child: CircleAvatar(
        backgroundColor: c,
        radius: 32,
      ).animate().scale(curve: Curves.easeOutBack),
    );
  }

  _loadMembersNames() async {
    try {
      final res = await http.get(
        Uri.parse('$apiURL/group-members/${widget.group['id']}'),
      );
      if (res.statusCode == 200) {
        List data = jsonDecode(res.body);
        List<String> names = data.map((m) {
          String n = m['name']?.toString() ?? '?';
          if (n == 'null' || n.isEmpty) n = '?';
          return m['uid'] == widget.myUser['uid'] ? 'Tú' : n;
        }).toList();
        if (mounted) setState(() => membersNames = names.join(', '));
      }
    } catch (e) {}
  }

  _history() async {
    final res = await http.get(
      Uri.parse('$apiURL/group-messages/${widget.group['id']}'),
    );
    if (res.statusCode == 200) {
      setState(() => messages = List.from(jsonDecode(res.body)));
      _scroll();
    }
  }

  _scroll() => Future.delayed(
    const Duration(milliseconds: 100),
    () => scrollC.animateTo(
      scrollC.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ),
  );
  _goToInfo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) =>
            GroupInfoScreen(myUser: widget.myUser, group: widget.group),
      ),
    );
    _loadMembersNames();
    setState(() {});
  }

  _sendViewOncePhoto() async {
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
      setState(() => messages.add(newMsg));
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
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text(
              "Imagen Segura",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: InteractiveViewer(
            child: Center(child: Image.memory(base64Decode(base64Img))),
          ),
        ),
      ),
    );
    await ScreenProtector.preventScreenshotOff();
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
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
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
            bitRate: 16000,
            sampleRate: 16000,
          ),
          path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        setState(() => _isRecording = true);
      } else {
        _showRedPopup(context, "Activa los permisos del micrófono.");
      }
    }
  }

  _send([String? customContent]) {
    String text = customContent ?? msgC.text.trim();
    if (text.isEmpty) return;
    var newMsg = {
      'group_id': widget.group['id'],
      'sender_id': widget.myUser['uid'],
      'sender_name': widget.myUser['name'],
      'content': text,
    };
    widget.socket.emit('send_group_message', newMsg);
    setState(() => messages.add(newMsg));
    if (customContent == null) msgC.clear();
    _scroll();
    playChatSound('send.mp3');
  }

  @override
  void dispose() {
    activeChatUserId = null;
    msgC.dispose();
    scrollC.dispose();
    _audioRecorder.dispose();
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 0,
        flexibleSpace: _buildGlassmorphism(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: const SizedBox.expand(),
        ),
        title: GestureDetector(
          onTap: _goToInfo,
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.group['id']}',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    image: groupAvatar.isNotEmpty
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(groupAvatar)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: groupAvatar.isEmpty
                      ? Icon(
                          Icons.groups_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      membersNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
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
            icon: Icon(Icons.palette_rounded, color: primaryColor, size: 28),
            onPressed: _showThemePicker,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            controller: scrollC,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 100,
              bottom: 140,
            ),
            itemCount: messages.length,
            itemBuilder: (c, i) {
              bool isMe = messages[i]['sender_id'] == widget.myUser['uid'];
              String content = messages[i]['content'];
              String senderName =
                  messages[i]['sender_name']?.toString() ?? 'Usuario';
              if (senderName == 'null' || senderName.isEmpty)
                senderName = 'Usuario';
              Widget bubble = Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                            color: primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      if (!isMe) const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          if (content.startsWith('[VIEW_ONCE]')) {
                            String base64Img = content.substring(11);
                            String photoHash = content.hashCode.toString();
                            bool isViewed = viewedPhotos.contains(photoHash);
                            return GestureDetector(
                              onTap: () {
                                if (!isViewed && !isMe) {
                                  _openEphemeralPhoto(base64Img, photoHash);
                                } else if (isViewed && !isMe) {
                                  _showRedPopup(
                                    context,
                                    "Esta imagen ya fue vista y destruida por seguridad.",
                                  );
                                } else if (isMe) {
                                  _showRedPopup(
                                    context,
                                    "Las fotos efímeras que envías no se pueden volver a previsualizar.",
                                  );
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isViewed
                                        ? Icons.check_circle_rounded
                                        : Icons.local_fire_department_rounded,
                                    color: isMe
                                        ? (isDark ? Colors.white : primaryColor)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    isViewed
                                        ? "Visualizada"
                                        : (isMe
                                              ? "Enviada"
                                              : "Toca para revelar"),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (content.startsWith('[AUDIO]')) {
                            return VoiceNotePlayer(
                              base64Audio: content.substring(7),
                              isMe: isMe,
                              themeColor: primaryColor,
                            );
                          } else {
                            return Text(
                              content,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            );
                          }
                        },
                      ),
                    ],
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
                      curve: Curves.easeOutBack,
                    )
                    .fade();
              }
              return bubble;
            },
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!_isRecording)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: IconButton.filledTonal(
                                  icon: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 26,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    padding: const EdgeInsets.all(14),
                                  ),
                                  onPressed: _sendViewOncePhoto,
                                ),
                              ),
                            if (!_isRecording) const SizedBox(width: 8),
                            Expanded(
                              child: _isRecording
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                                Icons.mic_rounded,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              )
                                              .animate(
                                                onPlay: (c) =>
                                                    c.repeat(reverse: true),
                                              )
                                              .scale(
                                                begin: const Offset(1, 1),
                                                end: const Offset(1.2, 1.2),
                                              ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Grabando...",
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onErrorContainer,
                                                fontWeight: FontWeight.w900,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : TextField(
                                      controller: msgC,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      maxLines: 4,
                                      minLines: 1,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Mensaje",
                                        fillColor: Colors.transparent,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: FloatingActionButton(
                                elevation: 0,
                                backgroundColor: _isRecording
                                    ? Theme.of(context).colorScheme.error
                                    : primaryColor,
                                foregroundColor: Colors.white,
                                onPressed: () => msgC.text.trim().isEmpty
                                    ? _toggleRecording()
                                    : _send(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  _isRecording
                                      ? Icons.stop_rounded
                                      : (msgC.text.trim().isEmpty
                                            ? Icons.mic_rounded
                                            : Icons.send_rounded),
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  void _initAudio() async {
    try {
      final bytes = base64Decode(widget.base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audio_${widget.base64Audio.hashCode}.m4a');
      if (!await file.exists()) {
        await file.writeAsBytes(bytes);
      }
      await _player.setSource(DeviceFileSource(file.path));
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });
    } catch (e) {}
  }

  @override
  void dispose() {
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
      width: 270,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: contentColor,
              size: 44,
            ),
            onPressed: () => _isPlaying ? _player.pause() : _player.resume(),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: contentColor,
                inactiveTrackColor: contentColor.withOpacity(0.3),
                thumbColor: contentColor,
                trackHeight: 4,
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
                onChanged: (val) {
                  setState(() => _position = Duration(seconds: val.toInt()));
                  _player.seek(Duration(seconds: val.toInt()));
                },
              ),
            ),
          ),
          Text(
            "${_formatTime(_position)} / ${_formatTime(_duration)}",
            style: TextStyle(
              color: contentColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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
  }

  _pickGroupImage() async {
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'avatar': base64GroupImage}),
      );
    } catch (e) {}
  }

  _loadMembers() async {
    try {
      final res = await http.get(
        Uri.parse('$apiURL/group-members/${widget.group['id']}'),
      );
      if (res.statusCode == 200) {
        List data = List.from(jsonDecode(res.body));
        bool adminStatus = false;
        for (var m in data) {
          if (m['uid'] == widget.myUser['uid']) {
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
      setState(() {
        isLoading = false;
      });
    }
  }

  _promote(String targetUid) async {
    await http.post(
      Uri.parse('$apiURL/group-promote'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_id': widget.group['id'],
        'target_uid': targetUid,
        'admin_uid': widget.myUser['uid'],
      }),
    );
    _loadMembers();
  }

  _leaveGroup() async {
    await http.post(
      Uri.parse('$apiURL/group-leave'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_id': widget.group['id'],
        'uid': widget.myUser['uid'],
      }),
    );
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String groupName = widget.group['name']?.toString() ?? 'Grupo';
    if (groupName == 'null' || groupName.isEmpty) groupName = 'Grupo';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Info de la Tribu",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 32),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(50),
                    image:
                        base64GroupImage != null && base64GroupImage!.isNotEmpty
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(base64GroupImage!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: base64GroupImage == null || base64GroupImage!.isEmpty
                      ? Icon(
                          Icons.groups_rounded,
                          size: 80,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                if (iAmAdmin)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: FloatingActionButton(
                      elevation: 4,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: _pickGroupImage,
                      child: const Icon(Icons.camera_alt_rounded, size: 28),
                    ).animate().scale(curve: Curves.easeOutBack),
                  ),
              ],
            ).animate().fade().scale(),
          ),
          const SizedBox(height: 24),
          Text(
            groupName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ).animate().fade().slideY(),
          if (createdAt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Creado el $createdAt",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 48),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: members.length,
                    itemBuilder: (c, i) {
                      var m = members[i];
                      bool isAdmin = m['role'] == 'admin';
                      bool isMe = m['uid'] == widget.myUser['uid'];
                      String avatarStr = m['avatar']?.toString() ?? '';
                      if (avatarStr == 'null' || avatarStr.length < 20)
                        avatarStr = '';
                      String nameStr = m['name']?.toString() ?? 'Desconocido';
                      if (nameStr == 'null' || nameStr.trim().isEmpty)
                        nameStr = 'Desconocido';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                image: avatarStr.isNotEmpty
                                    ? DecorationImage(
                                        image: MemoryImage(
                                          base64Decode(avatarStr),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: avatarStr.isEmpty
                                  ? Center(
                                      child: Text(
                                        nameStr[0].toUpperCase(),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              isMe ? "Tú" : nameStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              isAdmin ? "Administrador" : "Miembro",
                              style: TextStyle(
                                color: isAdmin
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: isAdmin
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            trailing: (iAmAdmin && !isMe)
                                ? PopupMenuButton(
                                    icon: const Icon(
                                      Icons.more_vert_rounded,
                                      size: 28,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    itemBuilder: (context) => [
                                      if (!isAdmin)
                                        const PopupMenuItem(
                                          value: 'promote',
                                          child: Text(
                                            "Hacer Administrador",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          "Expulsar de la tribu",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onSelected: (val) {
                                      if (val == 'promote') _promote(m['uid']);
                                      if (val == 'remove') _remove(m['uid']);
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ).animate().fade(delay: (i * 50).ms).slideX();
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: _buildGlassmorphism(
          child: const SizedBox.expand(),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        title: const Text(
          "Info del Contacto",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).padding.top + 40,
          24,
          40,
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                if (avatar.isNotEmpty) {
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
                            child: Image.memory(base64Decode(avatar)),
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
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(60),
                    image: avatar.isNotEmpty
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(avatar)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatar.isEmpty
                      ? Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 72,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ).animate().fade().slideY(),
            const SizedBox(height: 8),
            Text(
              "@${user['nickname']}",
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fade().slideY(),
            const SizedBox(height: 48),

            ...[
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  title: const Text(
                    "Acerca de",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  subtitle: const Text(
                    "Usuario de CroketaChat",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  title: const Text(
                    "Chat cifrado",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  subtitle: const Text(
                    "Tus mensajes con esta persona están protegidos.",
                    style: TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ),
            ].animate(interval: 100.ms).fade().slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }
}
