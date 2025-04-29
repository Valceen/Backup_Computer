<#
## SYNOPSIS
Effectue la sauvegarde des machines en fonction de leur type et supprime les anciennes sauvegardes.<br>
Date    : 2025-04-29<br>
Version : 2.0<br>

## DESCRIPTION
Ce script sauvegarde les machines (Clients, Serveurs, DC) dans une structure organisée par type et date.<br>
Il supprime également les sauvegardes plus anciennes que la période définie (par défaut : 15 jours).<br>
Les sauvegardes sont réalisées avec WBAdmin<br>

## PREREQUIS
- Module Windows Server Backup installé (pour Serveurs et DC), est installé si il n'est pas présent.
- Compte utilisateur avec droits : Backup Operators + accès écriture au dossier de sauvegarde.

## FONCTIONNEMENT
- Faire un premiere sauvegarde manuellement pour que le module Windows Server Backup soit installé.<br>
Changer le nom du serveur par défaut par le votre.
$BackupServer = "\\SERVER"<br>

- Fait un sauvegarde dans le répertoire :<br>
Pour un controlleur de domaine :
\\\\SERVEUR\\DC\\NOM_DE_MACHINE\\DATE (au format yyyy-mm-jj)<br>
Pour un serveur membre :
\\\\SERVEUR\\Serveurs\\NOM_DE_MACHINE\\DATE (au format yyyy-mm-jj)<br>
Pour un client membre :
\\\\SERVEUR\\Clients\\NOM_DE_MACHINE\\DATE (au format yyyy-mm-jj)<br>

Exemple :<br>
\\\\NAS01\\DC\\DC01\\2025-04-29<br>
\\\\NAS01\\Serveurs\\APP01\\2025-04-29<br>
\\\\NAS01\\Clients\\CLI01\\2025-04-29<br>

- Supprime toutes les sauvegardes de plus 15 jours :<br>
$DeleteFolderFiles = (Get-Date).AddDays(-15)

## RECOMMANATION
Fonctionne trés bien avec un compte Gmsa (Group Managed Service Accounts)<br>

Nécéssite :<br>
- droits sur le répertoire de sauvegarde<br>
- membre du groupe Backup Operators<br>

et les droits de la GPO :<br>
- Accéder a cet ordinateur a partir du réseau<br>
- Ouvrir une session en tant que service<br>
- Ouvrir une session en tant que tache<br>
- sauvegarder les fichiers et les répertoires<br>

## Licence
GNU General Public Licence V3.0
https://github.com/Valceen/
#>

Write-Host "=========================== Déclaration des variables ============================" -ForegroundColor Green

# Dossier racine de sauvegarde
$BackupServer = "\\SERVER"
$BackupFolderRoot = "\Backup\"

# Type de machine et chemins spécifiques
$ComputerType = (Get-CimInstance Win32_OperatingSystem).ProductType

Switch ($ComputerType) {
    "1" { $BackupFolderType = "$BackupServer\$BackupFolderRoot\Clients\$env:ComputerName" }
    "2" { $BackupFolderType = "$BackupServer\$BackupFolderRoot\DC\$env:ComputerName" }
    "3" { $BackupFolderType = "$BackupServer\$BackupFolderRoot\Serveurs\$env:ComputerName" }
    Default {
        Write-Host "Type de machine inconnu. Sauvegarde annulée." -ForegroundColor Red
        Exit
    }
}

# Chemin des sauvegardes avec date
$BackupFolderDate = "$BackupFolderType\$((Get-Date).ToString('yyyy-MM-dd'))"
$BackupFileLog = "$BackupFolderDate\$($env:ComputerName)_$((Get-Date).ToString('yyyy-MM-dd_HH-mm')).log"

# Suppression des sauvegardes anciennes
$DeleteFolderFiles = (Get-Date).AddDays(-15)

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""


Write-Host "=========================== Création des dossiers ================================" -ForegroundColor Green

# Création des dossiers si inexistants
@( $BackupFolderRoot, $BackupFolderType, $BackupFolderDate ) | ForEach-Object {
    If (!(Test-Path $_)) {
        New-Item $_ -Type Directory | Out-Null
    }
}

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""


Write-Host "=========================== Import du module de sauvegarde =======================" -ForegroundColor Green

# Vérification du module Windows Server Backup
$BackupModulePath = "$env:windir\System32\wbadmin.exe"
If (-Not (Test-Path $BackupModulePath)) {
    Write-Host "Module Windows Server Backup introuvable. Installation en cours..." -ForegroundColor Yellow
    Install-WindowsFeature Windows-Server-Backup
}

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""


Write-Host "=========================== Exécution de la sauvegarde ============================" -ForegroundColor Green

# Commande de sauvegarde en fonction du type de machine
Switch ($ComputerType) {
    "1" {
        WBAdmin Start systemstatebackup -BackupTarget:$BackupFolderDate -Quiet | Out-File -FilePath $BackupFileLog -Append
    }
    "2" {
        WBAdmin Start Backup -BackupTarget:$BackupFolderDate -systemState -allCritical -vssFull -Quiet | Out-File -FilePath $BackupFileLog -Append
    }
    "3" {
        WBAdmin Start Backup -BackupTarget:$BackupFolderDate -systemState -allCritical -vssFull -Quiet | Out-File -FilePath $BackupFileLog -Append
    }
}

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""


Write-Host "=========================== Suppression des anciennes sauvegardes ==================" -ForegroundColor Green

# Suppression des fichiers anciens
Get-ChildItem $BackupFolderType | Where-Object {$_.LastWriteTime -lt $DeleteFolderFiles} | Remove-Item -Confirm:$False -Recurse -Force

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""
