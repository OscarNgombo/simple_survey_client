import 'package:flutter/material.dart';
import 'package:simple_survey_client/views/questions.dart';
import 'package:simple_survey_client/survey_client.dart'; // Import your SurveyClient class

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create an instance of SurveyClient with the base URL for your API
    final surveyClient = SurveyClient('http://localhost:8000');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SurveyWidget(
        surveyClient: surveyClient,
      ), // Pass your SurveyClient instance here
    );
  }
}
