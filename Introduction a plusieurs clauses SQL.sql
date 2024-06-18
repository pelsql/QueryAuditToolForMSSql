--
-- pour notre démo on crée des données de test
-- la requête ci-dessous utilise Values pour construire des rangées virtuelles
-- qui n'existent que pour la durée d'exécution du Select
--
Select *
From (Values ('a',1,230),('b',2,1024),('b',4,2024),('b',5,6024),('z',7,24)) as Tb2(col1,col2,col3)

--
-- A partir de ces rangées virtuelles on va créer une table temporaire. 
-- Elle est rendue temporaire parce que son nom commence par '#'
-- Elle existe tant que la session est ouverte et la session est limitée à cette fenêtre de requête.
-- Pour que la démo soit rejouable, et qu'on pourrait vouloir retester avec d'autres valeurs, on
-- met la commande drop table if exists avant
-- Le Select ci-dessous créera une première table temporaire, à cause de la clause INTO
--
drop table if exists #TSrc
Select *
Into #TSrc
From (Values ('a',1,''),('b',2,'/'),('c',2,'x'),('d',4,'u'),('d',5,'?')) as Tb(col1,col2,colz)
select * from #TSrc
--
drop table if exists #TbJ -- s'assurer si on rejoue la requêtes avec de nouvelles valeurs que la table ne sera pas là
Select *
INTO #TbJ -- provoque la création de la table temporaire #TbJ avec l'output du Select.
From (Values ('a',1,230,'k'),('b',2,1024,'/'),('b',4,2024,'x'),('d',2,6024,'u'),('z',7,24,'?')) as Tb2(col21,col22,col23,colz)
select * from #TbJ
--
-- clause de recherche IN, équivalent à col1='D' Or col1='A'
--
select * from #TSrc where col1 = 'd' or col1 = 'a'
select * from #TSrc where col1 in ('d','a') 
--
-- clause de recherche IN, équivalent si dans #TSrc.Col1 la valeur existe dans #Tbj.Col21, retourne la rangée
-- le test ne porte que sur une colonne au maximum car le test implique un seul nom de colonne de par la syntaxe.
--
select * from #tsrc
select * from #tbj
--select * from #TSrc where col1 in (select col21 from #TbJ)
-- ceci ne donne pas du tout le même résultat
--select * from #TSrc where col1 in (select col21 from #TbJ) and col2 in (select col22 from #TbJ)
-- ceci donne le match complet des deux colonnes entre les tables, mais c'est poche comme syntaxe
--select * from #TSrc where col1+str(col2)  in (select col21+str(col22)   from #TbJ) 
--
-- clause de recherche EXISTS. L'équivalence se fait par le Where du Exists
-- Le EXISTS est plus versatile que le IN, même s'il demande un peu plus d'écriture
-- C'est plus versatile, car on peut faire la correspondance par plus d'une colonne
-- ici on fait correspondre #TBJ(col21,col22) à #TSrc(col1,col2)
-- EXISTS est appellé à chaque rangée de #TSrc, le Where est évalué à chaque nouvelle valeur de #TSrc(col1,col2)
--
select * from #TSrc where exists (select * From #TbJ Where #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2)
--
-- La clause inverse est aussi possible, le test de non-existence.
--
select * from #tsrc
select * from #tbj
select * from #TSrc where NOT exists (select * From #TbJ Where #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2)
select * from #TSrc where col1 not IN (select col21 from #TbJ)
-- une erreur facile à faire ci-dessous...  répéter l'alias des deux côtés de l'égalité
select * from #TSrc where NOT exists (select * From #TbJ Where #tbj.colz = #tbj.colz and #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2)
-- une erreur facile à faire ci-dessous...  Col1 n'appartient pas à #Tbj mais est disponible dans la condition
select * from #TSrc where col1 not in (select col1 from #TbJ)
-- requête correcte.
--
-- Les jointures : Lorsque dans une requête un condition est posée entre le contenu de deux colonnes appartenant 
-- à des tables différentes.  Dans le Exists on a une semi-jointure car la condition porte sur le contenu 
-- de deux tables différentes, mais rien d'une des deux tables n'est retournée, seulement un vrai ou faux.
-- Une jointure combine les colonnes des deux tables sur une même rangée dans un résultats à rangée multiple.
-- Dans le requête ci-dessous le mot clé "inner" devant le mot clé "JOIN" est totalement facultatif sur SQL Server.
-- La condition de relation qui suit le mot clé "ON" annonce la condition de relation entre les deux tablesm un peu
-- à la manière du EXISTS, 
--
Select
  Elèves.id
, Elèves.nom
, Elèves.prénom
, ÉlèvesGroupes.grp
, ÉlèvesGroupesResultats.Step
, ÉlèvesGroupesResultats.grade
From
  ( -- Itère sur les Élèves, une expression de table ne diffère pas vraiment d'une table réelle
  values
    ('Joe' , 'good', 12132)
  , ('Lu'  , 'Khin', 22323)
  , ('Hi'  , 'Bye' , 34571)
  , ('Héhé', 'Hho' , 92942)
  , ('Hein', 'What', 02942)
  , ('non',  'demo', 00011)
  )  Elèves(prénom, Nom, Id)
  ----------------------------------------------------------------------
  JOIN -- Pour chaque élève Itère les ElèvesGroupes
  (
  values
    (12132, 'MAT123'), (12132, 'CHI234')
  , (22323, 'MAT123'), (22323, 'CHI234'), (22323, 'FRA345')
  , (34571, 'CHI234'), (34571, 'FRA345')
  , (92942, 'FRA101')
  , (02942, 'CHI101')
  ) ÉlèvesGroupes(id, Grp)
  -- en itérant élimine les fiches non-correspondantes
  ON ÉlèvesGroupes.Id = Elèves.Id
  --------------------------------------------------------------------------
  JOIN -- Pour chaque élève group itère sur les notes
  (
  values
    (12132, 'MAT123', 1, 80), (12132, 'MAT123', 2, 85), (12132, 'MAT123', 3, 77)
  , (12132, 'CHI234', 1, 80), (12132, 'CHI234', 2, 85)

  , (22323, 'MAT123', 1, 65), (22323, 'MAT123', 2, 79), (22323, 'MAT123', 3, 91)
  , (22323, 'CHI234', 1, 88), (22323, 'CHI234', 2, 74)
  , (22323, 'FRA345', 1, 88), (22323, 'FRA345', 2, 74)

  , (34571, 'CHI234', 1, 47), (34571, 'CHI234', 2, 74)
  , (34571, 'FRA345', 1, 99), (34571, 'FRA345', 2, 71)

  , (92942, 'FRA101', 1, 69)
  ) ÉlèvesGroupesResultats(id, Grp, Step, Grade)
  -- en itérant élimine les fiche-grp non-correspondants
  ON   ÉlèvesGroupesResultats.id = ÉlèvesGroupes.id
   And ÉlèvesGroupesResultats.Grp = ÉlèvesGroupes.Grp
 Where ÉlèvesGroupes.Grp ='FRA101'
--
Select * From #Tsrc --afficher le contenu des deux tables
Select * From #Tbj
select S.*, J.*
from
  #TSrc as S
  inner JOIN
  #TbJ as J
  ON J.col21=S.col1 and J.col22=S.col2
Where S.col1='a'
--
-- Comparez la requête ci-dessous avec celle du haut. La condition est moins complète, les résultats diffèrent
-- on voit l'effet d'une condition incomplète.
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  JOIN  -- on enlève le mot clé inner, cela ne change rien
  #TbJ
  ON #TbJ.col21=#TSrc.col1  -- mais la condition moins complète, oui!
--
-- Attention aux erreurs de nom d'alias ou de table qui existent 
-- dans la base de données mais ne sont pas les bonnes dans la condition
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  JOIN
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TSrc.col2=#TSrc.col2
--
-- La requête ci-dessous ajoute une condition de filtre qui réduit le nombre de rangées à joindre.
-- La clause Where filtre les rangées possiblement avant la jointure.
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  JOIN
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
Where #TSrc.col1='a'
--
-- Un inner join provoque l'élimination du résultat des données qui n'ont pas de correspondance
-- Un LEFT join conserve le contenu des colonnes du côté des tables qui précèdent le LEFT JOIN
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  LEFT outer JOIN  -- un left / right / full sont des outer join. Le mot "OUTER" n'est pas requis entre LEFT et JOIN sur SQL Server.
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
--
-- comparer versus le INNER JOIN
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  JOIN  -- on enlève le mot clé inner, cela ne change rien
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
--
-- Pour le LEFT JOIN l'application d'une condition sur une donnée des tables à droite du LEFT JOIN
-- provoque l'élimination de la rangée, sur rien n'est retourné à droite
-- En effet quand une donnée est NULL, NULL > 1000 n'est ni vrai ni faux, aussi rien n'est retourné.
-- comparer les quatres requêtes suivantes et leur résultat.
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  LEFT JOIN  -- le mot clé outer n'est pas requis, LEFT RIGHT FULL sont implicitement des Outer joins
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2

select #TSrc.*, #Tbj.*
from
  #TSrc 
  LEFT JOIN  
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
Where #Tbj.col23 > 1000

-- le test d'une valeur NULL doit être fait explicitement
select #TSrc.*, #Tbj.*
from
  #TSrc 
  LEFT JOIN  
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
Where #Tbj.col23 IS NULL OR #Tbj.col23 > 1000 -- pas de risque d'erreur

-- on peut faire retourner la valeur de la colonne telle quelle si elle n'est
-- pas NULL, ou faire un retourner une valeur de substitution qui 
-- convient à l'effet recherché, soit que la condition soit vraie ou fausse.
-- en utilisant la fonction ISNULL. Ici comme on veut que la condition > 1000
-- soit vraie, on peut mettre comme valeur de substitution, 1001.
-- Si la condition > que quelque chose, et que quelque chose est fourni par l'usager
-- mieux vaut utiliser ISNULL à moins d'avoir l'absolue certitude que votre 
-- valeur de substitution soit plus grande que toutes les valeurs possible du filtre
-- spécifié par l'utilisateur. 
select #TSrc.*, #Tbj.*
from
  #TSrc 
  LEFT JOIN  
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
  -- ISNULL est une fonction qui retourne la valeur de la colonne si elle n'est pas NULL
  -- ou qui retourne une valeur de substitution (ici 1001) si elle l'est
