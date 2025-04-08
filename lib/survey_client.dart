import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:simple_survey_client/models/question.dart';
import 'package:xml/xml.dart';

class SurveyClient {
  final String baseUrl;

  SurveyClient(this.baseUrl);

  Future<List<Question>> getQuestions() async {
    final response = await http.get(Uri.parse('$baseUrl/api/questions'));

    if (response.statusCode == 200) {
      try {
        // Check if the response is XML
        if (response.headers['content-type']?.contains('xml') == true) {
          return _parseXmlQuestions(response.body);
        } else {
          // Assume it's JSON if not XML
          final List<dynamic> data = jsonDecode(response.body);
          return _parseJsonQuestions(data);
        }
      } catch (e) {
        throw Exception(
          'Failed to parse questions: $e - Response body: ${response.body}',
        );
      }
    } else {
      throw Exception(
        'Failed to load questions. Status code: ${response.statusCode} - Response body: ${response.body}',
      );
    }
  }

  List<Question> _parseJsonQuestions(List<dynamic> data) {
    return data.map((item) {
      return Question(
        name: item['name'],
        type: item['type'],
        required: item['required'],
        text: item['text'],
        description: item['description'],
        options: item['options'],
        fileProperties: item['file_properties'],
      );
    }).toList();
  }

  List<Question> _parseXmlQuestions(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final questions = <Question>[];

    for (final questionElement in document.findAllElements('question')) {
      final name = questionElement.getAttribute('name') ?? '';
      final type = questionElement.getAttribute('type') ?? '';
      final required = questionElement.getAttribute('required') ?? '';
      final text =
          questionElement.findElements('text').isNotEmpty
              ? questionElement.findElements('text').single.text
              : '';
      final descriptionElement = questionElement.findElements('description');
      final description =
          descriptionElement.isNotEmpty ? descriptionElement.single.text : null;
      final optionsElement = questionElement.findElements('options');
      Map<String, dynamic>? options;
      bool multiple = false;
      if (optionsElement.isNotEmpty) {
        multiple = optionsElement.single.getAttribute('multiple') == 'yes';
        final values =
            optionsElement.single
                .findElements('option')
                .map((e) => e.getAttribute('value'))
                .whereType<String>()
                .toList();
        options = {'values': values, 'multiple': multiple};
      }
      final filePropertiesElement = questionElement.findElements(
        'file_properties',
      );
      final Map<String, dynamic>? fileProperties =
          filePropertiesElement.isNotEmpty ? <String, dynamic>{} : null;

      questions.add(
        Question(
          name: name,
          type: type,
          required: required,
          text: text,
          description: description,
          options: options,
          fileProperties: fileProperties,
        ),
      );
    }

    return questions;
  }

  Future<void> submitResponses(List<Map<String, dynamic>> responses) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/questions/responses'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(responses),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to submit responses. Status code: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
