import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/champ.dart';

Future<Champ?> showChampFormSheet(BuildContext context, List<LatLng> polygon) {
  return showModalBottomSheet<Champ>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ChampForm(polygon: polygon),
  );
}

class _ChampForm extends StatefulWidget {
  final List<LatLng> polygon;

  const _ChampForm({required this.polygon});

  @override
  State<_ChampForm> createState() => _ChampFormState();
}

class _ChampFormState extends State<_ChampForm> {
  CropType _crop = CropType.mais;
  DateTime _harvestDate = DateTime.now();
  final _hauteurController = TextEditingController(text: '30');
  bool _hasBordures = false;

  @override
  void dispose() {
    _hauteurController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _harvestDate = picked);
  }

  void _save() {
    final hauteur = double.tryParse(_hauteurController.text) ?? 0;
    final champ = Champ(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      polygon: widget.polygon,
      crop: _crop,
      harvestDate: _harvestDate,
      hauteurCm: hauteur,
      hasBordures: _hasBordures,
    );
    Navigator.of(context).pop(champ);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouveau champ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<CropType>(
              value: _crop,
              decoration: const InputDecoration(labelText: 'Type de culture'),
              items: CropType.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _crop = v ?? _crop),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date de récolte prévue/passée'),
              subtitle: Text(
                '${_harvestDate.year}-${_harvestDate.month.toString().padLeft(2, '0')}-${_harvestDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hauteurController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hauteur actuelle (cm)'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Présence de bordures / haies'),
              value: _hasBordures,
              onChanged: (v) => setState(() => _hasBordures = v),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Enregistrer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