Where ISNULL(#Tbj.col23,1001) > 1000 ---- 1001 choisie pour que > 1000 soit vrai pour retourner les null

Declare @valUtilisateur Int = 1000
select #TSrc.*, #Tbj.*
from
  #TSrc 
  LEFT JOIN  
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
  -- ISNULL est une fonction qui retourne la valeur de la colonne si elle n'est pas NULL
  -- ou qui retourne une valeur de substitution (ici 1001) si elle l'est
Where ISNULL(#Tbj.col23,@valUtilisateur+1) > @valUtilisateur -- Ici c'est un truc infaillible

--
-- Un FULL OUTER JOIN FAIT UNE DOUBLE CORRESPONDANCE
-- On a à la fois les correspondances, et les non-correspondances
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  FULL JOIN  -- un left / right / full sont des outer join. Le mot "OUTER" n'est pas requis entre LEFT et JOIN sur SQL Server.
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2

--
-- Trouver seulement les non-correspondances est assez facile
--
select #TSrc.*, #Tbj.*
from
  #TSrc 
  FULL JOIN  -- un left / right / full sont des outer join. Le mot "OUTER" n'est pas requis entre LEFT et JOIN sur SQL Server.
  #TbJ
  ON #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
Where #TSrc.col1 IS NULL or #TbJ.col21 IS NULL 
-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-- LES INDEX,LE POURQUOI, LE COMMENT
-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
--L'accès à une table en SQL implique une itération sur la table, et si on
--en ajoute une autre une imbrication de l'itération sur la seconde table dans 
--l'itération de la première et si on en ajoute une troisième, un itération de 
--la troisième dans la deuxième. Cela fait beaucoup de balayages. 
--Cela fait donc en terme rangées examiné le produit du nombre de rangées de 
--chacune. Le résultat est dans le langage populaire exponentiel (en fait pire).
--Les conditions mises n'empêchent pas ce phénomène d'examen des rangées, elles ne font que 
--limiter le résultat retourné aux correspondances.

--Un type de structure permanente appellé INDEX peut être ajoutée à une table, 
--pour retrouver des rangées plus rapidement, en fonction des conditions exprimées dans 
--la requête, soit au niveau du WHERE, soit au niveau de la clause ON. 
--On veut éviter l'examen de chaque rangée, et l'index est là pour permettre de 
--fournir un raccourci à la recherche des données

--Un Index ajouté peut très bien aider au repérage des données
--ou seulement partiellement, ou être complètement inutile.
--Cela dépend des conditions de filtre ou de jointures dans la requête.
--On pourrait tout indexer mais ça coûte trop cher.  Chaque ajout ou retrait d'une
--rangée demande un ajustement de chacun des index pour refléter ce changement.
--Donc on n'indexe pas tout pour toutes les conditions possible.

--En fait on les choisi soigneusement, car chaque index ajoute de l'espace à la table
--et est maintenu, selon que les valeurs changent, s'ajoutent ou se retirent au gré
--des mises à jour de la base de données. Typiquement on indexe les colonnes qui
--identifient de manière unique la rangée (clé primaire, clé unique) et les colonnes
--qui se réfèrent en contenu entre tables. (clé primaire vs clé étrangères)

--On peut aussi indexer les colonnes qui discriminent de façon importante les catégories 
--de rangées dans les tables.
--Le choix des index va donc avec une fréquence potentielle élevée de leur utilisation,
--ou pour faciliter un traitement plus rare qui sans index peut être intense en accès.
--Un index peut être créé et détruit après un traitement, pour économiser de l'espace
--le travail de sa maintenance dans le temps.
--Le but de l'exercice est de balancer la maintenance des index versus le coût des accès.

-- Dans SQL Server and Azure SQL index architecture and design guide - SQL Server | Microsoft Docs
-- https://docs.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide?view=sql-server-ver15
-- Si on cherche le mot clé "illustration" on trouvera un schéma décrivant les structures d'index.

-- Les 7 prochaines minutes de la vidéo suivante les décrivent. https://youtu.be/MpAKdy54Eqg?t=585
-- des explications plus approfondies expliquent la différence entre les index clustered et non-clustered
-- Les index sont des arbres Btree+ Cet article de wikipedia https://en.wikipedia.org/wiki/B%2B_tree
-- indique comment ils sont maintenus afin que les feuilles de l'arbre aient toutes la même profondeur.

use gpi
-- Index existants de GPM_E_ELE
--
-- CREATE UNIQUE CLUSTERED INDEX GPM_E_ELE_P ON dbo.GPM_E_ELE
-- (
--  ORG ASC,
--  FICHE ASC
-- )
-- implicitement toute clé non clustered contient les champs de la clé clustered, de manière cachée
-- si une clé clustered existe sur la table, sinon elle a un pointeur d'enregistrement, immuable.
-- Donc avec le code permanent, se trouve aussi disponible le numéro de fiche. Je ne sais pas si la donnée
-- ORG est ici dupliquée dans la structure, mais elle est considérée disponible.
-- CREATE NONCLUSTERED INDEX GPM_E_ELE_ORG ON dbo.GPM_E_ELE
-- (
--  ORG ASC,
--  CODE_PERM ASC
-- )
-- CREATE NONCLUSTERED INDEX GPM_E_ELE_CODE_PERM ON dbo.GPM_E_ELE
-- (
--  CODE_PERM ASC,
--  ORG ASC
-- )

-- si on fait afficher les plans d'accès de ces requêtes, ils réfèreront tous à des index différents
select org, fiche from gpi.dbo.gpm_e_ele  tablesample (1) order by fiche DESC

-- quand tous les champs de la clé sont fournis, l'accès se fait directement par l'index
-- qui fournit tous ses champs. Ici l'index clustered donne aussi accès au contenu complet de la rangée
-- car les feuilles de l'arbre sont des rangées.
select * from gpi.dbo.gpm_e_ele where fiche = 9894858 and org = 824000

-- Quand les champs consécutifs de la clé clustered ne sont pas fournis, en particulier le premier et suivants
-- Si le premier champ n'est pas fourni, ou s'il est fourni mais qu'il n'est pas très sélectif,
-- (ex: avec élève si on ne fourni que la colonne ORG, l'index n'a pas d'intérêt, surtout que dans GPI
-- on n'utilise d'autres d'Organisme qu'avec très peu de rangées).
-- Dans un tel genre de situation, l'index perd son intérêt.
-- SQL cherche dans un autre index qui peut lui fournir l'information.
-- L'index est comparable à une mini-table qui contient les colonnes de sa définition, et les colonnes
-- de la clé clustered.
-- Toutefois ce n'est pas un accès direct mais séquentiel. C'est moins long que de balayer la table elle même
-- car l'index clustered incorpore tout la table.
-- Dans l'exemple ci-dessous, le champ org, le premier de la clé, n'est pas fourni. Ce serai comme chercher des mots
-- dans un dictionnaire à partir de la prochaine syllabe.
-- Ici comme la clé clustered est formé des colonnes org et fiche, ces données fiche et org de la clé-clustered 
-- sont implicitement ajoutées aux index nonclustered. Donc il est possible de balayer un index non-clustered, et de 
-- retrouver la données fiche, Org et de la tester.  Il n'est pas nécessaire de trouver la rangée elle-même
-- car tous les champs demandés sont disponibles dans la clé.
select fiche, org from gpi.dbo.gpm_e_ele where fiche = 9860552

-- même problème ici, mais l'enregistrement complet est demandé. Lorsque l'élève est trouvé, le numéro d'organisme est
-- trouvé. Donc un second accès direct est possible, via l'index clustered cette fois. Ce genre d'accès s'appel KeyLookup.
-- Cela est plus coûteux que la requêtre précédente.
-- Est qu'un KeyLookup est plus optimisé qu'un accès direct "clustered index seek" pour qu'on utilise une terminologie différente?
-- Difficile de le dire mais ça doit être très ressemblant
select * from gpi.dbo.gpm_e_ele where fiche = 9860552

-- ici on a un usage de l'accès direct par une "clustered index seek" car portion de la clé donnée est 
-- discriminante, et que les premiers champs fournis le sont tous.
select * from gpi.dbo.gpm_e_ele where fiche = 9860552 And Org = 824000	

-- Au prochain cours on fera la démonstration de l'efficacité et le coûts de ces requêtes en fonction
-- des chemins d'accès utilisés.

-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
--Les traitements d'ensemble de rangées : UNION, UNION ALL, INTERSECT, EXCEPT
-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
--
-- L'union sert à combiner le résultat de plusieurs Select en un SEUL
-- Le corrolaire à ce résultat est que le même nombre de colonnes doit être retourné par les deux 
-- requêtes de l'union et que les types des colonnes doivent être compatibles.
-- Comme #TSrc ne contient que 2 colonnes et #TbJ 3, on ajouté une colonne bidon Col3=NULL au premier Select

-- L'autre corrolaire, c'est que les noms de colonnes doivent être pris d'un seul
-- des deux Select. SQL prend toujours le premier des deux.

-- L'autre corrolaire, c'est que le tri des rangées se fait sur l'ensemble du résultat.
-- Donc puisqu'une seule clause de tri doit s'appliquer, on la met à la fin.

-- La clause UNION sans le mot clé ALL, fait réduire les rangées identiques à une seule rangée
--
-- L'Union permet de produire un résultat combiné issu de requêtes ayant des sources ou 
-- des conditions imcompatibles. Exemple: On peut facilement formuler un FULL OUTER JOIN
-- OU UN LEFT JOIN 
-- Exemple union all pour simuler LEFT JOIN : Select A JOIN B  + union all Select A where not Exists B
-- Exemple union all pour simuler FULL JOIN : Select A where not exists B  + union all + Select B Where where not Exists A

Use tempdb
  Select src='#TSrc', col1, col2, col3=null 
  From #TSrc
  union 
  Select src='#TbJ', col21, col22, col23 
  From #TbJ
  order by src desc, col1, col2, col3
--
-- Comparer le résultat avec UNION ALL vs UNION ci-dessus. On a aucune différence puisque toutes les rangées sont différentes
--
  Select src='#TSrc', col1, col2, col3=null 
  From #TSrc
  union ALL
  Select src='#TbJ', col21, col22, col23 
  From #TbJ
  order by src desc, col1, col2, col3
--
-- Par contre le résultat avec UNION ALL vs UNION ci-dessous. 
-- On aura des différence puisque qu'il y a deux résultats identiques de #Tsrc
--
  Select src='#TSrc', col1
  From #TSrc
  union ALL
  Select src='#TbJ', col21
  From #TbJ
  order by src desc, col1

  Select src='#TSrc', col1
  From #TSrc
  union 
  Select src='#TbJ', col21
  From #TbJ
  order by src desc, col1
--
-- L'élimination des répétitions porte sur le contenu complet, peu importe le Select
-- les valeurs de col1, col21 ont un contenu commun, dont la répétition est éliminée.
--
  Select col1
  From #TSrc
  union 
  Select col21
  From #TbJ
-- ----------------------------------------------------------------------------------
-- INTERSECT est une manière bien intéressante de retourner les rangées dont
-- le contenu est propre aux deux SELECT. C'est utile pour répondre à la question
-- trouve des données communes entre deux sources de données.
-- Les répétitions sont éliminées. Une seule rangée est retournée si plusieurs ont
-- une même valeur. L'élimination des doublons est semblable à celle faite par l'UNION
-- Pour visualiser son action sur le resultat, faites exécuter les deux select séparément
-- ----------------------------------------------------------------------------------
  Select col1--, col2, col3=null 
  From #TSrc
  intersect 
  Select col21--, col2, col3 
  From #TbJ

  Select col1, col2  --, col3=null 
  From #TSrc
  intersect 
  Select col21, col22 --, col3 
  From #TbJ
-- ----------------------------------------------------------------------------------
-- EXCEPT permet de soustraire d'un résultat les rangées retournées par le SELECT
-- subséquent, les doublons sont ramenés à une seule rangées.
-- Ici on voit les rangées de #TSrc dont le contenu des deux colonnes #TSrc(col1, col2)
-- n'est pas présent repectivement dans les rangées produites par les colonnes #Tbj(col21, Col21)
-- Contraitement à l'intersect, l'ordre des requêtes agit comme une soustraction et
-- donne un résultat différent.
-- ----------------------------------------------------------------------------------
  Select col1, col2--, col3=null 
  From #TSrc
  Except 
  Select col21, col22--, col3 
  From #TbJ
-- ----------------------------------------------------------------------------------
-- On commence ici par #Tbj au lieu de #TSrc
-- ----------------------------------------------------------------------------------
  Select col21, col22--, col3=null 
  From #TbJ
  Except 
  Select col1, col2--, col3 
  From #TSrc


-- ----------------------------------------------------
-- Difference entre deux sources de données
-- ----------------------------------------------------
  Select Diff='gpm_e_ele', *
  From 
    ( -- garde les rangées propres à gpm_e_ele qui ne sont pas dans e_ele
    Select
      fiche, code_Perm
    From
      GPI.dbo.gpm_e_ele

   EXCEPT -- sépare les requêtes

    Select
      fiche, codePerm
    From
      Jade.dbo.e_ele
   ) AS A

  union all

  Select Diff='e_ele', *
  From
  ( -- garde les rangées propres à e_ele qui ne sont pas dans gpm_e_ele
    Select
      fiche, codePerm
    From
      Jade.dbo.e_ele

   EXCEPT -- sépare les requêtes
    Select
      fiche, code_Perm
    From
      GPI.dbo.gpm_e_ele
  ) as B
GO
-- ----------------------------------------------------------
-- Difference entre deux sources de données version +compacte
-- ----------------------------------------------------------
;With 
  Src as
  (
  Select
    fiche, code_Perm
  From
    NotifsGPI.dbo.gpm_e_ele
  )
, Dest as 
  (
  Select
    fiche, code_Perm
  From
    NotifsAG.dbo.SDG_E_ELE
  )
Select Diff='NotifsGPI.dbo.gpm_e_ele', *
From 
  (Select * FROM Src EXCEPT Select * From Dest) as DiffAmoinsB
union all
Select Diff='NotifsAG.dbo.SDG_E_ELE', *
From
  (Select * FROM Dest EXCEPT Select * From Src) as DiffBMoinsA
Order By fiche
-- ----------------------------------------------------------------------------------
-- L'APPLY permet de faire des sous-requêtes sur d'autres tables
-- La recherche dans les autres tables se fait à la manière de la clause EXISTS
-- La clause APPLY permet l'input d'une requête Externe dans la requête de l'APPLY
-- Contraitement au EXISTS, la clause APPLY retourne le contenu de la requête
-- interne et le résultat ressemble à un JOIN
-- Un CROSS APPLY se comporte comme un inner JOIN et un OUTER APPLY comme un LEFT JOIN
-- C'est le WHERE de la clause dans le APPLY qui fait la jointure.
-- Dans notre exemple c'est Where #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2
--
-- On peut comparer les résultats de ces deux requêtes avec les join et left join
--
-- ----------------------------------------------------------------------------------
select * 
from 
  #TSrc 
  CROSS APPLY (select * From #TbJ Where #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2) as t2

select * 
from 
  #TSrc 
  OUTER APPLY (select * From #TbJ Where #TbJ.col21=#TSrc.col1 and #TbJ.col22=#TSrc.col2) as t2

-- -----------------------------------------------------------------------------------
-- Un Select n'a pas besoin de table pour retourner un résultat
-- Les trois exemples ci-dessous retournent les mêmes valeurs.
-- Le premier Select ne nomme pas ses colonnes, les deux autres oui.
-- Il y a 2 manière de nommer les résultats. Par convention nous utiliseront la 
-- première.
-- -----------------------------------------------------------------------------------
Select 150.23+10.50, 20.30+15.57+7.20 
Select FraisHebergement=150.23+10.50, FraisRepas=20.30+15.57+7.20 
Select 150.23+10.50 As FraisHebergement, 20.30+15.57+7.20 As FraisRepas 

-- -----------------------------------------------------------------------------------
-- Un Select mis dans un APPLY doit nommer ses colonnes, car un APPLY est une expression
-- de tables, et toutes les colonnes d'une table, doivent avoir des noms, et des noms
-- tous différents.  Ce qui va de soi pour une table, va de soi pour une expression de table.
-- Il y a 2 manière de nommer les colonnes. Par convention nous utiliseront la 
-- première. L'attribution d'un nom différent à une colonne existante ou une expression
-- s'appelle alias de colonne. FraisHebergement est l'alias de l'évaluation de l'expression 
-- 150.23+10.50
-- -----------------------------------------------------------------------------------
Select FraisHebergement=150.23+10.50, FraisRepas=20.30+15.57+7.20 
Select 150.23+10.50 As FraisHebergement, 20.30+15.57+7.20 As FraisRepas 

-- -----------------------------------------------------------------------------------
-- Voici un exemple de requête utilisant un ALIAS. La colonne DateFinMois est 
-- retournée par la fonction EOMONTH, qui pour une date donnée retourne la date
-- de fin du mois de la date correspondante passée en paramètre
--
Select maintenant=getdate() , DateFinMois=EOMONTH(Getdate())
--
-- La requête (sans table ci-dessous) retourne la rangée que si on est à la fin du mois
-- pour que la comparaison avec maintenant fonction, il faut ramener les deux temps
-- au même format.
--
Select 
  maintenant=getdate() , DateFinMois=EOMONTH(Getdate())
, DateFinMoisCmp=CONVERT(nvarchar,EOMONTH(Getdate()),112)
, DateJr=CONVERT(nvarchar,Getdate(),112)
Where CONVERT(nvarchar,EOMONTH(Getdate()),112) <> CONVERT(nvarchar,Getdate(),112) 
--
-- Mais si on préfère retourner 1 ou zéro pour nous dire si on est en fin de mois.
-- En bonus on voit ce que donne nos conversions. 
--
Select *
From 
  (Select maintenant=Convert(nvarchar,getdate(),112) , DateFinMois=Convert(nvarchar,EOMONTH(Getdate()),112)) as prm
  CROSS APPLY (Select finduMois=IIF(maintenant = DateFinMois,1,0) ) as finDuMoisTb
--
-- On peut arriver au même résultat avec OUTER APPLY
-- Quand la condition Maintenant = DateFinMois est fausse finDuMois est NULL, et si on désire avoir zéro dans 
-- ce cas la fonction générique ISNULL fait l'ajustement.
--
Select *
From 
  (Select maintenant=Convert(nvarchar,getdate(),112) , DateFinMois=Convert(nvarchar,EOMONTH(Getdate()),112)) as prm
  OUTER APPLY (Select finduMoisOuter=1 Where maintenant = DateFinMois) as finDuMoisTb
  CROSS APPLY (Select finDuMois=ISNULL(finDuMoisOuter,0)) as finDuMois
--
-- Ce qui peut simplement être ramené à 
--
Select *, finDuMois=ISNULL(finDuMoisOuter,0)
From 
  (Select maintenant=Convert(nvarchar,getdate(),112) , DateFinMois=Convert(nvarchar,EOMONTH(Getdate()),112)) as prm
  OUTER APPLY (Select finduMoisOuter=1 Where maintenant = DateFinMois) as finDuMoisTb
--
-- Un Select entre parenthèses est une expression de table, fussent elle seule, ou dans un APPLY
--
-- Quand elle est seule il s'agit d'une table dérivée
-- L'exemple ci-dessous montre l'imbrication de deux tables dérivées qui permet
-- la réutilisation d'expressions. Ici FraisHebergement et FraisRepas sont des alias de colonnes calculées
-- FraisTotaux une nouvelle colonne calculée, utilise les colonnes FraisHebergement et FraisRepas 
--
Select *, FraisTotaux=FraisDivers.FraisHebergement+FraisDivers.FraisRepas
From 
  -- Table dérivée FraisDivers 
  (Select FraisHebergement=150.23+10.50, FraisRepas=20.30+15.57+7.20) as FraisDivers 

Select *, TotalPlusTaxes=(FraisTotaux * 1.07)* 1.09 -- calcul totalPlusTaxes
From 
  -- Table dérivée Frais qui calcule FraisTotaux en puisant dans les données de la table dérivée FraisDivers
  ( 
  Select FraisTotaux=FraisHebergement+FraisRepas, FraisDivers.* 
  From 
    (Select FraisHebergement=150.23+10.50, FraisRepas=20.30+15.57+7.20) as FraisDivers 
  ) as Frais -- la table dérivée frais 
--
-- L'utilisation imbriquée de tables dérivées alourdit la lecture et la compréhension du Select
-- La clause APPLY permet de rendre l'évaluation plus linéaire.  Elle est analogue à l'utilisation de variables.
--
Declare @FraisHotel numeric(5,2) = 150.23+10.50
Declare @FraisRepas numeric(5,2) = 20.30+15.57+7.20
Declare @tvq numeric(5,2) = 1.09
Declare @tps numeric(5,2) = 1.07
Declare @FraisTotaux numeric(6,2) = @FraisHotel + @FraisRepas
Declare @Taxes numeric(6,2) = (@FraisTotaux * @TPS)* @TVQ
Declare @GrandTotal numeric(10,2) = @FraisTotaux + @Taxes
Select Tvq=@tvq, Tps=@tps, FraisHebergement=@FraisHotel, FraisRepas=@FraisRepas, FraisTotaux=@FraisTotaux, Taxes=@Taxes, GrandTotal=@GrandTotal
--
-- Ce qui se traduit aisément en un seul Select utilsant des APPLY
-- Contrairement aux variables ci-dessus, les types sont inférés par les expressions.
--
Select *
From 
  (Select TVQ=1.09, TPS=1.07) as constantes
  CROSS APPLY (Select FraisHebergement=150.23+10.50, FraisRepas=20.30+15.57+7.20) as FraisDetail
  CROSS APPLY (Select FraisTotaux=FraisHebergement+FraisRepas) as FraisTotaux 
  CROSS APPLY (Select Taxes=(FraisTotaux * TPS)* TVQ) as Taxes 
  CROSS APPLY (Select GrandTotal=FraisTotaux + Taxes) as GrandTotal 
--
-- Contraitement aux variables, l'avantage du Select est qu'il peut puiser ses 
-- données dans une table et calculer le résultat pour chacune. En plus une
-- telle expression peut être utilisée dans un Insert/Update.
-- A titre de démo crééons cette table
--
Drop Table if exists #fv
Select FraisHebergement=Cast(FraisHebergement as numeric(10,2)), 
       FraisRepas=Cast(FraisHebergement as numeric(10,2))
Into #fv
From 
  (Values 
    (150.23, 20.30)
  , (143.30, null)
  , (null, 20.30)
  ) as Fv (FraisHebergement, fraisRepas)
--
-- Et utilisons là dans la requête. En faisans le test on découvre une situation 
-- non-anticipée. Qu'arrive-t-il s'il n'y a pas de frais de repas ou frais de voyage
-- La présence de NULL dans une des parties de l'expression annule les expressions
-- suivantes qui s'en suivent.  
--
Select *
From 
  (Select TVQ=Cast(1.09 as numeric(4,2)), TPS=Cast(1.07 as numeric (4,2))) as constantes
  CROSS JOIN  #Fv as Fv
  CROSS APPLY (Select FraisTotaux=Fv.FraisHebergement+Fv.FraisRepas) as FraisTotaux 
  CROSS APPLY (Select Taxes=(FraisTotaux * TPS)* TVQ) as Taxes 
  CROSS APPLY (Select GrandTotal=FraisTotaux + Taxes) as GrandTotal 
--
-- On peut donc corriger à la source en mettant à zéro les valeurs NULL
-- donc on transformera les données sources dans un APPLY
-- en utilisant la fonction ISNULL pour retourner 0 quand on NULL
-- En sortie on peut arrondir la partie fractionnaire en convertissant le type à Numeric(10,2)
--
Select *
From 
  (Select TVQ=Cast(1.09 as numeric(4,2)), TPS=Cast(1.07 as numeric (4,2))) as constantes
  CROSS JOIN #FV as FV
  CROSS APPLY (Select FraisHotelC=ISNULL(FraisHebergement, 0.00), FraisRepasC=ISNULL(FraisRepas,0.00)) as FvMod
  CROSS APPLY (Select FraisTotaux=FvMod.FraisHotelC+FvMod.FraisRepasC) as FraisTotaux 
  CROSS APPLY (Select Taxes=Cast((FraisTotaux * TPS)* TVQ as Numeric(10,2))) as Taxes 
  CROSS APPLY (Select GrandTotal=Cast(FraisTotaux + Taxes  as Numeric(10,2))) as GrandTotal 
--
-- Je viens de me rendre compte que mon calcul de taxation n'est pas correct
-- Est-ce qu'on a fait la même erreur ailleurs?
-- Voilà la bonne raison d'avoir une fonction. On corrige d'abord la requête puis on fait la fonction.
--
Select *
From 
  (Select TVQ=Cast(1.09 as numeric(4,2)), TPS=Cast(1.07 as numeric (4,2))) as constantes
  CROSS JOIN #FV as FV
  CROSS APPLY (Select FraisHotelC=ISNULL(FraisHebergement, 0.00), FraisRepasC=ISNULL(FraisRepas,0.00)) as FvMod
  CROSS APPLY (Select FraisTotaux=FvMod.FraisHotelC+FvMod.FraisRepasC) as FraisTotaux 
  CROSS APPLY (Select TaxeFed=FraisTotaux * TPS) as TaxeFed
  CROSS APPLY (Select TaxeProv=(FraisTotaux + TaxeFed) * TVQ) as TaxeProv
  CROSS APPLY (Select Taxes=TaxeFed+TaxeProv) as Taxes
  CROSS APPLY (Select GrandTotal=FraisTotaux + Taxes) as GrandTotal 

--
-- Une telle requête est aisément transformable en fonction, mais au lieu 
-- de s'alimenter directement de la table, on passera en paramètre FraisHebergement et FraisRepas.
-- Donc la fonction ne peut par elle-même traiter qu'une ligne à la fois.
-- Ne pas oublier de retirer la table FV de la fonction
--
drop function if exists FraisVoyage
go
Create function FraisVoyage (@fraisHotel numeric(6,2), @fraisRepas numeric(6,2))
returns table
as
  Return
  Select *
  From 
    (Select TVQ=1.09, TPS=1.07) as constantes
    CROSS APPLY (Select FraisHotelC=ISNULL(@fraisHotel, 0.00), FraisRepasC=ISNULL(@fraisRepas,0.00)) as FvMod
    CROSS APPLY (Select FraisTotaux=FvMod.FraisHotelC+FvMod.FraisRepasC) as FraisTotaux 
    CROSS APPLY (Select TaxeFed=FraisTotaux * TPS) as TaxeFed
    CROSS APPLY (Select TaxeProv=(FraisTotaux + TaxeFed) * TVQ) as TaxeProv
    CROSS APPLY (Select Taxes=TaxeFed+TaxeProv) as Taxes
    CROSS APPLY (Select GrandTotal=FraisTotaux + Taxes) as GrandTotal 
GO
--
-- Mais par le moyen d'un APPLY on peut appeller la fonction à chaque ligne
-- de la table FV
--
Select FV.*, Calc.*
From 
  #FV as Fv
  Cross APPLY FraisVoyage(FV.FraisHebergement, FV.FraisRepas) as Calc
--
-- ON peut faire exécuter les 2, la requête avec et sans fonction et comparer l'algorithme
-- SQL, le Plan d'accès des deux
Select *
From 
  (Select TVQ=Cast(1.09 as numeric(4,2)), TPS=Cast(1.07 as numeric (4,2))) as constantes
  CROSS JOIN #FV as FV
  CROSS APPLY (Select FraisHotelC=ISNULL(FraisHebergement, 0.00), FraisRepasC=ISNULL(FraisRepas,0.00)) as FvMod
  CROSS APPLY (Select FraisTotaux=FvMod.FraisHotelC+FvMod.FraisRepasC) as FraisTotaux 
  CROSS APPLY (Select TaxeFed=FraisTotaux * TPS) as TaxeFed
  CROSS APPLY (Select TaxeProv=(FraisTotaux + TaxeFed) * TVQ) as TaxeProv
  CROSS APPLY (Select Taxes=TaxeFed+TaxeProv) as Taxes
  CROSS APPLY (Select GrandTotal=FraisTotaux + Taxes) as GrandTotal 
--
-- Dans le cas de la fonction Inline FraisVoyage, les paramètres sont remplacées par les colonnnes
-- passées via APPLY sur la fonction en lieu et place des paramètres dans la requête de la fonction.  
--
-- ---------------------------------------------------------------------------------------------
-- NOTE AU DEVELOPPEMENT DE FONCTIONS: ON PEUT FAIRE DU DEVELOPPEMENT AXE SUR DES DONNEES TESTS
-- EN SPECIFIANT UNE EXPRESSION DE VALEURS TEST AVEC LES RESULTATS ATTENDUS.
-- L'EXPRESSION CI-DESSOUS PEUT ÊTRE CONSTRUIRE LIGNE PAR LIGNE VALIDANT POUR TOUT LE JEU DE 
-- TEST LE RESULTAT DE CHAQUE NOUVEAU CALCUL, EN EXECUTANT LE RESULTAT A CHAQUE APPLY
-----------------------------------------------------------------------------------------------
Select *
From 
  (Select TVQ=1.09, TPS=1.07) as constantes
  CROSS JOIN
  (Values 
    (150.23, 20.30, 170.53,198.89,369.43 )
  , (143.30, null,  143.30,167.13,310.43 )
  , (null, 20.30,    20.30,23.68,43.98)
  , (null, Null,    0.00,0.00,0.00)
  ) as Fv (FraisHebergement, fraisRepas, rFraisTotaux, rTaxes, rGrandTotal)
  CROSS APPLY (Select FraisHotelC=ISNULL(FraisHebergement, 0.00), FraisRepasC=ISNULL(fraisRepas,0.00)) as FvMod
  CROSS APPLY (Select FraisTotaux=FvMod.FraisHotelC+FvMod.FraisRepasC) as FraisTotaux 
  CROSS APPLY (Select Taxes=Cast((FraisTotaux * TPS)* TVQ as Numeric(10,2))) as Taxes 
  CROSS APPLY (Select GrandTotal=Cast(FraisTotaux + Taxes  as Numeric(10,2))) as GrandTotal 
-- ---------------------------------------------------------------------------------------------
-- ON PEUT MEME FAIRE UN TEST UNITAIRE DE L'EXPRESSION EN RETOURNANT QUE LES RESULTATS INCORRECTS
-- SI ON A DES RANGEES RETOURNÉES, ALORS C'EST QUE DES RÉSULTATS DIFFÈRENT DES RESULTATS PRÉVUS
-----------------------------------------------------------------------------------------------
Select *
From 
  (Select TVQ=1.09, TPS=1.07) as constantes
  CROSS JOIN
  (Values 
    (150.23, 20.30, 170.53, 198.89, 369.42)
  , (143.30,  null, 143.30, 167.13, 310.43)
  , (null,   20.30,  20.30,  23.68, 43.98)
  , (null,    Null,   0.00,   0.00, 0.00)
  ) as Fv (FraisHebergement, fraisRepas, rFraisTotaux, rTaxes, rGrandTotal)

  CROSS APPLY (Select FraisHotelC=ISNULL(FraisHebergement, 0.00), FraisRepasC=ISNULL(fraisRepas,0.00)) as FvMod
  CROSS APPLY (Select FraisTotaux=FvMod.FraisHotelC+FvMod.FraisRepasC) as FraisTotaux 
  CROSS APPLY (Select Taxes=Cast((FraisTotaux * TPS)* TVQ as Numeric(10,2))) as Taxes 
  CROSS APPLY (Select GrandTotal=Cast(FraisTotaux + Taxes  as Numeric(10,2))) as GrandTotal 
Where
     rFraisTotaux<>FraisTotaux 
  OR rTaxes <> Taxes
  OR rGrandTotal <> GrandTotal
If @@ROWCOUNT>0 Raiserror ('Expression de calcul incorrecte',11,1)
go
--
-- Ou encore de la fonction, en utilisant à peu près la même technique.
--
Select *
From 
  (Values 
    (150.23, 20.30, 170.53, 198.89, 369.42)
  , (143.30,  null, 143.30, 167.13, 310.43)
  , (null,   20.30,  20.30,  23.68, 43.98)
  , (null,    Null,   0.00,   0.00, 0.00)
  ) as Fv (FraisHebergement, fraisRepas, rFraisTotaux, rTaxes, rGrandTotal)
  Cross APPLY FraisVoyage(FV.FraisHebergement, FV.FraisRepas) as Calc
Where
     rFraisTotaux<>FraisTotaux 
  OR rTaxes <> Taxes
  OR rGrandTotal <> GrandTotal
If @@ROWCOUNT>0 Raiserror ('Expression de calcul incorrecte',11,1)
--
-- Maintenant supposons que nous avons une table de frais avec des types de frais
-- certains types sont taxables, d'autres non
-- La fonction ne calcule qu'un type à la fois
-- On totalise par voyage
--
Select *
From
  (Select _Prov='0.09', _Fed='0.07') as _TauxTx -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _Heberg='H', _Repas='R', _LocAuto='L', _Comm='C', _Repres='D') as TypFrais -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _AM='A', _DI='D', _SP='S', _NA=NULL) as Per -- jeu de constantes, pourrait être une vue
--
-- Les constantes sont utiles tant pour documenter les valeurs
-- que gérer le contenu. En les faisant commencer par '_' l'intellisence nous les propose en premier
--
Select Fv.*, Det.*
From 
  (Select _Prov=0.09, _Fed=0.07) as _TauxTx -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _Heberg='H', _Repas='R', _PerDiemRepas='DR', _PerDiemHeberg='DH', _LocAuto='L', _Comm='C', _Repres='D') as TypFrais -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _AM='A', _DI='D', _SP='S', _NA='') as Per -- jeu de constantes, pourrait être une vue
  CROSS APPLY -- simule cas de données d'input
  (Values 
    ('20220531', _NA, 150.23, _Heberg,        _Prov, 0.0, NULL)
  , ('20220531', _AM, 12.99,  _Repas,         _Prov, _Fed,  NULL)
  , ('20220531', _DI, 20.10,  _Repas,         _Prov, _Fed,  NULL)
  , ('20220531', _SP, 30.54,  _Repas,         _Prov, _Fed,  NULL)
  , ('20220601', _SP, 7.0,    _PerDiemRepas,  0.0, 0.0, NULL)
  , ('20220601', _AM, 15.0,   _PerDiemRepas,  0.0, 0.0, NULL)
  , ('20220601', _NA, 50.0,   _PerDiemHeberg, 0.0, 0.0, NULL)
  , ('20220601', _SP, 170.20, _Repres,        0.0, 0.0, 'Rencontre avec les PDG de la table de concertation')
  ) as Fv (jr, per, Frais, typeFrais,  Prov, Fed, Commentaire)
  -- un peu d'algorithme
  -- Quand la taxe provinciale est là elle taxe le total de du montant taxé par la taxe fédérale
  -- on peu le faire de manière purement mathématique, mais on veut mettre de la condition là dedans
  -- On calcule le premier montant avec la donnée prov qui peut être à sa valeur 
  -- Cette forme d'algorithme est un genre de switch qui génère plus ou moins de rangées.
  -- On peut prendre une approche différente qui calcule des colonnes complémentaire jusqu'au résultat final.
  CROSS APPLY 
  (
  Select Detail='frais', frais
  UNION All
  Select Detail='taxe Fed', frais * Fed Where Fed > 0
  UNION All -- calcule taxe seulement sur frais si taxe provinciale et pas de taxe fédérale 
  Select Detail='taxe Prov', frais * Prov Where Prov > 0 And Fed = 0
  UNION All -- calcule taxe prov sur total du montant taxé si taxe provinciale et taxe fédérale 
  Select Detail='taxe Prov', (frais * 1.0+Fed) * Prov Where Prov > 0 And Fed > 0.001
  ) as Det
