import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:simple_survey_client/models/question.dart';
import 'package:simple_survey_client/models/survey_response.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';

class SurveyClient {
  final String baseUrl;

  SurveyClient(this.baseUrl);

  String _getElementText(
    XmlElement parent,
    String elementName, [
    String defaultValue = 'N/A',
  ]) {
    return parent.findElements(elementName).firstOrNull?.innerText ??
        defaultValue;
  }

  String _getAttributeValue(
    XmlElement element,
    String attributeName, [
    String defaultValue = '',
  ]) {
    return element.getAttribute(attributeName) ?? defaultValue;
  }

  Future<List<Question>> getQuestions() async {
    final response = await http.get(Uri.parse('$baseUrl/api/questions'));
    if (response.statusCode == 200 &&
        response.headers['content-type']?.contains('xml') == true) {
      return _parseXmlQuestions(response.body);
    }
    throw Exception(
      'Failed to load questions. Status code: ${response.statusCode}',
    );
  }

  List<Question> _parseXmlQuestions(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    return document.findAllElements('question').map((element) {
      final optionsElement = element.findElements('options').firstOrNull;
      final filePropertiesElement =
          element.findElements('file_properties').firstOrNull;

      return Question(
        name: _getAttributeValue(element, 'name'),
        type: _getAttributeValue(element, 'type'),
        required: _getAttributeValue(element, 'required', 'yes'),
        text: _getElementText(element, 'text', 'No question text provided'),
        description: _getElementText(
          element,
          'description',
          'No description provided',
        ),
        options: {
          'values':
              optionsElement
                  ?.findElements('option')
                  .map((e) => e.getAttribute('value'))
                  .whereType<String>()
                  .toList() ??
              ['No options available'],
          'multiple': optionsElement?.getAttribute('multiple') == 'yes',
        },
        fileProperties:
            filePropertiesElement == null
                ? {} // Assign an empty map if the element doesn't exist
                : {
                  'format': _getAttributeValue(
                    filePropertiesElement, // No ! needed now
                    'format',
                    '.pdf', // Default format
                  ),
                  'max_file_size': _getAttributeValue(
                    filePropertiesElement,
                    'max_file_size',
                    '1', // Default size
                  ),
                  'max_file_size_unit': _getAttributeValue(
                    filePropertiesElement,
                    'max_file_size_unit',
                    'mb', // Default unit
                  ),
                  'multiple': _getAttributeValue(
                    filePropertiesElement,
                    'multiple',
                    'no', // Default multiple
                  ),
                },
      );
    }).toList();
  }

  Future<void> submitResponses({
    required List<Map<String, dynamic>> responses,
    required List<List<PlatformFile>> filesMap,
    required List<Question> questions,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/api/questions/responses/'),
    );

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final responseValue = responses[i]['response'];

      if (question.type == 'file') {
        for (var file in filesMap[i]) {
          if (file.path != null) {
            request.files.add(
              await http.MultipartFile.fromPath(
                question.name,
                file.path!,
                filename: file.name,
              ),
            );
          } else if (file.bytes != null) {
            request.files.add(
              http.MultipartFile.fromBytes(
                question.name,
                file.bytes!,
                filename: file.name,
              ),
            );
          }
        }
      } else {
        request.fields[question.name] = responseValue?.toString() ?? '';
      }
    }

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to submit responses. Status code: ${response.statusCode}',
      );
    }
  }

  Future<PaginatedResponse> getResponses({
    int page = 1,
    int pageSize = 10,
    String? emailFilter,
  }) async {
    final uri = Uri.parse('$baseUrl/api/questions/responses/').replace(
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (emailFilter?.isNotEmpty == true) 'email': emailFilter,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final document = XmlDocument.parse(response.body);
      final root = document.rootElement;

      return PaginatedResponse(
        results:
            root.findElements('question_response').map((e) {
              return SurveyResponse(
                id: _getElementText(e, 'response_id'),
                fullName: _getElementText(e, 'full_name'),
                gender: _getElementText(e, 'gender'),
                programmingStack:
                    e
                        .findElements('programming_stack')
                        .map((e) => e.innerText)
                        .toList(),
                certificates:
                    e
                        .findElements('certificates')
                        .firstOrNull
                        ?.findElements('certificate')
                        .map((cert) {
                          return CertificateInfo(
                            filename: cert.innerText,
                            id: _getAttributeValue(cert, 'id'),
                          );
                        })
                        .toList() ??
                    [],
                dateResponded: _getElementText(e, 'date_responded'),
                email: _getElementText(e, 'email'),
              );
            }).toList(),
        currentPage: int.parse(_getAttributeValue(root, 'current_page', '1')),
        lastPage: int.parse(_getAttributeValue(root, 'last_page', '1')),
        pageSize: int.parse(_getAttributeValue(root, 'page_size', '10')),
        totalCount: int.parse(_getAttributeValue(root, 'total_count', '0')),
      );
    }
    throw Exception(
      'Failed to load responses. Status code: ${response.statusCode}',
    );
  }

  Future<void> downloadCertificateById(String certificateId) async {
    final uri = Uri.parse(
      '$baseUrl/api/questions/responses/certificates/$certificateId',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $uri');
    }
  }
}
