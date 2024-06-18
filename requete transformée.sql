SELECT        D.Annee, D.Simul, CASE WHEN X.NbParcours > 0 THEN 1 ELSE 0 END AS IndParcoursPresent, REPLACE(STR(E.Org, 6), ' ', '0') AS Org, E.Org AS OrgNum, REPLACE(STR(E.Fiche, 7), ' ', '0') AS Fiche, E.Fiche AS FicheNum, E.Nom,
                          E.PNom, E.CodePerm, E.DateNais, A.Bloc, B.DateEffectJade, A.DistBat, B.TypeAdrJade, dbo.GEO_FNC_GET_DESCR_ABREG(N'TYPE_ADR', B.TypeAdrJade) AS TypeAdrJadeDesc, A.GenreAdr, 
                         dbo.GEO_FNC_GET_DESCR_ABREG(N'GENRE_ADR', A.GenreAdr) AS GenreAdrDesc, A.NoCiv, A.Rue, A.Ville, A.GenreRue, A.OrientRue, LEFT(A.CodePost, 3) + ' ' + RIGHT(A.CodePost, 3) AS CodePostal, 
                         dbo.GEO_FNC_FORMAT_RUE(A.GenreRue, A.Rue, A.OrientRue, A.Appart) AS RueFmt, dbo.GEO_FNC_GET_DESCR_ABREG(N'GENRE_RUE', A.GenreRue) AS GenreRueDesc, dbo.GEO_FNC_GET_DESCR_ABREG(N'ORIENT_RUE', 
                         A.OrientRue) AS OrientRueDesc, A.IndEnvoiMEQ AS IndEnvoiMELS, SUBSTRING(B.TelTrav1, 1, 3) + '-' + SUBSTRING(B.TelTrav1, 4, 3) + '-' + SUBSTRING(B.TelTrav1, 7, 4) + ' ' + SUBSTRING(B.TelTrav1, 11, 10) AS TelTrav1, 
                         SUBSTRING(B.TelTrav2, 1, 3) + '-' + SUBSTRING(B.TelTrav2, 4, 3) + '-' + SUBSTRING(B.TelTrav2, 7, 4) + ' ' + SUBSTRING(B.TelTrav2, 11, 10) AS TelTrav2, SUBSTRING(B.Telecop, 1, 3) + '-' + SUBSTRING(B.Telecop, 4, 3) 
                         + '-' + SUBSTRING(B.Telecop, 7, 4) + ' ' + SUBSTRING(B.Telecop, 11, 10) AS Telecop, 
                         CASE B.TypeAdrJade WHEN '1' THEN E.NomPere + ' ' + E.PNomPere + ' / ' + E.NomMere + ' ' + E.PNomMere WHEN '2' THEN E.NomPere + ', ' + E.PNomPere WHEN '3' THEN E.NomMere + ', ' + E.PNomMere WHEN '4' THEN E.NomTuteur
                          + ', ' + E.PNomTuteur WHEN '5' THEN E.Nom + ', ' + E.PNom ELSE NULL END AS NomRepondant, D.Bat, D.GrpRepTut, D.CodeTrait, D.IndDeleg, D.OrgMandat, D.DateDebut, D.DateFin, D.NoFreqJade, REPLACE(STR(D.Eco, 3), 
                         ' ', '0') AS Eco, D.Eco AS EcoNum, D.Statut, dbo.GEO_FNC_GET_DESCR_ABREG(N'STATUT_DOSS_ANN', D.Statut) AS StatutDesc, D.OrdreEns, dbo.GEO_FNC_GET_DESCR_ABREG(N'ORDRE_ENS', D.OrdreEns) 
                         AS OrdreEnsDesc, D.Classe, dbo.GEO_FNC_GET_DESCR_ABREG(N'CLASSE', D.Classe) AS ClasseDesc, D.LangEns, dbo.GEO_FNC_GET_DESCR_ABREG(N'LANGUE_ENS', D.LangEns) AS LangEnsDesc, D.ClasseSpec, 
                         dbo.GEO_FNC_GET_DESCR_ABREG(N'CLASSE_SPEC', D.ClasseSpec) AS ClasseSpecDesc, D.Dist, dbo.GEO_FNC_GET_DESCR_ABREG(N'DIST', D.Dist) AS DistDesc, D.NatServ, 
                         dbo.GEO_FNC_GET_DESCR_ABREG(N'NATURE_SERVICE', D.NatServ) AS NatServDesc, D.LanguePelo, dbo.GEO_FNC_GET_DESCR_ABREG(N'LANGUE_PELO', D.LanguePelo) AS LanguePeloDesc, X.HreParcAM, X.DroitTrspAM, 
                         dbo.GEO_FNC_GET_DESCR_ABREG(N'DROIT_TRSP', X.DroitTrspAM) AS DroitTrspAMDesc, dbo.GEO_FNC_FORMAT_HRE_MIN(X.HreEmbNumAM) AS HreEmbAM, dbo.GEO_FNC_FORMAT_HRE_MIN(X.HreDebNumAM) 
                         AS HreDebAM, dbo.GEO_FNC_GET_ELAPSE_MINUTES(X.HreEmbNumAM, X.HreDebNumAM) AS TempsDeplAM, dbo.GEO_FNC_CONVERT_MIN_HRE(dbo.GEO_FNC_GET_ELAPSE_MINUTES(X.HreEmbNumAM, X.HreDebNumAM)) 
                         AS TempsDeplHreAM, X.CodeEmbAM1, X.NomEmbAM1, X.TypeEmbAM1, X.NoParcAM1, X.NoCircAM1, X.NoParcNumAM1, X.NoCircNumAM1, X.StationnementAM1, X.HrePassageAM1, X.CodeEmbAM2, X.NomEmbAM2, 
                         X.TypeEmbAM2, X.NoParcAM2, X.NoCircAM2, X.NoParcNumAM2, X.NoCircNumAM2, X.StationnementAM2, X.HrePassageAM2, X.CodeEmbAM3, X.NomEmbAM3, X.TypeEmbAM3, X.NoParcAM3, X.NoCircAM3, X.NoParcNumAM3, 
                         X.NoCircNumAM3, X.StationnementAM3, X.HrePassageAM3, X.CodeEmbAM4, X.NomEmbAM4, X.TypeEmbAM4, X.NoParcAM4, X.NoCircAM4, X.NoParcNumAM4, X.NoCircNumAM4, X.StationnementAM4, 
                         dbo.GEO_FNC_GET_DESCR_ABREG(N'DROIT_TRSP', X.DroitTrspM1) AS DroitTrspM1Desc, X.DroitTrspM1, X.HreParcM1, X.HreEmbNumM1, X.HreDebNumM1, X.CodeDebM1_1, X.NomDebM1_1, X.TypeDebM1_1, 
                         X.NoParcM1_1, X.NoCircM1_1, X.NoParcNumM1_1, X.NoCircNumM1_1, X.StationnementM1_1, X.HrePassageM1_1, dbo.GEO_FNC_GET_DESCR_ABREG(N'DROIT_TRSP', X.DroitTrspM2) AS DroitTrspM2Desc, X.DroitTrspM2, 
                         X.HreParcM2, X.HreEmbNumM2, X.HreDebNumM2, X.CodeEmbM2_1, X.NomEmbM2_1, X.TypeEmbM2_1, X.NoParcM2_1, X.NoCircM2_1, X.NoParcNumM2_1, X.NoCircNumM2_1, X.StationnementM2_1, X.HrePassageM2_1, 
                         X.HreParcPM, X.DroitTrspPM, dbo.GEO_FNC_GET_DESCR_ABREG(N'DROIT_TRSP', X.DroitTrspPM) AS DroitTrspPMDesc, dbo.GEO_FNC_FORMAT_HRE_MIN(X.HreEmbNumPM) AS HreEmbPM, 
                         dbo.GEO_FNC_FORMAT_HRE_MIN(X.HreDebNumPM) AS HreDebPM, dbo.GEO_FNC_GET_ELAPSE_MINUTES(X.HreEmbNumPM, X.HreDebNumPM) AS TempsDeplPM, 
                         dbo.GEO_FNC_CONVERT_MIN_HRE(dbo.GEO_FNC_GET_ELAPSE_MINUTES(X.HreEmbNumPM, X.HreDebNumPM)) AS TempsDeplHrePM, X.StationnementPM, X.CodeDebPM1, X.NomDebPM1, X.TypeDebPM1, X.NoParcPM1, 
                         X.NoCircPM1, X.NoParcNumPM1, X.NoCircNumPM1, X.StationnementPM1, X.HrePassagePM1, X.CodeDebPM2, X.NomDebPM2, X.TypeDebPM2, X.NoParcPM2, X.NoCircPM2, X.NoParcNumPM2, X.NoCircNumPM2, 
                         X.StationnementPM2, X.HrePassagePM2, X.CodeDebPM3, X.NomDebPM3, X.TypeDebPM3, X.NoParcPM3, X.NoCircPM3, X.NoParcNumPM3, X.NoCircNumPM3, X.StationnementPM3, X.HrePassagePM3, X.CodeDebPM4, 
                         X.NomDebPM4, X.TypeDebPM4, X.NoParcPM4, X.NoCircPM4, X.NoParcNumPM4, X.NoCircNumPM4, X.StationnementPM4, X.HrePassagePM4, dbo.GEO_B_BAT.Nom AS NomEcole, NULL AS CodeDebPM5, D.DonUtil6
