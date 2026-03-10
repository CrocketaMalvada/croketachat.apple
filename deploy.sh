#!/bin/bash

echo "🚀 Compilando nueva versión de CroketaChat..."
flutter build apk --release

echo "📤 Transfiriendo APK al servidor..."
rsync -avz /home/juanca/Proyectos/skychat_app/build/app/outputs/flutter-apk/app-release.apk juanca@192.168.1.50:/home/juanca/skychat_server/descargas/app.apk

echo "✅ ¡Listo! La actualización ya está disponible en el servidor."
