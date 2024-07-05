# QueryAuditToolForMSSQL

Cet outil, déployable en un seul script SQL, réunit plusiers automatismes SQL à des fins d'audit de requêtes.

- Il est basé sur l'utilisation des Extended Events de SQL Server.
- Il trace les requêtes complétées.
- En plus de consigner un audit de requêtes, il consigne avec chaque requête l'origine IP de la requête, qui l'a exécutée, le moment où elle se termine, quel programme l'a lancée et sur de quelle contexte de base de données où elle a été lancée.
- La trace va dans des fichiers externes, d'où elle est récupérée et traitée, afin d'être insérée au final dans la base de données.
- Le script SQL gère les fichiers traités et les retire, afin d'éviter une surconsommation d'espace.
- La trace finale, est stockée dans la base de données AuditReq, sous forme de table, dans la table dbo.AuditComplet. 
- Un stockage dans cette formet permet une interrogation avec tous les filtres permis dans le langage SQL.
- Le processus de traitement de la trace, est créé sous forme de tâche de l'Agent SQL. C'est une tâche qui exécute une procédure stockée qui tourne en permanence. Sa planification est toujours associée au démarrage du serveur. Les logs associés au traitement de la procédure font l'objet de sont stockées des tables placées dans la base de données AuditReq.
- Le processus garde 45 jours d'audit local en accès immédiat, et la conservation long terme est permise par sauvegarde de la base de données.
- L'intégrité du contenu peut faire l'objet de règles normalement appliquées à toutes bases de données. Choix du mode de recouvrement, sauvegardes de journaux. 


