import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/notifications_service.dart';

/// Demande confirmation avant de se déconnecter. Renvoie true si confirmé.
Future<bool> confirmerDeconnexion(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Déconnexion'),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Déconnexion'),
        ),
      ],
    ),
  );
  return ok == true;
}

class SidebarItem {
  final String icone;
  final String label;
  const SidebarItem(this.icone, this.label);
}

/// Cloche de notification : affiche en badge le nombre de nouvelles commandes
/// reçues depuis la dernière consultation. Un appui remet le compteur à zéro.
class ClocheNotifications extends StatelessWidget {
  final Color couleurIcone;
  final VoidCallback? onTap;
  const ClocheNotifications({super.key, this.couleurIcone = AppColors.ink, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationsService.instance.compteur,
      builder: (context, nb, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(nb > 0 ? Icons.notifications_active : Icons.notifications_none, color: couleurIcone),
              tooltip: 'Nouvelles commandes',
              onPressed: () {
                NotificationsService.instance.reinitialiser();
                // Renvoie directement vers la liste des commandes pour pouvoir valider.
                if (onTap != null) onTap!();
              },
            ),
            if (nb > 0)
              Positioned(
                right: 6,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(9)),
                  child: Text('${nb > 99 ? "99+" : nb}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Structure d'écran commune aux tableaux de bord staff : barre latérale sombre
/// avec logo + éléments de menu + déconnexion, et contenu principal à droite.
/// S'adapte automatiquement en menu déroulant sur petit écran (téléphone).
class StaffScaffold extends StatelessWidget {
  final List<SidebarItem> items;
  final int indexActif;
  final ValueChanged<int> onChangerIndex;
  final Widget contenu;
  final VoidCallback? onNotificationsTap;

  const StaffScaffold({
    super.key,
    required this.items,
    required this.indexActif,
    required this.onChangerIndex,
    required this.contenu,
    this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final large = MediaQuery.of(context).size.width >= 760;

    if (!large) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: Text(items[indexActif].label),
          actions: [
            ClocheNotifications(onTap: onNotificationsTap),
            PopupMenuButton<int>(
              icon: const Icon(Icons.menu),
              onSelected: onChangerIndex,
              itemBuilder: (ctx) => List.generate(
                items.length,
                (i) => PopupMenuItem(value: i, child: Row(children: [
                  Text(items[i].icone), const SizedBox(width: 10), Text(items[i].label),
                ])),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (!await confirmerDeconnexion(context)) return;
                if (!context.mounted) return;
                await auth.deconnexion();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              },
            ),
          ],
        ),
        body: contenu,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Row(
        children: [
          Container(
            width: 220,
            color: AppColors.ink,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant_menu, color: AppColors.gold, size: 28),
                    const SizedBox(width: 8),
                    const Text('ESPACE STAFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final actif = i == indexActif;
                      return Material(
                        color: actif ? AppColors.gold.withOpacity(0.15) : Colors.transparent,
                        child: InkWell(
                          onTap: () => onChangerIndex(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            decoration: BoxDecoration(
                              border: Border(left: BorderSide(color: actif ? AppColors.gold : Colors.transparent, width: 3)),
                            ),
                            child: Row(
                              children: [
                                Text(items[i].icone, style: const TextStyle(fontSize: 15)),
                                const SizedBox(width: 12),
                                Text(items[i].label,
                                    style: TextStyle(color: actif ? AppColors.gold : const Color(0xFFC9C1B0), fontSize: 13, fontWeight: actif ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Color(0xFF3A3327), height: 1),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      if (!await confirmerDeconnexion(context)) return;
                      if (!context.mounted) return;
                      await auth.deconnexion();
                      if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: Color(0xFFC9C1B0), size: 17),
                          const SizedBox(width: 10),
                          Text('Déconnexion (${auth.utilisateur?.username ?? ""})',
                              style: const TextStyle(color: Color(0xFFC9C1B0), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppColors.panel,
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(items[indexActif].label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClocheNotifications(onTap: onNotificationsTap),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'deconnexion') {
                            if (!await confirmerDeconnexion(context)) return;
                            if (!context.mounted) return;
                            await auth.deconnexion();
                            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'deconnexion', child: Text('Déconnexion')),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 15, backgroundColor: AppColors.gold,
                              child: Text(
                                (auth.utilisateur?.username ?? '?').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(auth.utilisateur?.username ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if (auth.utilisateur?.lieuNom != null)
                                  Text('📍 ${auth.utilisateur!.lieuNom}', style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.inkSoft),
                          ],
                        ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: contenu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
