import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  static const _orderChannel = AndroidNotificationDetails(
    'orders_channel',
    'Orders',
    channelDescription: 'Order status notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> orderPlaced(String orderId) async {
    await _plugin.show(
      0,
      'Order Placed! 🎉',
      'Your order #${orderId.substring(0, 8).toUpperCase()} is being prepared.',
      const NotificationDetails(android: _orderChannel),
    );
  }

  static Future<void> orderStatusChanged(
      String orderId, String status) async {
    final messages = {
      'confirmed': 'Your order has been confirmed by the vendor!',
      'ready': 'Your order is ready! 🍽️',
      'completed': 'Order completed. Enjoy your meal! 😋',
    };
    await _plugin.show(
      1,
      'Order Update',
      messages[status] ?? 'Your order status has changed.',
      const NotificationDetails(android: _orderChannel),
    );
  }

  static Future<void> newOrderReceived(String buyerName) async {
    await _plugin.show(
      2,
      'New Order! 🛎️',
      '$buyerName just placed an order.',
      const NotificationDetails(android: _orderChannel),
    );
  }
}
