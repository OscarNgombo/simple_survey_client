import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_survey_client/models/question.dart';
import 'package:simple_survey_client/services/survey_client.dart';

class SurveyController extends GetxController {
  final SurveyClient surveyClient = Get.find<SurveyClient>();

  var isLoading = true.obs;
  var errorMessage = RxnString();

  // Survey Data
  var questions = <Question>[].obs;
  var currentStep = 0.obs;

  // Form State & Responses
  final formKey = GlobalKey<FormState>();

  // Use RxList for observable lists
  var responses = <Map<String, dynamic>>[].obs;
  var selectedOptions = <RxList<String>>[].obs;
  var selectedFiles = <RxList<PlatformFile>>[].obs;

  var textControllers = <TextEditingController>[];
  var fieldKeys = <GlobalKey<FormFieldState>>[];

  // Submission State
  var isSubmitting = false.obs;
  var submissionSuccess = RxnBool();
  var submissionError = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetchQuestions();
  }

  @override
  void onClose() {
    for (var controller in textControllers) {
      controller.dispose();
    }
    super.onClose();
  }

  Future<void> fetchQuestions() async {
    try {
      isLoading(true);
      errorMessage(null);
      submissionSuccess(null);
      submissionError(null);
      final fetchedQuestions = await surveyClient.getQuestions();
      questions.assignAll(fetchedQuestions);
      _initializeState();
    } catch (e) {
      errorMessage("Failed to load survey: ${e.toString()}");
    } finally {
      isLoading(false);
    }
  }

  void _initializeState() {
    for (var controller in textControllers) {
      controller.dispose();
    }
    textControllers.clear();
    fieldKeys.clear();

    int numQuestions = questions.length;
    responses.assignAll(
      List.generate(
        numQuestions,
        (index) => {'question': questions[index].name, 'response': null},
      ),
    );
    textControllers = List.generate(
      numQuestions,
      (index) => TextEditingController(
        text: responses[index]['response']?.toString() ?? '',
      ),
    );
    selectedOptions.assignAll(
      List.generate(numQuestions, (index) => <String>[].obs),
    );
    selectedFiles.assignAll(
      List.generate(numQuestions, (index) => <PlatformFile>[].obs),
    );
    fieldKeys = List.generate(
      numQuestions,
      (index) => GlobalKey<FormFieldState>(),
    );
    currentStep(0); // Reset to first step
  }

  void onStepContinue() {
    // Validate current step before proceeding
    if (_validateCurrentStep()) {
      if (currentStep.value < questions.length - 1) {
        currentStep.value++;
      } else {
        // Last step: Trigger preview/submit
        _showPreviewAndSubmit();
      }
    } else {
      fieldKeys[currentStep.value].currentState?.validate();
    }
  }

  void onStepCancel() {
    if (currentStep.value > 0) {
      currentStep.value--;
    }
  }

  void updateTextResponse(int index, String value) {
    var updatedResponse = Map<String, dynamic>.from(responses[index]);
    updatedResponse['response'] = value.trim().isEmpty ? null : value.trim();
    responses[index] = updatedResponse;

    // Optional: Trigger validation on change if desired
    fieldKeys[index].currentState?.validate();
  }

  void updateChoiceResponse(int index, String option, bool isSelected) {
    final question = questions[index];
    final bool multiple = question.options?['multiple'] as bool? ?? false;
    final currentSelection = selectedOptions[index];

    if (isSelected) {
      if (!multiple) {
        // Single choice: clear previous, add new
        currentSelection.clear();
        currentSelection.add(option);
      } else if (!currentSelection.contains(option)) {
        // Multiple choice: add if not present
        currentSelection.add(option);
      }
    } else {
      // Deselecting: remove the option
      currentSelection.remove(option);
    }
    var updatedResponse = Map<String, dynamic>.from(responses[index]);
    updatedResponse['response'] =
        currentSelection.isEmpty ? null : currentSelection.join(', ');
    responses[index] = updatedResponse;
  }

  Future<void> pickFiles(int index) async {
    final question = questions[index];
    final String multipleStr =
        question.fileProperties?['multiple']?.toString() ?? 'yes';
    final bool allowMultiple = multipleStr.toLowerCase() == 'yes';

    String? allowedFormat = question.fileProperties?['format'] as String?;
    List<String> allowedFormatsList = [];
    if (allowedFormat != null && allowedFormat.isNotEmpty) {
      allowedFormatsList =
          allowedFormat
              .split(',')
              .map(
                (ext) =>
                    ext.trim().startsWith('.')
                        ? ext.trim().substring(1)
                        : ext.trim(),
              )
              .where((ext) => ext.isNotEmpty)
              .toList();
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            allowedFormatsList.isNotEmpty
                ? allowedFormatsList
                : null, // Allow any if not specified
        allowMultiple: allowMultiple,
      );

      if (result != null && result.files.isNotEmpty) {
        if (allowMultiple) {
          // Add to existing list or replace if needed by requirements
          selectedFiles[index].assignAll(result.files);
        } else {
          // Single file selection replaces the list
          selectedFiles[index].assignAll([result.files.first]);
        }

        // Update the main response map (store filenames for preview/submission)
        var updatedResponse = Map<String, dynamic>.from(responses[index]);
        updatedResponse['response'] = selectedFiles[index]
            .map((f) => f.name)
            .join(', ');
        responses[index] = updatedResponse;
      }
    } catch (e) {
      Get.snackbar(
        'File Picker Error',
        'Could not pick files: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  bool _validateCurrentStep() {
    final index = currentStep.value;
    final question = questions[index];
    final bool isRequired = question.required == 'yes';

    // Use FormField validation first
    bool fieldValid = fieldKeys[index].currentState?.validate() ?? false;

    // Add specific logic for choice/file required checks if FormField doesn't cover it
    if (isRequired) {
      if (question.type == 'choice' && selectedOptions[index].isEmpty) {
        return false;
      }
      if (question.type == 'file' && selectedFiles[index].isEmpty) {
        return false;
      }
    }

    // For choice, check single/multiple constraint if needed
    if (question.type == 'choice') {
      final bool multiple = question.options?['multiple'] as bool? ?? false;
      if (!multiple && selectedOptions[index].length > 1) {
        print("Validation failed: Single choice expected, multiple selected");
        return false; // Or handle within FormField validator
      }
    }

    return fieldValid;
  }

  void _showPreviewAndSubmit() {
    // First, ensure the overall form is valid (optional, as we validate step-by-step)
    // if (!_formKey.currentState!.validate()) {
    //   Get.snackbar('Error', 'Please fix errors before submitting.',
    //       snackPosition: SnackPosition.BOTTOM);
    //   return;
    // }

    Get.dialog(
      AlertDialog(
        title: Text('Preview and Submit'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                      _buildPreviewResponse(i), // Use helper for clarity
                    ],
                  ),
                ),
              // Loading indicator during submission
              Obx(() {
                if (isSubmitting.value) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  return SizedBox.shrink();
                }
              }),
            ],
          ),
        ),
        actions: [
          // Use Obx to disable buttons while submitting
          Obx(
            () => TextButton(
              onPressed:
                  isSubmitting.value ? null : () => Get.back(), // Close dialog
              child: Text('Cancel'),
            ),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: isSubmitting.value ? null : _submitSurvey,
              child: Text('Submit'),
            ),
          ),
        ],
      ),
      barrierDismissible: false, // Prevent closing while submitting
    );
  }

  Widget _buildPreviewResponse(int index) {
    final question = questions[index];
    final responseValue = responses[index]['response'];
    final bool isRequired = question.required == 'yes';

    if (question.type == 'file') {
      final files = selectedFiles[index];
      if (files.isEmpty) {
        return Text(
          'Response: Not provided (${isRequired ? "Required" : "Optional"})',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: isRequired ? Colors.red : null,
          ),
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: files.map((file) => Text('File: ${file.name}')).toList(),
        );
      }
    } else {
      final responseText = responseValue?.toString() ?? '';
      if (responseText.isEmpty) {
        return Text(
          'Response: Not provided (${isRequired ? "Required" : "Optional"})',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: isRequired ? Colors.red : null,
          ),
        );
      } else {
        return Text('Response: $responseText');
      }
    }
  }

  Future<void> _submitSurvey() async {
    isSubmitting(true);
    submissionSuccess(null);
    submissionError(null);
    List<List<PlatformFile>> filesToSubmit = List.generate(
      questions.length,
      (index) =>
          questions[index].type == 'file'
              ? List<PlatformFile>.from(selectedFiles[index]) // Create a copy
              : <PlatformFile>[], // Empty list for non-file questions
    );

    try {
      await surveyClient.submitResponses(
        // Pass the current state of responses
        responses: List<Map<String, dynamic>>.from(responses),
        filesMap: filesToSubmit,
        questions: List<Question>.from(questions),
      );

      submissionSuccess(true);
      Get.back(); // Close the dialog on success
      Get.snackbar(
        'Success',
        'Survey submitted successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      // Optionally reset the form or navigate away
      fetchQuestions(); // Refetch to reset the form
    } catch (e) {
      submissionSuccess(false);
      submissionError("Submission failed: ${e.toString()}");
      // Keep dialog open, show error within dialog or via snackbar
      Get.snackbar(
        'Submission Error',
        'Failed to submit: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting(false);
    }
  }

  String? validateRequiredText(String? value, int index) {
    final question = questions[index];
    if (question.required == 'yes' && (value == null || value.trim().isEmpty)) {
      return 'This field is required';
    }
    return null;
  }

  String? validateEmail(String? value, int index) {
    final question = questions[index];
    // First check required
    if (question.required == 'yes' && (value == null || value.trim().isEmpty)) {
      return 'This field is required';
    }
    // Then check format if not empty
    if (value != null && value.isNotEmpty && !GetUtils.isEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? validateChoice(dynamic value, int index) {
    final question = questions[index];
    final bool isRequired = question.required == 'yes';
    if (isRequired && selectedOptions[index].isEmpty) {
      return 'Please select at least one option';
    }
    // Add single choice validation if needed
    // final bool multiple = question.options?['multiple'] as bool? ?? false;
    // if (!multiple && selectedOptions[index].length > 1) {
    //   return 'Please select only one option';
    // }
    return null;
  }

  String? validateFile(dynamic value, int index) {
    final question = questions[index];
    final bool isRequired = question.required == 'yes';
    if (isRequired && selectedFiles[index].isEmpty) {
      return 'Please upload a file';
    }
    return null;
  }
}
