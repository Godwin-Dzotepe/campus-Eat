import 'package:flutter/material.dart';
import '../services/write_log_service.dart';
import '../utils/extensions.dart';

class DebugLogsScreen extends StatelessWidget {
  const DebugLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Logs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => WriteLogService.clear(),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: StreamBuilder<List<WriteLogEntry>>(
        stream: WriteLogService.stream,
        initialData: WriteLogService.snapshot,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text('No write logs yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _LogTile(entry: logs[i]),
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final WriteLogEntry entry;

  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.success ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.success ? Icons.check_circle : Icons.error,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.action,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${entry.durationMs} ms',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.target,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              entry.timestamp.toDisplay(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            if (!entry.success && entry.error != null) ...[
              const SizedBox(height: 6),
              Text(
                entry.error!,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
