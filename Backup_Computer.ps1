<#
.SYNOPSIS
    Effectue la sauvegarde des machines en fonction de leur type et supprime les anciennes sauvegardes.
    Date    : 
    Version : 2.0

.DESCRIPTION
    Ce script sauvegarde les machines (Clients, Serveurs, DC) dans une structure organisée par type et date.
    Il supprime également les sauvegardes plus anciennes que la période définie (par défaut : 15 jours).
    Les sauvegardes sont réalisées avec WBAdmin.

.NOTES
    Prérequis :
    - Module Windows Server Backup installé (pour Serveurs et DC).
    - Compte utilisateur avec droits : Backup Operators + accès écriture au dossier de sauvegarde.

.Licence :
    GNU General Pulic Licence V3.0
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
