import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const VidoFoodyKioskApp());

const brand = Color(0xFFFFCC00);
const brand2 = Color(0xFFFF9500);
const brandA = Color(0x2EFFCC00);
const darkBg = Color(0xFF0F1419);
const panel = Color(0xFF1A1F26);
const card = Color(0xFF252A33);
const cardHover = Color(0xFF2F3540);
const border = Color(0xFF374151);
const text = Color(0xFFF8FAFC);
const muted = Color(0xFF94A3B8);
const success = Color(0xFF22C55E);
const danger = Color(0xFFEF4444);

String money(num value) => '\$${value.toStringAsFixed(2)}';

class KioskSettings {
  String backendUrl = 'http://127.0.0.1:8787';
  String storeSlug = 'vido-foody-demo';
  String deviceId = 'KIOSK-1';
  String deviceName = 'Front Kiosk 1';
  String connectionMode = 'tcp';
  String terminalIp = '192.168.68.59';
  int terminalPort = 10009;
  int timeoutMs = 60000;
  bool useNativePosLink = true;
  bool requirePaymentBeforeSend = true;

  Map<String, dynamic> paymentPayload() => {
        'connectionMode': connectionMode,
        'ip': terminalIp,
        'port': terminalPort,
        'timeoutMs': timeoutMs,
        'deviceId': deviceId,
      };
}

class MenuCategory {
  const MenuCategory(this.id, this.name, this.icon);
  final String id;
  final String name;
  final String icon;
}

class MenuItemData {
  const MenuItemData(this.id, this.category, this.name, this.price, this.icon, {this.popular = false});
  final String id;
  final String category;
  final String name;
  final double price;
  final String icon;
  final bool popular;
}

class CartLine {
  CartLine(
    this.item, {
    this.qty = 1,
    this.size = 'M',
    this.sweetness = '100%',
    this.ice = 'Regular',
    this.toppings = const [],
  });
  final MenuItemData item;
  int qty;
  String size;
  String sweetness;
  String ice;
  List<String> toppings;
  String get key => '${item.id}|$size|$sweetness|$ice|${toppings.join(',')}';
  bool get hasDrinkOptions => item.category != 'snack';
  double get toppingsTotal => toppings.fold(0, (sum, topping) => sum + (toppingPrices[topping] ?? 0));
  double get sizePrice => switch (size) {
        'S' => -0.50,
        'L' => 1.00,
        _ => 0.00,
      };
  double get unit => item.price + sizePrice + toppingsTotal;
  double get total => unit * qty;
  String get optionLabel {
    final parts = <String>[];
    if (hasDrinkOptions) parts.addAll([size, 'Sugar $sweetness']);
    if (toppings.isNotEmpty) parts.add(toppings.join(', '));
    return parts.join(' · ');
  }
}

const toppingPrices = {
  'Boba': 0.75,
  'Crystal Boba': 0.85,
  'Pudding': 0.75,
  'Less Ice': 0.00,
  'No Ice': 0.00,
  'Extra Sweet': 0.00,
};

const fallbackCategories = [
  MenuCategory('milk-tea', 'Milk Tea', '🧋'),
  MenuCategory('fruit-tea', 'Fruit Tea', '🍑'),
  MenuCategory('coffee', 'Coffee', '☕'),
  MenuCategory('smoothie', 'Smoothies', '🥤'),
  MenuCategory('snack', 'Snacks', '🥐'),
];

