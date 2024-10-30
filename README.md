# QueryAuditToolForMSSQL

Version 2.60 **[Version Française](#queryaudittoolformssql-français)**

## Why Another Query Audit Tool?

The SQL client used by programs allows modification of the program name that appears in SQL connections. This can be useful, for example, to replace a generic engine name (such as an Apache or IIS server) with the name of the web application in the Dynamic Management View that lists active sessions. The same applies to the client machine name, which can be modified for practical reasons, especially when multiple instances of an application are running on different servers in a pool. In such cases, it is more relevant to see a name specific to the server pool rather than individual addresses.

However, SQL Server does not allow both the real source IP address and the substitution name provided at connection time to be obtained. This limitation also applies to the program name that sends the query. If this information were available simultaneously, this script would not be necessary.

None of the existing SQL audit tools address this issue:

- **SQL Profiler**, based on SQL Trace (now discouraged due to its performance impact).
- **Extended Events**, which replaces SQL Profiler, offering better performance and flexibility.
- **Server Audit**, based on Extended Events, and thus subject to the same limitations.

## How Does This Audit Tool Stand Out?

- Every audit tool must identify who made the query, which the tools mentioned above do. The connected user's name cannot be altered, which is essential for audit reliability.
- Although the program name behind the connection cannot be corrected, it is crucial to retrieve the source IP address of the query. Standard tools cannot provide this information directly, but it can be obtained via a login trigger that is installed with this tool.
- This tool combines and consolidates information from Extended Events (query, connection number, login name, execution time, event sequence) with the source IP address obtained from the login trigger.
- Reliable query auditing requires recording them on disk, allowing for later retrieval. Other audit targets may result in lost events.
- To ensure data retention, it is essential to manage audit files programmatically rather than allowing them to disappear with the "rollover" option. Without programmatic management, the disk may become full. The script handles the deletion of files whose contents have been processed.
- The continuous automation of file content retrieval provides a user-friendly interface in the form of a SQL table rather than requiring post-processing via XQuery in SQL. The query information is then reconciled with that intercepted by the login trigger.
- The final result is stored in a table, **dbo.AuditComplet**, within the **AuditReq** database. This storage is limited to 45 days to prevent indefinite growth of the database. Therefore, it is important to perform regular SQL backups.

This tool, deployable in a **[single SQL script available here](https://raw.githubusercontent.com/pelsql/QueryAuditToolForMSSql/main/QueryAuditToolForMSSql.sql)**, integrates several SQL automations for query auditing.

- It is based on the use of SQL Server Extended Events and a login trigger.
- It traces complete queries (excluding individual SQL module queries (stored procedures, functions, triggers), although this can be implemented at low cost).
- It logs the audit of queries, as well as the query's IP origin, the user who executed it, the time of completion, the program that launched it, and the database context in which it was executed.
- The trace is recorded in external files, retrieved and processed before being inserted into the database.
- The SQL script manages processed audit files and deletes them to avoid excessive space consumption.
- The final trace is stored in the **dbo.AuditComplet** table of the **AuditReq** database. This storage allows flexible querying using SQL filters.
- The trace processing task runs continuously via a SQL Agent job, scheduled to start with the server. The associated log is also stored in the **AuditReq** database. In case of interruption, the process is logged as an error in the SQL Agent job log, and the task is automatically restarted.
- The process retains the last 45 days of audit for immediate access. Long-term retention relies on regular backups, which are the responsibility of the DBA.
- Data integrity follows standard database management rules, such as choosing the recovery model and performing log backups. By default, the recovery model is full, requiring regular log backups, as is typically the case for most production databases.

### Successful Quality Tests:

- **Intensive Load Tests:** 20 simultaneous processes producing thousands of connections and queries (4,000 each), some reusing session numbers. These tests verified that the consolidation accounts for the temporal distance of events, correctly associating session information with the queries executed. The tool relies on the session number and event sequence specific to login events.
- **Forced Stop/Restart:** Resilience testing in case of interruption during intense processing. No audit file queries were lost during consolidation. All queries were verified to be present in the final audit.

### Future Improvement Plans:

- Trace individual SQL module queries.
- Add a pre-configuration mechanism for error reporting via email (with a choice of email server and recipients).

# Version History

- **Version 1.0:** Initial release (now obsolete).
- **Version 2.0:** Eliminated the need to store connection information in a table at the login trigger level, replacing the mechanism with the use of a user event containing the necessary information. Events are now sequenced to associate queries with their session number and event sequence. This method avoids the difficulties of linking by rounded temporal data at the trace file level.
- **Version 2.1:** Enhanced resilience to prevent event loss in case of interruption. Added a mechanism to prevent duplicate entries and implemented an automatic task restart every 15 minutes in case of stoppage. Support for multiple connections per session. Improved testing tools to simplify the verification of result accuracy, ensuring that no events are missing.
- **Version 2.11** : Streamlining of a process (minor modification) and adjustments to tests
- **Version 2.12** : RPC_Completed events added
- **Version 2.50** : Many fixes to problems found under heavy load, and other resiliency features
- **Version 2.60** : 
  -  Correction to address the fact that event_Sequence resets to 1 each time the extended session restarts, which prevents unique identification of events. We now include the session start date to ensure uniqueness.

  - We also took advantage of this update to enhance the handling of expired connections. Additionally, a fail-safe mechanism has been implemented: in the event of a recurring issue with the logon trigger, it will automatically deactivate to prevent prolonged interruptions.

  - Finally, email notifications have been added for the dbo.CompleterInfoAudit procedure, with options added in dbo.EnumsEtOpt to configure the destination email and the mail server.


# QueryAuditToolForMSSQL (Français)

Version 2.60

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
- **Version 2.11** : Allègement d'un traitement (modification mineure) et ajustements aux tests
- **Version 2.12** : Ajout des évènements RPC_Completed
- **Version 2.50** : Nombreuses corrections aux problèmes rencontrés sous forte charge, ainsi que d'autres fonctionnalités de résilience.
- **Version 2.60** : 
  - Correction pour remédier au fait que event_Sequence redémarre à 1 à chaque redémarrage de la session étendue, ce qui empêche l’identification unique des événements. Nous ajoutons maintenant la date de démarrage de la session pour garantir cette unicité.

  - Nous avons également tiré parti de cette modification pour optimiser la gestion des connexions périmées. En outre, un mécanisme fail-safe a été ajouté : en cas de problème récurrent avec le logon trigger, celui-ci se désactivera automatiquement pour éviter toute interruption prolongée.

  - Enfin, une notification par email a été intégrée pour la procédure dbo.CompleterInfoAudit, avec l’ajout d’options dans dbo.EnumsEtOpt pour configurer l’adresse de destination et le serveur de messagerie.