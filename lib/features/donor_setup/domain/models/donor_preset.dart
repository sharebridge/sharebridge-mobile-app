class DonorPreset {
  DonorPreset({
    required this.restaurantName,
    required this.orderUrl,
    required this.menuItems,
    required this.appName,
    required this.source,
    required this.confidence,
  });

  final String restaurantName;
  final String orderUrl;
  final List<String> menuItems;
  final String appName;
  final String source;
  final double confidence;
}
