import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/data/dto/suggest_vendors_response_dto.dart';

void main() {
  test('maps valid suggestions and trims to five', () {
    final json = <String, dynamic>{
      'suggestions': List.generate(
        6,
        (int i) => <String, dynamic>{
          'restaurant_name': 'R$i',
          'menu_items': <String>['Meals'],
          'order_url': 'https://example.com/$i',
          'app_name': 'VendorApp',
          'confidence': 0.8,
        },
      ),
    };

    final dto = SuggestVendorsResponseDto.fromJson(json);
    expect(dto.suggestions.length, 5);
  });

  test('throws for malformed payload', () {
    expect(
      () => SuggestVendorsResponseDto.fromJson(<String, dynamic>{
        'suggestions': 'not-a-list',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
