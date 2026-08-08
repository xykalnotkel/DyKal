import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dev_logger.dart';

/// Tombol log melayang di pojok kanan atas SEMUA layar.
/// Tap = buka Dialog live log (info/warning/error, bisa copy & select).
class FloatingDevLog extends StatelessWidget {
  const FloatingDevLog({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: (MediaQuery.of(context).padding.top) + 4,
      right: 6,
      child: GestureDetector(
        onTap: () => _openLog(context),
        onLongPress: () => DevLogger.instance.clear(),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1),
          ),
          child: const Icon(Icons.terminal, color: Colors.greenAccent, size: 18),
        ),
      ),
    );
  }

  void _openLog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(children: [
              const Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              const Text('Dev Log (Live)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          // Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              ValueListenableBuilder<int>(
                valueListenable: DevLogger.instance.update,
                builder: (_, c, __) => Text('$c entries', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 18),
                tooltip: 'Copy all',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: DevLogger.instance.copyText));
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Log disalin'), duration: Duration(seconds: 1)));
                },
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => DevLogger.instance.clear()),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Log list
          SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: ValueListenableBuilder<int>(
              valueListenable: DevLogger.instance.update,
              builder: (_, __, ___) {
                final logs = DevLogger.instance.logs;
                if (logs.isEmpty) return const Center(child: Text('Belum ada log', style: TextStyle(color: Colors.white38)));
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final e = logs[logs.length - 1 - i];
                    Color color;
                    switch (e.level) {
                      case LogLevel.error: color = Colors.redAccent; break;
                      case LogLevel.warning: color = Colors.amberAccent; break;
                      case LogLevel.info: color = Colors.white70; break;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText(
                        '${e.time.toIso8601String().substring(11, 19)} ${e.level.name.toUpperCase().padRight(5)} [${e.tag}] ${e.msg}',
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: color),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
