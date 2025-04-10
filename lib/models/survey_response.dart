class SurveyResponse {
  final String id;
  final String fullName;
  final String? email; // Changed name to camelCase convention
  final String? description;
  final String gender;
  final List<String> programmingStack;
  final List<CertificateInfo> certificates;
  final String dateResponded;

  SurveyResponse({
    required this.id,
    required this.fullName,
    this.email,
    this.description,
    required this.gender,
    required this.programmingStack,
    required this.certificates,
    required this.dateResponded,
  });

  // Factory constructor to parse JSON
  factory SurveyResponse.fromJson(Map<String, dynamic> json) {
    // Handle potential type differences (e.g., ID might be int or string)
    // Use null-aware operators and default values for safety

    // Parse programming_stack (assuming it's a list of strings in JSON)
    final List<String> stacks =
        (json['programming_stack'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        []; // Default to empty list if null or not a list

    // Parse certificates (assuming it's a list of objects in JSON)
    final List<CertificateInfo> certs =
        (json['certificates'] as List<dynamic>?)
            ?.map(
              (certJson) =>
                  CertificateInfo.fromJson(certJson as Map<String, dynamic>),
            )
            .toList() ??
        []; // Default to empty list

    return SurveyResponse(
      id: json['response_id']?.toString() ?? '', // Handle null or int
      fullName: json['full_name'] ?? 'N/A',
      // Use the correct JSON key names (snake_case from XML example)
      email: json['email'], // Will be null if missing in JSON
      description: json['description'], // Will be null if missing in JSON
      gender: json['gender']?.toString() ?? 'N/A', // Handle potential types
      programmingStack: stacks,
      certificates: certs,
      dateResponded: json['date_responded'] ?? 'N/A',
    );
  }
}

class CertificateInfo {
  final String filename;
  final String id; // Assuming 'id' is the key in JSON too

  CertificateInfo({required this.filename, required this.id});

  // Factory constructor to parse JSON
  factory CertificateInfo.fromJson(Map<String, dynamic> json) {
    return CertificateInfo(
      // Use appropriate keys from your JSON structure
      filename: json['filename'] ?? 'unknown_file',
      id: json['id']?.toString() ?? '', // Handle null or int
    );
  }
}

class PaginatedResponse {
  final List<SurveyResponse> results;
  final int currentPage;
  final int lastPage;
  final int pageSize;
  final int totalCount;

  PaginatedResponse({
    required this.results,
    required this.currentPage,
    required this.lastPage,
    required this.pageSize,
    required this.totalCount,
  });

  // Factory constructor to parse the overall paginated JSON
  factory PaginatedResponse.fromJson(Map<String, dynamic> json) {
    // Parse the list of results using SurveyResponse.fromJson
    final List<SurveyResponse> responseList =
        (json['results']
                as List<dynamic>?) // Assuming 'results' is the key for the list
            ?.map(
              (responseJson) =>
                  SurveyResponse.fromJson(responseJson as Map<String, dynamic>),
            )
            .toList() ??
        []; // Default to empty list

    return PaginatedResponse(
      results: responseList,
      // Use appropriate keys for pagination fields, provide defaults
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
      totalCount: json['total_count'] ?? 0,
    );
  }

  // Helper getters remain the same
  bool get hasNextPage => currentPage < lastPage;
  bool get hasPreviousPage => currentPage > 1;
}
