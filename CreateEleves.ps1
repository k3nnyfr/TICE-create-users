########################################################################################################
########################################################################################################
# Script de création d'utilisateurs a partir d'un CSV "eleves.csv"
# Format du fichier élèves :
# 
# Format inspiré du fichier xml rectorat
#	 classe,nom,prenom
#
#
#
# Variables pour la création de mots de passe
#
########################################################################################################
########################################################################################################
#	Librairie a installer :
# 	http://en-us.sysadmins.lv/Lists/Posts/Post.aspx?ID=28
#  
########################################################################################################
########################################################################################################

param([int] $len = 8,[string] $chars = "ABCabc012345678efg9",[string] $nums="0123456789")
$bytes = new-object "System.Byte[]" $len
$rnd = new-object System.Security.Cryptography.RNGCryptoServiceProvider

#Définition du domaine
$smb_serveur = "\\SERVEUR2008\"
$domaine = "stj"
$dc_domaine = "lan"
$ou_eleves = "ou=eleves,dc=$($domaine),dc=$($dc_domaine)"
$ou_profs = "ou=Profs,dc=$($domaine),dc=$($dc_domaine)"
$domain = [ADSI]"LDAP://$($ou_eleves)"
$domain_profs = [ADSI]"LDAP://$($ou_profs)"

# Chemin réseau du dossier docs
$path_eleve = "$($smb_serveur)eleves\"
$path_drive = "E:\Users\eleves\"

# Chemin réseau du dossier profil
$profil_root = "$($smb_serveur)profil\"
$profil_root_eleve = "$($smb_serveur)profil\eleves\"

# Chemin réseau du script de logon
$loginscriptpath = "$($smb_serveur)netlogon\"

#Import du fichier CSV
$csv_users = Import-Csv .\eleves.csv
$current_time = Get-Date –f "yyyy-MM-dd-HH:mm:ss"
$timeforfile = Get-Date –f "yyyyMMdd-HH-mm"

#Fichiers de log
$log_create_eleves = ".\Result-Eleves-CreateAD-$($timeforfile).csv"
"## Fichier de log - CreateEleves - Execution du $current_time" >> $log_create_eleves

Function user_exists($ola)
{
	$LdapFilter = "(&(objectcategory=user)(cn=$ola))"
	$SearchRoot = $domain
	$SearchProf = $domain_profs
	$Searcher = New-Object DirectoryServices.DirectorySearcher($SearchRoot, $LdapFilter)
	$SearcherProfs = New-Object DirectoryServices.DirectorySearcher($SearchProf, $LdapFilter)
	$mariejose = $Searcher.FindAll()
	$jeanpatrick = $SearcherProfs.FindAll()
	if(($mariejose -ne $null) -xor ($jeanpatrick -ne $null))
	{
		return $true; 
	}
	else
	{
		return $false; 
	}
}

Function group_exists($ola)
{
	$LdapFilter = "(&(objectcategory=group)(cn=$ola))"
	$SearchRoot = $domain
	$Searcher = New-Object DirectoryServices.DirectorySearcher($SearchRoot, $LdapFilter)
	$mariejose = $Searcher.FindAll()
	if($mariejose -ne $null)
	{
		return $true; 
	}
	else
	{
		return $false; 
	}
}

Function Remove-Diacritics([string]$String)
{
    $objD = $String.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder

    for ($i = 0; $i -lt $objD.Length; $i++) {
        $c = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($objD[$i])
        if($c -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
          [void]$sb.Append($objD[$i])
        }
      }

    return("$sb".Normalize([Text.NormalizationForm]::FormD))
}


########################################################################################################
########################################################################################################
#	Boucle principale
#  
########################################################################################################
########################################################################################################

