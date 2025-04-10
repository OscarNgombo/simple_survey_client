import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_survey_client/models/survey_response.dart';
import 'package:simple_survey_client/services/survey_client.dart';

class ResponsesController extends GetxController {
  final SurveyClient surveyClient = Get.find<SurveyClient>();

  var responses = <SurveyResponse>[].obs;
  var isLoading = false.obs;
  var error = RxnString();

  // Pagination State
  var currentPage = 1.obs;
  var lastPage = 1.obs;
  var totalCount = 0.obs;
  final int _pageSize = 10;

  // Filter State
  final filterController = TextEditingController();
  var activeFilter = RxnString();

  // Scroll Controller (optional, keep if needed for specific scroll logic)
  final scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    // Fetch initial data when the controller is initialized
    fetchResponses(page: 1);
    filterController.addListener(() {
      final text = filterController.text.trim();
      activeFilter.value = text.isEmpty ? null : text;
    });
  }

  @override
  void onClose() {
    filterController.dispose();
    super.onClose();
  }

  bool get canGoPrev => currentPage.value > 1;
  bool get canGoNext => currentPage.value < lastPage.value;

  Future<void> fetchResponses({required int page, bool reset = false}) async {
    if (isLoading.value && !reset) return;

    isLoading(true);
    if (reset) {
      responses.clear();
      currentPage(1);
      lastPage(1);
      totalCount(0);
    }
    error(null);

    try {
      final result = await surveyClient.getResponses(
        page: page,
        emailFilter: activeFilter.value,
        pageSize: _pageSize,
      );

      responses.assignAll(result.results);
      currentPage(result.currentPage);
      lastPage(result.lastPage);
      totalCount(result.totalCount);
    } catch (e) {
      error("Failed to load responses: ${e.toString()}");

      responses.clear();
      currentPage(1);
      lastPage(1);
      totalCount(0);
    } finally {
      isLoading(false);
    }
  }

  void applyFilter() {
    final newFilter = filterController.text.trim();
    if (activeFilter.value != (newFilter.isEmpty ? null : newFilter)) {
      activeFilter(newFilter.isEmpty ? null : newFilter);
      fetchResponses(page: 1, reset: true);
    }
  }

  void clearFilter() {
    if (activeFilter.value != null) {
      filterController.clear();
      activeFilter(null);
      fetchResponses(page: 1, reset: true);
    } else {
      filterController.clear();
    }
  }

  void goToPage(int page) {
    if (page >= 1 &&
        page <= lastPage.value &&
        page != currentPage.value &&
        !isLoading.value) {
      fetchResponses(page: page);
    }
  }

  Future<void> handleDownload(CertificateInfo cert) async {
    if (cert.id.isEmpty) {
      Get.snackbar(
        'Download Error',
        'Missing ID for certificate ${cert.filename}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
      );
      return;
    }
    try {
      await surveyClient.downloadCertificateById(cert.id);
      Get.snackbar(
        'Download Started',
        'Downloading ${cert.filename}...',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Download Error',
        'Could not download ${cert.filename}: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