--
-- On fait une fonction qui traite ces données. C'est une bonne chose qu'une fonction 
-- n'accède jamais une table. On évite d'en faire des boîtes noires comme les vues 
-- qui utilisées ensemble provoquent des dédoublement de lectures.
-- Ici on discerne que le requête précédente exprime une règle d'affaire: 
-- L'association des taxations avec les types. Idéalement cette association devrait faire partie de la fonction.
-- Les valeurs de per-diem sont comme une donnée, alors qu'en fait on a une valeur fixe selon la règle d'affaire
-- selon le type et le moment de la journée pour les repas.
--
GO
Drop function If exists dbo.CalculeFraisTotal
GO
Create Function dbo.CalculeFraisTotal (@frais as Numeric(9,2), @jr Date, @per NVarchar(2), @typeFrais NVarchar(2))
Returns Table
AS
Return
Select Frais, jr, typeFrais, Per, rPer, rTypeFrais, Prov, Fed, TxFed, TxProv, MntTx
FROM  
  (Select _Prov=0.09, _Fed=0.07) as _TauxTx -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _Heberg='H', _Repas='R', _PerDiemRepas='DR', _PerDiemHeberg='DH', _LocAuto='L', _Comm='C', _Repres='D') as _TypFrais -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _AM='A', _DI='D', _SP='S', _NA='') as _Per -- jeu de constantes, pourrait être une vue
  CROSS APPLY -- transformation des paramètres en colonnes et pré-traitement des paramètres
  (
  Select 
    Frais=@frais
  , jr=@jr
  , typeFrais=@TypeFrais
  ) as Prm
  CROSS APPLY (Select Per=IIF(typeFrais IN (_PerDiemRepas, _PerDiemHeberg), @per, _NA)) as Per 
  -- faire correspondre les règles d'affaires sous forme de table de décision
  -- et calculer les résultats par type
  OUTER APPLY 
  (
  Select *
  FROM
    (
    Values
      (_NA, Prm.frais, _Repres,        0.0 , 0.0)
    , (_NA, Prm.frais, _Heberg,        0.0 , Prm.frais * _Prov)
    , (_NA, Prm.frais, _Repas,         Prm.frais *_Fed , (Prm.Frais * 1.0 + _Fed)*_Prov)
    , (_SP, 17.0,      _PerDiemRepas,  0.0 , 0.0)
    , (_AM, 7.0,       _PerDiemRepas,  0.0 , 0.0)
    , (_DI, 12.0,      _PerDiemRepas,  0.0 , 0.0)
    , (_NA, 50.0,      _PerDiemHeberg, 0.0 , 0.0)
    ) as RèglesTx (rPer, Montant, rTypeFrais, TxFed, TxProv)
  Where RèglesTx.rTypeFrais = Prm.typeFrais 
    And RèglesTx.rPer = Per.Per -- Per.Per devient NULL qand le type est _Heberg ou _Repas
  ) as CalculFraisEtTaxe
  CROSS APPLY (Select MntTx=Montant+TxFed+TxProv) as MntTx
