import 'package:flutter/material.dart';

import '../models/track.dart';

class TracksPage extends StatelessWidget {
  final bool recording;
  final int recordingPointCount;
  final List<Track> tracks;
  final VoidCallback onToggleRecording;
  final ValueChanged<Track> onRename;
  final ValueChanged<Track> onDelete;

  const TracksPage({
    super.key,
    required this.recording,
    required this.recordingPointCount,
    required this.tracks,
    required this.onToggleRecording,
    required this.onRename,
    required this.onDelete,
  });

  Future<void> _rename(BuildContext context, Track track) async {
    final ctrl = TextEditingController(text: track.nom);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      onRename(Track(id: track.id, nom: newName, date: track.date, points: track.points));
    }
  }

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracés')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: onToggleRecording,
              style: FilledButton.styleFrom(
                backgroundColor: recording ? Colors.red : null,
              ),
              icon: Icon(recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record),
              label: Text(
                recording
                    ? 'Arrêter l\'enregistrement ($recordingPointCount points)'
                    : 'Registre — démarrer l\'enregistrement',
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tracks.isEmpty
                ? const Center(child: Text('Aucun tracé sauvegardé'))
                : ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return ListTile(
                        leading: const Icon(Icons.route_outlined),
                        title: Text(track.nom),
                        subtitle: Text('${_dateLabel(track.date)} · ${track.distanceLabel}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _rename(context, track),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDelete(track),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
