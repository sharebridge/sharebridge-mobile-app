/// Response from POST /v1/donor-seeker/order-intents.
class OrderIntentRegistration {
  const OrderIntentRegistration({
    required this.orderIntentId,
    required this.packId,
    required this.status,
    required this.createdAt,
  });

  final String orderIntentId;
  final String packId;
  final String status;
  final String createdAt;
}