GO  
Select R.*, Commentaire
FROM  
  (Select _Heberg='H', _Repas='R', _PerDiemRepas='DR', _PerDiemHeberg='DH', _LocAuto='L', _Comm='C', _Repres='D') as _TypFrais -- jeu de constantes, pourrait être une vue
  CROSS JOIN (Select _AM='A', _DI='D', _SP='S', _NA='') as _Per -- jeu de constantes, pourrait être une vue
  CROSS APPLY -- données de test
  (Values 
    ('20220601', _SP, 170.20, _Repres, 'Rencontre avec les PDG de la table de concertation')
  , ('20220531', _NA, 150.23, _Heberg, null)
  , ('20220531', _AM, 12.99,  _Repas, null)
  , ('20220531', _DI, 20.10,  _Repas, null)
  , ('20220531', _SP, 30.54,  _Repas, null)
  , ('20220601', _SP, 7.0,    _PerDiemRepas, null)
  , ('20220601', _AM, 15.0,   _PerDiemRepas, null)
  , ('20220601', _NA, 50.0,   _PerDiemHeberg, null)
  ) as Fv (jr, per, Frais, typeFrais, Commentaire)
  CROSS APPLY dbo.CalculeFraisTotal(frais, jr, per, typeFrais) as R
GO
-- Au lieu de trimbaler les constantes deux fois, pourquoi ne pas utiliser de vues qui seraient utiles dans de futures requêtes
-- et assureraient une cohérence permanente entre les constantes de la fonction et des requêtes.
Drop view if exists dbo._TauxTx
GO
create view dbo._TauxTx As Select _Prov=0.09, _Fed=0.07
GO
Drop view if exists dbo._typFrais
GO
create view dbo._typFrais As Select _Heberg='H', _Repas='R', _PerDiemRepas='DR', _PerDiemHeberg='DH', _LocAuto='L', _Comm='C', _Repres='D'
GO
Drop view if exists dbo._typPerFrais
GO
create view dbo._typPerFrais As Select _AM='A', _DI='D', _SP='S', _NA=''
GO
Drop function If exists dbo.CalculeFraisTotal
GO
Create Function dbo.CalculeFraisTotal (@frais as Numeric(9,2), @jr Date, @per NVarchar(2), @typeFrais NVarchar(2))
Returns Table
AS
Return
Select Frais, jr, typeFrais, Per, rPer, rTypeFrais, Prov=_Prov, Fed=_Fed, TxFed, TxProv, MntTx
FROM  
  dbo._typFrais as TF
  CROSS JOIN dbo._typPerFrais as TPF
  CROSS JOIN dbo._TauxTx as TT
  CROSS APPLY -- transformation des paramètres en colonnes et pré-traitement des paramètres
  (
  Select 
    Frais=@frais
  , jr=@jr
  , typeFrais=@TypeFrais
  ) as Prm
  CROSS APPLY (Select Per=IIF(typeFrais IN (TF._PerDiemRepas,TF._PerDiemHeberg), @per, _NA)) as Per 
  -- faire correspondre les règles d'affaires sous forme de table de décision
  -- et calculer les résultats par type
  OUTER APPLY 
  (
  Select *
  FROM
    (
    Values
      (TPF._NA, Prm.frais, TF._Repres,        0.0,              0.0)
    , (TPF._NA, Prm.frais, TF._Heberg,        0.0,              Prm.frais * _Prov)
    , (TPF._NA, Prm.frais, TF._Repas,         Prm.frais *_Fed , (Prm.Frais * 1.0 + _Fed)*_Prov)
    , (TPF._SP, 17.0,      TF._PerDiemRepas,  0.0,              0.0)
    , (TPF._AM, 7.0,       TF._PerDiemRepas,  0.0,              0.0)
    , (TPF._DI, 12.0,      TF._PerDiemRepas,  0.0,              0.0)
    , (TPF._NA, 50.0,      TF._PerDiemHeberg, 0.0,              0.0)
    ) as RèglesTx (rPer, Montant, rTypeFrais, TxFed,            TxProv)
  Where RèglesTx.rTypeFrais = Prm.typeFrais 
    And RèglesTx.rPer = Per.Per 
  ) as CalculFraisEtTaxe
  CROSS APPLY (Select MntTx=Montant+TxFed+TxProv) as MntTx  -- Outer apply donne null si @per. n'est pas fournie pour le perDiem repas, en tenir compte!
  -- autre possibilités ici..