const fallbackMenu = [
  MenuItemData('classic', 'milk-tea', 'Classic Milk Tea', 5.50, '🧋'),
  MenuItemData('brown-sugar', 'milk-tea', 'Brown Sugar Boba', 6.75, '🧋', popular: true),
  MenuItemData('oolong', 'milk-tea', 'Oolong Milk Tea', 5.75, '🧋'),
  MenuItemData('matcha', 'milk-tea', 'Matcha Latte', 6.25, '🍵'),
  MenuItemData('thai', 'milk-tea', 'Thai Milk Tea', 5.75, '🧋', popular: true),
  MenuItemData('taro', 'milk-tea', 'Taro Milk Tea', 6.25, '🧋'),
  MenuItemData('mango', 'fruit-tea', 'Mango Green Tea', 5.75, '🥭'),
  MenuItemData('strawberry', 'fruit-tea', 'Strawberry Tea', 6.25, '🍓'),
  MenuItemData('passion', 'fruit-tea', 'Passion Fruit Tea', 5.95, '🍊'),
  MenuItemData('lychee', 'fruit-tea', 'Lychee Tea', 5.95, '🌸'),
  MenuItemData('latte', 'coffee', 'Latte', 5.50, '☕'),
  MenuItemData('viet-coffee', 'coffee', 'Vietnamese Coffee', 5.25, '☕', popular: true),
  MenuItemData('mango-sm', 'smoothie', 'Mango Smoothie', 6.50, '🥤'),
  MenuItemData('straw-sm', 'smoothie', 'Strawberry Smoothie', 6.50, '🥤'),
  MenuItemData('waffle', 'snack', 'Bubble Waffle', 5.50, '🧇'),
  MenuItemData('mochi', 'snack', 'Mochi (3 pcs)', 4.25, '🍡'),
];

enum KioskStep { ordering, checkout, done }

class VidoFoodyKioskApp extends StatelessWidget {
  const VidoFoodyKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vido Foody Kiosk',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const KioskHome(),
    );
  }
}

class KioskHome extends StatefulWidget {
  const KioskHome({super.key});

  @override
  State<KioskHome> createState() => _KioskHomeState();
}

class _KioskHomeState extends State<KioskHome> {
  static const platform = MethodChannel('vido.foody/poslink');
  final settings = KioskSettings();
  final cart = <CartLine>[];
  List<MenuCategory> menuCategories = List<MenuCategory>.from(fallbackCategories);
  List<MenuItemData> menuItems = List<MenuItemData>.from(fallbackMenu);
  KioskStep step = KioskStep.ordering;
  String category = 'milk-tea';
  bool busy = false;
  String orderNumber = '';
  String message = '';
  String customerName = '';
  String receiptMessage = '';
  double selectedTip = 0;

  double get subtotal => cart.fold(0, (sum, line) => sum + line.total);
  double get tax => subtotal * 0.0875;
  double get totalBeforeTip => subtotal + tax;
  double get total => totalBeforeTip + selectedTip;

