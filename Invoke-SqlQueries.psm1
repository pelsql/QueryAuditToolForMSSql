function Invoke-SqlQueries   
{
<#
.SYNOPSIS
    Exécute et retourne l'ensemble de RESULTSETS sous forme de tableau
    L'utilisateur peut spécifier quel RESULTSET qu'il désire obtenir ou l'ensemble (par défaut)
    Auteur : Maurice Pelchat 

.DESCRIPTION
    Cette fonction exéctute un script SQL par batch en séparant chacune des séries de ligne par des instructions [GO]
    Le script peut être fournis directement sous forme de chaîne de caractère ou dans un fichier.
    Les messages d'erreur son capturés par un handler.
    
.EXAMPLE 
    # ----- Éxécution à partir d'un fichier script (les messages d'erreurs son envoyé dans le canal STDOUT)
    
    Invoke-SqlQueries -inputFile ".\YourSQLDba_InstallOrUpdateScript.sql" -serverInstance ".\isql2012" 

.EXAMPLE
    # ----- Obtenir le détail des noms de fichiers physiques associés à la base de données à partir d'un fichier de backup
    
    $pathBkps = "C:\isql2012\backups\myDb.bak"
    $db = "MyDb"
    $sql = 
@"
    RESTORE FileListOnly 
    FROM  DISK = N'$PathBkps$db.bak'
"@

    $BkpInfo = Invoke-SqlQueries -ServerInstance $ServerInstance -Database Master -GetResultSet 1 -Queries $sql 
    
    # ----- Filter row set that we assumes in which there is only two rows
    
    $Data = $BkpInfo | Where-Object -Property Type -In -Value 'D' | Select-Object -Property LogicalName, PhysicalName
    $Logs = $BkpInfo | Where-Object -Property Type -In -Value 'L' | Select-Object -Property LogicalName, PhysicalName

    Write-Host "Data file logical name : $($Data.LogicalName) Physical name : $($Data.PhysicalNam)"
    Write-Host "Log  file logical name : $($Logs.LogicalName) Physical name : $($Logs.PhysicalNam)"
.NOTES
    Chaque  RESULTSET retourné est un objet contenant un tableau dont chaque lignes est une rangée et les proriétés de l'objet sont les colonnnes.
    Il peut être utilisé en chainage avec les instrucions  Where-Object, Select-Object etc.
#>
    [CmdletBinding()]
    param 
    (
      ## Le script SQL sous forme de chaîne de caractère  
      [string]$queries
    , ## Le nom du fichier de script SQL
      [string]$inputFile
    , ## Le nom de l'instance de SQL Server
      [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$serverInstance
    , ## Le nom de la base de donnée
      [string]$Database
    , ## Le Login
      [string]$User
    ,  ## Le mot de passe
      [string]$Pwd
    , ## Spécifie l'index du ResultSet ciblé à retourner  
      [int]$GetResultSet = -1  
    , ## Affiche les messages
      [int]$HideInformationMsg
    , ## Formate de façon lisible les résultats (pour affichage seulement --> ne peut être utilisé pour traiter les résultats)
      [switch]$FormatResult
    , ## Arrête l'execution du script SQL et envoie une exception au lieu du Write-Error
      [switch]$ThrowExceptionOnError
    , ## Fichier Log d'output
      [string] $OutputLogFileName
    , ## On traite les --GO
      [switch] $GO
    )

    # ----- On envoie le resultat complet
    if ($OutputLogFileName -ne '')
    {
        if ((Get-PSCallStack)[1].Command -ne 'Invoke-SqlQueries')
        {
            # ----- Nous sommes au premier niveau d'appel, alors on peut se rappeler en redirigeant les outputs 
            #       et doubler la canal vers un fichier
            $bp = $PSBoundParameters
            Invoke-SqlQueries @PSBoundParameters *>&1 | Tee-Object $OutputLogFileName -Append
            
            # ----- Si cest variables ont été définis alors on doit changer leur portées pour qu'elles soient accessibles par l'appelant
            if ($bp['ErrorVariable'])
            {
                Invoke-Expression "`$global:$($bp['ErrorVariable']) = `$$($bp['ErrorVariable'])"
            }

            if ($bp['WarningVariable'])
            {
                Invoke-Expression "`$global:$($bp['WarningVariable']) = `$$($bp['WarningVariable'])"
            }

            if ($bp['OutVariable'])
            {
                Invoke-Expression "`$global:$($bp['OutVariable']) = `$$($bp['OutVariable'])"
            }
            
            if ($bp['PipelineVariable'])
            {
                Invoke-Expression "`$global:$($bp['PipelineVariable']) = `$$($bp['PipelineVariable'])"
            }
                
            return
        }
    }

    if ($inputFile -ne '') 
    {   
        if ($GO.IsPresent)
        {
            $script = Get-Content $inputFile
            $ErrorActions = $script | where {$_ -like '--GO*'}

            $script = $script.foreach({if ($_ -like '--GO*'){'--GO'} else {$_}})
            $chunks = @(($script | Out-String).Split(@("`r`n--GO"), [System.StringSplitOptions]::None))
        }
        else
        {          
            $chunks = @(Get-Content $inputFile -ReadCount 0 | Out-String)
        }
    }
    else
    {
        $chunks = @($queries)
    }

    if ($chunks.Count -gt 1 -and $GetResultSet -ne -1)
    {
        $msg = "Vous ne pouvez pas spécifier le paramètre [GetResultSet] pour une requête possédant plusieurs BATCH"
        $Err = $msg + "`r`n---------- Stack ----------`r`n" + ((Get-PSCallStack).InvocationInfo.PositionMessage -join "`r`n") 
        Write-Error -Message $Err                

        if ($ThrowExceptionOnError.IsPresent)
        {
            throw $msg
        }
        else
        {           
            return
        }
    }

    # ----- Variables globales pour le Handler
    New-Variable -Name SqlErrCount -Scope global -Force -Value 0
    New-Variable -Name SQLError -Scope global -Force
    New-Variable -Name InTryCatch -Scope global -Force -Value $false

    if ($user -ne '')
    {
        $SqlCon = new-object System.Data.SqlClient.SQLConnection("Data Source=$serverInstance;User=$User;Password=$pwd;Initial Catalog=$database;App=Invoke-SqlQueries");
    }
    else
    {
        $SqlCon = new-object System.Data.SqlClient.SQLConnection("Data Source=$serverInstance;Trusted_Connection=True;Initial Catalog=$database;App=Invoke-SqlQueries;WSID=Contournement");
    }
    
    # ----- Le Handler
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] `
    {
        param($sender, $event) 

        # ----- On sort si pas d'erreur
        If ($event.Errors.count -eq 0) 
        {
            return
        }

        $SQLError = @()

        if (-not $global:InTryCatch)
        {
            # ----- Ramasse toute les erreurs potentielle
            Foreach ($err in $event.Errors) 
            {
                If ($err.Message -ne $null)  
                {               
                    If ($Err.Class -ge 0 -and $err.Class -le 10)  
                    {
                        # ----- Message d'information
                        If ($HideInformationMsg -eq 0)
                        {
                                Write-Warning $Err.Message 
                        }
                    }
                    else 
                    {
                        # ----- Message d'erreur
                        $global:SqlErrCount++
                        $ProcedureMsg = @($null, ", Procedure: $($err.Procedure)")[$err.Procedure -ne ""]
                        $global:SQLError += "`r`nMsg $($err.Number), Level $($err.Class), State $($err.State)$ProcedureMsg, Line $($err.LineNumber) `r`n$($err.Message)"                                
                    } 
                } 
            }
        } 
    }

    # ----- Ajout du Handler
    $SqlCon.add_InfoMessage($handler)    
    $SqlCon.FireInfoMessageEventOnUserErrors = $true 
     
    $retrycount = 0

    # on implemente un retry parce que pour des traitements
    # lourds sur des serveurs en lot, on a parfois des délais
    while ($retrycount -le 3)
    {
        try
        {
            $SqlCon.Open()
            Break
        }
        catch
        {
            $retrycount += 1
            if ($retrycount -GE 3)
            {
                Write-Error "$($_) Chaîne de connexion: $($sqlcon.connectionString)" 
                if ($ThrowExceptionOnError.IsPresent)
                {
                    throw "$($_) Chaîne de connexion: $($sqlcon.connectionString)" 
                }
                else
                {
                    return
                }
            }
        }
    }

    for ($ind = 0; $ind -lt $chunks.Count; $ind++)
    {  
        $queries = $chunks[$ind]

        if ($GO.IsPresent)
        {
            if ($ErrorActions[$ind] -like "--GO E+*")
            {           
                $global:InTryCatch = $false
            }

            if ($ErrorActions[$ind] -like "--GO E-*")
            {           
                $global:InTryCatch = $true
            }
        }

        $SqlBatches = @()
          
        # ----- Prendre une copie de la requête avec les commentaires et litéraux strippé
        $copy = (Hide-LiteralsAndComments $queries) -split "`r`n"

        # ----- Remplacer les lignes contenant uniquement 'GO' par la marque $MarkChar
        $MarkChar = '■'
        $queries = (($queries -split "`r`n" ) | % {$i = 0} {if ($_.Trim() -eq 'GO' -and $copy[$i] -eq $_) {$MarkChar} else {$_}; $i++}) -join "`r`n"
        $queries = $queries -replace "`r`n$MarkChar`r`n", $MarkChar -replace "$MarkChar`r`n", $MarkChar -replace "`r`n$MarkChar", $MarkChar

        # ---- On split en plusieurs Batches
        $SqlBatches += $queries -split $MarkChar

        if ($SqlBatches.Count -gt 1 -and $GetResultSet -ne -1)
        {
            $msg = "Vous ne pouvez pas spécifier le paramètre [GetResultSet] pour une requête possédant plusieurs BATCH"
            $Err = $msg + "`r`n---------- Stack ----------`r`n" + ((Get-PSCallStack).InvocationInfo.PositionMessage -join "`r`n") 
            Write-Error -Message $Err                

            if ($ThrowExceptionOnError.IsPresent)
            {
                throw $msg
            }
            else
            {           
                return
            }
        }

          
        $rsCount = 0  

        # ----- Execute chaque Batch
        Foreach ($batch in $SqlBatches)
        {   
            # ----- Affiche la Batch
            $DisplayBatch = (($batch -split "`r`n") | % {$i = 1} {("{0:D4} " -f $i) + $_; $i++}) -join "`r`n"
            Write-Verbose "`r`n/*$('-' * 40)`r`n$DisplayBatch`r`n$('-' * 40)/*" 
        
            if ($batch -eq '')
            {
                continue
            }
           
            # ----- Exécute la Batch
            $cmd = new-object System.Data.SqlClient.SqlCommand($batch, $SqlCon);
            $cmd.CommandTimeout = 0 # Pas de limite au temps d'exécution
            $reader = $cmd.ExecuteReader()

            # ----- On arrête s'il y a une erreur
            If ($global:SqlErrCount -gt 0 -and -not $global:InTryCatch) 
            {
                $reader.Close()
                $SqlCon.FireInfoMessageEventOnUserErrors = $false    
                $SqlCon.Close()                      
                $msg = $global:SQLError + "`r`n---------- Stack ----------`r`n" + ((Get-PSCallStack).InvocationInfo.PositionMessage -join "`r`n")  
                Write-Error $msg       

                if ($ThrowExceptionOnError.IsPresent)
                {
                    throw $global:SQLError
                }
                else
                {
                   return
                }                    
            }

            # ----- Tant qu'il y a des résultats
            do
            {
                $rs = @()

                while ($reader.Read())
                {
                    $row = [ordered]@{} 

                    for ($i = 0; $i -lt $reader.FieldCount; $i++)
                    {
                        $colName = $reader.GetName($i)  

                        # ----- Donner le nom "NoName" à la colonne s'il n'y en a pas
                        if ($colName -eq "") 
                        { 
                            $colName = "NoName{0:D4}" -f $i
                        }

                        $row[$colName] = $reader.GetValue($i) 
                    }

                    $rs += ,(new-object psobject -property $row)            
                }

                # ----- S'il y a des résultats
                if ($reader.FieldCount -gt 0) 
                { 
                    $rsCount++ 

                    # ----- On retourne l'ensemble des resultsets si l'option GetResultSet n'est pas spécifiée ou si GetResultSet est spécifié, on retourne le bon
                    If ($GetResultSet -eq -1 -or $GetResultSet -eq $rsCount)
                    {
                        # ----- On formatte le résultat si demandé
                        if ($FormatResult.IsPresent)
                        {
                            $rs  | Format-Table -AutoSize -Wrap
                        }
                        else
                        {
                            $rs
                        }
                    }
                } 
            } while ($reader.NextResult())
        
            # ---- Une erreur peut survenir au $reader.nextResult()
            If ($global:SqlErrCount -gt 0 -and -not $global:InTryCatch) 
            {
                $reader.Close(); 
                $SqlCon.FireInfoMessageEventOnUserErrors = $false 
                $SqlCon.Close();            
                $msg = $global:SQLError + "`r`n---------- Stack ----------" + ((Get-PSCallStack).InvocationInfo.PositionMessage -join "`r`n") 
                Write-Error -Message $msg       
            
                if ($ThrowExceptionOnError.IsPresent)
                {             
                    throw $global:SQLError
                }
                else
                {
                    return
                }                                                         
            }

            $reader.Close()
        }        
    }

    $SqlCon.FireInfoMessageEventOnUserErrors = $false 
    $SqlCon.Close();
}  

<#
.SYNOPSIS
    Cache tout commentaire et litéraux d'une requête SQL   
#>
function Hide-LiteralsAndComments
{
    param 
    (
      ## Le script SQL sous forme de chaîne de caractère  
      [string]$query
    )

    [char[]]$query = [char[]]$query
    
    # ----- On boucle sur chaque caractère
    for ($i = 0; $i -lt $query.Count; $i++)
    {
        # ----- Cas du litéral (on strippe jusqu'au prochain ['])
        if ($query[$i] -eq '''')
        {        
            if (($i + 1) -ge $query.Count)
            {
                break
            }

            $i++
        
            while ($query[$i] -ne '''' -and $i -lt $query.Count)
            {
                if ($query[$i] -ne "`r" -and $query[$i] -ne "`n")
                {
                    $query[$i] = ' '
                }               

                $i++
            }

            if ($i -ge $query.Count)
            {
                break
            }
        }

        # ----- Cas du commentaire -- (on strippe jusqu'au prochain <cr>)
        if (($i + 1) -lt $query.Count -and $query[$i] -eq '-' -and $query[$i + 1] -eq '-')
        {
            $i++

            if (($i + 1) -ge $query.Count)
            {
                break
            }

            $i++

            while ($query[$i] -ne "`r" -and $i -lt $query.Count)
            {           
                $query[$i] = ' '            
                $i++
            }

            if ($i -ge $query.Count)
            {
                break
            }
        }
       
        # ----- Cas du commentaire /* (on strippe jusqu'au prochain */ correspondant)
        if (($i + 1) -lt $query.Count -and $query[$i] -eq '/' -and $query[$i + 1] -eq '*')
        {
            $depth = 1
            $i++

            while ($i -lt $query.Count -and $depth -gt 0)
            {
                $i++
              
                if (($i + 1) -lt $query.Count -and $query[$i] -eq '/' -and $query[$i + 1] -eq '*')
                {
                    $query[$i] = ' '
                    $i++
                    $query[$i] = ' '
                    $depth++
                    continue
                }

                if (($i + 1) -lt $query.Count -and $query[$i] -eq '*' -and $query[$i + 1] -eq '/')
                {
                    $i++

                    if ($depth -ne 1)
                    {
                        $query[$i - 1] = ' '
                        $query[$i] = ' '
                    }
                    
                    $depth--
                    continue
                }

                if ($query[$i] -ne "`r" -and $query[$i] -ne "`n")
                {
                    $query[$i] = ' '
                }              
            }
        }
    }

    $query -join ''
}