GO

-- Discussion::::
--
-- Peut-on enrichir le fonction de messages de validation et/ou notification
-- Un message de validation non NULL permet
   -- L'application ou le code SQL émet une erreur
   -- Exemple: Il faut une période du jour pour les PerDiemrepas 
-- Un message de notification non NULL permet de signaler un emploi de valeur ignoré
   -- Exemple: La période du jour pour le frais Heberg, PerdiemHeberg, est ignorée
--
-- On pourrait aller plus loin: Spécifier des limites, afficher des notifications ou erreur pour les dépassements de perDiem

--========================================================================================================================
-- 
-- Fonctions de classement "ranking", exemple avec NTILE et ROW_NUMBER
--
--========================================================================================================================
create function dbo.MedianeDesNotes ()
returns table
as
return
Select *
From
 (
 Select 
   -- attribue un numero de sequence à la plus haute note de chaque groupe
   ordre=row_number() Over (Partition by groupe Order by note desc) 
 , *
 From
   (
   select 
     -- separe les notes en deux groupes a peu près égaux, en leur donnant un numero 1,2 à chaque
     groupe=NTILE(2) Over (Order by note) 
   , *
   From -- simule une table de notes par matieres
     (Values (10),(20),(30),(30),(45),(17),(22),(99),(99),(99)) as t (note) 
   ) as NotesGrp
  ) as x
Where 
  -- la médiane est la plus haute note du premier groupe
  groupe=1 And ordre=1
GO
--========================================================================================================================
-- Les fonctions RANK et DENSE_RANK tiennent à la fois compte de l'ordre et de la valeur de l'expression de tri
-- pour attribuer un numéro de séquence. On a ici une démo qui compare le résultat des trois
--========================================================================================================================
Select 
  *
, ResRowNumber = row_number() Over (Order by valeurATrier)  
, ResRank      = Rank()       Over (Order by valeurATrier)  
, ResDenseRank = Dense_rank() Over (order by valeurATrier)
FROM
  (
   Values (1,'a'), (2,'A'), (3,'b'), (4,'c'), (5,'d'), (6,'D'), (7,'d'), (8,'e'), (9,'f'), (10,'g')
  ) as t(noRangee, valeurATrier)
order by noRangee
-- concernant le déconcertant résultat de ResRowNumber où a > A, la valeur n'est pas déterminée, car 'a'='A'
-- la requête ci-dessous le démontre. L'insensibilité à la casse se réflète dans le tri.
Select * from (Values ('a'),('A')) as t(class) order by class
Select * from (Values ('A'),('a')) as t(class) order by class
--========================================================================================================================
-- La clause partition du OVER agit comme un GROUP BY. On recommence à évaluer à chaque groupe.
-- Donc ici la séquence recommence à chaque groupe
-- On ajoute aussi des fonctions d'aggrégation pour le démontrer.
--========================================================================================================================
Select 
  *