  @override
  void initState() {
    super.initState();
    syncMenuFromPos();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${settings.backendUrl}$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(Duration(milliseconds: settings.timeoutMs + 10000));
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Future<void> syncMenuFromPos() async {
    try {
      final res = await http.get(Uri.parse('${settings.backendUrl}/api/menu'))
          .timeout(const Duration(seconds: 5));
      final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(data['menu'] ?? {});
      final rawCategories = (payload['categories'] as List? ?? const []);
      final rawItems = (payload['items'] as List? ?? const []);
      final loadedItems = rawItems
          .map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            return MenuItemData(
              '${item['id']}',
              '${item['category']}',
              '${item['name']}',
              num.tryParse('${item['price']}')?.toDouble() ?? 0,
              '${item['icon'] ?? '•'}',
              popular: item['popular'] == true,
            );
          })
          .where((item) => item.category != 'topping' && item.price > 0)
          .toList();
      final visibleCategoryIds = loadedItems.map((item) => item.category).toSet();
      final loadedCategories = rawCategories.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return MenuCategory(
          '${item['id']}',
          '${item['name']}',
          '${item['icon'] ?? '•'}',
        );
      }).where((cat) => visibleCategoryIds.contains(cat.id)).toList();
      if (!mounted || loadedCategories.isEmpty || loadedItems.isEmpty) return;
      setState(() {
        menuCategories = loadedCategories;
        menuItems = loadedItems;
        if (!menuCategories.any((cat) => cat.id == category)) {
          category = menuCategories.first.id;
        }
      });
    } catch (_) {
      // Keep bundled menu for offline kiosk/demo mode.
    }
  }

  Future<void> addItem(MenuItemData item) async {
    final configuredLine = item.category == 'snack'
        ? CartLine(item)
        : await showModalBottomSheet<CartLine>(
            context: context,
            isScrollControlled: true,
            backgroundColor: panel,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            builder: (_) => ProductOptionsSheet(item: item),
          );
    if (configuredLine == null) return;
    setState(() {
      final index = cart.indexWhere((line) => line.key == configuredLine.key);
      if (index >= 0) {
        cart[index].qty += 1;
      } else {
        cart.add(configuredLine);
      }
    });
  }

  Future<Map<String, dynamic>> payCard() async {
    final ref = 'K${DateTime.now().millisecondsSinceEpoch % 100000000}';
    if (settings.useNativePosLink) {
      try {
        final result = await platform.invokeMethod('sale', {
          'amount': total,
          'refNum': ref,
          'tipAmount': selectedTip,
          'payment': settings.paymentPayload(),
        });
        return Map<String, dynamic>.from(result);
      } catch (_) {
        // Fallback is useful for dev with TCP BroadPOS backend.
      }
    }
    return post('/api/payment/sale', {
      'amount': total,
      'refNum': ref,
      'tipAmount': selectedTip,
      'payment': settings.paymentPayload(),
    });
  }

  Future<void> sendKioskOrder({required String paymentStatus, String paymentMethod = 'card', Map<String, dynamic>? paymentResult}) async {
    final result = await post('/api/kiosk/orders', {
      'storeSlug': settings.storeSlug,
      'deviceId': settings.deviceId,
      'source': 'Kiosk-${settings.deviceId}',
      'customer': customerName,
      'status': 'new',
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'tax': tax,
      'tip': selectedTip,
      'total': total,
      'shouldPrint': true,
      'printRouting': {
        'customerReceipt': 'receipt_printer',
        'kitchenTicket': 'kitchen_or_receipt_printer',
        'drinkLabel': 'label_printer_when_configured',
      },
      'paymentResult': paymentResult ?? {},
      'items': [
        for (final line in cart)
          {
            'id': line.item.id,
            'name': line.item.name,
            'qty': line.qty,
            'size': line.size,
            'sweetness': line.sweetness,
            'ice': line.ice,
            'toppings': line.toppings,
            'modifiers': line.optionLabel,
            'price': line.unit,
            'total': line.total,
          }
      ],
    });
    final order = Map<String, dynamic>.from(result['order'] ?? {});
    orderNumber = (order['id'] ?? 'KIOSK').toString();
  }

  Future<void> checkoutCard() async {
    if (cart.isEmpty) return;
    setState(() {
      busy = true;
      message = 'Waiting for card terminal...';
    });
    try {
      final payment = await payCard();
      final approved = payment['ok'] == true || payment['approved'] == true || (payment['result'] is Map && payment['result']['approved'] == true);
      if (!approved) throw Exception(payment['error'] ?? payment['resultText'] ?? 'Card was declined');
      if (mounted) setState(() => message = 'Payment approved. Sending order to POS...');
      await sendKioskOrder(paymentStatus: 'paid', paymentMethod: 'card', paymentResult: payment);
      finishOrder();
    } catch (err) {
      setState(() => message = 'Payment failed. Please try again or ask staff for help. $err');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void finishOrder() {
    setState(() {
      step = KioskStep.done;
      message = '';
      receiptMessage = '';
    });
    Future.delayed(const Duration(seconds: 25), reset);
  }

  Future<void> saveReceiptPhone(String phone) async {
    final clean = phone.trim();
    if (clean.isEmpty || orderNumber.isEmpty) return;
    try {
      await post('/api/kiosk/orders/$orderNumber/receipt-phone', {
        'storeSlug': settings.storeSlug,
        'customerPhone': clean,
      });
      if (mounted) setState(() => receiptMessage = 'Receipt phone saved');
    } catch (err) {
      if (mounted) setState(() => receiptMessage = 'Could not save phone. Please ask staff for a printed receipt.');
    }
  }

  void reset() {
    if (!mounted) return;
    setState(() {
      cart.clear();
      customerName = '';
      orderNumber = '';
      message = '';
      receiptMessage = '';
      selectedTip = 0;
      step = KioskStep.ordering;
    });
  }

  void openSettings() {
    showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(
        settings: settings,
        onSave: () => setState(() {}),
        onTest: testTerminal,
      ),
    );
  }

  Future<void> testTerminal() async {
    try {
      if (settings.useNativePosLink) {
        await platform.invokeMethod('testConnection', {'payment': settings.paymentPayload()});
      } else {
        await post('/api/payment/test-connection', {'payment': settings.paymentPayload()});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment terminal connected')));
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terminal test failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (step) {
          KioskStep.ordering => OrderingScreen(
              category: category,
              categories: menuCategories,
              menuItems: menuItems,
              cart: cart,
              subtotal: subtotal,
              tax: tax,
              total: total,
              onCategory: (id) => setState(() => category = id),
              onAdd: addItem,
              onQty: (line, delta) => setState(() {
                line.qty += delta;
                if (line.qty <= 0) cart.remove(line);
              }),
              onSize: (line, size) => setState(() => line.size = size),
              onCheckout: cart.isEmpty ? null : () => setState(() => step = KioskStep.checkout),
              onCancel: reset,
              onSettings: openSettings,
            ),
          KioskStep.checkout => CheckoutScreen(
              total: total,
              totalBeforeTip: totalBeforeTip,
              selectedTip: selectedTip,
              customerName: customerName,
              busy: busy,
              message: message,
              onTip: (tip) => setState(() => selectedTip = tip),
              onName: (v) => setState(() => customerName = v),
              onBack: busy ? null : () => setState(() => step = KioskStep.ordering),
              onCard: busy ? null : checkoutCard,
            ),
          KioskStep.done => DoneScreen(orderNumber: orderNumber, receiptMessage: receiptMessage, onReceiptPhone: saveReceiptPhone, onDone: reset),
        },
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart, required this.onSettings});
  final VoidCallback onStart;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onSettings,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [darkBg, panel]),
        ),
        child: Column(
          children: [
            const Spacer(),
            Image.asset('assets/vido-foody-logo.png', width: 260, height: 180, fit: BoxFit.contain),
            const SizedBox(height: 24),
            const Text('Welcome to Vido Foody', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('Order when you are ready', style: TextStyle(fontSize: 22, color: muted, fontWeight: FontWeight.w800)),
            const Spacer(),
            SizedBox(
              width: 420,
              height: 76,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Start Order', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class OrderingScreen extends StatelessWidget {
  const OrderingScreen({
    super.key,
    required this.category,
    required this.categories,
    required this.menuItems,
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.onCategory,
    required this.onAdd,
    required this.onQty,
    required this.onSize,
    required this.onCheckout,
    required this.onCancel,
    required this.onSettings,
  });

  final String category;
  final List<MenuCategory> categories;
  final List<MenuItemData> menuItems;
  final List<CartLine> cart;
  final double subtotal;
  final double tax;
  final double total;
  final ValueChanged<String> onCategory;
  final Future<void> Function(MenuItemData item) onAdd;
  final void Function(CartLine line, int delta) onQty;
  final void Function(CartLine line, String size) onSize;
  final VoidCallback? onCheckout;
  final VoidCallback onCancel;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final portrait = constraints.maxHeight > constraints.maxWidth;
      final menuWidth = portrait ? constraints.maxWidth : (constraints.maxWidth > 420 ? constraints.maxWidth - 420 : constraints.maxWidth);
      final columns = menuWidth < 620 ? 2 : (menuWidth < 1120 ? 3 : 4);
      final menuPane = _MenuPane(
        category: category,
        categories: categories,
        menuItems: menuItems,
        columns: columns,
        onCategory: onCategory,
        onAdd: onAdd,
        onSettings: onSettings,
      );
      final cartPane = CartPanel(
        cart: cart,
        subtotal: subtotal,
        tax: tax,
        total: total,
        onQty: onQty,
        onSize: onSize,
        onCheckout: onCheckout,
        onCancel: onCancel,
        compact: portrait,
      );

      if (portrait) {
        return Column(
          children: [
            Expanded(flex: 7, child: menuPane),
            SizedBox(height: constraints.maxHeight * 0.32, child: cartPane),
          ],
        );
      }

      return Row(
        children: [
          Expanded(flex: 7, child: menuPane),
          SizedBox(width: 420, child: cartPane),
        ],
      );
    });
  }
}

