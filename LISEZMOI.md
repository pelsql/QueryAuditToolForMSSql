# QueryAuditToolForMSSQL

Version 2.1

## Pourquoi un autre outil d'Audit de requête?

Le client SQL utilisé par les programmes permet de modifier le nom de programme qui apparaît dans les connexions SQL. Cela peut être utile, par exemple, pour remplacer un nom générique d'engin (comme un serveur Apache ou IIS) par le nom de l'application Web dans la Dynamic Management View qui énumère les sessions actives. Il en va de même pour le nom du poste client, qui peut être modifié pour des raisons pratiques, notamment lorsque plusieurs instances d'une application s'exécutent sur des serveurs différents d'un pool. Dans ce cas, il est plus pertinent de voir un nom spécifique au pool de serveurs plutôt que des adresses individuelles.

Cependant, SQL Server ne permet pas d'obtenir à la fois l'adresse IP réelle d'origine et le nom de substitution fourni au moment de la connexion. Cette limitation s'applique également au nom du programme qui envoie la requête. Si ces informations étaient disponibles simultanément, ce script n'aurait pas lieu d'être.

Aucun des outils d'audit SQL existants ne résout ce problème :

- **SQL Profiler**, basé sur SQL Trace (désormais déconseillé en raison de son impact sur les performances).
- **Extended Events**, qui remplace le Profiler SQL, offrant plus de performance et de flexibilité.
- **Server Audit**, basé sur Extended Events, et donc sujet aux mêmes limitations.

## Aucun des outils d'audit SQL existants ne résout ce problème :

- SQL Profiler basé sur SQL Trace (désormais déconseillé en raison de son impact sur les performances).
- Extended Events, qui remplace le Profiler SQL, offrant plus de performance et de flexibilité.
- Server Audit, basé sur Extended Events, et donc sujet aux mêmes limitations.

## En quoi cet outil d'audit se distingue-t-il ?

- Tout outil d'audit doit identifier l'auteur de la requête, ce que font les outils mentionnés ci-dessus. Le nom de l'utilisateur connecté ne peut déjà pas être altéré, ce qui est essentiel pour la fiabilité de l'audit.
- Bien que le nom de programme derrière la connexion ne puisse être corrigé, il est crucial de pouvoir retrouver l'adresse IP source de la requête. Les outils standards ne peuvent pas fournir cette information directement, mais elle peut être obtenue via un déclencheur de logon qui est installé avec cet outil.
- Cet outil combine et consolide les informations issues des Extended Events (requête, numéro de connexion, nom de login, temps d'exécution, séquence de l'événement) avec l'adresse IP d'origine obtenue par le déclencheur de logon.
- L'audit infaillible des requêtes nécessite leur enregistrement sur disque, ce qui permet une récupération ultérieure. Les autres cibles de l'audit permettent de "perdre" des évènements.
- Pour garantir la conservation des données, il est essentiel de gérer les fichiers d'audit manuellement, plutôt que de les laisser disparaître avec l'option de "rollover". Sans gestion manuelle, on risque de saturer le disque. Le script se charge de supprimer les fichiers dont le contenu a été traité.
- La récupération du contenu de ces fichiers est automatisée en continu, offrant une interface conviviale sous forme de table SQL plutôt que nécessitant un traitement postérieur via XQuery en SQL. L'information sur la requête est ensuite conciliée avec celle interceptée par le déclencheur de logon.
- Le résultat final est stocké dans une table, **dbo.AuditComplet**, au sein de la base de données **AuditReq**. Ce stockage est limité à une période de 45 jours pour éviter une croissance indéfinie de la base. Il est donc important d'effectuer des sauvegardes SQL régulières.

Cet outil, déployable en un **[seul script SQL disponible ici](https://raw.githubusercontent.com/pelsql/QueryAuditToolForMSSql/main/QueryAuditToolForMSSql.sql)**, intègre plusieurs automatismes SQL pour l'audit des requêtes.

- Il est basé sur l'utilisation des Extended Events de SQL Server et d'un déclencheur sur login.
- Il trace les requêtes complètes (à l'exception des requêtes individuelles des modules SQL (stored procedures, fonctions, déclencheurs), bien que cela soit réalisable à peu de frais).
- Il consigne l'audit des requêtes, ainsi que l'origine IP de la requête, l'utilisateur qui l'a exécutée, le moment de sa terminaison, le programme l'ayant lancée et le contexte de la base de données.
- La trace est enregistrée dans des fichiers externes, récupérés et traités avant d'être insérés dans la base de données.
- Le script SQL gère les fichiers d'audit traités et les supprime pour éviter une consommation excessive d'espace.
- La trace finale est stockée dans la table dbo.AuditComplet de la base de données AuditReq. Ce stockage permet une interrogation flexible grâce aux filtres SQL.
- Le processus de traitement de la trace est exécuté en continu via une tâche de l'Agent SQL, planifiée pour démarrer avec le serveur. Le journal associé est également stocké dans la base AuditReq. En cas d'interruption, le processus est consigné comme une erreur et redémarré automatiquement.
- Le processus conserve les 45 derniers jours d'audit pour un accès immédiat. La conservation à long terme repose sur des sauvegardes régulières, à la charge du DBA.
- L'intégrité des données suit les règles standard de gestion de bases de données, telles que le choix du mode de récupération et les sauvegardes de journaux. Par défaut, le mode de récupération est complet, nécessitant des sauvegardes régulières des journaux.

Tests de qualité réussis:
- **Tests de charge intense :** 20 processus simultanés produisant des milliers de connexions et de requêtes (4 000 chacun), certaines réutilisant des numéros de session. Ces tests ont vérifié que la consolidation tient compte de la distance temporelle des événements, associant correctement les informations des sessions actives au moment des requêtes. L'outil s'appuie sur le numéro de session et la séquence d'événements propres aux événements de login.
- **Arrêt/redémarrage forcé :** Test de la résilience en cas d'interruption en traitement intense. Aucune requête des fichiers d'audit n'est perdue lors de la consolidation. Toutes les requêtes ont vérifiées comme étant présentes dans l'audit final.

### Planification d'améliorations futures:
- Traçage des requêtes individuelles des modules SQL.
- Ajout d'un mécanisme de pré-configuration pour le rapport d'erreurs par courriel (avec choix du serveur de courriel et des destinataires).

# Historique des versions

- **Version 1.0** : Première version (désormais obsolète).
- **Version 2.0** : Élimination du besoin de mémoriser dans une table, au niveau du déclencheur de Login, les informations de connexions. Remplacement du mécanisme par l'utilisation d'un événement utilisateur contenant les informations nécessaires. Les événements sont dorénavant séquencés pour associer les requêtes à leur numéro de session et séquence d'événement. C'est une méthode qui n'est pas sujette aux difficultés de faire des liens par des données temporelles arrondies au niveau du fichier trace.
- **Version 2.1** : Renforcement de la résilience pour éviter la perte d'événements en cas d'interruption. Ajout d'un mécanisme empêchant l'insertion de doublons et mise en place d'un redémarrage automatique de la tâche toutes les 15 minutes en cas d'arrêt. Prise en charge des connexions multiples par session. Amélioration des outils de test pour simplifier la vérification de l'exactitude des résultats, garantissant notamment l'absence d'événements manquants.