, ResRowNumber = row_number() Over (Partition By chpPart Order by valeurATrier)  
, ResRank      = Rank()       Over (Partition By chpPart Order by valeurATrier)  
, ResDenseRank = Dense_rank() Over (Partition By chpPart order by valeurATrier)

, MinNoRangeeChpPart =Min(noRangee) Over (Partition By chpPart)
, MinNoRangeeChpPart =Max(noRangee) Over (Partition By chpPart)
, SumNoRangeeChpPart =SUM(noRangee) Over (Partition By chpPart)
, SommeProgressive   =SUM(noRangee) Over (Partition By chpPart Order By valeurATrier)

FROM
  (
   Values (1,1,100,'a'), (2,2,100,'A'), (3,3,100,'b'), (4,1,200,'c'), (5,2,200,'d')
        , (6,3,200,'D'), (7,4,200,'d'), (8,5,200,'e'), (9,6,200,'f'), (10,7,200,'g')
  ) as t(noRangee, noRangeeGrp, ChpPart, valeurATrier)
order by noRangee
GO
--========================================================================================================================
-- Application de la somme progressive
-- Suivi de balance
--========================================================================================================================
Select 
  date
, depense
, paiement
, Depenses=SUM(depense) Over (Partition BY NULL Order by Date)
, Paiement=SUM(paiement) Over (Partition BY NULL Order by Date)
From (Values (10,5, '20220621'), (10,5,'20220622'), (0,40,'20220623'),(20,0,'20220624'),(3,5,'20220625')) As Tx (depense, paiement, date)
--========================================================================================================================
-- Application de la somme progressive
-- Suivi de solde
--========================================================================================================================
Select 
  date
, depense
, paiement
, Solde   
, CumulDepenses=SUM(depense) Over (Partition BY NULL Order by Date)
, CumulPaiements=SUM(paiement) Over (Partition BY NULL Order by Date)
FROM
  (
  Select 
    *
  , CumulDepenses=SUM(depense) Over (Partition BY NULL Order by Date)
  , CumulPaiements=SUM(paiement) Over (Partition BY NULL Order by Date)
  From 
    (
    Values (10,5, '20220621'), (10,5,'20220622'), (0,40,'20220623'),(20,0,'20220624')
          ,(15,0,'20220625'), (15,17,'20220626')
    ) As Tx (depense, paiement, date)
  ) as Engagements
  CROSS APPLY (Select Solde=CumulPaiements-CumulDepenses) as Solde
--========================================================================================================================
-- Application de la somme progressive
-- Suivi de solde, piège à éviter. Le résultat n'est pas pertinent à toutes les rangées.
-- Le calcul du solde à l'avant dernière rangée n'est pas bon.
-- si l'expression de tri comporte des valeurs identiques. Elle est sûre avec la dernière valeur seulement.
-- Ici on prend habituellement un moment qui a une plus grande précision que la date
--========================================================================================================================
Select 
  date
, depense
, paiement
, Solde   
, CumulDepenses=SUM(depense) Over (Partition BY NULL Order by Date)
, CumulPaiements=SUM(paiement) Over (Partition BY NULL Order by Date)
FROM
  (
  Select 
    *
  , CumulDepenses=SUM(depense) Over (Partition BY NULL Order by Date)
  , CumulPaiements=SUM(paiement) Over (Partition BY NULL Order by Date)
  From 
    (
    Values (10,5, '20220621'), (10,5,'20220622'), (0,40,'20220623'),(20,0,'20220624')
          ,(15,0,'20220625'), (15,17,'20220625')
    ) As Tx (depense, paiement, date)
  ) as Engagements
  CROSS APPLY (Select Solde=CumulPaiements-CumulDepenses) as Solde
Order by Date
--========================================================================================================================
-- Application de la somme progressive
-- Suivi de solde, éviter le piège à éviter. Générer un ordre absolu sans égalité.
-- si l'expression de tri comporte des valeurs identiques. Elle est sûre avec la dernière valeur seulement.
-- Ici on prend habituellement un moment qui a une plus grande précision que la date
--========================================================================================================================
Select 
  date
, depense
, paiement
, Solde   
, CumulDepenses
, CumulPaiements
FROM
  (
  Select 
    *
  , CumulDepenses=SUM(depense) Over (Partition BY NULL Order by OrdrePaiement)
  , CumulPaiements=SUM(paiement) Over (Partition BY NULL Order by OrdrePaiement)
  From 
    (
    Select 
      OrdrePaiement=Row_Number() Over (Order by Date, noTx)
    , * 
    From
      (
      Values (10,5, '20220621',1), (10,5,'20220622',2), (0,40,'20220623',3),(20,0,'20220624',4)
            ,(15,0,'20220625',5), (15,17,'20220625',6)
      ) As Tx (depense, paiement, date, noTx)
    ) as TxEnOrdre
  ) as Engagements
  CROSS APPLY (Select Solde=CumulPaiements-CumulDepenses) as Solde
Order by OrdrePaiement
--========================================================================================================================
-- 
-- Fonctions de classement "ranking", cas plus corsé à cause des données d'entrée
-- Utilisation du APPLY pour normaliser le contenu (en pivotant plusieurs colonnes en rangées)
--
--========================================================================================================================
-- CALCUL DE LA MEDIANE DANS LES RESULTATS DES ELEVES DE GPI
-- SUR LES COLONNES RES_ETAPE_nn

-- PROBLEME SIMILAIRE PLUS CORIACE CAR GPM_E_MAT_ELE est DENORMALISEE CONCERNANT LES RESULTATS
-- EX: RES_ETAPE_01... RES_ETAPE_30

-- ON IDENTIFIE DES DONNEES INTERESSANTES POUR LA DEMO, CAR ON VEUT BEAUCOUP DE RESULTATS PAR matiere-Groupe
Drop table if Exists #ResNombreux
Select Top 100
  nbRes=Count(*), ID_MAT_GRP 
Into #ResNombreux
From
  (Select * From GPI.dbo.GPM_E_MAT_ELE) as E
  CROSS APPLY -- les notes sont en colonnes séparées
  (
  Values -- Provoque un pivot des données vers la colonne res
    (RES_ETAPE_01), (RES_ETAPE_02), (RES_ETAPE_03), (RES_ETAPE_04), (RES_ETAPE_05), (RES_ETAPE_06), (RES_ETAPE_07), (RES_ETAPE_08), (RES_ETAPE_09), (RES_ETAPE_10)
  , (RES_ETAPE_11), (RES_ETAPE_12), (RES_ETAPE_13), (RES_ETAPE_14), (RES_ETAPE_15), (RES_ETAPE_16), (RES_ETAPE_17), (RES_ETAPE_18), (RES_ETAPE_19), (RES_ETAPE_20)
  , (RES_ETAPE_21), (RES_ETAPE_22), (RES_ETAPE_23), (RES_ETAPE_24), (RES_ETAPE_25), (RES_ETAPE_26), (RES_ETAPE_27), (RES_ETAPE_28), (RES_ETAPE_29), (RES_ETAPE_30)
  ) as Res(res)
Where Res is not null -- on veut les colonnes complétées seulement pour avoir un décompte valable du nombre de résultats complétées
Group by ID_MAT_GRP 
Order by nbRes Desc
--option (Maxdop 1) -- experimenter avec le parallélisme, 1=pas de parralélis
Select * from #ResNombreux Order by nbRes desc


--==========================================================================================
-- ON SE LIMITE AUX MATIERES-GROUPES AVEC ASSEZ DE RESULTATS POUR RENDRE L'EXERCICE
-- DE LA RECHERCHE DE LA MEDIANE INTERESSANT, ILS SONT DANS #ResNombreux 
--==========================================================================================
-- Les résultats sont chiffrés ou lettres, donc pour une mediane il faut une equivalence des lettres avec les chiffres
-- et les résultats chiffrés doivent être convertis en entier.
Select *
From
  (
  Select 
    -- identifie la rangée avec la plus haute note dans la section basse(1), puis dans la section haute (2)
    -- vrai lorsque seqDescroissanteResPargroupe = 1 et que section = 1
    seqDescroissanteResPargroupe=Row_number() Over (Partition by id_mat_grp, Section Order By NoteInt Desc)
  , Div.*
  From
    ( 
    -- identifier la section basse(1) et la section haute(2) des résultats pour calculer la médiane 
    -- obtenu par NTILE(2) Over (Partition BY Id_mat_grp Order by NoteInt) 
    Select 
      -- TRIER PAR NoteInt !!!! dans le matiere-groupe pour identifier la section basse (1) versus la section haute (2)
      Section=NTILE(2) Over (Partition BY Id_mat_grp Order by NoteInt) 
    , E.*
    , T.NoteNum -- Si e.Res est par exemple A alors NoteNum = 90
    , NoteInt --Si e.Res est par exemple A alors NoteInt = 90, si e.res = '81' alors NoteInt = 81
    From
      ( -- Obtenir les résultats non NULL dans les résultats nombreux
      Select R.Org, R.ID_ECO, R.MAT, R.GRP, R.ID_MAT_GRP, R.nbRes, Rx.Res
      From 
        ( -- se limiter aux résultats nombreux pour la démo
        select E.*, N.nbRes
        From 
          #ResNombreux As N
          JOIN
          GPI.dbo.GPM_E_MAT_ELE as E
          ON E.ID_MAT_GRP = N.ID_MAT_GRP 
        ) as R
        CROSS APPLY -- les notes sont en colonnes séparées
        (
        Values -- Provoque un pivot des données vers la colonne res en sortie. Pour 1 rangée de GPM_E_MAT_ELE on a 30 rangées de résultats
          (R.RES_ETAPE_01), (R.RES_ETAPE_02), (R.RES_ETAPE_03), (R.RES_ETAPE_04), (R.RES_ETAPE_05), (R.RES_ETAPE_06), (R.RES_ETAPE_07), (R.RES_ETAPE_08), (R.RES_ETAPE_09), (R.RES_ETAPE_10)
        , (R.RES_ETAPE_11), (R.RES_ETAPE_12), (R.RES_ETAPE_13), (R.RES_ETAPE_14), (R.RES_ETAPE_15), (R.RES_ETAPE_16), (R.RES_ETAPE_17), (R.RES_ETAPE_18), (R.RES_ETAPE_19), (R.RES_ETAPE_20)
        , (R.RES_ETAPE_21), (R.RES_ETAPE_22), (R.RES_ETAPE_23), (R.RES_ETAPE_24), (R.RES_ETAPE_25), (R.RES_ETAPE_26), (R.RES_ETAPE_27), (R.RES_ETAPE_28), (R.RES_ETAPE_29), (R.RES_ETAPE_30)
        ) as Rx(res)
      Where rx.res IS NOT NULL -- les colonnes de résultat sans contenu ne doivent pas générer des rangées de résultats
      ) as E
      -- convertir résultats en lettre en chiffrés
      LEFT JOIN 
      (
      Values ('A', 90), ('A-', 95), ('A+', 100)
           , ('B', 85), ('B-', 80), ('B+', 89)
           , ('C', 70), ('C-', 60), ('C+', 79)
           , ('D', 59), ('D-', 50), ('NE', 0)
      ) as T (Note, NoteNum)
      ON T.Note = E.Res
      -- s'assurer que le résultat est entier si pas converti du lettre à numérique
      -- donc e.res = '82 ' devient 82
      CROSS APPLY (Select NoteInt=ISNULL(T.NoteNum, CONVERT(Int,E.Res))) as NoteInt
    ) as Div
  ) as filtreRes
