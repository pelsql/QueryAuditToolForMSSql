# QueryAuditToolForMSSQL

Version 2.1

Cet outil, déployable en un **[seul script SQL disponible ici](https://raw.githubusercontent.com/pelsql/QueryAuditToolForMSSql/main/QueryAuditToolForMSSql.sql)**, réunit plusiers automatismes SQL à des fins d'audit de requêtes.

- Il est basé sur l'utilisation des Extended Events de SQL Server.
- Il trace les requêtes complétées (mais pas les requêtes individuelles des modules).
- En plus de consigner un audit de requêtes, il consigne avec chaque requête l'origine IP de la requête, qui l'a exécutée, le moment où elle se termine, quel programme l'a lancée et sur de quelle contexte de base de données où elle a été lancée. 
- La trace va dans des fichiers externes, d'où elle est récupérée et traitée, afin d'être insérée au final dans la base de données.
- Le script SQL gère les fichiers d'évènements traités et les retire, afin d'éviter une surconsommation d'espace.
- La trace finale, est stockée dans la base de données AuditReq, sous forme de table, dans la table dbo.AuditComplet. 
- Le stockage sous cette forme permet une interrogation avec tous les filtres permis dans le langage SQL.
- Le processus de traitement de la trace, est créé sous forme de tâche de l'Agent SQL, qui en exécution permanente. Sa planification est toujours associée au démarrage du serveur. Les logs associés aus traitements par cette procédure sont également stockées des tables placées dans la base de données AuditReq. Comme il doit toujours fonctionner, son arrêt met un erreur dans le l'historique de son travail dans l'Agent SQL.
- Le processus garde 45 jours d'audit local en accès immédiat. La conservation sur le long terme est complétée par une sauvegarde de la base de données qui est la responsabilité du DBA.
- L'intégrité du contenu peut faire l'objet de règles normalement appliquées à toutes bases de données telles le choix du mode de recouvrement, les sauvegardes de journaux. Par défaut le mode de recouvrement est complet.

Planification d'avancements supplémentaires:
- Tracer aussi les requêtes individuelles des modules SQL
- Ajouter mécanisme de pré-configuration pour rapport d'erreur par courriel (usager choisi son serveur de courriel, ses destinataires)

#Historique des versions

Version 1.0 : En gros le Readme...

Version 2.0
- Éliminer le besoin d'insérer dans une table dans le déclencheur de Login (élimine possibilité d'erreur qui bloque un login). À la place on utilise un évènement utilisateur qui contient l'information qu'on veut passer au traitement des évènements. Le traitement de évènements ajoute aussi un numéro de séquence qui assure que les requêtes sont bien liés aux évènements de login correspondants.

Version  2.1
- Ajoute un peu plus de résilience (on veut tout tracer n'est-ce pas). Si le processus est interrompu, on ne veut pas qu'ils soit "cassé" et perde des évènements. On fonctionne par retraitement des évènenements en éliminant ce qui pourrait causer problème c'est à dire l'insertion d'évènements en double. On ajoute à la requête le test que l'évènement n'est pas déjà inséré pour l'insérer. L'autre élément de résilience, est l'ajout d'un horaire de auto-restart. Quand l'Agent SQL redémarre il y a un horaire de autoStart, mais si la procédure est interrompue, il y a un horaire supplémentaire qui essaie de la partir au 15 minutes. Elle est sans effet quand cela roule, mais si la procédure est stoppé, ce redémarrage évitera d'accumuler des fichiers d'évènements à côté qui ne sont pas traités. Cas extrêment limites détectés et résolus. Ajout d'outils de test.

