import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/load_presets_usecase.dart';
import '../../data/auth_context.dart';
import '../../data/donor_setup_api_exceptions.dart';
import '../../data/donor_setup_repository_impl.dart';
import '../../data/http_donor_setup_api_client.dart';
import '../../domain/models/donor_preset.dart';

class DonorPresetsPage extends StatefulWidget {
  const DonorPresetsPage({
    super.key,
    this.loadPresetsUseCase,
    this.authContext,
  });

  final LoadPresetsUseCase? loadPresetsUseCase;
  final AuthContext? authContext;

  @override
  State<DonorPresetsPage> createState() => _DonorPresetsPageState();
}

class _DonorPresetsPageState extends State<DonorPresetsPage> {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  late final AuthContext _authContext;
  late final LoadPresetsUseCase _loadPresetsUseCase;
  List<DonorPreset> _presets = <DonorPreset>[];
  bool _loading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _authContext = widget.authContext ?? AuthContext.fromEnvironment();
    _loadPresetsUseCase =
        widget.loadPresetsUseCase ??
        LoadPresetsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(
              baseUrl: _defaultApiBaseUrl,
              authContext: _authContext,
            ),
          ),
        );
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final presets = await _loadPresetsUseCase(userId: _authContext.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _presets = presets;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = _friendlyError(error);
        _presets = <DonorPreset>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is DonorSetupTimeoutException) {
      return 'The server took too long to respond. Pull to retry.';
    }
    if (error is DonorSetupNetworkException) {
      return 'Network unavailable. Pull to retry.';
    }
    if (error is DonorSetupServerException) {
      return 'Server error (HTTP ${error.statusCode}). Pull to retry.';
    }
    if (error is DonorSetupBadRequestException) {
      return error.message;
    }
    if (error is DonorSetupResponseException) {
      return 'Unexpected server response.';
    }
    return error.toString();
  }

  Uri? _orderUri(DonorPreset preset) {
    final uri = Uri.tryParse(preset.orderUrl.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    return uri;
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order link copied to clipboard')),
    );
  }

  Future<void> _openLink(DonorPreset preset) async {
    final uri = _orderUri(preset);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link is missing or not http/https.'),
        ),
      );
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open browser. Try Copy link or check device settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved presets'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorText != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              )
            else if (_presets.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No presets on server for this user.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverList.separated(
                  itemCount: _presets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final preset = _presets[index];
                    final canOpen = _orderUri(preset) != null;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              preset.restaurantName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${preset.appName} · ${preset.source}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              preset.orderUrl,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            if (preset.menuItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  preset.menuItems.join(', '),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: <Widget>[
                                TextButton.icon(
                                  onPressed: preset.orderUrl.trim().isEmpty
                                      ? null
                                      : () => _copyLink(preset.orderUrl.trim()),
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('Copy link'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: !canOpen
                                      ? null
                                      : () => _openLink(preset),
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('Open link'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
