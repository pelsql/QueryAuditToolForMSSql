--select * from dbo.GPM_E_MAT_ELE
-- pour ceux qui n'ont pas la librairie S# consulter la définition des index dans management STUDIO
select fullTbName, IdxName, BuildColsIndex, i.IncludedCols, i.CreateIndexWithoutWithClause  
from s#.IndexInfoByIndexName ('GPM_E_MAT_ELE', NULL) as i


-- pour démo créer sous-ensemble de donnéees de index GPM_E_MAT_ELE_MAT_GRP de dbo.GPM_E_MAT_ELE (non-clustered) (235K de rangées)
drop table if exists #pgIdx
Select Feuilles.*
into #pgIdx
From
  (
  select  
    -- notre simulation d'index compte 2000 blocs au niveau des feuilles, 200 au niveau intermediaire et 1 à la racine par définition
    -- donc on fait commencer les numéros de blocs apres 201
    PageNo=200 + NTILE (2000) Over (Order By  cle) 
  , cle
  , pageBelow=NULL
  From 
    (select d='.') as Typ
    cross join dbo.GPM_E_MAT_ELE 
    CROSS APPLY (Select Cle=d+Str(FICHE,7)+d+Str(ORG,6)+d+Str(ID_ECO,3)+d+left(MAT+space(8),8)+d+left(GRP+space(4),4) ) as Cle
  where id_eco between 200 and 250
  ) as Feuilles
Select #pgIdx.* From #pgIdx order by cle

Insert into #pgIdx 
Select *
From
  (
  select  
    -- le niveau intermediaire commence à 1 et n'a que 200 blocs
    pageNo=NTILE(200) Over (Order By pageBelow, lastItemPageBelow) -- on réserve le bloc 1 pour la racine
  , cle=lastItemPageBelow
  , pageBelow
  From 
    (
    Select 
      pageBelow=pageNo  
    , lastItemPageBelow=Max(cle)
    From #pgIdx
    Where pageNo>200 -- blocs des feuilles
    Group by PageNo
    --order by pageNo
    ) as LastLeaf
  --order by pageNo
  ) as Leaf
Select #pgIdx.* From #pgIdx Where pageNo between 1 and 200 order by cle -- intermediare



Insert into #pgIdx 
Select *
From
  (
  select  
    pageNo=0 -- la racine n'est qu'une seule page, la zéro 
  , cle=lastItemPageBelow
  , pageBelow
  From 
    (
    Select 
      pageBelow=pageNo  
    , lastItemPageBelow=Max(cle)
    From #pgIdx
    Where pageNo Between 1 And 200 
    Group by PageNo
    --order by pageNo
    ) as Interm
  ) as racine
Select #pgIdx.* From #pgIdx Where PageNo=0 order by cle

-- VU QUE LES DONNÉES SONT TRIÉES COMMENT SQL PEUT OPTIMISER LA RECHERCHE DANS LE BLOC?
-- ES-CE que la recherche est plus longue si la donnée ORG et ID_ECO N'EST PAS FOURNIE DANS LA REQUETE?
-- QU'ARRIVE T IL SI LE PREMIER SEGMENT DE LA CLE, LE NUMERO DE FICHE N'EST PAS LA?
-- UNE NOUVELLE NOTION SQL EST INTRODUITE DANS CETTE SIMULATION. UNE FONCTION ANALYTIQUE QUI PERMET DE TROUVER LA 
-- VALEUR PRECEDENTE D'UNE VALEUR DANS UNE TABLE PAR RAPPORT A UN ORDRE DONNÉE

Select #pgIdx.* From #pgIdx order by cle

Select *
From
  (
  Select cleAv=Lag(cle,1,'') Over(partition by null order by cle), #pgIdx.* 
  From #pgIdx 
  Where PageNo=0
  --Order by cle
  ) as chemin
Where  '. 145425.824000.243.EMRC2C  .13' between cleAv and cle

Select *
From
  (
  Select cleAv=Lag(cle,1,'') Over(partition by null order by cle), #PgIdx.*
  From #pgIdx 
  Where pageNo=16 -- numéro de page trouvé par recherche dans la racine
  --Order by cle
  ) as chemin
Where  '. 145425.824000.243.EMRC2C  .13' between cleAv and cle

Select * -- au niveau des feuilles de l'arbre toutes les veleurs de clé sont sensées être là, sinon la clé n'est pas trouvée.
From
  (
  Select * 
  From #pgIdx 
  Where pageNo=356 -- numéro de page trouvé dans la page 16 par recherche dans le niveau intermediaire
  order by cle
  ) as chemin
Where  cle='. 145425.824000.243.EMRC2C  .13'

