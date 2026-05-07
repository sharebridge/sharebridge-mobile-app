class VendorSuggestion {
  VendorSuggestion({
    required this.restaurantName,
    required this.menuItems,
    required this.orderUrl,
    required this.appName,
    required this.confidence,
    this.notes,
  });

  final String restaurantName;
  final List<String> menuItems;
  final String orderUrl;
  final String appName;
  final double confidence;
  final String? notes;
}
