Create Function dbo.OrdisPlusUtilisesParUtilisateur(@utilisateur sysname = 'Pelletierr')
Returns Table
as
Return
Select Top 1 Utilisateur, ordinateur -- parce que les rangées sont toutes pareilles
From 
  (
  Select 
    Utilisateur
  , ordinateur
  , nbOccOrdinateur
  , plusFrequent=MAX(nbOccOrdinateur) Over (Partition by Utilisateur)
  From
    ( -- ajouter 
    Select Utilisateur, ordinateur, nbOccOrdinateur=count(*) Over (Partition by Utilisateur, Ordinateur)
    From
      (Select PrmUtil=@utilisateur) as P
      CROSS APPLY 
      (
      Select Top 10 ordinateur ,utilisateur, ip, dateHeure,domaine
      FROM AuditLogin.dbo.Login 
      Where Utilisateur=P.PrmUtil
      Order By utilisateur, dateHeure Desc
      ) As DixDerniersPostesParUtilisateur
    ) as DecompteOrdis
  ) as LigneFreq
Where nbOccOrdinateur=plusFrequent -- 
