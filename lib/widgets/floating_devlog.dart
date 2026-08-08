import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dev_logger.dart';

/// Tombol log melayang di pojok kanan atas SEMUA layar.
/// Tap = buka bottom sheet live log (info/warning/error, bisa copy).
class FloatingDevLog extends StatelessWidget {
  const FloatingDevLog({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: (MediaQuery.of(context).padding.top) + 4,
      right: 6,
      child: GestureDetector(
        onTap: () => _openSheet(context),
        onLongPress: () => DevLogger.instance.clear(),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1),
          ),
          child: const Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _LogSheet(),
    );
  }
}

class _LogSheet extends StatefulWidget {
  const _LogSheet();

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            const Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Dev Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            // Auto-scroll toggle (always on)
            ValueListenableBuilder<int>(
              valueListenable: DevLogger.instance.update,
              builder: (_, count, __) {
                return Text('$count logs', style: const TextStyle(color: Colors.white38, fontSize: 12));
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: DevLogger.instance.copyText));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log disalin ✅')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              onPressed: () => DevLogger.instance.clear(),
            ),
          ]),
        ),
        const Divider(color: Colors.white12, height: 1),
        // Log list (live)
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: DevLogger.instance.update,
            builder: (_, __, ___) {
              final logs = DevLogger.instance.logs;
              if (logs.isEmpty) {
                return const Center(child: Text('Belum ada log', style: TextStyle(color: Colors.white38)));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final idx = logs.length - 1 - i;
                  final e = logs[idx];
                  Color color;
                  switch (e.level) {
                    case LogLevel.error: color = Colors.redAccent; break;
                    case LogLevel.warning: color = Colors.amberAccent; break;
                    case LogLevel.info: color = Colors.white70; break;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: RichText(
                      text: TextSpan(style: const TextStyle(fontSize: 10, fontFamily: 'monospace'), children: [
                        TextSpan(text: '${e.time.toIso8601String().substring(11, 19)} ', style: const TextStyle(color: Colors.white24)),
                        TextSpan(text: '${e.level.name.toUpperCase().padRight(5)} ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                        TextSpan(text: '[${e.tag}] ', style: const TextStyle(color: Colors.blueAccent)),
                        TextSpan(text: e.msg, style: TextStyle(color: color)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