function Invoke-SqlQueriesWithLog   
{
<#
.SYNOPSIS
    Exécute et retourne l'ensemble de RESULTSETS sous forme de tableau
    L'utilisateur peut spécifier quel RESULTSET qu'il désire obtenir ou l'ensemble (par défaut)
    Auteur : Maurice Pelchat 

.DESCRIPTION
    Cette fonction exéctute un script SQL par batch en séparant chacune des séries de ligne par des instructions [GO]
    Le script peut être fournis directement sous forme de chaîne de caractère ou dans un fichier.
    Les messages d'erreur son capturés par un handler.
#>

    [CmdletBinding()]
    param 
    (
      ## Le script SQL sous forme de chaîne de caractère  
      [string]$queries
    , ## Le nom du fichier de script SQL
      [string]$inputFile
    , ## Le nom de l'instance de SQL Server
      [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$serverInstance
    , ## Le nom de la base de donnée
      [string]$Database
    , ## Le Login
      [string]$User
    ,  ## Le mot de passe
      [string]$Pwd
    , ## Spécifie l'index du ResultSet ciblé à retourner  
      [int]$GetResultSet = -1  
    , ## Affiche les messages
      [int]$HideInformationMsg
    , ## Formate de façon lisible les résultats (pour affichage seulement --> ne peut être utilisé pour traiter les résultats)
      [switch]$FormatResult
    , ## Arrête l'execution du script SQL et envoie une exception au lieu du Write-Error
      [switch]$ThrowExceptionOnError
    )
}

