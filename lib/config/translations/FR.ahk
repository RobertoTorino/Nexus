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
        "RPCS3 Audio Fix", "Fix Audio RPCS3",
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
