import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/rendez_vous.dart';

/// Rappels locaux des rendez-vous du patient.
///
/// Ce sont des notifications LOCALES, pas des notifications push :
/// aucune donnée ne quitte l'appareil, il n'y a donc pas besoin de backend
/// (contrairement à Firebase Cloud Messaging). Conséquence : un rappel
/// programmé est reprogrammé à chaque ouverture de l'espace patient, à
/// partir des rendez-vous lus dans Firestore. C'est aussi ce qui les resynchronise
/// après une annulation ou une reprogrammation.
///
/// Les rappels utilisent le mode IMPRÉCIS (inexactAllowWhileIdle) :
/// - aucune permission SCHEDULE_EXACT_ALARM n'est nécessaire, donc pas de
///   demande d'autorisation supplémentaire à l'utilisateur ;
/// - Android peut les décaler de quelques minutes, ce qui est sans
///   conséquence pour un rappel de rendez-vous médical ;
/// - Google Play n'accorde la permission exacte qu'aux applications de type
///   calendrier/alarme : l'exiger ici ferait rejeter l'application.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  // Le plugin v22 s'instancie par son constructeur (il n'expose plus de
  // champ statique "instance").
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialise = false;

  /// Prépare le plugin. À appeler une fois, avant runApp (main.dart).
  ///
  /// Ne lève pas d'exception si l'initialisation échoue : les rappels sont
  /// un confort, l'application doit rester utilisable sans eux (sur un
  /// environnement de test par exemple).
  Future<void> init() async {
    if (_initialise) return;

    try {
      // Les données de fuseaux horaires sont nécessaires pour traduire un
      // DateTime local en instant TZ, sinon zonedSchedule lève une erreur.
      tzdata.initializeTimeZones();

      // Constantes d'initialisation : sur Android, seul "icon" est réellement
      // utilisé, et il DOIT être le nom d'une ressource de votre application
      // (drawable) — prendre "@mipmap/ic_launcher" est le piège classique,
      // qui produit une exception au lancement plutôt qu'une notification
      // invisible.
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const linux = LinuxInitializationSettings(
        defaultActionName: 'Ouvrir Medigo',
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, linux: linux),
      );

      await _demanderPermission();

      _initialise = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
  }

  /// Demande l'autorisation d'afficher des notifications.
  ///
  /// Sur Android 13+ la permission est un simple dialogue système. Sur les
  /// versions antérieures, l'autorisation est implicite à l'installation :
  /// la méthode ne fait alors rien et rend true.
  Future<bool> _demanderPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;

    return await android.requestNotificationsPermission() ?? true;
  }

  /// Reprogramme tous les rappels à partir de la liste des rendez-vous.
  ///
  /// On commence TOUJOURS par annuler les rappels existants : c'est ce qui
  /// supprime le rappel d'un rendez-vous que le patient vient d'annuler,
  /// sans avoir à retrouver l'identifiant du rappel à annuler.
  Future<void> planifierRappels(List<RendezVous> rendezVous) async {
    if (!_initialise) return;

    try {
      await _plugin.cancelAll();

      final maintenant = DateTime.now();

      for (final rdv in rendezVous) {
        // Seuls les rendez-vous encore divalents et à venir ont un rappel.
        if (rdv.statut == StatutRendezVous.annule ||
            rdv.statut == StatutRendezVous.refuse ||
            rdv.statut == StatutRendezVous.termine) {
          continue;
        }

        final instant = rdv.dateHeure;
        if (!instant.isAfter(maintenant)) continue;

        // Deux rappels par rendez-vous : la veille à 8 h (le patient a le
        // temps de s'organiser) et une heure avant (il part bientôt).
        final veille = DateTime(
          instant.year,
          instant.month,
          instant.day - 1,
          8,
        );
        if (veille.isAfter(maintenant)) {
          await _programmer(
            id: _idRappel(rdv.id, veille),
            instant: veille,
            titre: 'Rendez-vous demain',
            corps:
                '${rdv.medecinNom ?? 'Votre médecin'} — ${rdv.heure}. '
                'N\'oubliez pas vos documents.',
          );
        }

        final uneHeureAvant = instant.subtract(const Duration(hours: 1));
        if (uneHeureAvant.isAfter(maintenant)) {
          await _programmer(
            id: _idRappel(rdv.id, uneHeureAvant),
            instant: uneHeureAvant,
            titre: 'Rendez-vous dans une heure',
            corps:
                '${rdv.medecinNom ?? 'Votre médecin'} à ${rdv.heure}, le '
                '${instant.day}/${instant.month}/${instant.year}.',
          );
        }
      }
    } catch (e) {
      debugPrint('Programmation des rappels impossible : $e');
    }
  }

  Future<void> _programmer({
    required int id,
    required DateTime instant,
    required String titre,
    required String corps,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: titre,
      body: corps,
      scheduledDate: tz.TZDateTime.from(instant, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rendez_vous',
          'Rappels de rendez-vous',
          channelDescription: 'Rappels envoyés avant un rendez-vous médical',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Identifiant numérique du rappel, dérivé du id du rendez-vous et du
  /// moment du rappel.
  ///
  /// Android n'accepte que des entiers, et chaque (rendez-vous, moment) doit
  /// avoir le sien PROPRE : sinon deux rappels du même rendez-vous
  /// s'écraseraient. On combine donc l'empreinte numérique du id Firestore
  /// avec le jour du rappel.
  int _idRappel(String rdvId, DateTime instant) {
    var empreinte = 7; // any prime > 1, per hash de String en Java
    for (final code in rdvId.codeUnits) {
      empreinte = (empreinte * 31 + code) & 0x7FFFFFFF;
    }
    // Le jour décale l'empreinte pour distinguer le rappel de la veille de
    // celui d'une heure avant sur le même rendez-vous.
    return (empreinte + instant.day) & 0x7FFFFFFF;
  }

  /// Supprime tous les rappels. À appeler à la déconnexion : un téléphone
  /// partagé ne doit pas laisser les rappels du compte précédent.
  Future<void> toutAnnuler() async {
    if (!_initialise) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Annulation des rappels impossible : $e');
    }
  }
}
