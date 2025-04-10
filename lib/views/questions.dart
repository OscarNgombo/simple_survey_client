import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_survey_client/controllers/survey_controller.dart';
import 'package:simple_survey_client/models/question.dart';
import 'package:file_picker/file_picker.dart';

class SurveyView extends GetView<SurveyController> {
  const SurveyView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SurveyController());

    return Scaffold(
      appBar: AppBar(
        title: Text('Survey Form'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => controller.fetchQuestions(),
            tooltip: 'Refresh Survey',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: CircularProgressIndicator());
          } else if (controller.errorMessage.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${controller.errorMessage.value}'),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => controller.fetchQuestions(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (controller.questions.isEmpty) {
            return Center(child: Text('No questions found.'));
          } else {
            return Form(
              key: controller.formKey,
              child: Stepper(
                currentStep: controller.currentStep.value,
                onStepContinue: controller.onStepContinue,
                onStepCancel: controller.onStepCancel,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: <Widget>[
                        // Show Previous button only if not on the first step
                        if (controller.currentStep.value > 0)
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Previous'),
                          ),
                        const SizedBox(width: 10),
                        // Next / Preview Button
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child:
                              controller.currentStep.value ==
                                      controller.questions.length - 1
                                  ? const Text('Preview')
                                  : const Text('Next'),
                        ),
                      ],
                    ),
                  );
                },
                steps: List.generate(controller.questions.length, (index) {
                  final question = controller.questions[index];
                  return Step(
                    title: Text(question.text),
                    content: _buildQuestionWidget(question, index),
                    isActive: controller.currentStep.value == index,
                    state:
                        controller.currentStep.value > index
                            ? StepState.complete
                            : StepState.indexed,
                  );
                }),
              ),
            );
          }
        }),
      ),
    );
  }

  Widget _buildQuestionWidget(Question question, int index) {
    final fieldKey = controller.fieldKeys[index];

    Widget descriptionWidget =
        question.description != null && question.description!.isNotEmpty
            ? Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(question.description!),
            )
            : SizedBox.shrink();

    switch (question.type) {
      case 'short_text':
      case 'long_text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            descriptionWidget,
            TextFormField(
              key: fieldKey,
              controller: controller.textControllers[index],
              maxLines: question.type == 'long_text' ? 5 : 1,
              decoration: InputDecoration(hintText: 'Enter your answer'),
              validator: (value) {
                // Use specific validators from controller
                if (question.name == 'email_address') {
                  return controller.validateEmail(value, index);
                }
                return controller.validateRequiredText(value, index);
              },
              onChanged: (value) => controller.updateTextResponse(index, value),
            ),
          ],
        );

      case 'choice':
        final List<String> options =
            (question.options?['values'] as List?)?.cast<String>() ?? [];

        // Wrap choice group in FormField for unified validation message
        return FormField<List<String>>(
          key: fieldKey,
          initialValue: controller.selectedOptions[index],
          validator: (_) => controller.validateChoice(null, index),
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                descriptionWidget,
                Obx(
                  () => Column(
                    children:
                        options.map((option) {
                          return CheckboxListTile(
                            title: Text(option),
                            value: controller.selectedOptions[index].contains(
                              option,
                            ),
                            onChanged: (bool? selected) {
                              controller.updateChoiceResponse(
                                index,
                                option,
                                selected ?? false,
                              );
                              fieldState.didChange(
                                controller.selectedOptions[index],
                              );
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                  ),
                ),
                if (fieldState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      fieldState.errorText!,
                      style: TextStyle(
                        color: Theme.of(Get.context!).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

      case 'file':
        final String multipleStr =
            question.fileProperties?['multiple']?.toString() ?? 'yes';
        final bool allowMultiple = multipleStr.toLowerCase() == 'yes';
        return FormField<List<PlatformFile>>(
          key: fieldKey,
          initialValue: controller.selectedFiles[index],
          validator: (_) => controller.validateFile(null, index),
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                descriptionWidget,
                ElevatedButton.icon(
                  icon: Icon(Icons.upload_file),
                  label: Text(allowMultiple ? 'Upload File(s)' : 'Upload File'),
                  onPressed: () async {
                    await controller.pickFiles(index);
                    fieldState.didChange(controller.selectedFiles[index]);
                  },
                ),
                Obx(() {
                  if (controller.selectedFiles[index].isEmpty) {
                    return SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Selected:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...controller.selectedFiles[index].map(
                          (file) =>
                              Text(file.name, style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }),
                if (fieldState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      fieldState.errorText!,
                      style: TextStyle(
                        color: Theme.of(Get.context!).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

      default:
        return ListTile(title: Text('Unknown question type: ${question.type}'));
    }
  }
}
