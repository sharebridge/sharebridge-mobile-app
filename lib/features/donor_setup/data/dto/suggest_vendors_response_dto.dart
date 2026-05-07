import '../../domain/models/vendor_suggestion.dart';

class SuggestVendorsResponseDto {
  SuggestVendorsResponseDto({required this.suggestions});

  final List<VendorSuggestion> suggestions;

  factory SuggestVendorsResponseDto.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'];
    if (rawSuggestions is! List) {
      throw const FormatException('suggestions must be a list');
    }

    final parsed = rawSuggestions.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('suggestion item must be an object');
      }

      final menuItemsRaw = item['menu_items'];
      if (menuItemsRaw is! List) {
        throw const FormatException('menu_items must be a list');
      }

      return VendorSuggestion(
        restaurantName: item['restaurant_name'] as String,
        menuItems: menuItemsRaw.map((e) => e.toString()).toList(),
        orderUrl: item['order_url'] as String,
        appName: item['app_name'] as String,
        confidence: (item['confidence'] as num).toDouble(),
        notes: item['notes'] as String?,
      );
    }).toList();

    return SuggestVendorsResponseDto(suggestions: parsed.take(5).toList());
  }
}