FROM            
  dbo.GEO_E_ADR AS A 
  INNER JOIN
  dbo.GEO_E_BLOC AS B 
  ON B.Org = A.Org AND B.Fiche = A.Fiche AND B.Annee = A.Annee AND B.Simul = A.Simul AND B.Bloc = A.Bloc 
  INNER JOIN
  dbo.GEO_E_DOSS_ANN AS D 
  ON D.Org = A.Org AND D.Fiche = A.Fiche AND D.Annee = A.Annee AND D.Simul = A.Simul 
  INNER JOIN
  dbo.GEO_E_ELE AS E 
  ON E.Org = D.Org AND E.Fiche = D.Fiche 
  INNER JOIN
  dbo.GEO_B_BAT 
  ON D.Annee = dbo.GEO_B_BAT.Annee AND D.Simul = dbo.GEO_B_BAT.Simul AND D.Bat = dbo.GEO_B_BAT.Bat 
  LEFT OUTER JOIN
  (
  SELECT        
    T.Annee, T.Simul, T.IdAdr, COUNT(TP.Ordre) AS NbParcours, 
    MAX(CASE WHEN T .Per = 1 THEN T .DroitTrsp ELSE NULL END) AS DroitTrspAM, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN dbo.GEO_FNC_FORMAT_HRE_MIN(P.HreDeb) ELSE NULL END ELSE NULL END) AS HreParcAM, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN EMB.HrePassage ELSE NULL END ELSE NULL END) AS HreEmbNumAM, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN DEB.HrePassage ELSE NULL END ELSE NULL END) AS HreDebNumAM, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeEmbAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN CASE EMB.TypeStop WHEN 1 THEN EMB.NomStop WHEN 4 THEN 'Domicile' END ELSE NULL END ELSE NULL END) AS NomEmbAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' END ELSE NULL END ELSE NULL END) AS TypeEmbAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN EMB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 1 THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassageAM1, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN EMB.CodeStop ELSE NULL END ELSE NULL END) AS CodeEmbAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN EMB.NomStop ELSE NULL END ELSE NULL END) AS NomEmbAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN CASE EMB.TypeStop WHEN 3 THEN 'E' END ELSE NULL END ELSE NULL END) AS TypeEmbAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN EMB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 2 THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassageAM2, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN EMB.CodeStop ELSE NULL END ELSE NULL END) AS CodeEmbAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN EMB.NomStop ELSE NULL END ELSE NULL END) AS NomEmbAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN CASE EMB.TypeStop WHEN 3 THEN 'E' END ELSE NULL END ELSE NULL END) AS TypeEmbAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN EMB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 3 THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassageAM3, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN EMB.CodeStop ELSE NULL END ELSE NULL END) AS CodeEmbAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN EMB.NomStop ELSE NULL END ELSE NULL END) AS NomEmbAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN CASE EMB.TypeStop WHEN 3 THEN 'E' END ELSE NULL END ELSE NULL END) AS TypeEmbAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumAM4, 
    MAX(CASE WHEN TP.Per = 1 THEN CASE WHEN TP.Ordre = 4 THEN EMB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementAM4, 
    MAX(CASE WHEN T .Per = 2 THEN T .DroitTrsp ELSE NULL END) AS DroitTrspM1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN LEFT(REPLACE(STR(P.HreDeb, 4), ' ', '0'), 2) + ':' + RIGHT(REPLACE(STR(P.HreDeb, 4), ' ', '0'), 2) ELSE NULL END ELSE NULL END) AS HreParcM1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN DEB.HrePassage ELSE NULL END ELSE NULL END) AS HreEmbNumM1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = 1 THEN EMB.HrePassage ELSE NULL END ELSE NULL END) AS HreDebNumM1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeDebM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'Domicile' ELSE EMB.NomStop END ELSE NULL END ELSE NULL END) AS NomDebM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' WHEN 3 THEN 'D' END ELSE NULL END ELSE NULL END) AS TypeDebM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN EMB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementM1_1, 
    MAX(CASE WHEN TP.Per = 2 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassageM1_1, 
    MAX(CASE WHEN T .Per = 4 THEN T .DroitTrsp ELSE NULL END) AS DroitTrspM2, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN dbo.GEO_FNC_FORMAT_HRE_MIN(P.HreDeb) ELSE NULL END ELSE NULL END) AS HreParcM2, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN EMB.HrePassage ELSE NULL END ELSE NULL END) AS HreEmbNumM2, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN DEB.HrePassage ELSE NULL END ELSE NULL END) AS HreDebNumM2, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeEmbM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN CASE EMB.TypeStop WHEN 1 THEN EMB.NomStop WHEN 4 THEN 'Domicile' END ELSE NULL END ELSE NULL END) AS NomEmbM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' END ELSE NULL END ELSE NULL END) AS TypeEmbM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN EMB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementM2_1, 
    MAX(CASE WHEN TP.Per = 4 THEN CASE WHEN TP.Ordre = 1 THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassageM2_1, 
    MAX(CASE WHEN TP.Per = 8 THEN T .DroitTrsp ELSE NULL END) AS DroitTrspPM,
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN dbo.GEO_FNC_FORMAT_HRE_MIN(P.HreDeb) ELSE NULL END ELSE NULL END) AS HreParcPM, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN DEB.HrePassage ELSE NULL END ELSE NULL END) AS HreEmbNumPM, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = 1 THEN EMB.HrePassage ELSE NULL END ELSE NULL END) AS HreDebNumPM, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeDebPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'Domicile' ELSE EMB.NomStop END ELSE NULL END ELSE NULL END) AS NomDebPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' WHEN 3 THEN 'D' END ELSE NULL END ELSE NULL END) AS TypeDebPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN DEB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementPM, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (4 - (4 - Z.NbOrdre)) THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassagePM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeDebPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'Domicile' ELSE EMB.NomStop END ELSE NULL END ELSE NULL END) AS NomDebPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' WHEN 3 THEN 'D' END ELSE NULL END ELSE NULL END) AS TypeDebPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN DEB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementPM1, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (3 - (4 - Z.NbOrdre)) THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassagePM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeDebPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'Domicile' ELSE EMB.NomStop END ELSE NULL END ELSE NULL END) AS NomDebPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' WHEN 3 THEN 'D' END ELSE NULL END ELSE NULL END) AS TypeDebPM3, MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN DEB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementPM2, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (2 - (4 - Z.NbOrdre)) THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassagePM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'DOM-' ELSE EMB.CodeStop END ELSE NULL END ELSE NULL END) AS CodeDebPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 4 THEN 'Domicile' ELSE EMB.NomStop END ELSE NULL END ELSE NULL END) AS NomDebPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN CASE EMB.TypeStop WHEN 1 THEN 'A' WHEN 4 THEN 'C' WHEN 3 THEN 'D' END ELSE NULL END ELSE NULL END) AS TypeDebPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN REPLACE(STR(EMB.NoParc, 5), ' ', '0') ELSE NULL END ELSE NULL END) AS NoParcPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN REPLACE(STR(P.NoCirc, 3), ' ', '0') ELSE NULL END ELSE NULL END) AS NoCircPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN EMB.NoParc ELSE NULL END ELSE NULL END) AS NoParcNumPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN P.NoCirc ELSE NULL END ELSE NULL END) AS NoCircNumPM4, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN DEB.Stationnement ELSE NULL END ELSE NULL END) AS StationnementPM3, 
    MAX(CASE WHEN TP.Per = 8 THEN CASE WHEN TP.Ordre = (1 - (4 - Z.NbOrdre)) THEN dbo.GEO_FNC_FORMAT_HRE_MIN(EMB.HrePassage) ELSE NULL END ELSE NULL END) AS HrePassagePM4, NULL AS StationnementPM4
    FROM            
      dbo.GEO_E_TRSP AS T 

      LEFT OUTER JOIN
      dbo.GEO_E_TRSP_PARC AS TP 
      ON T.Org = TP.Org AND T.Fiche = TP.Fiche AND T.Annee = TP.Annee AND T.Simul = TP.Simul AND T.Bloc = TP.Bloc AND T.Per = TP.Per 

      LEFT OUTER JOIN
      (
      SELECT   Org, Fiche, Annee, Simul, Bloc, Per, COUNT(Ordre) AS NbOrdre
      FROM      dbo.GEO_E_TRSP_PARC
      GROUP BY Org, Fiche, Annee, Simul, Bloc, Per
      ) AS Z 
      ON Z.Annee = TP.Annee AND Z.Simul = TP.Simul AND Z.Org = TP.Org AND Z.Fiche = TP.Fiche AND Z.Bloc = TP.Bloc AND Z.Per = TP.Per 
      LEFT OUTER JOIN
      dbo.GEO_P_PARC AS P 
      ON TP.Annee = P.Annee AND TP.Simul = P.Simul AND TP.IdParc = P.IdParc 
      LEFT OUTER JOIN
      dbo.GEO_P_POINT_SRV AS EMB 
      ON EMB.Annee = TP.Annee AND EMB.Simul = TP.Simul AND EMB.IdPointSrv = TP.IdEmb 
      LEFT OUTER JOIN
      dbo.GEO_P_POINT_SRV AS DEB 
      ON DEB.Annee = TP.Annee AND DEB.Simul = TP.Simul AND DEB.IdPointSrv = TP.IdDeb
    GROUP BY T.Annee, T.Simul, T.IdAdr
  ) AS X 
  ON A.Annee = X.Annee AND A.Simul = X.Simul AND A.IdAdr = X.IdAdr
WHERE        
  (D.Annee = CASE WHEN month(getdate()) < 7 THEN year(getdate()) - 1 ELSE year(getdate()) END) AND (D.Simul = 0)