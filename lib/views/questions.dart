import 'package:flutter/material.dart';
import 'package:simple_survey_client/models/question.dart';
import 'package:simple_survey_client/survey_client.dart';

class SurveyWidget extends StatefulWidget {
  final SurveyClient surveyClient;

  const SurveyWidget({super.key, required this.surveyClient});

  @override
  SurveyWidgetState createState() => SurveyWidgetState();
}

class SurveyWidgetState extends State<SurveyWidget> {
  late Future<List<Question>> futureQuestions;
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _responses = [];
  List<TextEditingController> _textControllers = [];
  List<List<String>> _selectedOptions = [];
  List<GlobalKey<FormFieldState>> _fieldKeys = [];

  @override
  void initState() {
    super.initState();
    futureQuestions = widget.surveyClient.getQuestions();
  }

  @override
  void dispose() {
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onStepContinue(List<Question> questions) {
    bool isValid = true;
    if (questions[_currentStep].type == 'choice') {
      isValid = _validateMultipleChoice(questions[_currentStep]);
    } else {
      isValid = _formKey.currentState!.validate();
    }

    if (isValid) {
      _formKey.currentState!.save();
      if (_currentStep < questions.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _showPreviewAndSubmit(questions);
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _showPreviewAndSubmit(List<Question> questions) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Preview and Submit'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < questions.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          questions[i].text,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Response: ${_responses[i]['response'] ?? 'Not answered'}',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _submitResponses();
                Navigator.pop(context);
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _submitResponses() async {
    try {
      await widget.surveyClient.submitResponses(_responses);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Responses submitted successfully!')),
      );
      // Optionally, reset the form or navigate to a success screen
      setState(() {
        _currentStep = 0;
        _responses.clear();
        for (var controller in _textControllers) {
          controller.clear();
        }
        _selectedOptions.clear();
      });
    } catch (e) {
      // Log the error to the console
      print('Error submitting responses: $e');

      // Show the error in a SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting responses: $e')));
    }
  }

  bool _validateMultipleChoice(Question question) {
    final int index = _currentStep;
    final bool multiple = question.options?['multiple'] as bool? ?? false;
    if (question.required == 'yes' && _selectedOptions[index].isEmpty) {
      return false;
    }
    if (!multiple && _selectedOptions[index].length > 1) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Survey Form')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder<List<Question>>(
          future: futureQuestions,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No questions found.'));
            }

            final questions = snapshot.data!;
            if (_responses.isEmpty) {
              _responses = List.generate(
                questions.length,
                (index) => {
                  'question': questions[index].name,
                  'response': null,
                },
              );
              _textControllers = List.generate(
                questions.length,
                (index) => TextEditingController(),
              );
              _selectedOptions = List.generate(questions.length, (index) => []);
              _fieldKeys = List.generate(
                questions.length,
                (index) => GlobalKey<FormFieldState>(),
              );
            }

            return Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () => _onStepContinue(questions),
                onStepCancel: _onStepCancel,
                controlsBuilder: (
                  BuildContext context,
                  ControlsDetails details,
                ) {
                  return Row(
                    children: <Widget>[
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Previous'),
                        ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child:
                            _currentStep == questions.length - 1
                                ? const Text('Preview')
                                : const Text('Next'),
                      ),
                    ],
                  );
                },
                steps: List.generate(questions.length, (index) {
                  final question = questions[index];
                  return Step(
                    title: Text(question.text),
                    content: _buildQuestionWidget(question, index),
                    isActive: _currentStep == index,
                    state:
                        _currentStep > index
                            ? StepState.complete
                            : StepState.indexed,
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionWidget(Question question, int index) {
    switch (question.type) {
      case 'short_text':
        return _buildTextQuestion(question, index);
      case 'long_text':
        return _buildLongTextQuestion(question, index);
      case 'choice':
        return _buildMultipleChoiceQuestion(question, index);
      case 'file':
        return _buildFileUploadQuestion(question, index);
      default:
        return ListTile(title: Text('Unknown question type: ${question.type}'));
    }
  }

  Widget _buildTextQuestion(Question question, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.description != null) Text(question.description!),
        TextFormField(
          key: _fieldKeys[index],
          controller: _textControllers[index],
          decoration: InputDecoration(hintText: 'Enter your answer'),
          validator: (value) {
            if (question.required == 'yes' &&
                (value == null || value.isEmpty)) {
              return 'Please enter an answer';
            }
            return null;
          },
          onSaved: (value) {
            _responses[index]['response'] = value;
          },
        ),
      ],
    );
  }

  Widget _buildLongTextQuestion(Question question, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.description != null) Text(question.description!),
        TextFormField(
          key: _fieldKeys[index],
          controller: _textControllers[index],
          maxLines: 5,
          decoration: InputDecoration(hintText: 'Enter your answer'),
          validator: (value) {
            if (question.required == 'yes' &&
                (value == null || value.isEmpty)) {
              return 'Please enter an answer';
            }
            return null;
          },
          onSaved: (value) {
            _responses[index]['response'] = value;
          },
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceQuestion(Question question, int index) {
    final bool multiple = question.options?['multiple'] as bool? ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.description != null) Text(question.description!),
        Column(
          children:
              (question.options?['values'] as List<String>)
                  .map(
                    (option) => CheckboxListTile(
                      title: Text(option),
                      value: _selectedOptions[index].contains(option),
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            if (!multiple) {
                              _selectedOptions[index].clear();
                            }
                            _selectedOptions[index].add(option);
                          } else {
                            _selectedOptions[index].remove(option);
                          }
                          _responses[index]['response'] =
                              _selectedOptions[index].join(', ');
                        });
                      },
                    ),
                  )
                  .toList(),
        ),
        if (question.required == 'yes')
          Builder(
            builder: (context) {
              if (_selectedOptions[index].isEmpty && _currentStep == index) {
                return Text(
                  'Please select at least one option',
                  style: TextStyle(color: Colors.red),
                );
              }
              if (!multiple &&
                  _selectedOptions[index].length > 1 &&
                  _currentStep == index) {
                return Text(
                  'Please select only one option',
                  style: TextStyle(color: Colors.red),
                );
              }
              return SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildFileUploadQuestion(Question question, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.description != null) Text(question.description!),
        ElevatedButton(
          onPressed: () {
            // Handle file upload logic
            // For now, just update the response as "File Uploaded"
            _responses[index]['response'] = 'File Uploaded';
          },
          child: Text('Upload File'),
        ),
      ],
    );
  }
}