class _MenuPane extends StatelessWidget {
  const _MenuPane({
    required this.category,
    required this.categories,
    required this.menuItems,
    required this.columns,
    required this.onCategory,
    required this.onAdd,
    required this.onSettings,
  });

  final String category;
  final List<MenuCategory> categories;
  final List<MenuItemData> menuItems;
  final int columns;
  final ValueChanged<String> onCategory;
  final Future<void> Function(MenuItemData item) onAdd;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final items = menuItems.where((item) => item.category == category).toList();
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Image.asset('assets/vido-foody-logo.png', width: 84, height: 58, fit: BoxFit.contain),
            const SizedBox(width: 20),
            const Expanded(child: Text('Choose Your Favorites', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
            IconButton(
              onPressed: onSettings,
              tooltip: 'Kiosk settings',
              icon: const Icon(Icons.settings, color: muted),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final cat = categories[i];
                final selected = cat.id == category;
                return KioskCategoryPill(
                  label: cat.name,
                  icon: cat.icon,
                  selected: selected,
                  onTap: () => onCategory(cat.id),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: categories.length,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columns == 2 ? 0.94 : 1.05,
              ),
              itemBuilder: (_, i) => MenuCard(item: items[i], onAdd: onAdd),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.item, required this.onAdd});
  final MenuItemData item;
  final Future<void> Function(MenuItemData item) onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onAdd(item),
        splashColor: brandA,
        highlightColor: brandA,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 72))),
              )),
              const SizedBox(height: 10),
              Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(money(item.price), style: const TextStyle(fontSize: 18, color: brand, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => onAdd(item),
                  style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KioskCategoryPill extends StatelessWidget {
  const KioskCategoryPill({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? brand : card,
          foregroundColor: selected ? Colors.black : text,
          side: BorderSide(color: selected ? brand : border, width: selected ? 2 : 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          )),
        ]),
      ),
    );
  }
}

