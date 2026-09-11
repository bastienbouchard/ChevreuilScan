enum Season { preRut, rut, postRut }

extension SeasonLabel on Season {
  String get label => switch (this) {
        Season.preRut => 'Pré-rut',
        Season.rut => 'Rut',
        Season.postRut => 'Post-rut',
      };

  String get description => switch (this) {
        Season.preRut => 'Nourriture feuillue, coupes 3-10 ans, arbustes',
        Season.rut => 'Déplacements, écotones, zones de femelles',
        Season.postRut => 'Sapin, cèdre, tremble, couvert dense',
      };
}
