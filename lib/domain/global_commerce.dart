class GlobalCommerceCapabilities {
  const GlobalCommerceCapabilities({
    required this.checkoutEnabled,
    required this.readOnly,
    required this.countryCodes,
    required this.currency,
    required this.currencyExponent,
    required this.paymentChannels,
  });

  factory GlobalCommerceCapabilities.fromJson(Map<String, Object?> json) {
    final checkout = commerceMap(json['checkout']);
    final maintenance = commerceMap(json['maintenance']);
    final countries =
        (checkout['countryCodes'] is List
                ? checkout['countryCodes'] as List
                : const [])
            .whereType<String>()
            .where((value) => RegExp(r'^[A-Z]{2}$').hasMatch(value))
            .toSet()
            .toList(growable: false);
    final currency = checkout['currency'];
    final exponent = checkout['currencyExponent'];
    return GlobalCommerceCapabilities(
      checkoutEnabled: checkout['enabled'] == true,
      readOnly: maintenance['readOnly'] == true,
      countryCodes: countries,
      currency: currency is String && RegExp(r'^[A-Z]{3}$').hasMatch(currency)
          ? currency
          : null,
      currencyExponent: exponent is int && exponent >= 0 && exponent <= 4
          ? exponent
          : null,
      paymentChannels: commerceRows(json['payments']),
    );
  }

  static const unavailable = GlobalCommerceCapabilities(
    checkoutEnabled: false,
    readOnly: false,
    countryCodes: [],
    currency: null,
    currencyExponent: null,
    paymentChannels: [],
  );

  final bool checkoutEnabled;
  final bool readOnly;
  final List<String> countryCodes;
  final String? currency;
  final int? currencyExponent;
  final List<Map<String, Object?>> paymentChannels;

  List<String> nativePaymentChannels(String platform) {
    final normalizedPlatform = platform.trim().toLowerCase();
    const supported = {'wechat_app', 'alipay_app'};
    return paymentChannels
        .where((channel) {
          final environments = channel['environments'];
          final name = commerceText(channel['channel']).toLowerCase();
          return supported.contains(name) &&
              channel['enabled'] == true &&
              environments is List &&
              environments
                  .whereType<String>()
                  .map((value) => value.toLowerCase())
                  .contains(normalizedPlatform);
        })
        .map((channel) => commerceText(channel['channel']).toLowerCase())
        .toSet()
        .toList(growable: false);
  }

  bool hasNativePayment(String platform) =>
      nativePaymentChannels(platform).isNotEmpty;

  Map<String, Object?> withCurrency(Map<String, Object?> value) => {
    ...value,
    if (!value.containsKey('currency') && currency != null)
      'currency': currency,
    if (!value.containsKey('currencyExponent') && currencyExponent != null)
      'currencyExponent': currencyExponent,
  };
}

class GlobalShopPaymentLaunchResult {
  const GlobalShopPaymentLaunchResult({
    required this.intent,
    required this.cancelled,
  });

  final Map<String, Object?> intent;
  final bool cancelled;
}

Map<String, Object?> commerceMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry('$key', item))
    : const <String, Object?>{};

List<Map<String, Object?>> commerceRows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => row.map((key, item) => MapEntry('$key', item)))
          .toList(growable: false)
    : const <Map<String, Object?>>[];

String commerceText(Object? value) => value is String ? value.trim() : '';

String commerceId(Object? value) {
  final id = commerceText(value);
  return id.length <= 180 ? id : '';
}

int? commerceCents(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}
