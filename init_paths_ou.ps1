# Script Powershell pour initialiser avant creation utilisateurs
#
# Auteur : David Canevet - Alexandre Gauvrit
# Date   : 07-06-2013
# Desc   : Creation des dossiers et OU dans Active Directory avant Creation utilisateurs
############################################################################################
clear

# Paramètres Modifiables
$dcdomain = "dc=test,dc=lan"
$OUeleves = "eleves"
$OUprofs = "profs"
$Drive = "G:\"
$DossierProfils = "profils"
$DossierUtilisateurs = "users"

######################################################
$LDAP = "LDAP://$($dcdomain)"
$Domain = [ADSI]"$ldap"
$path_profils = "$($Drive)$($DossierProfils)" 
$path_profils_profs = "$($Drive)$($DossierProfils)\profs" 
$path_profils_eleves = "$($Drive)$($DossierProfils)\eleves" 
$path_users = "$($Drive)$($DossierUtilisateurs)" 
$path_users_profs = "$($Drive)$($DossierUtilisateurs)\profs" 
$path_users_eleves = "$($Drive)$($DossierUtilisateurs)\eleves" 

# Creation du fichier de log
$date = $(Get-Date -f "yyyy-MM-dd-HH-mm-ss")
$new_name = $date + '_compterendu.txt' 
$file = New-Item -Name "$new_name" -ItemType file -Path "$($Drive)" 

# Function LOG pour log ecran+fichier
Function log([string]$a)
{
  $date_log = $(Get-Date -f "yyyy-MM-dd-HH-mm-ss")
	Write-Host "$($date_log) - $($a)" 
	"$($date_log) - $($a)" >> $file
	$date_log = ""
}

# Test si le dossier $b existe, si il n'existe pas creation
Function test_create_path([string]$b)
{
	if(Test-Path -Path "$b")
	{
		log("le dossier $b existe déja") 
	}
	else
	{
		log("Le dossier $b n'existe pas")
		$result = New-Item -Path $b -ItemType "directory"
		log("Création du dossier $b")
	}
}

# Test si l'Organisational Unit $b existe, si elle n'existe creation
Function test_create_OU([string]$c)
{
	$recherche_ou = "LDAP://OU=$($c),$($dcdomain)"
	if([adsi]::Exists($recherche_ou))
	{
		log("OU $($c) existes")
	}
	else
	{
		log("OU $($c) n'existes pas")
		$objAD = $Domain.Create("OrganizationalUnit", "ou=" + $c)
		$objAD.SetInfo()
		log("Création de l'OU $($c)")
	}
}

# Test et Creation des dossiers
test_create_path($path_profils)
test_create_path($path_profils_profs)
test_create_path($path_profils_eleves)
test_create_path($path_users)
test_create_path($path_users_profs)
test_create_path($path_users_eleves)

# Test et Creation des OU
test_create_OU($OUeleves)
test_create_OU($OUprofs)