Where 
  Section=1 -- dans la section basse 
  And seqDescroissanteResPargroupe = 1 -- la valeur la plus haute est la médiane
Order by ID_MAT_GRP, Section Desc, NoteInt Desc 
GO

GO
-- ==============================================================================
-- Differentes façon de lister les changements de valeurs de contenu
-- à partir d'un journal de modification des rangées
-- ====================================================================================
-- La table dbo.FIN_FOUR_JRNL une image des colonnes de FIN_JOUR modifiée à 
-- plus des colonnes supplémentaire dont NO_HIST_SEQ qui est une colonne auto-incrément
-- plus des informations sur la source(utilisateur) et le moment de la modification
-- On a une index clustered NO_FOUR, NO_HIST_SEQ qui permet une bonne performance
-- dans la requête ci-dessous, et encore la seule bonne solution si on la modifiait
-- pour interroge fréquemment les modifications sur un seul fournisseur.
--
-- On a une première application de la clause TOP qui limite le nombre d'enregistrement
-- retourné. Ici on veut aller chercher pour la rangée Modifiée qui a un numéro de fournisseur
-- la rangée qui précède immédiatement selon NO_HIST_SEQ avec le même numéro de fournisseur.
-- Le Where permet de cibler potentiellement toutes les rangées du même numéro de fournisseur
-- dont le no_hist_seq est < que celle de la rangée précédente.
-- On doit donc imposer un ordre descendant AvantModif.NO_FOUR Desc, AvantModif.NO_HIST_SEQ Desc 
-- et le clause TOP (1) limite à la première rangée qui correspond en ordre descendant.
-- 
-- Cette approche est très économique si on compare beaucoup de colonnes par rangée 
--
USE DOFIN
Select colDiff.*
from 
  dbo.FIN_FOUR_JRNL as Modifiée -- boucle sur chaque rangée
  OUTER APPLY -- chaque rangée de Modifiée invoque la requête ci-dessous, qui donne la rangée précédente dans l'historique
  (
  -- TOP (1) limite à la première rangée selon l'ordre du ORDER BY
  -- car il y a en potentiellement plusieurs à cause du AvantModif.NO_HIST_SEQ < Modifiée.no_hist_Seq
  Select Top (1) * 
  From dbo.FIN_FOUR_JRNL as AvantModif -- cherche dans la même table
  Where AvantModif.NO_FOUR = Modifiée.NO_FOUR  -- pour le même fournisseur
    AND AvantModif.NO_HIST_SEQ < Modifiée.NO_HIST_SEQ -- implique toutes les rangées historiquement plus anciennes, 
                                                      -- mais TOP + ORDER BY a un effet limitatif sur la jointure
  -- la clause ORDER BY est optimisée par l'index clustered qui donne l'ordre sans faire de tri.
  ORDER BY AvantModif.NO_FOUR Desc, AvantModif.NO_HIST_SEQ Desc 
  ) AS AvantModif
  -- Maintenant qu'on a sur la même rangée les colonnes de "Modifiée" vs "AvantModif" on peut comparer les colonnes séparément
  -- et produire le liste de colonnes de "courant" et "AvantModif" qui ont changé
  -- ATTENTION : Un UNION ALL exige que toutes les valeurs d'une colonne soient du même type, donc il faut tout convertir
  -- vers un type commun soit nvarchar soit SQL_Variant
  CROSS APPLY
  (
  -- faire un select pour chaque colonne à comparer. Il n'y a pas vraiment de lecture physique car toutes les valeurs
  -- impliquées ne viennent de que la rangée Modifiée qui contient toutes les colonnes de "Modifiée" avec les colonnes de "AvantModif"
  Select NomDonnee='ADR', AV_ADR = Cast(AvantModif.ADR as Sql_variant), AP_ADR= Cast(Modifiée.ADR as Sql_variant) 
  Where Modifiée.ADR <> AvantModif.ADR
  UNION ALL
  Select NomDonnee='RSN_SOC', AV_RSN_SOC =Cast(AvantModif.RSN_SOC as Sql_variant), AP_RSN_SOC = Cast(Modifiée.RSN_SOC as Sql_variant) 
  Where Modifiée.RSN_SOC <> AvantModif.RSN_SOC 
  UNION ALL
  Select NomDonnee='ESCMPTE', AV_ESCMPTE  =Cast(AvantModif.ESCMPTE as Sql_variant), AP_ESCMPTE = Cast(Modifiée.ESCMPTE  as Sql_variant) 
  Where Modifiée.ESCMPTE <> AvantModif.ESCMPTE
  ) as ColDiff
Order by Modifiée.NO_FOUR , Modifiée.NO_HIST_SEQ
--
-- Si on compare toutes les rangées et qu'il n'y a que peu de colonnes
-- La fonction Analytique LAG permet d'obtenir la valeur de la colonne précédente
-- du même fournisseur. On doit cependant faire une expression de table (une requête entre paranthèse)
-- Comme c'est une expression de table on doit la nommer. Ici on lui donne l'alias: FourAvecDiff

Select * 
from 
  (
  Select no_four, rsn_soc, rsn_soc_av=LAG(rsn_soc) OVER (Partition BY no_four Order by NO_HIST_SEQ)
  from 
    dbo.FIN_FOUR_JRNL as AP
  ) as FourAvecDiff 
Where rsn_soc_av <> RSN_SOC 

--
-- Une autre approche pour créer des expressions de tables, mais qui permettent 
-- leur référence plus d'une fois dans la requête est d'utiliser une Common Table Expression ou CTE
-- La déclaration de l'alias est analogue, mais elle doit précéder l'expression de table;
-- Une CTE doit débuter avec WITH et toujours être séparée des requêtes précédente d'un ";"
-- Par précaution on met donc le ";" avant le WITH (;WITH).
-- C'est comme une vue SQL, mais interne à la requête seulement
-- Puis le select après la parenthèse fermant peut y référer par son alias comme si c'était un vue ou une table.
--
;With
  FourAvecDiff AS
  (
  Select no_four, rsn_soc, rsn_soc_av=LAG(rsn_soc) OVER (Partition BY no_four Order by NO_HIST_SEQ)
  from 
    dbo.FIN_FOUR_JRNL as AP
  )
Select * from FourAvecDiff Where rsn_soc_av <> RSN_SOC 
--
-- Voici une exemple d'utilisation de CTE qui réfère plus d'une fois à une
-- des expressions CTE.  Hé oui, plusieurs CTE peuvent être définies avec
-- le ;WITH
--
-- Cette méthode permet de comparer les colonnes que l'on veut des tables 
-- que l'on veut même si ces tables ne sont pas dans la même base de données
-- Dans ce cas il faut simplement préfixer le nom de la table de la base de données
--
Drop table If exists #Src
Drop Table if exists #Dest
Select * Into #Src  From (Values (1,1),(2,1),(2,5),(3,1),(4,1)) as Src(i,j)
Select * Into #Dest From (Values (1,1),(2,1),(2,5),(3,2),(5,1),(6,1)) as Src(i,j)

;With 
  Src as -- CTE pour vos données source. Au lieu de "Select i,j From #Src", mettre votre requête des données source . Ex: Select fiche, code_Perm From GPI.dbo.GPM_ELE 
  (
  Select i,j From #Src
  )  
, Dest as -- CTE pour vos données destination. Au lieu de "Select i,j From #Src", mettre votre requête des données source . Ex: Select fiche, codeperm From JADE.dbo.E_ELE
  (
  Select i,j From #Dest
  )  
-- ici c'est toujours pareil...
Select Diff='Source', *  -- identifier l'appartenance des données de la source
From (Select * FROM Src EXCEPT Select * From Dest) as DiffSrcSansDonneesDeDestination -- lister les données de la source qui ne sont pas dans la destination
union all
Select Diff='Destination', *
From (Select * FROM Dest EXCEPT Select * From Src) as DiffDestinationSansDonneesDelaSource -- lister les données de la source qui ne sont pas dans la destination
-- trier les différences dans l'ordre voulu
Order By i, j