class ProductOptionsSheet extends StatefulWidget {
  const ProductOptionsSheet({super.key, required this.item});
  final MenuItemData item;

  @override
  State<ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<ProductOptionsSheet> {
  String size = 'M';
  String sweetness = '100%';
  String ice = 'Regular';
  final selectedToppings = <String>{};

  double get unitPrice {
    final toppingsTotal = selectedToppings.fold<double>(0, (sum, topping) => sum + (toppingPrices[topping] ?? 0));
    final sizePrice = switch (size) {
      'S' => -0.50,
      'L' => 1.00,
      _ => 0.00,
    };
    return widget.item.price + sizePrice + toppingsTotal;
  }

  void addToOrder() {
    Navigator.pop(
      context,
      CartLine(
        widget.item,
        size: size,
        sweetness: sweetness,
        ice: ice,
        toppings: selectedToppings.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(widget.item.icon, style: const TextStyle(fontSize: 46)),
                const SizedBox(width: 14),
                Expanded(child: Text(widget.item.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 18),
              const OptionTitle('Size'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OptionChip(label: 'S -\$0.50', selected: size == 'S', onTap: () => setState(() => size = 'S')),
                OptionChip(label: 'M Included', selected: size == 'M', onTap: () => setState(() => size = 'M')),
                OptionChip(label: 'L +\$1.00', selected: size == 'L', onTap: () => setState(() => size = 'L')),
              ]),
              const SizedBox(height: 18),
              const OptionTitle('Sugar'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final value in const ['0%', '25%', '50%', '75%', '100%'])
                  OptionChip(label: value, selected: sweetness == value, onTap: () => setState(() => sweetness = value)),
              ]),
              const SizedBox(height: 18),
              const OptionTitle('Toppings & Add-ons'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final entry in toppingPrices.entries)
                  FilterChip(
                    label: Text('${entry.key} +${money(entry.value)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    selected: selectedToppings.contains(entry.key),
                    selectedColor: brandA,
                    backgroundColor: card,
                    checkmarkColor: brand,
                    side: BorderSide(color: selectedToppings.contains(entry.key) ? brand : border),
                    onSelected: (value) => setState(() {
                      if (value) {
                        selectedToppings.add(entry.key);
                      } else {
                        selectedToppings.remove(entry.key);
                      }
                    }),
                  ),
              ]),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: addToOrder,
                  style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text('Add to Order - ${money(unitPrice)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OptionTitle extends StatelessWidget {
  const OptionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 16, color: muted, fontWeight: FontWeight.w900)),
    );
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? brand : card,
        foregroundColor: selected ? Colors.black : text,
        side: BorderSide(color: selected ? brand : border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.onQty,
    required this.onSize,
    required this.onCheckout,
    required this.onCancel,
    this.compact = false,
  });

  final List<CartLine> cart;
  final double subtotal;
  final double tax;
  final double total;
  final void Function(CartLine line, int delta) onQty;
  final void Function(CartLine line, String size) onSize;
  final VoidCallback? onCheckout;
  final VoidCallback onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: panel,
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Your Order', style: TextStyle(fontSize: compact ? 22 : 26, fontWeight: FontWeight.w900)),
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Tap Add to start your order', style: TextStyle(color: muted, fontWeight: FontWeight.w800)))
                : ListView.separated(
                    itemBuilder: (_, i) {
                      final line = cart[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(8)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(line.item.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                            Text(money(line.total), style: const TextStyle(color: brand2, fontWeight: FontWeight.w900)),
                          ]),
                          if (line.optionLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(line.optionLabel, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            if (line.hasDrinkOptions)
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'S', label: Text('S')),
                                  ButtonSegment(value: 'M', label: Text('M')),
                                  ButtonSegment(value: 'L', label: Text('L')),
                                ],
                                selected: {line.size},
                                onSelectionChanged: (v) => onSize(line, v.first),
                              ),
                            const Spacer(),
                            IconButton(onPressed: () => onQty(line, -1), icon: const Icon(Icons.remove_circle_outline)),
                            Text('${line.qty}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            IconButton(onPressed: () => onQty(line, 1), icon: const Icon(Icons.add_circle_outline)),
                          ]),
                        ]),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: cart.length,
                  ),
          ),
          const Divider(color: border),
          TotalRow('Subtotal', money(subtotal)),
          TotalRow('Tax', money(tax)),
          TotalRow('Total', money(total), large: true),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: compact ? 58 : 64,
            child: FilledButton(
              onPressed: onCheckout,
              style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('Checkout', style: TextStyle(fontSize: compact ? 20 : 22, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.totalBeforeTip,
    required this.selectedTip,
    required this.customerName,
    required this.busy,
    required this.message,
    required this.onTip,
    required this.onName,
    required this.onBack,
    required this.onCard,
  });

  final double total;
  final double totalBeforeTip;
  final double selectedTip;
  final String customerName;
  final bool busy;
  final String message;
  final ValueChanged<double> onTip;
  final ValueChanged<String> onName;
  final VoidCallback? onBack;
  final VoidCallback? onCard;

  @override
  Widget build(BuildContext context) {
    final tips = [0.15, 0.18, 0.20, 0.25];
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Back')),
          const SizedBox(height: 24),
          const Text('Checkout', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
            child: Row(children: [
              const Text('Total Due', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(money(total), style: const TextStyle(fontSize: 44, color: brand2, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Add Tip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final percent in tips)
                TipButton(
                  label: '${(percent * 100).round()}%',
                  amount: totalBeforeTip * percent,
                  selected: (selectedTip - (totalBeforeTip * percent)).abs() < 0.01,
                  onTap: () => onTip(totalBeforeTip * percent),
                ),
              TipButton(label: 'No Tip', amount: 0, selected: selectedTip == 0, onTap: () => onTip(0)),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: onName,
            decoration: const InputDecoration(labelText: 'Name for order (optional)', border: OutlineInputBorder()),
          ),
          const Spacer(),
          if (message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: danger.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(message, style: const TextStyle(color: danger, fontWeight: FontWeight.w800)),
            ),
          if (busy) ...[
            const LinearProgressIndicator(color: brand),
            const SizedBox(height: 14),
          ],
          PayButton(label: 'Pay Now', icon: Icons.credit_card, onTap: onCard),
          const SizedBox(height: 10),
          const Text(
            'After payment, this kiosk sends the paid order to POS for customer receipt, kitchen ticket, and drink label printing.',
            style: TextStyle(color: muted, fontWeight: FontWeight.w800, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class TipButton extends StatelessWidget {
  const TipButton({super.key, required this.label, required this.amount, required this.selected, required this.onTap});
  final String label;
  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 78,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? brand : card,
          foregroundColor: selected ? Colors.black : text,
          side: BorderSide(color: selected ? brand : border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(money(amount), style: TextStyle(color: selected ? Colors.black : muted, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class PayButton extends StatelessWidget {
  const PayButton({super.key, required this.label, required this.icon, required this.onTap, this.secondary = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? card : brand,
          foregroundColor: secondary ? text : Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.orderNumber, required this.receiptMessage, required this.onReceiptPhone, required this.onDone});
  final String orderNumber;
  final String receiptMessage;
  final Future<void> Function(String phone) onReceiptPhone;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final phone = TextEditingController();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: success, size: 110),
            const SizedBox(height: 24),
            const Text('Thank you!', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Paid order sent to POS. Receipt, kitchen ticket, and drink label will print based on store settings.', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: muted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
              child: Text('Order $orderNumber', style: const TextStyle(fontSize: 28, color: brand2, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 420,
              child: TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone for receipt (optional)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 420,
              height: 54,
              child: OutlinedButton(onPressed: () { onReceiptPhone(phone.text); }, child: const Text('Send Receipt')),
            ),
            if (receiptMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(receiptMessage, style: const TextStyle(color: success, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: onDone, child: const Text('Start New Order')),
          ],
        ),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.settings, required this.onSave, required this.onTest});
  final KioskSettings settings;
  final VoidCallback onSave;
  final Future<void> Function() onTest;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final backend = TextEditingController(text: widget.settings.backendUrl);
  late final storeSlug = TextEditingController(text: widget.settings.storeSlug);
  late final deviceId = TextEditingController(text: widget.settings.deviceId);
  late final deviceName = TextEditingController(text: widget.settings.deviceName);
  late final terminalIp = TextEditingController(text: widget.settings.terminalIp);
  late final terminalPort = TextEditingController(text: '${widget.settings.terminalPort}');
  late final timeoutMs = TextEditingController(text: '${widget.settings.timeoutMs}');

  void save() {
    widget.settings.backendUrl = backend.text.trim();
    widget.settings.storeSlug = storeSlug.text.trim();
    widget.settings.deviceId = deviceId.text.trim();
    widget.settings.deviceName = deviceName.text.trim();
    widget.settings.terminalIp = terminalIp.text.trim();
    widget.settings.terminalPort = int.tryParse(terminalPort.text) ?? 10009;
    widget.settings.timeoutMs = int.tryParse(timeoutMs.text) ?? 60000;
    widget.onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: panel,
      title: const Text('Vido Foody Kiosk Settings', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsField('Backend URL', backend),
              SettingsField('Store Slug', storeSlug),
              SettingsField('Kiosk Device ID', deviceId),
              SettingsField('Kiosk Name', deviceName),
              const Divider(color: border),
              DropdownButtonFormField<String>(
                value: widget.settings.connectionMode,
                decoration: const InputDecoration(labelText: 'PAX Connection Mode'),
                items: const [
                  DropdownMenuItem(value: 'tcp', child: Text('TCP/IP')),
                  DropdownMenuItem(value: 'usb', child: Text('USB via Android POSLink')),
                ],
                onChanged: (v) => setState(() => widget.settings.connectionMode = v ?? 'tcp'),
              ),
              SwitchListTile(
                value: widget.settings.useNativePosLink,
                title: const Text('Use native Android POSLink'),
                subtitle: const Text('Required for USB. TCP can use native or backend fallback.'),
                onChanged: (v) => setState(() => widget.settings.useNativePosLink = v),
              ),
              SettingsField('PAX Terminal IP', terminalIp),
              SettingsField('PAX Terminal Port', terminalPort, keyboard: TextInputType.number),
              SettingsField('Timeout (ms)', timeoutMs, keyboard: TextInputType.number),
              SwitchListTile(
                value: widget.settings.requirePaymentBeforeSend,
                title: const Text('Require payment before sending kiosk order'),
                onChanged: (v) => setState(() => widget.settings.requirePaymentBeforeSend = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Each kiosk should have a unique Device ID and its own assigned PAX terminal IP or USB connection.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        OutlinedButton(onPressed: widget.onTest, child: const Text('Test PAX')),
        FilledButton(onPressed: save, style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black), child: const Text('Save')),
      ],
    );
  }
}

class SettingsField extends StatelessWidget {
  const SettingsField(this.label, this.controller, {super.key, this.keyboard});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class TotalRow extends StatelessWidget {
  const TotalRow(this.label, this.value, {super.key, this.large = false});
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(color: muted, fontSize: large ? 18 : 14, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text(value, style: TextStyle(color: large ? brand2 : text, fontSize: large ? 26 : 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
