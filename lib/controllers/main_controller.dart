import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_survey_client/services/survey_client.dart';
import 'package:simple_survey_client/views/questions.dart';
import 'package:simple_survey_client/views/response.dart';

class MainController extends GetxController {
  final SurveyClient surveyClient = Get.find<SurveyClient>();

  var selectedIndex = 0.obs;

  late final List<Widget> widgetOptions;

  @override
  void onInit() {
    super.onInit();
    widgetOptions = <Widget>[const SurveyView(), const ResponsesView()];
  }

  void changeTabIndex(int index) {
    selectedIndex.value = index;
  }
}
