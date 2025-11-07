
import 'dart:convert';
import 'package:http/http.dart' as http;

class MailService {
  final String _accessToken;

  MailService(this._accessToken);

  Future<List<dynamic>> getMails() async {
    final response = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['value'];
    } else {
      throw Exception('Failed to load mails');
    }
  }

  Future<void> deleteMails(List<String> mailIds) async {
    for (final mailId in mailIds) {
      final response = await http.delete(
        Uri.parse('https://graph.microsoft.com/v1.0/me/messages/$mailId'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete mail');
      }
    }
  }

  Future<void> moveMailsToDeletedItems(List<String> mailIds) async {
    for (final mailId in mailIds) {
      final response = await http.post(
        Uri.parse('https://graph.microsoft.com/v1.0/me/messages/$mailId/move'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'destinationId': 'deleteditems'}),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to move mail');
      }
    }
  }
}
