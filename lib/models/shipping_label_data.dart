/// Everything ShippingLabelParser can pull off a shipping label, plus the
/// raw inputs it worked from. Every extracted field is nullable — a label
/// is never guaranteed to contain any particular field, and this model
/// must never invent a value that wasn't actually read off the label.
class ShippingLabelData {
  final String? recipientName;
  final String? recipientCompany;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? province;
  final String? postalCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? trackingNumber;
  final String? orderNumber;
  final String? referenceNumber;
  final String? carrier;
  final String? serviceType;
  final String? senderName;
  final String? senderAddress;
  final String? senderCity;
  final String? senderState;
  final String? senderPostalCode;
  final String? senderCountry;
  final double? packageWeight;

  final String rawOcrText;
  // OCR-mistake-aware cleanup (O<->0, I<->1, S<->5, B<->8 in numeric-looking
  // runs) applied for matching/parsing purposes only — rawOcrText above is
  // never modified, so nothing the label actually said is ever lost.
  final String normalizedOcrText;

  final String? barcodeValue;
  final String? barcodeType;

  /// 0.0-1.0 confidence per extracted field, keyed by the same names as the
  /// getters above (e.g. 'recipientName', 'trackingNumber'). A field with
  /// no entry here was not found at all. See ShippingLabelParser for how
  /// these are derived — never a bare guess, always tied to a concrete
  /// signal (regex specificity, barcode corroboration, label keyword
  /// proximity, etc.).
  final Map<String, double> confidence;

  const ShippingLabelData({
    this.recipientName,
    this.recipientCompany,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.province,
    this.postalCode,
    this.country,
    this.phone,
    this.email,
    this.trackingNumber,
    this.orderNumber,
    this.referenceNumber,
    this.carrier,
    this.serviceType,
    this.senderName,
    this.senderAddress,
    this.senderCity,
    this.senderState,
    this.senderPostalCode,
    this.senderCountry,
    this.packageWeight,
    required this.rawOcrText,
    required this.normalizedOcrText,
    this.barcodeValue,
    this.barcodeType,
    this.confidence = const {},
  });

  double confidenceFor(String field) => confidence[field] ?? 0.0;

  Map<String, dynamic> toJson() => {
    'recipientName': recipientName,
    'recipientCompany': recipientCompany,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city': city,
    'state': state,
    'province': province,
    'postalCode': postalCode,
    'country': country,
    'phone': phone,
    'email': email,
    'trackingNumber': trackingNumber,
    'orderNumber': orderNumber,
    'referenceNumber': referenceNumber,
    'carrier': carrier,
    'serviceType': serviceType,
    'senderName': senderName,
    'senderAddress': senderAddress,
    'senderCity': senderCity,
    'senderState': senderState,
    'senderPostalCode': senderPostalCode,
    'senderCountry': senderCountry,
    'packageWeight': packageWeight,
    'barcodeValue': barcodeValue,
    'barcodeType': barcodeType,
    'confidence': confidence,
  };

  ShippingLabelData copyWith({
    Object? recipientName = _unset,
    Object? recipientCompany = _unset,
    Object? addressLine1 = _unset,
    Object? addressLine2 = _unset,
    Object? city = _unset,
    Object? state = _unset,
    Object? province = _unset,
    Object? postalCode = _unset,
    Object? country = _unset,
    Object? phone = _unset,
    Object? email = _unset,
    Object? trackingNumber = _unset,
    Object? orderNumber = _unset,
    Object? referenceNumber = _unset,
    Object? carrier = _unset,
    Object? serviceType = _unset,
    Object? senderName = _unset,
    Object? senderAddress = _unset,
    Object? senderCity = _unset,
    Object? senderState = _unset,
    Object? senderPostalCode = _unset,
    Object? senderCountry = _unset,
    Object? packageWeight = _unset,
  }) {
    return ShippingLabelData(
      recipientName: recipientName == _unset
          ? this.recipientName
          : recipientName as String?,
      recipientCompany: recipientCompany == _unset
          ? this.recipientCompany
          : recipientCompany as String?,
      addressLine1: addressLine1 == _unset
          ? this.addressLine1
          : addressLine1 as String?,
      addressLine2: addressLine2 == _unset
          ? this.addressLine2
          : addressLine2 as String?,
      city: city == _unset ? this.city : city as String?,
      state: state == _unset ? this.state : state as String?,
      province: province == _unset ? this.province : province as String?,
      postalCode: postalCode == _unset
          ? this.postalCode
          : postalCode as String?,
      country: country == _unset ? this.country : country as String?,
      phone: phone == _unset ? this.phone : phone as String?,
      email: email == _unset ? this.email : email as String?,
      trackingNumber: trackingNumber == _unset
          ? this.trackingNumber
          : trackingNumber as String?,
      orderNumber: orderNumber == _unset
          ? this.orderNumber
          : orderNumber as String?,
      referenceNumber: referenceNumber == _unset
          ? this.referenceNumber
          : referenceNumber as String?,
      carrier: carrier == _unset ? this.carrier : carrier as String?,
      serviceType: serviceType == _unset
          ? this.serviceType
          : serviceType as String?,
      senderName: senderName == _unset
          ? this.senderName
          : senderName as String?,
      senderAddress: senderAddress == _unset
          ? this.senderAddress
          : senderAddress as String?,
      senderCity: senderCity == _unset
          ? this.senderCity
          : senderCity as String?,
      senderState: senderState == _unset
          ? this.senderState
          : senderState as String?,
      senderPostalCode: senderPostalCode == _unset
          ? this.senderPostalCode
          : senderPostalCode as String?,
      senderCountry: senderCountry == _unset
          ? this.senderCountry
          : senderCountry as String?,
      packageWeight: packageWeight == _unset
          ? this.packageWeight
          : packageWeight as double?,
      rawOcrText: rawOcrText,
      normalizedOcrText: normalizedOcrText,
      barcodeValue: barcodeValue,
      barcodeType: barcodeType,
      confidence: confidence,
    );
  }
}

const _unset = Object();
