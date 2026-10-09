import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_backend.dart';

void main() {
  late List<http.BaseRequest> sent;
  late http.Client httpClient;

  setUp(() {
    sent = [];
    httpClient = MockClient((request) async {
      sent.add(request);
      return http.Response('{}', 200);
    });
  });

  ApiClient client({String? sessionToken, String? bearer}) => ApiClient(
    baseUrl: Uri.parse('http://127.0.0.1:52144/api/v1'),
    sessionToken: sessionToken,
    httpClient: httpClient,
    tokenProvider: () => bearer,
  );

  test('sends the session token on JSON calls', () async {
    await client(sessionToken: 'launch-token', bearer: 'jwt').get('/accounts');

    final headers = sent.single.headers;
    expect(headers[sessionTokenHeader], 'launch-token');
    expect(headers['Authorization'], 'Bearer jwt');
  });

  test('sends the session token on uploads and downloads', () async {
    final api = client(sessionToken: 'launch-token');
    await api.postMultipart(
      '/imports',
      fileField: 'file',
      fileName: 'releve.ofx',
      fileBytes: const [1, 2, 3],
    );
    await api.postForBytes('/backup/export');

    expect(
      sent.map((request) => request.headers[sessionTokenHeader]),
      everyElement('launch-token'),
    );
  });

  test('omits the header for a dev backend without a token', () async {
    await client().get('/accounts');

    expect(sent.single.headers.containsKey(sessionTokenHeader), isFalse);
  });

  test('targets the port the backend announced', () async {
    await client().get('/accounts', query: {'limit': '5'});

    expect(
      sent.single.url,
      Uri.parse('http://127.0.0.1:52144/api/v1/accounts?limit=5'),
    );
  });

  test('the provider builds the client from the running backend', () async {
    final container = ProviderContainer(
      overrides: [
        backendControllerProvider.overrideWith(
          () => ReadyBackendController(
            BackendConnection(
              baseUrl: Uri.parse('http://127.0.0.1:61000/api/v1'),
              version: '0.1.0',
              sessionToken: 'launch-token',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(backendControllerProvider.future);

    final api = container.read(apiClientProvider);
    expect(api.baseUrl.port, 61000);
    expect(api.sessionToken, 'launch-token');
  });
}
