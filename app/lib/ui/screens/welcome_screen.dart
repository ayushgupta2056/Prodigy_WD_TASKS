import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// First launch: paste the Web App URL and API key, or explore with demo data.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: EaseIn(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(16)),
                    child: Icon(LucideIcons500.house, color: c.onAccent, size: 28),
                  ),
                  const SizedBox(height: Space.xxl),
                  Text('Your stays,\nall in one place.', style: AppText.h1(context).copyWith(fontSize: 32, height: 1.12)),
                  const SizedBox(height: Space.md),
                  Text('Bookings from Airbnb, MakeMyTrip, Goibibo, Agoda and Booking.com in one calendar, with what you actually earned.',
                      style: AppText.body(context).copyWith(color: c.muted)),
                  const SizedBox(height: Space.xxxl),
                  const ConnectForm(),
                  const SizedBox(height: Space.lg),
                  Row(children: [
                    Expanded(child: Divider(color: c.hairline)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: AppText.label(context))),
                    Expanded(child: Divider(color: c.hairline)),
                  ]),
                  const SizedBox(height: Space.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.repoRead.startDemo(),
                      icon: const Icon(LucideIcons300.sparkles, size: 18),
                      label: const Text('Explore with demo data'),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => context.repoRead.startLocal(),
                      icon: const Icon(LucideIcons300.hardDrive, size: 18),
                      label: const Text('Start empty, save on this device only'),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Text('Set-up steps are in SETUP.md: create the Google Sheet, deploy the Web App, then paste its URL and key here.',
                      style: AppText.label(context)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectForm extends StatefulWidget {
  final VoidCallback? onConnected;
  const ConnectForm({super.key, this.onConnected});
  @override
  State<ConnectForm> createState() => _ConnectFormState();
}

class _ConnectFormState extends State<ConnectForm> {
  late final _url = TextEditingController(text: context.repoRead.url);
  late final _key = TextEditingController(text: context.repoRead.apiKey);
  bool _busy = false;
  bool _showKey = false;
  String? _error;

  Future<void> _connect() async {
    final url = _url.text.trim();
    if (!url.startsWith('https://script.google.com/')) {
      setState(() => _error = 'The URL should start with https://script.google.com/ and end with /exec');
      return;
    }
    if (_key.text.trim().length < 20) {
      setState(() => _error = 'Paste the full API key from the Sheet (Booking App → Show Web App URL and API key).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.repoRead.connect(url, _key.text);
      widget.onConnected?.call();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _url,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'Web App URL', hintText: 'https://script.google.com/macros/s/…/exec', prefixIcon: Icon(LucideIcons300.link, size: 18)),
      ),
      const SizedBox(height: Space.md),
      TextField(
        controller: _key,
        obscureText: !_showKey,
        decoration: InputDecoration(
          labelText: 'API key',
          prefixIcon: const Icon(LucideIcons300.keyRound, size: 18),
          suffixIcon: IconButton(
            icon: Icon(_showKey ? LucideIcons300.eyeOff : LucideIcons300.eye, size: 18),
            onPressed: () => setState(() => _showKey = !_showKey),
          ),
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: Space.md), child: Text(_error!, style: AppText.label(context).copyWith(color: context.colors.danger))),
      const SizedBox(height: Space.lg),
      FilledButton(
        onPressed: _busy ? null : _connect,
        child: _busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onAccent)) : const Text('Connect'),
      ),
    ]);
  }
}
