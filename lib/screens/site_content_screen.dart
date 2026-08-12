import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Admin editor for every customizable piece of the public site — hero
/// copy, service cards (also the dedicated Services page), "why choose us"
/// features, stats, the sign-up CTA, footer/contact info, and the
/// About/Rates page text. Saving here writes straight to `site_content`
/// and takes effect on the live site immediately (the landing page and the
/// About/Services/Rates/Contact pages all fetch it fresh on every load).
class SiteContentScreen extends StatefulWidget {
  const SiteContentScreen({super.key});

  @override
  State<SiteContentScreen> createState() => _SiteContentScreenState();
}

class _SiteContentScreenState extends State<SiteContentScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late Map<String, dynamic> _content;
  late List<Key> _serviceKeys;
  late List<Key> _whyKeys;
  late List<Key> _statKeys;
  late List<Key> _socialKeys;
  late List<Key> _heroFeatureKeys;
  int _formVersion = 0;

  @override
  void initState() {
    super.initState();
    _content = _deepCopy(LandingContent.defaults);
    _rebuildKeys();
    _load();
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> src) {
    return (jsonDecode(jsonEncode(src)) as Map).cast<String, dynamic>();
  }

  void _rebuildKeys() {
    _serviceKeys = List.generate(_servicesItems.length, (_) => UniqueKey());
    _whyKeys = List.generate(_whyItems.length, (_) => UniqueKey());
    _statKeys = List.generate(_statsItems.length, (_) => UniqueKey());
    _socialKeys = List.generate(_socialItems.length, (_) => UniqueKey());
    _heroFeatureKeys = List.generate(_heroFeatureItems.length, (_) => UniqueKey());
  }

  Map<String, dynamic> _sec(String key) =>
      _content[key] as Map<String, dynamic>;
  List<Map<String, dynamic>> get _servicesItems =>
      (_sec('services')['items'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _whyItems =>
      (_sec('whyChooseUs')['items'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _statsItems =>
      (_sec('stats')['items'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _socialItems =>
      (_sec('social')['items'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _heroFeatureItems =>
      (_sec('hero')['features'] as List).cast<Map<String, dynamic>>();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final overrides = await _db.getSiteContent('landing');
      final merged = LandingContent.merged(overrides).data;
      setState(() {
        _content = _deepCopy(merged);
        _rebuildKeys();
        _formVersion++;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load saved customizations — showing defaults instead. $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updateSiteContent('landing', _content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Landing page updated — changes are live now.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmResetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reset everything to defaults?'),
        content: const Text(
          'This discards every customization on this form and restores the '
          "page's original copy, images, and numbers. Nothing on the live "
          'site changes until you press Save afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _content = _deepCopy(LandingContent.defaults);
      _rebuildKeys();
      _formVersion++;
    });
  }

  void _previewSite() => html.window.open('/', '_blank');

  void _addItem(List<Map<String, dynamic>> items, List<Key> keys, Map<String, dynamic> blank) {
    setState(() {
      items.add(blank);
      keys.add(UniqueKey());
    });
  }

  void _removeItem(List<Map<String, dynamic>> items, List<Key> keys, int i) {
    setState(() {
      items.removeAt(i);
      keys.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_formVersion),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerSection(),
                    const SizedBox(height: 20),
                    _heroSection(),
                    const SizedBox(height: 20),
                    _knutsfordSection(),
                    const SizedBox(height: 20),
                    _servicesSection(),
                    const SizedBox(height: 20),
                    _whySection(),
                    const SizedBox(height: 20),
                    _statsSection(),
                    const SizedBox(height: 20),
                    _ctaSection(),
                    const SizedBox(height: 20),
                    _footerContactSection(),
                    const SizedBox(height: 20),
                    _socialSection(),
                    const SizedBox(height: 20),
                    _aboutRatesSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site Content',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
            ),
            SizedBox(height: 2),
            Text(
              'Customize every section of the public landing page — text, numbers, icons, and images.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _previewSite,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Preview site'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _saving ? null : _confirmResetAll,
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Reset to defaults'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
      ],
    );
  }

  // ─── Header / branding ─────────────────────────────────────────────────

  Widget _headerSection() {
    final header = _sec('header');
    return _Section(
      title: 'Header / branding',
      subtitle:
          'Shown next to the logo in the top nav on every public page — the '
          'logo artwork itself is too detailed to read at that size, so this '
          'text is what actually carries the name.',
      child: Column(
        children: [
          _Field(
            label: 'Company name in header',
            initial: header['companyName'],
            onChanged: (v) => header['companyName'] = v,
          ),
          _Field(
            label: 'Logo image URL (blank = default logo)',
            initial: header['logoUrl'],
            hint: 'https://…',
            onChanged: (v) => header['logoUrl'] = v,
          ),
        ],
      ),
    );
  }

  // ─── Hero ──────────────────────────────────────────────────────────────

  Widget _heroSection() {
    final hero = _sec('hero');
    return _Section(
      title: 'Hero banner',
      subtitle: 'The first thing visitors see at the top of the page.',
      child: Column(
        children: [
          _fieldRow(
            _Field(label: 'Headline line 1', initial: hero['titleLine1'], onChanged: (v) => hero['titleLine1'] = v),
            _Field(label: 'Headline line 2 (highlighted)', initial: hero['titleLine2'], onChanged: (v) => hero['titleLine2'] = v),
          ),
          _Field(label: 'Subtext', initial: hero['subtitle'], maxLines: 2, onChanged: (v) => hero['subtitle'] = v),
          _fieldRow(
            _Field(label: 'Primary button text', initial: hero['primaryButtonText'], onChanged: (v) => hero['primaryButtonText'] = v),
            _Field(label: 'Secondary button text', initial: hero['secondaryButtonText'], onChanged: (v) => hero['secondaryButtonText'] = v),
          ),
          _Field(
            label: 'Photo card URL (blank = default photo) — the image on the right',
            initial: hero['backgroundImageUrl'],
            hint: 'https://…',
            onChanged: (v) => hero['backgroundImageUrl'] = v,
          ),
          _Field(
            label: 'Background video URL (blank = default clip) — full-width, plays behind everything, desktop only',
            initial: hero['backgroundVideoUrl'],
            hint: 'https://…/video.mp4',
            onChanged: (v) => hero['backgroundVideoUrl'] = v,
          ),
          _fieldRow(
            _Field(label: 'Origin badge flag (emoji)', initial: hero['originFlag'], onChanged: (v) => hero['originFlag'] = v),
            _Field(label: 'Origin badge label', initial: hero['originLabel'], onChanged: (v) => hero['originLabel'] = v),
          ),
          _Field(label: 'Origin badge text', initial: hero['originText'], onChanged: (v) => hero['originText'] = v),
          _fieldRow(
            _Field(label: 'Destination badge flag (emoji)', initial: hero['destFlag'], onChanged: (v) => hero['destFlag'] = v),
            _Field(label: 'Destination badge label', initial: hero['destLabel'], onChanged: (v) => hero['destLabel'] = v),
          ),
          _Field(label: 'Destination badge text', initial: hero['destText'], onChanged: (v) => hero['destText'] = v),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Feature badges (the 4 small icons under the subtext)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _heroFeatureItems.length; i++)
            KeyedSubtree(
              key: _heroFeatureKeys[i],
              child: _ItemCard(
                title: 'Badge ${i + 1}',
                onRemove: _heroFeatureItems.length > 1
                    ? () => _removeItem(_heroFeatureItems, _heroFeatureKeys, i)
                    : null,
                child: Column(
                  children: [
                    _IconPicker(
                      label: 'Icon',
                      initial: _heroFeatureItems[i]['icon'] as String? ?? '',
                      onChanged: (v) => _heroFeatureItems[i]['icon'] = v,
                    ),
                    _fieldRow(
                      _Field(label: 'Line 1', initial: _heroFeatureItems[i]['line1'], onChanged: (v) => _heroFeatureItems[i]['line1'] = v),
                      _Field(label: 'Line 2', initial: _heroFeatureItems[i]['line2'], onChanged: (v) => _heroFeatureItems[i]['line2'] = v),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(_heroFeatureItems, _heroFeatureKeys, {
                'icon': 'star',
                'line1': 'NEW',
                'line2': 'BADGE',
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add badge'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Knutsford promo card ──────────────────────────────────────────────

  Widget _knutsfordSection() {
    final k = _sec('knutsford');
    return _Section(
      title: 'Partner promo card',
      subtitle: 'The small card overlapping the hero photo (currently "Knutsford Express"). Turn it off if you don\'t have a similar partnership to promote.',
      child: Column(
        children: [
          Row(
            children: [
              Switch(
                value: k['enabled'] as bool? ?? true,
                onChanged: (v) => setState(() => k['enabled'] = v),
              ),
              const Text('Show this card on the hero photo', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          _fieldRow(
            _Field(label: 'Title (styled part)', initial: k['titlePrefix'], onChanged: (v) => k['titlePrefix'] = v),
            _Field(label: 'Title (plain part)', initial: k['titleSuffix'], onChanged: (v) => k['titleSuffix'] = v),
          ),
          _fieldRow(
            _Field(label: 'Subtitle', initial: k['subtitle'], onChanged: (v) => k['subtitle'] = v),
            _Field(label: 'Badge text', initial: k['badge'], onChanged: (v) => k['badge'] = v),
          ),
          _Field(label: 'Popup detail text', initial: k['dialogBody'], maxLines: 3, onChanged: (v) => k['dialogBody'] = v),
        ],
      ),
    );
  }

  // ─── Services ──────────────────────────────────────────────────────────

  Widget _servicesSection() {
    final services = _sec('services');
    final items = _servicesItems;
    return _Section(
      title: 'Services',
      subtitle: 'The service cards grid on the homepage, and the full '
          'Services page each "Learn more" leads to.',
      child: Column(
        children: [
          _fieldRow(
            _Field(label: 'Eyebrow label', initial: services['eyebrow'], onChanged: (v) => services['eyebrow'] = v),
            _Field(label: 'Heading', initial: services['heading'], onChanged: (v) => services['heading'] = v),
          ),
          _Field(
            label: 'Services page banner subtitle',
            initial: services['bannerSubtitle'],
            maxLines: 2,
            onChanged: (v) => services['bannerSubtitle'] = v,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++)
            KeyedSubtree(
              key: _serviceKeys[i],
              child: _ItemCard(
                title: 'Service ${i + 1}',
                onRemove: items.length > 1 ? () => _removeItem(items, _serviceKeys, i) : null,
                child: Column(
                  children: [
                    _fieldRow(
                      _IconPicker(label: 'Icon', initial: items[i]['icon'] as String? ?? '', onChanged: (v) => items[i]['icon'] = v),
                      _Field(label: 'Title', initial: items[i]['title'], onChanged: (v) => items[i]['title'] = v),
                    ),
                    _Field(label: 'Card description', initial: items[i]['description'], maxLines: 2, onChanged: (v) => items[i]['description'] = v),
                    _Field(label: 'Full detail text (shown on the Services page)', initial: items[i]['detail'], maxLines: 3, onChanged: (v) => items[i]['detail'] = v),
                    _Field(
                      label: 'Card image URL (blank = default photo)',
                      initial: items[i]['imageUrl'],
                      hint: 'https://…',
                      onChanged: (v) => items[i]['imageUrl'] = v,
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(items, _serviceKeys, {
                'icon': 'local_shipping',
                'title': 'New Service',
                'description': '',
                'detail': '',
                'imageUrl': '',
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add service'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Why choose us ─────────────────────────────────────────────────────

  Widget _whySection() {
    final why = _sec('whyChooseUs');
    final items = _whyItems;
    return _Section(
      title: 'Why Choose Us',
      subtitle: 'The dark feature-highlights band.',
      child: Column(
        children: [
          _fieldRow(
            _Field(label: 'Eyebrow label', initial: why['eyebrow'], onChanged: (v) => why['eyebrow'] = v),
            _Field(label: 'Heading', initial: why['heading'], onChanged: (v) => why['heading'] = v),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++)
            KeyedSubtree(
              key: _whyKeys[i],
              child: _ItemCard(
                title: 'Feature ${i + 1}',
                onRemove: items.length > 1 ? () => _removeItem(items, _whyKeys, i) : null,
                child: Column(
                  children: [
                    _fieldRow(
                      _IconPicker(label: 'Icon', initial: items[i]['icon'] as String? ?? '', onChanged: (v) => items[i]['icon'] = v),
                      _Field(label: 'Title', initial: items[i]['title'], onChanged: (v) => items[i]['title'] = v),
                    ),
                    _Field(label: 'Description', initial: items[i]['description'], onChanged: (v) => items[i]['description'] = v),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(items, _whyKeys, {
                'icon': 'star',
                'title': 'New Feature',
                'description': '',
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add feature'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats ─────────────────────────────────────────────────────────────

  Widget _statsSection() {
    final items = _statsItems;
    return _Section(
      title: 'Stats bar',
      subtitle: 'The yellow strip of numbers.',
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            KeyedSubtree(
              key: _statKeys[i],
              child: _ItemCard(
                title: 'Stat ${i + 1}',
                onRemove: items.length > 1 ? () => _removeItem(items, _statKeys, i) : null,
                child: _fieldRow(
                  _Field(label: 'Number', initial: items[i]['value'], onChanged: (v) => items[i]['value'] = v),
                  _Field(label: 'Label', initial: items[i]['label'], onChanged: (v) => items[i]['label'] = v),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(items, _statKeys, {'value': '0', 'label': 'NEW STAT'}),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add stat'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CTA ───────────────────────────────────────────────────────────────

  Widget _ctaSection() {
    final cta = _sec('cta');
    return _Section(
      title: 'Sign-up call to action',
      subtitle: 'The "Ready to ship?" section with the courier/customer sign-up cards.',
      child: Column(
        children: [
          _fieldRow(
            _Field(label: 'Eyebrow', initial: cta['eyebrow'], onChanged: (v) => cta['eyebrow'] = v),
            _Field(label: 'Heading', initial: cta['heading'], onChanged: (v) => cta['heading'] = v),
          ),
          _Field(label: 'Subtext', initial: cta['subtitle'], onChanged: (v) => cta['subtitle'] = v),
          _fieldRow(
            _Field(label: 'Courier card title', initial: cta['courierCardTitle'], onChanged: (v) => cta['courierCardTitle'] = v),
            _Field(label: 'Courier card description', initial: cta['courierCardDesc'], onChanged: (v) => cta['courierCardDesc'] = v),
          ),
          _fieldRow(
            _Field(label: 'Customer card title', initial: cta['customerCardTitle'], onChanged: (v) => cta['customerCardTitle'] = v),
            _Field(label: 'Customer card description', initial: cta['customerCardDesc'], onChanged: (v) => cta['customerCardDesc'] = v),
          ),
          _Field(
            label: 'Photo URL (blank = default photo)',
            initial: cta['imageUrl'],
            hint: 'https://…',
            onChanged: (v) => cta['imageUrl'] = v,
          ),
        ],
      ),
    );
  }

  // ─── Footer / contact ──────────────────────────────────────────────────

  Widget _footerContactSection() {
    final footer = _sec('footer');
    final contact = _sec('contact');
    return _Section(
      title: 'Footer & contact info',
      subtitle: 'Also used by the dedicated "Contact Us" page from the top menu.',
      child: Column(
        children: [
          _fieldRow(
            _Field(label: 'Footer tagline', initial: footer['tagline'], onChanged: (v) => footer['tagline'] = v),
            _Field(label: 'Copyright name', initial: footer['copyrightName'], onChanged: (v) => footer['copyrightName'] = v),
          ),
          _fieldRow(
            _Field(label: 'Phone', initial: contact['phone'], onChanged: (v) => contact['phone'] = v),
            _Field(label: 'Email', initial: contact['email'], onChanged: (v) => contact['email'] = v),
          ),
          _Field(label: 'Address', initial: contact['address'], onChanged: (v) => contact['address'] = v),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Contact Us page banner',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          _fieldRow(
            _Field(label: 'Eyebrow', initial: contact['bannerEyebrow'], onChanged: (v) => contact['bannerEyebrow'] = v),
            _Field(label: 'Title', initial: contact['bannerTitle'], onChanged: (v) => contact['bannerTitle'] = v),
          ),
          _Field(
            label: 'Subtitle',
            initial: contact['bannerSubtitle'],
            maxLines: 2,
            onChanged: (v) => contact['bannerSubtitle'] = v,
          ),
        ],
      ),
    );
  }

  // ─── Social media ──────────────────────────────────────────────────────

  Widget _socialSection() {
    final items = _socialItems;
    return _Section(
      title: 'Social media',
      subtitle:
          'The icon row in the footer. Leave a link blank to show a "coming soon" message instead of opening it — add a link once the page is live.',
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            KeyedSubtree(
              key: _socialKeys[i],
              child: _ItemCard(
                title: 'Social link ${i + 1}',
                onRemove: () => _removeItem(items, _socialKeys, i),
                child: Column(
                  children: [
                    _fieldRow(
                      _IconPicker(label: 'Icon', initial: items[i]['icon'] as String? ?? '', onChanged: (v) => items[i]['icon'] = v),
                      _Field(label: 'Platform / handle', initial: items[i]['label'], hint: 'e.g. Instagram or @onevillageshipping', onChanged: (v) => items[i]['label'] = v),
                    ),
                    _Field(
                      label: 'Profile URL (blank = "coming soon" instead of a link)',
                      initial: items[i]['url'],
                      hint: 'https://…',
                      onChanged: (v) => items[i]['url'] = v,
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(items, _socialKeys, {
                'icon': 'language',
                'label': 'New Platform',
                'url': '',
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add social link'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── About / Rates pages ────────────────────────────────────────────────

  Widget _aboutRatesSection() {
    final about = _sec('about');
    final rates = _sec('rates');
    return _Section(
      title: 'About Us & Rates pages',
      subtitle: 'Shown on the dedicated "About Us" and "Rates" pages, reachable from the top menu.',
      child: Column(
        children: [
          _fieldRow(
            _Field(label: 'About Us banner eyebrow', initial: about['bannerEyebrow'], onChanged: (v) => about['bannerEyebrow'] = v),
            _Field(label: 'About Us banner title', initial: about['bannerTitle'], onChanged: (v) => about['bannerTitle'] = v),
          ),
          _Field(label: 'About Us page text', initial: about['body'], maxLines: 3, onChanged: (v) => about['body'] = v),
          const SizedBox(height: 8),
          _fieldRow(
            _Field(label: 'Rates banner eyebrow', initial: rates['bannerEyebrow'], onChanged: (v) => rates['bannerEyebrow'] = v),
            _Field(label: 'Rates banner title', initial: rates['bannerTitle'], onChanged: (v) => rates['bannerTitle'] = v),
          ),
          _Field(label: 'Rates page text', initial: rates['body'], maxLines: 3, onChanged: (v) => rates['body'] = v),
        ],
      ),
    );
  }

  Widget _fieldRow(Widget a, Widget b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String title;
  final VoidCallback? onRemove;
  final Widget child;
  const _ItemCard({required this.title, required this.onRemove, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? initial;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final String? hint;
  const _Field({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.maxLines = 1,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: initial ?? '',
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  const _IconPicker({required this.label, required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = LandingContent.iconKeys.contains(initial) ? initial : LandingContent.iconKeys.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: [
          for (final k in LandingContent.iconKeys)
            DropdownMenuItem(
              value: k,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LandingContent.icons[k], size: 16, color: AppTheme.textPrimary),
                  const SizedBox(width: 8),
                  Text(k.replaceAll('_', ' ')),
                ],
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
