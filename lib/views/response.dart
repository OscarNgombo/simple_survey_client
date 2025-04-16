import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_survey_client/controllers/responses_controller.dart';

class ResponsesView extends GetView<ResponsesController> {
  const ResponsesView({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the controller. Get.put ensures it's created only once
    // for this view instance or finds an existing one if already put.
    Get.put(ResponsesController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Submitted Responses'),
        backgroundColor: Colors.white,
        actions: [
          Obx(
            () => IconButton(
              icon:
                  controller.isLoading.value
                      ? SizedBox(
                        // Show progress indicator instead of icon when loading
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
                        ),
                      )
                      : const Icon(Icons.refresh),
              onPressed:
                  controller.isLoading.value
                      ? null // Disable button while loading
                      : () => controller.fetchResponses(
                        page: controller.currentPage.value,
                        reset: true,
                      ),
              tooltip: 'Refresh Responses',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Filter Section ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.filterController,
                    decoration: InputDecoration(
                      labelText: 'Filter by Email',
                      hintText: 'Enter email address',
                      border: OutlineInputBorder(),
                      // Use Obx for reactive suffix icon
                      suffixIcon: Obx(() {
                        if (controller.activeFilter.value != null) {
                          return IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: controller.clearFilter,
                          );
                        }
                        return Center();
                      }),
                    ),
                    onSubmitted: (_) => controller.applyFilter(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: controller.applyFilter,
                  child: const Text('Filter'),
                ),
              ],
            ),
          ),

          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.responses.isEmpty) {
                // Show loading only if the list is empty (initial load or after reset)
                return const Center(child: CircularProgressIndicator());
              } else if (controller.error.value != null) {
                // Show error message
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Error: ${controller.error.value}',
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed:
                              () => controller.fetchResponses(
                                page: 1,
                                reset: true,
                              ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (controller.responses.isEmpty) {
                // Show empty message if no error and list is empty
                return const Center(child: Text('No responses found.'));
              } else {
                // Show the list
                return ListView.builder(
                  itemCount: controller.responses.length,
                  itemBuilder: (context, index) {
                    final response = controller.responses[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          response.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (response.email != null) Text(response.email!),
                            Text('Gender: ${response.gender}'),
                            if (response.programmingStack.isNotEmpty)
                              Text(
                                'Stack: ${response.programmingStack.join(', ')}',
                              ),
                            if (response.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Desc: ${response.description}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (response.certificates.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Certificates:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ...response.certificates.map(
                                      (cert) => Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cert.filename,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => controller.handleDownload(
                                                  cert,
                                                ),
                                            child: const Text(
                                              'Download',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              'Responded: ${response.dateResponded}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine:
                            (response.description != null &&
                                response.description!.isNotEmpty) ||
                            response.certificates.isNotEmpty,
                      ),
                    );
                  },
                );
              }
            }),
          ),
          Obx(() {
            if (!(controller.isLoading.value && controller.responses.isEmpty) &&
                controller.error.value == null &&
                controller.totalCount.value > 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed:
                          controller.canGoPrev && !controller.isLoading.value
                              ? () => controller.goToPage(
                                controller.currentPage.value - 1,
                              )
                              : null,
                      child: const Text('Previous'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Page ${controller.currentPage.value} of ${controller.lastPage.value} (${controller.totalCount.value} total)',
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          controller.canGoNext && !controller.isLoading.value
                              ? () => controller.goToPage(
                                controller.currentPage.value + 1,
                              )
                              : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );
  }
}
