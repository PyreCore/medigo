// Régénère l'historique des commits et le nombre de commits par membre
// dans le README, à partir de `git log`.
//
//   dart run tool/historique.dart             met le README à jour
//   dart run tool/historique.dart --verifier  échoue si le README n'est pas à jour
//
// Ce que le script conserve :
// - la colonne « Contenu » déjà rédigée à la main pour un commit (repérée par
//   son identifiant) ; un nouveau commit reçoit son titre en gras ;
// - le sous-titre des mois (« #### Octobre 2026 — Espaces Patient… ») ;
// - les colonnes « Membre » et « Partie » du tableau des membres. Un auteur
//   Git inconnu du tableau y est ajouté avec une partie « à compléter ».
//
// Le script ne touche qu'aux zones délimitées dans le README par
// <!-- historique:debut --> / <!-- historique:fin --> et
// <!-- membres:debut --> / <!-- membres:fin -->.
import 'dart:convert';
import 'dart:io';

const _fichier = 'README.md';
const _mois = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août',
  'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

class _Commit {
  final String hash;
  final String auteur;
  final String dateIso; // date de l'AUTEUR, avec son décalage horaire
  final bool fusion;
  final String titre;

  _Commit(this.hash, this.auteur, this.dateIso, this.fusion, this.titre);

  DateTime get instant => DateTime.parse(dateIso);
  int get annee => int.parse(dateIso.substring(0, 4));
  int get mois => int.parse(dateIso.substring(5, 7));

  // L'heure affichée est celle de l'auteur (lue telle quelle dans la date
  // ISO) et non convertie dans le fuseau de la machine qui lance le script.
  String get dateCourte =>
      '${dateIso.substring(8, 10)}/${dateIso.substring(5, 7)} '
      '${dateIso.substring(11, 16)}';
}

Future<void> main(List<String> args) async {
  final verifier = args.contains('--verifier');

  final fichier = File(_fichier);
  if (!fichier.existsSync()) {
    _echec('$_fichier introuvable : lancez le script depuis la racine du projet.');
  }
  final brut = fichier.readAsStringSync();
  final crlf = brut.contains('\r\n');
  final texte = brut.replaceAll('\r\n', '\n');

  final commits = await _lireCommits();

  var resultat = _remplacerZone(texte, 'historique', (ancien) => _historique(ancien, commits));
  resultat = _remplacerZone(resultat, 'membres', (ancien) => _membres(ancien, commits));

  if (resultat == texte) {
    stdout.writeln('README déjà à jour (${commits.length} commits).');
    return;
  }
  if (verifier) {
    _echec('README pas à jour : lancez « dart run tool/historique.dart ».');
  }
  fichier.writeAsStringSync(crlf ? resultat.replaceAll('\n', '\r\n') : resultat);
  stdout.writeln('README mis à jour : ${commits.length} commits.');
}

Future<List<_Commit>> _lireCommits() async {
  // %x1f (séparateur d'unité) ne peut pas apparaître dans un titre de commit.
  final res = await Process.run(
    'git',
    ['log', '--format=%h%x1f%an%x1f%aI%x1f%P%x1f%s'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (res.exitCode != 0) _echec('git log a échoué : ${res.stderr}');

  final commits = <_Commit>[];
  for (final ligne in LineSplitter.split(res.stdout as String)) {
    if (ligne.trim().isEmpty) continue;
    final c = ligne.split('\x1f');
    final parents = c[3].trim().split(' ').where((p) => p.isNotEmpty);
    commits.add(_Commit(c[0], c[1], c[2], parents.length > 1, c[4].trim()));
  }
  // Ordre chronologique d'écriture, et non l'ordre du graphe Git : un
  // commit rebasé garde sa date d'origine.
  commits.sort((a, b) => a.instant.compareTo(b.instant));
  return commits;
}

String _remplacerZone(String texte, String nom, String Function(String) generer) {
  final debut = '<!-- $nom:debut -->';
  final fin = '<!-- $nom:fin -->';
  final i = texte.indexOf(debut);
  final j = texte.indexOf(fin);
  if (i < 0 || j < i) _echec('Repères $debut / $fin absents du README.');
  final ancien = texte.substring(i + debut.length, j);
  return '${texte.substring(0, i + debut.length)}\n${generer(ancien)}\n${texte.substring(j)}';
}

final _ligneCommit = RegExp(r'^\| [^|]+ \| [^|]+ \| `([0-9a-f]+)` \| (.*) \|$');
final _titreMois = RegExp(r'^#### (\S+) (\d{4})(?: — (.+))?$');

String _historique(String ancien, List<_Commit> commits) {
  // Contenus et sous-titres déjà rédigés, à conserver.
  final contenus = <String, String>{};
  final sousTitres = <String, String>{};
  for (final ligne in ancien.split('\n')) {
    final c = _ligneCommit.firstMatch(ligne);
    if (c != null) contenus[c.group(1)!] = c.group(2)!;
    final m = _titreMois.firstMatch(ligne);
    if (m != null && m.group(3) != null) {
      sousTitres['${m.group(1)} ${m.group(2)}'] = m.group(3)!;
    }
  }

  final sortie = StringBuffer();
  String? moisCourant;
  for (final c in commits) {
    final mois = '${_mois[c.mois - 1]} ${c.annee}';
    if (mois != moisCourant) {
      moisCourant = mois;
      final sousTitre = sousTitres[mois];
      sortie
        ..writeln()
        ..writeln(sousTitre == null ? '#### $mois' : '#### $mois — $sousTitre')
        ..writeln()
        ..writeln('| Date | Auteur | Commit | Contenu |')
        ..writeln('| --- | --- | --- | --- |');
    }
    final titre = c.titre.replaceAll('|', r'\|');
    final contenu = contenus[c.hash] ?? (c.fusion ? '*Fusion* : $titre' : '**$titre**');
    sortie.writeln('| ${c.dateCourte} | ${c.auteur} | `${c.hash}` | $contenu |');
  }
  return sortie.toString().trimRight();
}

final _ligneMembre = RegExp(r'^\| (.+?) \| (.*) \| \d+ \|$');
final _nomGras = RegExp(r'\*\*([^*]+)\*\*');

String _membres(String ancien, List<_Commit> commits) {
  final parAuteur = <String, int>{};
  for (final c in commits) {
    parAuteur[c.auteur] = (parAuteur[c.auteur] ?? 0) + 1;
  }

  final lignes = <String>[];
  final connus = <String>{};
  for (final ligne in ancien.split('\n')) {
    final m = _ligneMembre.firstMatch(ligne);
    if (m == null) {
      if (ligne.trim().isNotEmpty) lignes.add(ligne); // en-tête du tableau
      continue;
    }
    // Un membre peut avoir plusieurs identités Git : « **mvp** / **etoumbi9** ».
    final noms = _nomGras.allMatches(m.group(1)!).map((n) => n.group(1)!).toList();
    connus.addAll(noms);
    final total = noms.fold<int>(0, (s, n) => s + (parAuteur[n] ?? 0));
    lignes.add('| ${m.group(1)} | ${m.group(2)} | $total |');
  }
  for (final auteur in parAuteur.keys) {
    if (!connus.contains(auteur)) {
      lignes.add('| **$auteur** | *à compléter* | ${parAuteur[auteur]} |');
    }
  }
  return lignes.join('\n');
}

Never _echec(String message) {
  stderr.writeln(message);
  exit(1);
}