GO
-- La demo suivante demande d'être sur une banque GPI
use gpi
---------------------------------------------------------------------------
-- Techniques apprises ici: 
-- 1) Comment créer des cas de test d'une requête en se passant des 
--    des données réelles.
-- 2) Utiliser les fonctions de classement et aggregate avec Over pour 
--    faciliter le solutionnement d'un problème
---------------------------------------------------------------------------
Select *
From
  (
  Select 
    *
  , NbAdrAdrTypPere=Count(AdrTypPere)  Over (Partition By Fiche, annee)
  , NbAdrAdrTypMere=Count(AdrTypMere)  Over (Partition By Fiche, annee)
  , NbAdrAdrTypPereMere=Count(AdrTypPereMere)  Over (Partition By Fiche, annee)
  From
    (
    Select 
      org, fiche, type_adr, Date_Effect, date_fin_adr
    , annee 
    , OrdreDatePlusRecenteAPlusAncienne=ROW_NUMBER() Over (Partition By Fiche, annee, type_adr Order by date_effect desc)
    , DatePourFutureAdresse 
    , DateDeFinDepassee 
    , AdrTypMere 
    , AdrTypPere 
    , AdrTypPereMere
    From 
      -- constantes pour rendre le cas de test plus lisible
      (Select TypAdrPere='3', TypAdrMere='2', TypeAdrPereMere='1') as c
      
      -- calculer des valeurs qui serviront à monter des cas de test

      CROSS APPLY (Select Aujourdhui=Convert(datetime, CONVERT(date, getdate()))) as Aujourdhui
      CROSS APPLY (Select Hier=Convert(datetime, CONVERT(date, getdate()))-1) as Hier
      CROSS APPLY (Select Demain=Convert(datetime, CONVERT(date, getdate()))+1) as Demain
      --CROSS JOIN gpm_e_adr as A
      --/* Donnees de test, mettre en commentaire un fois tests fini et décommenter --CROSS JOIN gpm_e_adr

      CROSS APPLY (Select AnPassee=Convert(datetime, CONVERT(date, getdate()))-365) as AnPassee
      CROSS APPLY (Select AnProchain=Convert(datetime, CONVERT(date, getdate()))+365) as AnProchain
      CROSS APPLY 
      (       -- org, fiche, type_adr, Date_Effect, date_fin_adr
      Values 
        -- eleve avec date effect adresse typ 2,3 passées, en cours, futures
        (820000, 1111, c.TypAdrMere, AnPassee, Hier-1)     -- Date_fin_adr  
      , (820000, 1111, c.TypAdrPere, AnPassee, Hier-1)     -- date passee typ 3
      , (820000, 1111, c.TypAdrMere, Hier,    NULL)       -- date effectivité, et date effective typ c.TypAdrMere
      , (820000, 1111, c.TypAdrPere, Hier,    NULL)       -- date effectivité, et date effective typ c.TypAdrPere 
      , (820000, 1111, c.TypAdrMere, AnProchain, NULL)    -- date effectivité future, donc non encore effective typ c.TypAdrMere
      , (820000, 1111, c.TypAdrPere, AnProchain, NULL)    -- date effectivité future, donc non encore effective typ c.TypAdrPere

        -- eleve avec date effect adresse typ 2 seulement adr type 3 absente, donc exclu
      , (820000, 1111, c.TypAdrMere, AnPassee, Hier-1)     -- Date_fin_adr  
      , (820000, 1111, c.TypAdrMere, Hier,    NULL)       -- date effectivité typ c.TypAdrMere
      , (820000, 1111, c.TypAdrMere, AnProchain, NULL)    -- date effectivité future, donc non encore effective

        -- eleve avec date effective commençant aujourd'hui 
      , (820000, 2111, c.TypAdrMere, Aujourdhui, NULL)    -- date effectivite aujourd'hui typ c.TypAdrMere
      , (820000, 2111, c.TypAdrPere, Aujourdhui, NULL)    -- date effectivite aujourd'hui typ c.TypAdrPere

        -- eleve avec date effect terminée hier donc exclue
      , (820000, 3333, c.TypAdrMere, AnPassee-280, AnPassee-1) -- Date_fin_adr avant celle qui finit aujourdhui
      , (820000, 3333, c.TypAdrMere, AnPassee, Hier-1)         -- Date_fin_adr  
      , (820000, 3333, c.TypAdrPere, AnPassee-280, AnPassee-1) -- Date_fin_adr avant celle qui finit aujourdhui
      , (820000, 3333, c.TypAdrPere, AnPassee, Hier-1)         -- Date_fin_adr avant aujourdhui 

        -- eleve avec date effect finie aujourd'hui donc ok
      , (820000, 4444, c.TypAdrMere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 4444, c.TypAdrMere, AnPassee, Aujourdhui)      -- Date_fin_adr aujourd'hui 
      , (820000, 4444, c.TypAdrPere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 4444, c.TypAdrPere, AnPassee, Aujourdhui)      -- Date_fin_adr aujourd'hui 

        -- eleve avec date effective et date de fin non spécifiée
      , (820000, 5555, c.TypAdrMere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 5555, c.TypAdrMere, AnPassee, NULL)            -- Date_fin_adr non spéficiée, adresse effective
      , (820000, 5555, c.TypAdrPere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 5555, c.TypAdrPere, AnPassee, NULL)            -- Date_fin_adr, adresse effective 
      )
      As gpm_e_adr (org, fiche, type_adr, Date_Effect, date_fin_adr) -- simule les données de gpm_e_adr
      --*/
      CROSS APPLY (Select Annee=LEFT(Convert(nvarchar, Date_Effect, 112),4)) as Annee
      OUTER APPLY (Select DatePourFutureAdresse=Date_Effect Where DATE_EFFECT > Aujourdhui ) as DatePourFutureAdresse
      OUTER APPLY (Select DateDeFinDepassee=DATE_FIN_ADR Where DATE_FIN_ADR IS NOT NULL OR DATE_FIN_ADR > Aujourdhui) as DateDeFinDepassee
      OUTER APPLY (Select AdrTypPereMere=1 Where type_adr=c.TypeAdrPereMere) as AdrTypPeremere
      OUTER APPLY (Select AdrTypPere=1 Where type_adr=c.TypAdrPere) as AdrTypPere
      OUTER APPLY (Select AdrTypMere=1 Where type_adr=c.TypAdrMere) as AdrTypMere

    Where DatePourFutureAdresse IS NULL  And DateDeFinDepassee IS NULL
    ) as a
  Where OrdreDatePlusRecenteAPlusAncienne=1
  ) as x
-- presence des deux types d'adresses dans les adresses effectives de l'élève
Where x.NbAdrAdrTypMere > 0 And x.NbAdrAdrTypPere > 0  
Order by fiche, annee
GO
Drop Function if exists dbo.AdrEffectives 
Go
--
-- Faire une fonction inline comme celle-ci à partir de la requête au dessus n'est pas sorcier.
-- On peut mettre un paramètre (ici si on passe NULL au numéro de fiche, c'est tous les élèves)
-- Le paramètre @fiche est transformé en colonne fiche et ony réfère à la colonne fiche
-- partout dans la requête
-- on peut garder le bloc de données test en commentaire au cas ou on voudrait vérifier la fonction
Create Function dbo.AdrEffectives  (@fiche int)
Returns table
as
Return
(
Select *
From
  (Select TypAdrPere='3', TypAdrMere='2', TypeAdrPereMere='1') as c
  CROSS APPLY (Select PrmFiche=@fiche) as PrmFiche
  CROSS APPLY
  (
  Select 
    *
  , NbAdrAdrTypPere=Count(AdrTypPere)  Over (Partition By Fiche, annee)
  , NbAdrAdrTypMere=Count(AdrTypMere)  Over (Partition By Fiche, annee)
  , NbAdrAdrTypPereMere=Count(AdrTypPereMere)  Over (Partition By Fiche, annee)
  From
    (
    Select 
      org, fiche, type_adr, Date_Effect, date_fin_adr
    , annee 
    , OrdreDatePlusRecenteAPlusAncienne=ROW_NUMBER() Over (Partition By Fiche, annee, type_adr Order by date_effect desc)
    , DatePourFutureAdresse 
    , DateDeFinDepassee 
    , AdrTypMere 
    , AdrTypPere 
    , AdrTypPereMere
    From 
      (Select Aujourdhui=Convert(datetime, CONVERT(date, getdate()))) as Aujourdhui
      CROSS APPLY (Select Hier=Convert(datetime, CONVERT(date, getdate()))-1) as Hier
      CROSS APPLY (Select Demain=Convert(datetime, CONVERT(date, getdate()))+1) as Demain
      CROSS JOIN gpm_e_adr as A
      /* Donnees de test, mettre en commentaire un fois tests fini et décommenter --CROSS JOIN gpm_e_adr

      CROSS APPLY (Select AnPassee=Convert(datetime, CONVERT(date, getdate()))-365) as AnPassee
      CROSS APPLY (Select AnProchain=Convert(datetime, CONVERT(date, getdate()))+365) as AnProchain
      CROSS APPLY 
      (       -- org, fiche, type_adr, Date_Effect, date_fin_adr
      Values 
        -- eleve avec date effect adresse typ 2,3 passées, en cours, futures
        (820000, 1111, c.TypAdrMere, AnPassee, Hier-1)     -- Date_fin_adr  
      , (820000, 1111, c.TypAdrPere, AnPassee, Hier-1)     -- date passee typ 3
      , (820000, 1111, c.TypAdrMere, Hier,    NULL)       -- date effectivité, et date effective typ c.TypAdrMere
      , (820000, 1111, c.TypAdrPere, Hier,    NULL)       -- date effectivité, et date effective typ c.TypAdrPere 
      , (820000, 1111, c.TypAdrMere, AnProchain, NULL)    -- date effectivité future, donc non encore effective typ c.TypAdrMere
      , (820000, 1111, c.TypAdrPere, AnProchain, NULL)    -- date effectivité future, donc non encore effective typ c.TypAdrPere

        -- eleve avec date effect adresse typ 2 seulement adr type 3 absente, donc exclu
      , (820000, 1111, c.TypAdrMere, AnPassee, Hier-1)     -- Date_fin_adr  
      , (820000, 1111, c.TypAdrMere, Hier,    NULL)       -- date effectivité typ c.TypAdrMere
      , (820000, 1111, c.TypAdrMere, AnProchain, NULL)    -- date effectivité future, donc non encore effective

        -- eleve avec date effective commençant aujourd'hui 
      , (820000, 2111, c.TypAdrMere, Aujourdhui, NULL)    -- date effectivite aujourd'hui typ c.TypAdrMere
      , (820000, 2111, c.TypAdrPere, Aujourdhui, NULL)    -- date effectivite aujourd'hui typ c.TypAdrPere

        -- eleve avec date effect terminée hier donc exclue
      , (820000, 3333, c.TypAdrMere, AnPassee-280, AnPassee-1) -- Date_fin_adr avant celle qui finit aujourdhui
      , (820000, 3333, c.TypAdrMere, AnPassee, Hier-1)         -- Date_fin_adr  
      , (820000, 3333, c.TypAdrPere, AnPassee-280, AnPassee-1) -- Date_fin_adr avant celle qui finit aujourdhui
      , (820000, 3333, c.TypAdrPere, AnPassee, Hier-1)         -- Date_fin_adr avant aujourdhui 

        -- eleve avec date effect finie aujourd'hui donc ok
      , (820000, 4444, c.TypAdrMere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 4444, c.TypAdrMere, AnPassee, Aujourdhui)      -- Date_fin_adr aujourd'hui 
      , (820000, 4444, c.TypAdrPere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 4444, c.TypAdrPere, AnPassee, Aujourdhui)      -- Date_fin_adr aujourd'hui 

        -- eleve avec date effective et date de fin non spécifiée
      , (820000, 5555, c.TypAdrMere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 5555, c.TypAdrMere, AnPassee, NULL)            -- Date_fin_adr non spéficiée, adresse effective
      , (820000, 5555, c.TypAdrPere, AnPassee-280, AnPassee-1)  -- Date_fin_adr lointaine
      , (820000, 5555, c.TypAdrPere, AnPassee, NULL)            -- Date_fin_adr, adresse effective 
      )
      As gpm_e_adr (org, fiche, type_adr, Date_Effect, date_fin_adr) -- simule les données de gpm_e_adr
      --*/
      CROSS APPLY (Select Annee=LEFT(Convert(nvarchar, Date_Effect, 112),4)) as Annee
      OUTER APPLY (Select DatePourFutureAdresse=Date_Effect Where DATE_EFFECT > Aujourdhui ) as DatePourFutureAdresse
      OUTER APPLY (Select DateDeFinDepassee=DATE_FIN_ADR Where DATE_FIN_ADR IS NOT NULL OR DATE_FIN_ADR > Aujourdhui) as DateDeFinDepassee
      OUTER APPLY (Select AdrTypPereMere=1 Where type_adr=c.TypeAdrPereMere) as AdrTypPeremere
      OUTER APPLY (Select AdrTypPere=1 Where type_adr=c.TypAdrPere) as AdrTypPere
      OUTER APPLY (Select AdrTypMere=1 Where type_adr=c.TypAdrMere) as AdrTypMere

    Where DatePourFutureAdresse IS NULL  And DateDeFinDepassee IS NULL
    ) as a
  Where OrdreDatePlusRecenteAPlusAncienne=1
  ) as x
-- presence des deux types d'adresses dans les adresses effectives de l'élève
Where 
  fiche = ISNULL(prmFiche, fiche) 
)
GO
Select *
From 
  dbo.AdrEffectives (null) -- tous les élèves
Where NbAdrAdrTypMere > 0 And NbAdrAdrTypPere > 0  
GO
-- On peut possiblement tracer le changement de statut de couple du père et mère en utilisant les dates de fin
-- qui sont obligatoires sur les dates antérieures d'un même type pour un même élève.
-- Par exemple si on passe de pere+mere à pere et mere séparée, la date de fin de pere+mere sera antérieure à la date d'effectivité de pere et mere séparés
-- Si l'inverse se produit, les dates de fin de pere et mere séparées seront antérieures à pere+mere, si l'application le valide, mais on a aussi un cas ou 
-- la nouvelle adresse pere+mere n'a rien à voir avec l'un des anciens parents. Dans ce cas on ne peut conclure avec certitude à la réunion des parents originaux.
-- Est-il possible de fournir un indicateur de séparation?  Possiblement en se servant de fonction de classement. 


