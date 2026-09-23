import 'package:flutter/material.dart';

import '../models/observation.dart';
import '../models/score_level.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Carte d\'habitat', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Chaque zone forestière est colorée selon la qualité d\'habitat pour le '
            'chevreuil, calculée à partir des données écoforestières du MFFP et '
            'ajustée selon la saison choisie (pré-rut, rut, post-rut).',
          ),
          const SizedBox(height: 12),
          for (final level in ScoreLevel.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 16, height: 16, color: level.color),
                  const SizedBox(width: 10),
                  Text(level.label),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Étoile : peuplement avec chêne rouge ou hêtre à grandes feuilles — '
                  'glands et faînes, la nourriture de prédilection du chevreuil à l\'automne.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Couches de carte', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Le bouton en forme de calque (en bas à droite) permet de changer le '
            'fond de carte (OSM, satellite ESRI/Sentinel/MRNF QC, topographique), '
            'd\'ajuster la transparence de chaque couche, d\'afficher les lots à '
            'bois (terres privées) et les codes forestiers (essence/âge).',
          ),
          const SizedBox(height: 24),
          Text('Position et boussole', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Le triangle bleu indique ta position GPS. Le bouton "N" (en haut à '
            'droite) bascule entre nord fixe (la carte ne tourne pas) et carte '
            'dynamique (la carte tourne pour toujours pointer dans la direction où '
            'tu regardes). Le bouton en dessous recentre la carte sur ta position.',
          ),
          const SizedBox(height: 24),
          Text('Champs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '"Dessiner un champ" dans le menu permet d\'ajouter un champ sur la '
            'carte (culture, date de récolte, hauteur, bordures). Touche un champ '
            'déjà dessiné pour voir son score, le modifier ou le supprimer.',
          ),
          const SizedBox(height: 24),
          Text('Observations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Le bouton avec le repère permet de noter une observation de terrain '
            'à ta position actuelle :',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final type in ObservationType.values)
                Text('${type.emoji} ${type.label}'),
            ],
          ),
        ],
      ),
    );
  }
}
