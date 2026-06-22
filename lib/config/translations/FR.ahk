#Requires AutoHotkey v2.0

TM_Lang_FR() {
    return Map(
        ; --- MAIN UI BUTTONS ---
        "Set Launch Path", "Définir Chemin",
        "Profiles", "Profils",
        "Delete Game", "Supprimer",
        "Emulators", "Émulateurs",
        "Clear Path", "Effacer",
        "Restore Path", "Restaurer",
        "Window Manager", "Fenêtres",
        "Focus", "Focus",
        "Music", "Musique",
        "Video", "Vidéo",
        "Gallery", "Galerie",
        "Database", "Base de Données",
        "Notes", "Notes",
        "Browser", "Navigateur",
        "Rec Audio", "Enr. Audio",
        "Rec Video", "Enr. Vidéo",
        "Icon Manager", "Icônes",
        "Idle", "Inactif",
        "Normal", "Normal",
        "High", "Haut",
        "Realtime", "Temps Réel",
        "Clone Wizard", "Assistant Clone",
        "Patch Manager", "Gestion Patchs",
        "Purge Logs", "Vider Logs",
        "Purge List", "Vider Liste",
        "View Logs", "Voir Logs",
        "Show Games Config", "Config Jeux",
        "View System Config", "Config Système",
        "Hide Advanced", "Masquer Avancé",
        "Show Advanced Utilities", "Outils Avancés",
        "Patch Game", "Patcher Jeu",

        ; --- ADVANCED UTILITIES ---
        "AT3 Convert", "Conv. AT3",
        "Pad Test", "Test Pad",
        "Hash Calc / Validator", "Calc. Hash",
        "Wipe List", "Vider Liste",
        "Wipe Full List", "Tout Effacer",

        ; --- GALLERY ---
        "Previous", "Précédent", "Next", "Suivant", "Slideshow", "Diaporama", "Browse", "Parcourir", "Delete", "Supprimer",
        "Image", "Image", "Path", "Chemin", "Size", "Taille",
        "GALLERY_HELP_1", "Appuyez sur Espace pour lancer le diaporama.",
        "GALLERY_HELP_2", "Double-cliquez pour le plein écran.",
        "GALLERY_HELP_3", "Appuyez sur M en plein écran pour changer d'écran.",
        "GALLERY_HELP_4", "Appuyez sur SUPPR pour supprimer l'image.",
        "Sound Manager", "Gestionnaire audio",
        "Emulator Audio Config", "Configuration audio de l'émulateur",
        "Hardware Output Mapping", "Mappage des sorties matériel",
        "Route Game Audio (Strip 3)", "Router l'audio du jeu (Piste 3)",
      "Capture Backend", "Backend de capture",
        "Backend:", "Backend :",
        "Save", "Enregistrer",
        "Refresh Device List ↻", "Actualiser la liste des périphériques ↻",
        "Clear", "Effacer",
        "Mute", "Muet",
        "Hard Reset (Relaunch VoiceMeeter App)", "Réinitialisation dure (relancer VoiceMeeter)",
        "Out A1", "Sortie A1",
        "Out A2", "Sortie A2",
        "Out A3", "Sortie A3",
        "Install Loopback Helper", "Installer l'assistant loopback",
        "Test Loopback 3s", "Tester le loopback 3 s",
      "Help", "Aide",
      "Check for Updates", "Vérifier les mises à jour",
      "Choose an option", "Choisissez une option",
        "Status:", "Statut :",
        "Ready", "Prêt",
        "Saved backend:", "Backend enregistré :",
        "Capture backend saved:", "Backend de capture enregistré :",
        "Loopback helper installed", "Assistant loopback installé",
        "Loopback install failed", "Échec de l'installation de l'assistant loopback",
        "Install Error", "Erreur d'installation",
        "Could not install loopback helper.", "Impossible d'installer l'assistant loopback.",
        "FFmpeg missing", "FFmpeg manquant",
        "Capture Test", "Test de capture",
        "FFmpeg missing:", "FFmpeg manquant :",
        "Loopback helper missing", "Assistant loopback manquant",
        "Loopback helper is missing and could not be installed.", "L'assistant loopback est manquant et n'a pas pu être installé.",
        "Running 3s loopback test...", "Exécution du test loopback de 3 s...",
        "Loopback test saved:", "Test loopback enregistré :",
        "Loopback test capture saved", "Capture du test loopback enregistrée",
        "Loopback test failed", "Test loopback échoué",
        "Loopback test failed. No valid output file was generated.", "Le test loopback a échoué. Aucun fichier de sortie valide n'a été généré.",
        "Update check finished", "Vérification des mises à jour terminée",
        "Update Check", "Vérification des mises à jour",
            "Update Decision", "Choix de la mise à jour",
            "Apply All Updates", "Appliquer toutes les mises à jour",
            "Install Helper", "Installer l'assistant",
            "Download FFmpeg", "Télécharger FFmpeg",
            "Download Nexus", "Télécharger Nexus",
            "Skip", "Ignorer",
            "Helper local", "Assistant local",
            "FFmpeg local", "FFmpeg local",
            "Nexus local", "Nexus local",
            "Latest", "Dernière",
            "Stable", "Stable",
            "Nightly", "Nightly",
            "Selected release", "Version sélectionnée",
            "None", "Aucune",
        "HELP_TEXT_SOUND_MANAGER", "
        (
1. MODE AUDIO :
   - Auto utilise d'abord l'assistant loopback.
   - Loopback capture le périphérique de lecture Windows actif.
   - DShow utilise le périphérique d'entrée direct configuré.
   - Voicemeeter conserve le flux de routage classique.

2. PARAMÈTRES SONORES DE WINDOWS :
   - Définissez comme sortie par défaut les haut-parleurs ou le casque que vous voulez entendre.
   - Laissez votre micro comme entrée pour les commandes vocales.
   - Si l'audio passe par un périphérique non par défaut, basculez vers DShow ou Voicemeeter.

3. ASSISTANT LOOPBACK :
   - Cliquez sur Installer l'assistant loopback si l'utilitaire intégré est absent.
   - Cliquez sur Tester le loopback 3 s pour vérifier que l'audio système est capturé.

4. MISES À JOUR :
   - Utilisez le bouton de vérification pour comparer l'assistant, FFmpeg et Nexus.

5. ROUTAGE LÉGACY :
   - Voicemeeter reste disponible pour les utilisateurs qui ont besoin d'un routage manuel par bus.
        )",

        "HELP_TEXT_GAMEPAD", "
        (
         EXPLICATION DES AXES (Émulation Xbox 360)

         X et Y : Stick gauche
         • X : Horizontal (0=Gauche, 50=Centre, 100=Droite)
         • Y : Vertical (0=Haut, 50=Centre, 100=Bas)

         R : Stick droit (Vertical)
         • Revient à 50 au repos, puis va vers 0 ou 100.

         Z : Gâchettes L2 / R2
         • Les deux gâchettes partagent ce même axe.
         • 50 = Aucune pressée (ou les deux pressées de façon identique)
         • 100 = Gâchette gauche (L2) enfoncée à fond
         • 0 = Gâchette droite (R2) enfoncée à fond

         POV : Croix directionnelle (POV Hat)
         • Affiche l'angle en degrés x 100.
         • -1 = Rien n'est pressé
         • 0 = Haut
         • 9000 = Droite
         • 18000 = Bas
         • 27000 = Gauche
            )",

        ; --- HELP TEXT ---
        "HELP_TEXT_MAIN", "
        (
1. AJOUTER DES JEUX :
   - Cliquez sur 'Définir Chemin' pour ajouter l'exécutable principal.
   - Pour TeknoParrot, sélectionnez un profil dans 'Profils'.

2. ÉMULATEURS :
   - Cliquez sur 'Émulateurs' pour configurer les chemins.

3. LANCER DES JEUX :
   - Sélectionner un .ISO/.BIN vous demandera quel émulateur utiliser.
   - Ou sélectionnez un jeu dans la liste et cliquez sur ▶️.

4. QUAND LE JEU EST ACTIF :
   - Utilisez 'Fenêtres' pour manipuler la fenêtre du jeu.
   - Utilisez les boutons CPU pour corriger les ralentissements.
   - 'Rafale' prend des captures d'écran rapides (max. 99).

5. ENREGISTREMENT :
   - Enregistrez uniquement l'audio ou la vidéo avec le son.

6. OUTILS :
   - Convertisseur AT3 : Convertit l'audio ATRAC3 en WAV.
   - Validateur de Fichier : Vérifie les hashs MD5/SHA1.
   - Base de données de recherche de jeux.

7. RACCOURCIS :
   - Échap : Quitter le jeu.
  - Échap+1 : Réinitialisation matérielle (Reset).
  - Ctrl+L : Ouvrir le journal en direct.
   - F8 : Active le catalogue des commandes vocales.
  - Ctrl+Alt+F9 : En mode capture, affiche le terminal ffmpeg.
  - Ctrl+Alt+F10 : Affiche les logs ffmpeg.
   - CTRL+SHIFT+A : Ouvre le gestionnaire audio.

8. LANCEMENT RAPIDE :
   - Clic droit sur l'icône de la barre des tâches.
   - Double-clic sur la barre de titre pour le mode texte.

9. FENÊTRES MAGNÉTIQUES :
   - Maintenez Ctrl sur l'interface principale pour la détacher.

T. DÉPANNAGE :
   - Pour redémarrer un jeu, utilisez 'Redémarrer'.
   - Utilisez 'Voir Logs' pour chercher des erreurs.
        )"
    )
}
