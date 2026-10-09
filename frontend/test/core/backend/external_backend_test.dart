import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/backend/external_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('resolveExternalBackend', () {
    test('the BASTIDE_BACKEND_URL define skips the supervisor', () {
      final backend = resolveExternalBackend(
        url: 'http://127.0.0.1:9000',
        sessionToken: 'dev-token',
        debug: false,
        packagedBackendFound: true,
      );

      expect(backend!.baseUrl, Uri.parse('http://127.0.0.1:9000/api/v1'));
      expect(backend.sessionToken, 'dev-token');
    });

    test('a URL that already names the API root is kept', () {
      final backend = resolveExternalBackend(
        url: 'http://127.0.0.1:9000/api/v1/',
        sessionToken: '',
        debug: true,
        packagedBackendFound: false,
      );

      expect(backend!.baseUrl, Uri.parse('http://127.0.0.1:9000/api/v1'));
      expect(backend.sessionToken, isNull);
    });

    test('a debug build without a packaged backend uses the dev default', () {
      final backend = resolveExternalBackend(
        url: '',
        sessionToken: '',
        debug: true,
        packagedBackendFound: false,
      );

      expect(backend!.baseUrl, Uri.parse('$defaultDevBackendUrl/api/v1'));
    });

    test('a debug build with a backend to start starts it', () {
      expect(
        resolveExternalBackend(
          url: '',
          sessionToken: '',
          debug: true,
          packagedBackendFound: true,
        ),
        isNull,
      );
    });

    test('a release build never falls back to the dev default', () {
      expect(
        resolveExternalBackend(
          url: '',
          sessionToken: '',
          debug: false,
          packagedBackendFound: false,
        ),
        isNull,
      );
    });
  });

  group('probeExternalBackend', () {
    final backend = ExternalBackend(
      baseUrl: Uri.parse('http://127.0.0.1:8765/api/v1'),
      sessionToken: 'dev-token',
    );

    test('reads the version from /health, sending the token', () async {
      late http.Request seen;
      final connection = await probeExternalBackend(
        backend,
        client: MockClient((request) async {
          seen = request;
          return http.Response('{"status":"ok","version":"0.1.0"}', 200);
        }),
      );

      expect(seen.url, Uri.parse('http://127.0.0.1:8765/api/v1/health'));
      expect(seen.headers[sessionTokenHeader], 'dev-token');
      expect(connection.version, '0.1.0');
      expect(connection.baseUrl, backend.baseUrl);
      expect(connection.sessionToken, 'dev-token');
    });

    test('a backend that is not running is unreachable', () async {
      final probing = probeExternalBackend(
        backend,
        client: MockClient(
          (_) => throw http.ClientException('Connection refused'),
        ),
      );

      await expectLater(
        probing,
        throwsA(
          isA<BackendFailure>().having(
            (f) => f.kind,
            'kind',
            BackendFailureKind.unreachable,
          ),
        ),
      );
    });

    test('a wrong session token is unreachable too', () async {
      final probing = probeExternalBackend(
        backend,
        client: MockClient((_) async => http.Response('{}', 401)),
      );

      await expectLater(probing, throwsA(isA<BackendFailure>()));
    });
  });

  test('the controller uses the external backend, not a process', () async {
    final external = ExternalBackend(
      baseUrl: Uri.parse('http://127.0.0.1:8765/api/v1'),
    );
    final container = ProviderContainer(
      overrides: [
        externalBackendProvider.overrideWithValue(external),
        externalBackendProbeProvider.overrideWithValue(
          (backend) async =>
              BackendConnection(baseUrl: backend.baseUrl, version: '0.1.0'),
        ),
        backendSupervisorProvider.overrideWith(
          (ref) => throw StateError('no process in dev mode'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final connection = await container.read(backendControllerProvider.future);
    expect(connection.baseUrl.port, 8765);
  });
}
