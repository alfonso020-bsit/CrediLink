import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactStoreButton extends StatelessWidget {
  const ContactStoreButton({
    super.key,
    this.phone,
    this.storeName,
  });

  final String? phone;
  final String? storeName;

  @override
  Widget build(BuildContext context) {
    if (phone == null || phone!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _call(phone!),
            icon: const Icon(Icons.phone),
            label: const Text('Call Store'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _sms(phone!, storeName),
            icon: const Icon(Icons.sms),
            label: const Text('SMS'),
          ),
        ),
      ],
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sms(String number, String? store) async {
    final body = store != null ? 'Hi $store, regarding my debt...' : 'Hi, regarding my debt...';
    final uri = Uri(scheme: 'sms', path: number, queryParameters: {'body': body});
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
