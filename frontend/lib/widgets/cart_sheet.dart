import 'package:flutter/material.dart';

import 'cart_body.dart';

/// Mobile cart presentation: modal bottom sheet that wraps a [CartBody].
/// On desktop/wide screens, the POS screen renders [CartBody] inline as a
/// side panel instead.
class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Expanded(child: CartBody(inSheet: true)),
          ],
        ),
      ),
    );
  }
}
