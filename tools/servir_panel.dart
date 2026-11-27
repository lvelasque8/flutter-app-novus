import 'dart:io';

/// Sirve el panel web compilado (`build/web`) para probarlo en la red local.
///
/// Uso:
///   dart run tools/servir_panel.dart [puerto]
///
/// Luego abrir http://localhost:8080 (o la IP del equipo desde otro
/// dispositivo en la misma red).
Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8080 : (int.tryParse(args.first) ?? 8080);
  final root = Directory('build/web');
  if (!root.existsSync()) {
    stderr.writeln(
      'No existe build/web. Compila primero:\n'
      '  flutter build web --release -t lib/admin/main.dart',
    );
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Panel Novus disponible en:');
  stdout.writeln('  http://localhost:$port');
  for (final interface in await NetworkInterface.list()) {
    for (final address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4) {
        stdout.writeln('  http://${address.address}:$port');
      }
    }
  }
  stdout.writeln('Ctrl+C para detener.');

  await for (final request in server) {
    try {
      await _handle(request, root);
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $error');
      await request.response.close();
    }
  }
}

Future<void> _handle(HttpRequest request, Directory root) async {
  var path = request.uri.path;
  if (path == '/' || path.isEmpty) path = '/index.html';

  var file = File('${root.path}$path');
  if (!file.existsSync() && !path.contains('.')) {
    file = File('${root.path}/index.html');
  }
  if (!file.existsSync()) {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('No encontrado: $path');
    await request.response.close();
    return;
  }

  final headers = request.response.headers;
  headers.set('Content-Type', _contentType(file.path));
  headers.set('Cache-Control', 'no-store');
  headers.set(
    'Cross-Origin-Opener-Policy',
    'same-origin',
  );
  headers.set(
    'Cross-Origin-Embedder-Policy',
    'require-corp',
  );

  await request.response.addStream(file.openRead());
  await request.response.close();
}

String _contentType(String path) {
  final extension = path.split('.').last.toLowerCase();
  switch (extension) {
    case 'html':
      return 'text/html; charset=utf-8';
    case 'js':
    case 'mjs':
      return 'text/javascript; charset=utf-8';
    case 'json':
    case 'map':
      return 'application/json; charset=utf-8';
    case 'css':
      return 'text/css; charset=utf-8';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'svg':
      return 'image/svg+xml';
    case 'ico':
      return 'image/x-icon';
    case 'wasm':
      return 'application/wasm';
    case 'ttf':
      return 'font/ttf';
    case 'otf':
      return 'font/otf';
    case 'woff':
      return 'font/woff';
    case 'woff2':
      return 'font/woff2';
    default:
      return 'application/octet-stream';
  }
}