#Boucle de création
foreach ($line in $csv_users) 
{
	# Nettoyage nom,prenom
	$nom_famille = $line.nom.Replace(" ","")
	$nom_famille = Remove-Diacritics([string]$nom_famille)
	
	$prenom = $line.prenom.Replace(" ","")
	$prenom = Remove-Diacritics([string]$prenom)
		
	# Init des variables
	$NewPassword = "Toto1234"
		
	#Mot de passe 4 chiffres
	$rnd.GetBytes($bytes)
	
	#for( $i=0; $i -lt $len; $i++ )
	#{
	#	$NewPassword += $chars[ $bytes[$i] % $chars.Length ]	
	#}
		
	$inc = 1
	$login = "$($nom_famille)"
	while(user_exists($login) -eq $true)
	{
		$login = "$($nom_famille)$($inc)"
		$inc += 1
	}
		
	#Fichier de log
	"$($line.classe),$($nom_famille),$($prenom),$($login),$($NewPassword)" >> $log_create_eleves
	
	# Sortie écran pour repère
	Write-Host "$($nom_famille) $($prenom) - $($line.classe) - Login : $login"
	Write-Host " Password : $($NewPassword)"

	#################################################################################################
	#################################################################################################
	#	CREATION DES DOSSIERS
	#  -> Dossier Classe
	#  	-> Dossier Commun
	#  	-> Dossier Utilisateur
	# 
	#	AD : Groupe Classe
	#	AD : Droit de sécurité du groupe classe sur dossier commun
	#
	#################################################################################################
	#################################################################################################

	# Creation du dossier classe dans l'arborescence + Groupe classe AD
	$path_classe = Join-Path $path_eleve -childpath $line.classe
	if(!(Test-Path $path_classe))
	{
		# Le dossier classe n'existe pas -> on le crée
		New-Item $path_classe -type directory | out-null		
	}
		
	$GroupName = "Classe"+$line.classe
	$Groupexists = group_exists("$GroupName")
	if($Groupexists -eq $false)
	{
		$objOU = $domain
		$objGroup = $objOU.Create("group","CN="+$GroupName)
		$objGroup.Put("sAMAccountName", $GroupName )
		$objGroup.SetInfo()
	}
		
		
	# Creation dossier documents utilisateur
	$docs_eleve = Join-Path $path_eleve -childpath $login
	if(!(Test-Path $docs_eleve))
	{
		# Le dossier utilisateur n'existe pas -> on le crée
		New-Item $docs_eleve -type directory | out-null 
	}
	
	# Creation dossier profil utilisateur
	$profil_user = Join-Path $profil_root_eleve -ChildPath $login
	if(!(Test-Path $profil_user))
	{
		New-Item $profil_user -type directory | out-null
	}

	#################################################################################################
	#################################################################################################
	#	CREATION DES UTILISATEURS
	#	-> Utilisateur avec ses identifiants
	#	-> Activation du profil
	#	-> Création du mot de passe
	#	-> Ajout de l'utilisateur au groupe classe
	#
	#################################################################################################
	#################################################################################################
	
	$user_exists = user_exists($login)
	if($user_exists -eq $false)
	{
		# Creation de l'utilisateur
		$newUser = $domain.Create("user","cn=$($login)")
		$newUser.put("sAMAccountName","$($login)")
		$newUser.put("givenName","$($prenom)")
		$newUser.put("sn","$($nom_famille)")
		$newUser.put("title", "Eleve")
		$newUser.put("description", "Eleve de $($line.classe)")
		$newUser.put("displayName","$($nom_famille) $($prenom)")
		
		# Activation du profil
		$newUser.SetInfo()
		$newUser.psbase.InvokeSet("Accountdisabled",$false)
		$newUser.psbase.CommitChanges()

		# Creation du Mot de Passe
		$Userpwd = ([ADSI]"LDAP://CN=$login,$($ou_eleves)")
		$Userpwd.SetPassword($NewPassword)
		$Userpwd.Put("userAccountControl", "65536")
		$Userpwd.SetInfo()
		
		# Ajout au groupe classe
		$Group = [adsi]"LDAP://CN=$GroupName,$($ou_eleves)"
		$User = "LDAP://CN=$login,$($ou_eleves)"
		$Group.Add($User)
	}
	else
	{
		Write-Error "Utilisateur $login existe deja !"
	}
	
	##################################################################################################
	##################################################################################################
	#	PARTAGE RESEAUX
	#	AD :	Partage reseau du dossier eleve Mes Documents
	#	AD :	Droit de sécurité sur dossier eleve Mes Documents
	#
	##################################################################################################
	##################################################################################################	
	
	# Partage réseau samba du dossier classe
	$ShareName = $line.classe+"$"
	$checkShare = (Get-WmiObject Win32_Share -Filter "Name='$ShareName'") 
    if ($checkShare -eq $null)
	{	
		$path_classe_drive = Join-Path $path_drive -childpath $line.classe
		$ShareName = $line.classe+"$"
		$Type = 0
		$objWMI = [wmiClass] 'Win32_share'
		$objWMI.create($path_classe_drive, $ShareName, $Type) | Out-Null
	}
	
	# Partage réseau samba du dossier eleve
	$ShareName = $login+"$"
	$checkShare = (Get-WmiObject Win32_Share -Filter "Name='$ShareName'")
	$path_eleve_drive = Join-Path $path_drive -childpath $login
    if ($checkShare -eq $null)
	{
		$path_eleve_drive = Join-Path $path_drive -childpath $login
		$ShareName = $login+"$"
		$Type = 0
		$objWMI = [wmiClass] 'Win32_share'
		$objWMI.create($path_eleve_drive, $ShareName, $Type) | Out-Null
	}

	# Droit de sécurité sur dossier eleve
	$acl = Get-Acl $path_eleve_drive
	$permission = "$($domaine)\$login","FullControl","Allow"
	$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
	$acl.SetAccessRule($accessRule)
	$acl | Set-Acl $path_eleve_drive
	
	# Droit de sécurité sur dossier eleve
	$acl = Get-Acl $profil_user
	$permission = "$($domaine)\$login","FullControl","Allow"
	$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
	$acl.SetAccessRule($accessRule)
	$acl | Set-Acl $profil_user
	
	#################################################################################################
	#################################################################################################
	#	Attributs de profil itinérant
	#	AD :	Définition du chemin de profil
	#	AD :	Définition du dossier homedir
	#
	#################################################################################################
	#################################################################################################
	
	$user_exists = user_exists($login)
	if($user_exists -eq $true)
	{	
		# Attributs de profil itinerant (dossier, script)
		$Userpwd = [ADSI]"LDAP://CN=$login,$($ou_eleves)"
		
		# Dossier de profil
		$Userpwd.put("profilePath","$profil_user")
		$Userpwd.put("ScriptPath", "$($login).vbs")
		
		# Dossier de base
		$Userpwd.put("homeDrive","H:")
		$Userpwd.put("homeDirectory", "$docs_eleve")
		$Userpwd.SetInfo()
	}
	else
	{
		Write-Host "--- Attributs de profil itinerant ---"
		Write-Host "Utilisateur $login introuvable !"
	}
	
	
	#################################################################################################
	#################################################################################################
	#	Creation du .bat eleve
	#	
	#	Création du fichier .vbs lancé a la connexion
	#
	#################################################################################################
	#################################################################################################	


	$fichier = get-content "$($loginscriptpath)exemple_eleves.vbs" |foreach {$_ -replace "SERVEURSMB",$smb_serveur -replace "LOGIN",$login -replace "CLASSE",$line.classe} 
	set-content "$($loginscriptpath)$($login).vbs" $fichier
	
	#############################
	#	RAZ des variables
	#############################

	$NewPassword = ""
	$id = ""
}



