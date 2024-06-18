


-- Trigger qui insère les valeurs avant et après vers une table de "travail" avec indic U, I, D

-- Si U, diff directe des colonnes et seulement des colonnes

-- Si type de rangée insérée est "I"
  --    S'il n'y a pas de rangée delete correspondante, génère liste de chaque colonne de la rangée, valeur avant à NULL
  --    S'il en existe un, liste les colonnes différentes et supprime le delete d'avant, et le Insert
  
-- Si rangée est "D", repère enregistement insert avant ==> implique connaissance de la meilleure clé primaire (unique clustered, unique non clustered)
--    S'il n'y a pas de rangée insert correspondante et s'il la rangée n'existe pas dans la table
--      génère liste de chaque colonne de la rangée, valeur après à NULL
--    Sinon
--      S'il en existe un, liste les colonnes différentes et supprime le insert d'avant ET LE Delete

