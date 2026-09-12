import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_payment_bridge.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'native payment launch stays pending until the server confirms the order',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final api = _CommercePaymentApi();
      final bridge = _PaymentBridge();
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              MemoryHealthStore(),
              _Wearable(),
              paymentBridge: bridge,
            )
            ..session = Session(
              accessToken: 'token',
              refreshToken: 'refresh',
              expiresAt: DateTime(2030),
              memberId: 'member',
              displayName: 'Member',
              accountKey: 'email:member@example.com',
            );
      addTearDown(controller.dispose);

      final launch = await controller.startGlobalShopPayment(
        orderId: _orderId,
        channel: 'alipay_app',
      );

      expect(api.lastChannel, 'alipay_app');
      expect(api.lastPlatform, 'android');
      expect(api.lastIdempotencyKey, matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(bridge.alipayOrder, 'signed-order');
      expect(launch.cancelled, isFalse);
      expect(launch.intent['status'], 'pending');

      final refreshed = await controller.refreshGlobalShopPayment(_paymentId);
      expect(api.lastPaymentId, _paymentId);
      expect(refreshed['status'], 'pending');
    },
  );

  test(
    'a mismatched provider response never reaches the native bridge',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final api = _CommercePaymentApi()..mismatchedChannel = true;
      final bridge = _PaymentBridge();
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              MemoryHealthStore(),
              _Wearable(),
              paymentBridge: bridge,
            )
            ..session = Session(
              accessToken: 'token',
              refreshToken: 'refresh',
              expiresAt: DateTime(2030),
              memberId: 'member',
              displayName: 'Member',
            );
      addTearDown(controller.dispose);

      await expectLater(
        controller.startGlobalShopPayment(
          orderId: _orderId,
          channel: 'wechat_app',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(bridge.wechatCalls, 0);
    },
  );
}

const _orderId = '22222222-2222-4222-8222-222222222222';
const _paymentId = '66666666-6666-4666-8666-666666666666';

class _CommercePaymentApi extends Fake
    implements SaydianApi, GlobalCommerceApi {
  String? lastChannel;
  String? lastPlatform;
  String? lastIdempotencyKey;
  String? lastPaymentId;
  bool mismatchedChannel = false;

  @override
  Future<Map<String, Object?>> createGlobalShopPayment({
    required String orderId,
    required String channel,
    required String platform,
    required String idempotencyKey,
  }) async {
    lastChannel = channel;
    lastPlatform = platform;
    lastIdempotencyKey = idempotencyKey;
    return {
      'id': _paymentId,
      'businessType': 'commerce_order',
      'businessId': orderId,
      'channel': mismatchedChannel ? 'alipay_app' : channel,
      'status': 'pending',
      'invoke': channel == 'wechat_app'
          ? {
              'appId': 'wx1234567890',
              'partnerId': 'merchant',
              'prepayId': 'prepay',
              'nonceStr': 'nonce',
              'timeStamp': '1',
              'sign': 'signed',
            }
          : {'orderString': 'signed-order'},
    };
  }

  @override
  Future<Map<String, Object?>> getGlobalShopPayment(String id) async {
    lastPaymentId = id;
    return {'id': id, 'status': 'pending'};
  }
}

class _PaymentBridge implements AppPaymentBridge {
  int wechatCalls = 0;
  String? alipayOrder;

  @override
  Future<void> startWechat(Map<String, Object?> signedParameters) async {
    wechatCalls++;
  }

  @override
  Future<AppPaymentResult?> takeWechatResult() async => null;

  @override
  Future<AppPaymentResult> startAlipay(String signedOrder) async {
    alipayOrder = signedOrder;
    return const AppPaymentResult(
      code: '9000',
      message: 'client success',
      raw: {},
    );
  }
}

class _Wearable extends Fake implements WearableBridge {}
