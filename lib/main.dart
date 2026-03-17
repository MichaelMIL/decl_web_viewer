import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:html' as html;

void main() {
  runApp(const DeclViewerApp());
}

class DeclViewerApp extends StatelessWidget {
  const DeclViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = const ColorScheme.dark(
      background: Color(0xFF050714),
      surface: Color(0xFF070A16),
      primary: Color(0xFF4F8CFF),
      secondary: Color(0xFF4F8CFF),
      error: Color(0xFFF97373),
    );

    return MaterialApp(
      title: 'DECL Viewer - ESP32 LED Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF050714),
        textTheme: Typography.whiteCupertino,
        fontFamily: 'SF Pro Text',
      ),
      home: const DeclViewerPage(),
    );
  }
}

class DeclViewerPage extends StatefulWidget {
  const DeclViewerPage({super.key});

  @override
  State<DeclViewerPage> createState() => _DeclViewerPageState();
}

class _DeclViewerPageState extends State<DeclViewerPage> {
  bool _loading = false;
  String _statusMessage = 'Waiting for data…';
  bool _statusError = false;

  String? _fileName;
  List<DeclComponent> _components = const [];
  List<DeclNet> _nets = const [];
  List<DeclInstance> _instances = const [];
  List<DeclConnection> _connections = const [];

