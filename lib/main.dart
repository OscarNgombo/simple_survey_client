import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Import GetX
import 'package:simple_survey_client/controllers/main_controller.dart'; // Import the controller
import 'package:simple_survey_client/services/survey_client.dart';

void main() {
  Get.put<SurveyClient>(SurveyClient('https://13tracso.pythonanywhere.com'));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Survey',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends GetView<MainController> {
  MainScreen({super.key}) {
    Get.put(MainController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(
            () => Center(
              child: controller.widgetOptions[controller.selectedIndex.value],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Obx(
            () => BottomNavigationBar(
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.question_answer),
                  label: 'Survey Form',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: 'Responses',
                ),
              ],
              currentIndex: controller.selectedIndex.value,
              selectedItemColor: Colors.deepPurple,
              onTap: controller.changeTabIndex,
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