  Future<void> _loadDecl() async {
    setState(() {
      _loading = true;
      _statusError = false;
      _statusMessage = 'Waiting for DECL file…';
    });

    try {
      final input = html.FileUploadInputElement()
        ..accept = '.decl'
        ..click();

      final completer = Completer<html.File?>();
      input.onChange.listen((event) {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          completer.complete(files.first);
        } else {
          completer.complete(null);
        }
      });

      final file = await completer.future;
      if (file == null) {
        setState(() {
          _loading = false;
          _statusMessage = 'File selection cancelled.';
        });
        return;
      }

      final reader = html.FileReader();
      final readCompleter = Completer<String>();
      reader.onLoadEnd.listen((_) {
        readCompleter.complete(reader.result as String? ?? '');
      });
      reader.onError.listen((error) {
        readCompleter.completeError(error ?? 'Failed to read file');
      });
      reader.readAsText(file);

      final text = await readCompleter.future;
      final parsed = parseDeclText(text);

      final componentsJson = parsed['components'] as List<dynamic>? ?? [];
      final schematicsJson = parsed['schematics'] as List<dynamic>? ?? [];
      final firstSch =
          (schematicsJson.isNotEmpty ? schematicsJson.first : null) as Map<String, dynamic>? ??
              {};

      final instancesJson = firstSch['instances'] as List<dynamic>? ?? [];
      final netsJson = firstSch['nets'] as List<dynamic>? ?? [];
      final connectionsJson = firstSch['connections'] as List<dynamic>? ?? [];

      setState(() {
        _components =
            componentsJson.map((e) => DeclComponent.fromJson(e as Map<String, dynamic>)).toList();
        _nets = netsJson.map((e) => DeclNet.fromJson(e as Map<String, dynamic>)).toList();
        _instances =
            instancesJson.map((e) => DeclInstance.fromJson(e as Map<String, dynamic>)).toList();
        _connections = connectionsJson
            .map((e) => DeclConnection.fromJson(e as Map<String, dynamic>))
            .toList();

        _fileName = file.name;
        _statusMessage = 'Loaded from file: $_fileName';
        _statusError = false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to load DECL file: $e';
        _statusError = true;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Wait for user to choose a DECL file via the browse button.
  }

  @override
  Widget build(BuildContext context) {
    final compCount = _components.length;
    final netCount = _nets.length;
    final headerSubtitle = _fileName ?? 'no file selected';
    final headerTitle = _fileName != null
        ? _fileName!.replaceAll('.decl', '')
        : 'DECL Viewer';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _HeaderBar(
                    title: headerTitle,
                    subtitle: headerSubtitle,
                    onReload: _loading ? null : _loadDecl,
                    loading: _loading,
                  ),
                  const SizedBox(height: 8),
                  _StatusBar(
                    message: _statusMessage,
                    isError: _statusError,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _GlassCard(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _Panel(
                                    title: 'Topology',
                                    pillText:
                                        '$compCount components · $netCount nets',
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _ListPanel(
                                            title: 'Components',
                                            children: _instances
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final idx = entry.key;
                                              final inst = entry.value;
                                              final comp = _components
                                                  .where((c) =>
                                                      c.name == inst.component)
                                                  .firstOrNull;
                                              final attrCount =
                                                  comp?.attributes.keys.length ??
                                                      0;
                                              final pinCount =
                                                  comp?.pins.length ?? 0;
                                              final meta =
                                                  '$pinCount pins · ${inst.component}${attrCount > 0 ? " · $attrCount attrs" : ""}';
                                              final pinTypes = {
                                                for (final p
                                                    in comp?.pins ??
                                                        <DeclPin>[])
                                                  p.type
                                              }.toList()
                                                ..sort();
                                              final showTypes =
                                                  pinTypes.take(2).toList();

                                              return _ListItem(
                                                main: idx == 0,
                                                title: inst.name,
                                                subtitle: meta,
                                                badges: showTypes
                                                    .map((t) =>
                                                        _PinTypeBadge(type: t))
                                                    .toList(),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ListPanel(
                                            title: 'Nets',
                                            children:
                                                _nets.map((net) {
                                              final connected = _connections
                                                  .where((c) =>
                                                      c.net == net.name)
                                                  .length;
                                              return _ListItem(
                                                title: net.name,
                                                subtitle:
                                                    '$connected connections',
                                                badges: const [
                                                  _SimpleBadge(
                                                    label: 'NET',
                                                    kind: BadgeKind.net,
                                                  )
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 13,
                                  child: _Panel(
                                    title: 'Schematic',
                                    pillText: 'Instances & nets',
                                    child: _CodePanel(
                                      header: 'Topology diagram',
                                      child: _TopologyDiagram(
                                        instances: _instances,
                                        nets: _nets,
                                        connections: _connections,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 720,
                            child: _GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _CardHeader(
                                    chipLabel: 'DECL Viewer',
                                    title: 'Schematic view',
                                    subtitle: 'instance pins & nets',
                                    showReload: false,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _Panel(
                                      title: 'Detailed schematic',
                                      pillText: 'Auto‑layout from DECL',
                                      child: _CodePanel(
                                        header: 'Instances with pin nets',
                                        child: _DetailedSchematic(
                                          components: _components,
                                          instances: _instances,
                                          connections: _connections,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onReload;
  final bool loading;

  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.onReload,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          const _TitleChip(label: 'DECL Schematic Viewer'),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.03,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subtitle.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade400,
                          letterSpacing: 1.6,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (onReload != null)
            FilledButton.icon(
              onPressed: loading ? null : onReload,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                loading ? 'Loading…' : 'Browse DECL file',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusBar({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFF97373) : const Color(0xFF4ADE80);
    final glow = isError
        ? const Color(0xFFF87171).withOpacity(0.35)
        : const Color(0xFF4ADE80).withOpacity(0.35);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glow,
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isError ? color : Colors.grey.shade400,
                ),
          ),
        )
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF111628), Color(0xFF070A16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.16)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.9),
            offset: Offset(0, 28),
            blurRadius: 80,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _TitleChip extends StatelessWidget {
  final String label;

  const _TitleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.2,
          colors: [Color(0xFF1D253E), Color(0xFF050714)],
        ),
        border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.16),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade300,
                ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String pillText;
  final Widget child;

  const _Panel({
    required this.title,
    required this.pillText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF171C30), Color(0xFF050814)],
        ),
        border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade400,
                        letterSpacing: 1.4,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF0F172A).withOpacity(0.85),
                    border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F8CFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pillText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey.shade300,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ListPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ListPanel({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.22)),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [Color(0xFF171D33), Color(0xFF050814)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade400,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: children[index],
            ),
          )
        ],
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  final bool main;
  final String title;
  final String subtitle;
  final List<Widget> badges;

  const _ListItem({
    this.main = false,
    required this.title,
    required this.subtitle,
    this.badges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = main
        ? const Color(0xFF4ADE80).withOpacity(0.6)
        : const Color(0xFF94A3B8).withOpacity(0.24);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0F172A).withOpacity(0.9),
        border: Border.all(color: borderColor),
        boxShadow: main
            ? [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withOpacity(0.3),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: badges,
            ),
          ],
        ],
      ),
    );
  }
}

enum BadgeKind { normal, net, io, power, passive, analog }

class _SimpleBadge extends StatelessWidget {
  final String label;
  final BadgeKind kind;

  const _SimpleBadge({required this.label, this.kind = BadgeKind.normal});

  @override
  Widget build(BuildContext context) {
    Color border;
    Color text;
    Color bg;

    switch (kind) {
      case BadgeKind.net:
        border = const Color(0xFF38BDF8).withOpacity(0.6);
        text = const Color(0xFF7DD3FC);
        bg = const Color(0xFF0F172A).withOpacity(0.9);
        break;
      case BadgeKind.io:
        border = const Color(0xFF818CF8).withOpacity(0.8);
        text = const Color(0xFFA5B4FC);
        bg = const Color(0xFF0F172A).withOpacity(0.85);
        break;
      case BadgeKind.power:
        border = const Color(0xFF34D399).withOpacity(0.8);
        text = const Color(0xFF6EE7B7);
        bg = const Color(0xFF0F172A).withOpacity(0.85);
        break;
      case BadgeKind.passive:
        border = const Color(0xFFF97316).withOpacity(0.8);
        text = const Color(0xFFFED7AA);
        bg = const Color(0xFF0F172A).withOpacity(0.85);
        break;
      case BadgeKind.analog:
        border = const Color(0xFFF43F5E).withOpacity(0.8);
        text = const Color(0xFFFECACA);
        bg = const Color(0xFF0F172A).withOpacity(0.85);
        break;
      case BadgeKind.normal:
      default:
        border = const Color(0xFF94A3B8).withOpacity(0.35);
        text = Colors.grey.shade300;
        bg = const Color(0xFF0F172A).withOpacity(0.85);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        color: bg,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: text,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _PinTypeBadge extends StatelessWidget {
  final String type;

  const _PinTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    BadgeKind kind;
    switch (type) {
      case 'PowerInput':
        kind = BadgeKind.power;
        break;
      case 'Analog':
        kind = BadgeKind.analog;
        break;
      case 'Passive':
        kind = BadgeKind.passive;
        break;
      case 'Bidirectional':
      case 'Input':
      case 'Output':
        kind = BadgeKind.io;
        break;
      default:
        kind = BadgeKind.normal;
        break;
    }
    return _SimpleBadge(label: type, kind: kind);
  }
}

class _CodePanel extends StatelessWidget {
  final String header;
  final Widget child;

  const _CodePanel({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF0B1020), Color(0xFF020412)],
        ),
        border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF020412)),
              ),
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.1,
                colors: [Color(0xFF050816), Color(0xFF020412)],
              ),
            ),
            child: Row(
              children: [
                Text(
                  header,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _TopologyDiagram extends StatelessWidget {
  final List<DeclInstance> instances;
  final List<DeclNet> nets;
  final List<DeclConnection> connections;

  const _TopologyDiagram({
    required this.instances,
    required this.nets,
    required this.connections,
  });

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty && nets.isEmpty) {
      return const Center(child: Text('No topology to display'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 260.0;
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _TopologyPainter(
              instances: instances,
              nets: nets,
              connections: connections,
            ),
          ),
        );
      },
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final List<DeclInstance> instances;
  final List<DeclNet> nets;
  final List<DeclConnection> connections;

  _TopologyPainter({
    required this.instances,
    required this.nets,
    required this.connections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    const height = 260.0;
    const marginX = 70.0;
    const topMargin = 30.0;
    const bottomMargin = 40.0;
    final usableHeight = height - topMargin - bottomMargin;

    final bgPaint = Paint()
      ..color = const Color.fromRGBO(15, 23, 42, 0.95)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color.fromRGBO(148, 163, 184, 0.5)
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);

    final instancePositions = <String, Offset>{};
    for (var i = 0; i < instances.length; i++) {
      final y = topMargin +
          (usableHeight / (instances.length > 1 ? (instances.length - 1) : 1)) * i;
      instancePositions[instances[i].name] = Offset(marginX, y);
    }

    final netPositions = <String, Offset>{};
    for (var i = 0; i < nets.length; i++) {
      final y =
          topMargin + (usableHeight / (nets.length > 1 ? (nets.length - 1) : 1)) * i;
      netPositions[nets[i].name] = Offset(width - marginX, y);
    }

    final instanceRectPaint = Paint()
      ..color = const Color.fromRGBO(37, 99, 235, 0.75)
      ..style = PaintingStyle.fill;
    final instanceBorderPaint = Paint()
      ..color = const Color.fromRGBO(129, 140, 248, 0.9)
      ..style = PaintingStyle.stroke;

    const instanceWidth = 120.0;
    const instanceHeight = 30.0;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    instancePositions.forEach((name, pos) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pos,
          width: instanceWidth,
          height: instanceHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(r, instanceRectPaint);
      canvas.drawRRect(r, instanceBorderPaint);

      textPainter.text = TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontSize: 11,
          fontFamily: 'SF Pro Text',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    });

    final netCirclePaint = Paint()
      ..color = const Color.fromRGBO(22, 163, 74, 0.85)
      ..style = PaintingStyle.fill;
    final netCircleBorder = Paint()
      ..color = const Color.fromRGBO(74, 222, 128, 0.95)
      ..style = PaintingStyle.stroke;

    const netRadius = 10.0;
    netPositions.forEach((name, pos) {
      canvas.drawCircle(pos, netRadius, netCirclePaint);
      canvas.drawCircle(pos, netRadius, netCircleBorder);

      textPainter.text = const TextSpan(
        text: '',
      );
      textPainter.text = TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFFBBF7D0),
          fontSize: 10,
          fontFamily: 'SF Pro Text',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx + netRadius + 6, pos.dy - textPainter.height / 2),
      );
    });

    final palette = <Color>[
      const Color(0xFF4F46E5),
      const Color(0xFF22C55E),
      const Color(0xFFEAB308),
      const Color(0xFFFB7185),
      const Color(0xFF0EA5E9),
      const Color(0xFFA855F7),
      const Color(0xFFF97316),
    ];
    final netColors = <String, Color>{};
    for (var i = 0; i < nets.length; i++) {
      netColors[nets[i].name] = palette[i % palette.length];
    }

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (final conn in connections) {
      final parts = conn.endpoint.split('.');
      if (parts.length != 2) continue;
      final instName = parts[0];
      final instPos = instancePositions[instName];
      final netPos = netPositions[conn.net];
      if (instPos == null || netPos == null) continue;

      final start = Offset(instPos.dx + instanceWidth / 2, instPos.dy);
      final end = Offset(netPos.dx - 14, netPos.dy);
      final midX = (start.dx + end.dx) / 2;

      final color = netColors[conn.net] ?? const Color.fromRGBO(148, 163, 184, 0.85);
      pathPaint.color = color;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          midX,
          start.dy,
          midX,
          end.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, pathPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) {
    return oldDelegate.instances != instances ||
        oldDelegate.nets != nets ||
        oldDelegate.connections != connections;
  }
}

class _DetailedSchematic extends StatefulWidget {
  final List<DeclComponent> components;
  final List<DeclInstance> instances;
  final List<DeclConnection> connections;

  const _DetailedSchematic({
    required this.components,
    required this.instances,
    required this.connections,
  });

  @override
  State<_DetailedSchematic> createState() => _DetailedSchematicState();
}

class _DetailedSchematicState extends State<_DetailedSchematic> {
  final Map<String, Offset> _overrides = {};
  String? _draggingName;
  Offset? _dragDelta;

  Map<String, _InstanceLayout> _computeLayout(
    Size size,
    Map<String, DeclComponent> componentsByName,
  ) {
    final width = size.width;
    const marginX = 180.0;
    const topMargin = 50.0;
    const bottomMargin = 80.0;
    const gapBetweenInstances = 40.0;

    final instanceLayout = <String, _InstanceLayout>{};
    var leftY = topMargin;
    var rightY = topMargin;

    for (var i = 0; i < widget.instances.length; i++) {
      final inst = widget.instances[i];
      final comp = componentsByName[inst.component];
      final pins = comp?.pins ?? <DeclPin>[];
      const w = 150.0;
      final h = math.max(46.0, 20.0 + pins.length * 12.0);

      final isRoot = i == 0;
      double x;
      double y;
      String side;

      if (isRoot) {
        x = marginX;
        y = leftY + h / 2;
        leftY += h + gapBetweenInstances;
        side = 'right';
      } else {
        final localIndex = i - 1;
        const cols = 3;
        final col = localIndex % cols;
        final row = (localIndex / cols).floor();
        const colSpacing = 260.0;
        const rowSpacing = 140.0;

        x = marginX + 260.0 + col * colSpacing;
        y = topMargin + row * rowSpacing + h / 2;
        rightY = (rightY > y + h / 2 + gapBetweenInstances)
            ? rightY
            : y + h / 2 + gapBetweenInstances;
        side = 'left';
      }

      final override = _overrides[inst.name];
      if (override != null) {
        x = override.dx.clamp(40.0, width - 40.0);
        y = override.dy.clamp(40.0, size.height - bottomMargin);
      }

      instanceLayout[inst.name] = _InstanceLayout(
        x: x,
        y: y,
        w: w,
        h: h,
        pins: pins,
        side: side,
      );
    }

    return instanceLayout;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.instances.isEmpty) {
      return const Center(child: Text('No schematic to display'));
    }

    final compByName = {
      for (final c in widget.components) c.name: c,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        const canvasHeight = 560.0;
        final size = Size(constraints.maxWidth, canvasHeight);
        final layout = _computeLayout(size, compByName);

        String? hitTest(Offset pos) {
          for (final entry in layout.entries) {
            final l = entry.value;
            final rect = Rect.fromCenter(
              center: Offset(l.x, l.y),
              width: l.w,
              height: l.h,
            );
            if (rect.contains(pos)) {
              return entry.key;
            }
          }
          return null;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final name = hitTest(details.localPosition);
            if (name != null) {
              final l = layout[name]!;
              _draggingName = name;
              _dragDelta = details.localPosition - Offset(l.x, l.y);
            }
          },
          onPanUpdate: (details) {
            if (_draggingName == null || _dragDelta == null) return;
            final newCenter = details.localPosition - _dragDelta!;
            setState(() {
              _overrides[_draggingName!] = newCenter;
            });
          },
          onPanEnd: (_) {
            _draggingName = null;
            _dragDelta = null;
          },
          onPanCancel: () {
            _draggingName = null;
            _dragDelta = null;
          },
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CustomPaint(
              painter: _DetailedSchematicPainter(
                componentsByName: compByName,
                instances: widget.instances,
                connections: widget.connections,
                overrides: _overrides,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailedSchematicPainter extends CustomPainter {
  final Map<String, DeclComponent> componentsByName;
  final List<DeclInstance> instances;
  final List<DeclConnection> connections;
  final Map<String, Offset> overrides;

  _DetailedSchematicPainter({
    required this.componentsByName,
    required this.instances,
    required this.connections,
    required this.overrides,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const marginX = 180.0;
    const topMargin = 50.0;
    const bottomMargin = 80.0;
    const gapBetweenInstances = 40.0;

    final bgPaint = Paint()
      ..color = const Color.fromRGBO(15, 23, 42, 0.96)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color.fromRGBO(148, 163, 184, 0.5)
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);

    if (instances.isEmpty) return;

    final instanceLayout = <String, _InstanceLayout>{};
    var leftY = topMargin;
    var rightY = topMargin;

    for (var i = 0; i < instances.length; i++) {
      final inst = instances[i];
      final comp = componentsByName[inst.component];
      final pins = comp?.pins ?? <DeclPin>[];
      const w = 150.0;
      final h = math.max(46.0, 20.0 + pins.length * 12.0);

      final isRoot = i == 0;
      double x;
      double y;
      String side;

      if (isRoot) {
        x = marginX;
        y = leftY + h / 2;
        leftY += h + gapBetweenInstances;
        side = 'right';
      } else {
        final localIndex = i - 1;
        const cols = 3;
        final col = localIndex % cols;
        final row = (localIndex / cols).floor();
        const colSpacing = 260.0;
        const rowSpacing = 140.0;

        x = marginX + 260.0 + col * colSpacing;
        y = topMargin + row * rowSpacing + h / 2;
        rightY = (rightY > y + h / 2 + gapBetweenInstances)
            ? rightY
            : y + h / 2 + gapBetweenInstances;
        side = 'left';
      }

      final override = overrides[inst.name];
      if (override != null) {
        x = override.dx.clamp(40.0, width - 40.0);
        y = override.dy.clamp(40.0, size.height - bottomMargin);
      }

      instanceLayout[inst.name] = _InstanceLayout(
        x: x,
        y: y,
        w: w,
        h: h,
        pins: pins,
        side: side,
      );
    }

    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final l in instanceLayout.values) {
      final top = l.y - l.h / 2;
      final bottom = l.y + l.h / 2;
      if (top < minY) minY = top;
      if (bottom > maxY) maxY = bottom;
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = topMargin;
      maxY = (leftY > rightY) ? leftY : rightY;
    }

    final instancesBg = Paint()
      ..color = const Color.fromRGBO(15, 23, 42, 0.95)
      ..style = PaintingStyle.fill;
    final instancesBorder = Paint()
      ..color = const Color.fromRGBO(148, 163, 184, 0.9)
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    instanceLayout.forEach((name, layout) {
      final inst =
          instances.firstWhere((i) => i.name == name, orElse: () => instances.first);
      final comp = componentsByName[inst.component];
      final attrs = inst.attributes;
      String valueText = '';
      if (inst.component == 'Resistor') {
        valueText = attrs['resistance']?.toString() ??
            (comp?.attributes['resistance']?.value?.toString() ?? '');
      } else if (inst.component == 'Capacitor') {
        valueText = attrs['capacitance']?.toString() ??
            (comp?.attributes['capacitance']?.value?.toString() ?? '');
      } else if (inst.component == 'LED') {
        valueText =
            attrs['color']?.toString() ?? (comp?.attributes['color']?.value?.toString() ?? '');
      }

      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(layout.x, layout.y),
          width: layout.w,
          height: layout.h,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(r, instancesBg);
      canvas.drawRRect(r, instancesBorder);

      textPainter.text = TextSpan(
        text: '${inst.name} : ${inst.component}',
        style: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontSize: 11,
          fontFamily: 'SF Pro Text',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          layout.x - textPainter.width / 2,
          layout.y - layout.h / 2 + 4,
        ),
      );

      if (valueText.isNotEmpty) {
        textPainter.text = TextSpan(
          text: valueText,
          style: const TextStyle(
            color: Color(0xFFA5B4FC),
            fontSize: 10,
            fontFamily: 'SF Pro Text',
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            layout.x - textPainter.width / 2,
            layout.y - layout.h / 2 + 18,
          ),
        );
      }

      for (var i = 0; i < layout.pins.length; i++) {
        final pin = layout.pins[i];
        final pinY = layout.y - layout.h / 2 + 24 + i * 12;
        final pinEdgeX = layout.side == 'right'
            ? layout.x + layout.w / 2
            : layout.x - layout.w / 2;
        final dotX = layout.side == 'right' ? pinEdgeX + 6 : pinEdgeX - 6;

        canvas.drawCircle(
          Offset(dotX, pinY),
          3,
          Paint()
            ..color = const Color.fromRGBO(148, 163, 184, 0.9)
            ..style = PaintingStyle.fill,
        );

        textPainter.text = TextSpan(
          text: pin.name,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 10,
            fontFamily: 'SF Pro Text',
          ),
        );
        textPainter.layout();
        final textX = layout.side == 'right'
            ? pinEdgeX - 4 - textPainter.width
            : pinEdgeX + 4;
        textPainter.paint(
          canvas,
          Offset(textX, pinY - textPainter.height / 2),
        );
      }
    });

    final netToPins = <String, List<_NetPinRef>>{};
    for (final conn in connections) {
      final parts = conn.endpoint.split('.');
      if (parts.length != 2) continue;
      final instName = parts[0];
      final pinName = parts[1];
      final layout = instanceLayout[instName];
      if (layout == null) continue;
      final pins = layout.pins;
      final idx = pins.indexWhere((p) => p.name == pinName);
      if (idx == -1) continue;

      final pinY = layout.y - layout.h / 2 + 24 + idx * 12;
      final pinEdgeX =
          layout.side == 'right' ? layout.x + layout.w / 2 : layout.x - layout.w / 2;
      final isLeft = layout.side == 'left';
      final outerX = isLeft ? pinEdgeX - 40 : pinEdgeX + 40;

      (netToPins[conn.net] ??= []).add(
        _NetPinRef(
          x: pinEdgeX,
          y: pinY,
          outerX: outerX,
          isLeft: isLeft,
        ),
      );
    }

    final netPalette = <Color>[
      const Color(0xFF4F46E5),
      const Color(0xFF22C55E),
      const Color(0xFFEAB308),
      const Color(0xFFFB7185),
      const Color(0xFF0EA5E9),
      const Color(0xFFA855F7),
      const Color(0xFFF97316),
    ];

    var netIndex = 0;
    netToPins.forEach((netName, pins) {
      if (pins.isEmpty) return;

      final color = netPalette[netIndex % netPalette.length];
      netIndex++;

      if (netName == 'NET_GND') {
        for (final p in pins) {
          final size = 10.0;

          // Direction from the pin into the GND symbol:
          // - For right-side pins, draw symbol to the right.
          // - For left-side pins, draw symbol to the left.
          final dir = p.isLeft ? const Offset(-1, 0) : const Offset(1, 0);
          final perp = const Offset(0, 1); // bars are perpendicular to dir

          final leadLen = 6.0;
          final barSpacing = 3.0;

          final start = Offset(p.x, p.y);
          final mid = start + dir * leadLen;

          final paint = Paint()
            ..color = color
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          // Lead from pin into symbol.
          canvas.drawLine(start, mid, paint);

          // Three bars, widest closest to the pin.
          final topCenter = mid + perp * 0;
          final midCenter = mid + perp * barSpacing;
          final bottomCenter = mid + perp * (2 * barSpacing);

          void drawBar(Offset center, double fullWidth) {
            final half = fullWidth / 2;
            final p1 = center + dir * -half;
            final p2 = center + dir * half;
            canvas.drawLine(p1, p2, paint);
          }

          drawBar(topCenter, size);
          drawBar(midCenter, size * 2 / 3);
          drawBar(bottomCenter, size / 3);
        }
        return;
      }

      final avgY =
          pins.map((p) => p.y).reduce((a, b) => a + b) / pins.length.toDouble();
      final offset = (netIndex % 5) * 6 - 12;
      final busY = avgY + offset;

      final adjustedPins = <_NetPinRef>[];
      for (var i = 0; i < pins.length; i++) {
        final p = pins[i];
        const spread = 8.0;
        final o = (i - (pins.length - 1) / 2) * spread;
        final adjustedOuterX = p.outerX + (p.isLeft ? -o : o);
        adjustedPins.add(
          _NetPinRef(
            x: p.x,
            y: p.y,
            outerX: adjustedOuterX,
            isLeft: p.isLeft,
          ),
        );
      }

      final minOuterX = adjustedPins
          .map((p) => p.outerX)
          .reduce((a, b) => a < b ? a : b);
      final maxOuterX = adjustedPins
          .map((p) => p.outerX)
          .reduce((a, b) => a > b ? a : b);

      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final p in adjustedPins) {
        final path = Path()
          ..moveTo(p.x, p.y)
          ..lineTo(p.outerX, p.y)
          ..lineTo(p.outerX, busY);
        canvas.drawPath(path, paint);
      }

      canvas.drawLine(
        Offset(minOuterX, busY),
        Offset(maxOuterX, busY),
        paint,
      );

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: netName,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontFamily: 'SF Pro Text',
          ),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(maxOuterX + 6, busY - 4),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _DetailedSchematicPainter oldDelegate) {
    return oldDelegate.instances != instances ||
        oldDelegate.connections != connections ||
        oldDelegate.componentsByName != componentsByName ||
        oldDelegate.overrides != overrides;
  }
}

class _InstanceLayout {
  final double x;
  final double y;
  final double w;
  final double h;
  final List<DeclPin> pins;
  final String side;

  _InstanceLayout({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.pins,
    required this.side,
  });
}

Map<String, dynamic> parseDeclText(String text) {
  final lines = const LineSplitter().convert(text);

  final components = <Map<String, dynamic>>[];
  final schematics = <Map<String, dynamic>>[];

  Map<String, dynamic>? currentComponent;
  Map<String, dynamic>? currentSchematic;
  var inPinsBlock = false;
  var inAttributesBlock = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final compMatch = RegExp(r'^component\s+(\w+)\s*\{').firstMatch(line);
    if (compMatch != null) {
      currentComponent = {
        'name': compMatch.group(1) ?? '',
        'pins': <Map<String, dynamic>>[],
        'attributes': <String, dynamic>{},
      };
      components.add(currentComponent);
      inPinsBlock = false;
      inAttributesBlock = false;
      continue;
    }

    if (line == 'pins {') {
      inPinsBlock = true;
      inAttributesBlock = false;
      continue;
    }

    if (line == 'attributes {') {
      inPinsBlock = false;
      inAttributesBlock = true;
      continue;
    }

    if (line == '}' || line == '};') {
      if (currentSchematic != null && line == '}') {
        currentSchematic = null;
      } else if (currentComponent != null && line == '}') {
        currentComponent = null;
      }
      inPinsBlock = false;
      inAttributesBlock = false;
      continue;
    }

    if (currentComponent != null) {
      if (inPinsBlock) {
        final pinMatch = RegExp(r'^(.+?):\s*(\w+)\s+as\s+(\w+)').firstMatch(line);
        if (pinMatch != null) {
          (currentComponent['pins'] as List<Map<String, dynamic>>).add({
            'id': (pinMatch.group(1) ?? '').trim(),
            'type': (pinMatch.group(2) ?? '').trim(),
            'name': (pinMatch.group(3) ?? '').trim(),
          });
        }
        continue;
      }

      if (inAttributesBlock) {
        final attrMatch =
            RegExp(r'^(\w+):\s*([\w]+)\s*=\s*(.+)$').firstMatch(line);
        if (attrMatch != null) {
          final key = attrMatch.group(1) ?? '';
          final valueType = attrMatch.group(2) ?? '';
          var value = attrMatch.group(3) ?? '';
          value = value.replaceAll(RegExp(r';$'), '').trim();
          (currentComponent['attributes'] as Map<String, dynamic>)[key] = {
            'type': valueType,
            'value': value,
          };
        }
        continue;
      }
    }

    final schMatch = RegExp(r'^schematic\s+(\w+)\s*\{').firstMatch(line);
    if (schMatch != null) {
      currentSchematic = {
        'name': schMatch.group(1) ?? '',
        'instances': <Map<String, dynamic>>[],
        'nets': <Map<String, dynamic>>[],
        'connections': <Map<String, dynamic>>[],
      };
      schematics.add(currentSchematic);
      continue;
    }

    if (currentSchematic != null) {
      final instMatch =
          RegExp(r'^instance\s+(\w+):\s*(\w+)(\s*\{.*\})?').firstMatch(line);
      if (instMatch != null) {
        final instance = <String, dynamic>{
          'name': instMatch.group(1) ?? '',
          'component': instMatch.group(2) ?? '',
          'raw': line,
          'attributes': <String, dynamic>{},
        };

        final overridesRaw = instMatch.group(3);
        if (overridesRaw != null) {
          final inner = overridesRaw
              .replaceAll(RegExp(r'^\s*\{\s*'), '')
              .replaceAll(RegExp(r'\s*\}\s*$'), '');
          for (final part in inner.split(',')) {
            final trimmed = part.trim();
            if (trimmed.isEmpty) continue;
            final ovMatch =
                RegExp(r'^(\w+)\s*=\s*(.+)$').firstMatch(trimmed);
            if (ovMatch != null) {
              final key = ovMatch.group(1)!;
              var value = ovMatch.group(2) ?? '';
              value = value.replaceAll(RegExp(r';$'), '').trim();
              (instance['attributes'] as Map<String, dynamic>)[key] = value;
            }
          }
        }

        (currentSchematic['instances'] as List<Map<String, dynamic>>)
            .add(instance);
        continue;
      }

      final netMatch = RegExp(r'^net\s+(\w+)').firstMatch(line);
      if (netMatch != null) {
        (currentSchematic['nets'] as List<Map<String, dynamic>>).add({
          'name': netMatch.group(1) ?? '',
        });
        continue;
      }

      final connMatch =
          RegExp(r'^connect\s+([\w\.]+)\s*--\s*net\s+(\w+)').firstMatch(line);
      if (connMatch != null) {
        (currentSchematic['connections'] as List<Map<String, dynamic>>).add({
          'endpoint': connMatch.group(1) ?? '',
          'net': connMatch.group(2) ?? '',
        });
        continue;
      }
    }
  }

  return {
    'components': components,
    'schematics': schematics,
  };
}

class _NetPinRef {
  final double x;
  final double y;
  final double outerX;
  final bool isLeft;

  _NetPinRef({
    required this.x,
    required this.y,
    required this.outerX,
    required this.isLeft,
  });
}

class _CardHeader extends StatelessWidget {
  final String chipLabel;
  final String title;
  final String subtitle;
  final bool showReload;

  const _CardHeader({
    required this.chipLabel,
    required this.title,
    required this.subtitle,
    this.showReload = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TitleChip(label: chipLabel),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.03,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  subtitle.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade400,
                        letterSpacing: 1.6,
                      ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        if (showReload)
          FilledButton.icon(
            onPressed: () {},
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text(
              'Reload from file',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class DeclComponent {
  final String name;
  final List<DeclPin> pins;
  final Map<String, DeclAttribute> attributes;

  DeclComponent({
    required this.name,
    required this.pins,
    required this.attributes,
  });

  factory DeclComponent.fromJson(Map<String, dynamic> json) {
    final pinsJson = json['pins'] as List<dynamic>? ?? [];
    final attrsJson = json['attributes'] as Map<String, dynamic>? ?? {};
    return DeclComponent(
      name: json['name'] as String? ?? '',
      pins: pinsJson.map((e) => DeclPin.fromJson(e as Map<String, dynamic>)).toList(),
      attributes: attrsJson.map(
        (key, value) => MapEntry(key, DeclAttribute.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }
}

class DeclPin {
  final String name;
  final String type;

  DeclPin({
    required this.name,
    required this.type,
  });

  factory DeclPin.fromJson(Map<String, dynamic> json) {
    return DeclPin(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}

class DeclAttribute {
  final dynamic value;

  DeclAttribute({this.value});

  factory DeclAttribute.fromJson(Map<String, dynamic> json) {
    return DeclAttribute(value: json['value']);
  }
}

class DeclNet {
  final String name;

  DeclNet({required this.name});

  factory DeclNet.fromJson(Map<String, dynamic> json) {
    return DeclNet(name: json['name'] as String? ?? '');
  }
}

class DeclInstance {
  final String name;
  final String component;
  final Map<String, dynamic> attributes;

  DeclInstance({
    required this.name,
    required this.component,
    required this.attributes,
  });

  factory DeclInstance.fromJson(Map<String, dynamic> json) {
    return DeclInstance(
      name: json['name'] as String? ?? '',
      component: json['component'] as String? ?? '',
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }
}

class DeclConnection {
  final String endpoint;
  final String net;

  DeclConnection({
    required this.endpoint,
    required this.net,
  });

  factory DeclConnection.fromJson(Map<String, dynamic> json) {
    return DeclConnection(
      endpoint: json['endpoint'] as String? ?? '',
      net: json['net'] as String? ?? '',
    );
  }
}
