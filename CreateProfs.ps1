########################################################################################################
# Script de création d'utilisateurs a partir d'un CSV "eleves.csv"
# Format du fichier élèves :
# 
# Format inspiré du fichier xml rectorat
#	 classe,nom,prenom
#
########################################################################################################

#. '.\mklink.psm1'

#### MODIFICATIONS A FAIRE ICI

param([int] $len = 8,[string] $chars = "ABC0123456789",[string] $nums="0123456789")
$bytes = new-object "System.Byte[]" $len
$rnd = new-object System.Security.Cryptography.RNGCryptoServiceProvider

#Définition des paramètres du domaine
$smb_serveur = "\\Serveur2008\"
$domaine = "stj"
$dc_domaine = "lan"

$ou_profs = "ou=Profs,dc=$($domaine),dc=$($dc_domaine)"
$ou_eleves = "ou=Eleves,dc=$($domaine),dc=$($dc_domaine)"

$ldap_domain_ou_profs = [ADSI]"LDAP://$($ou_profs)"
$ldap_domain_ou_eleves = [ADSI]"LDAP://$($ou_eleves)"

# Chemin d'accès documents profs
$path_documents_profs = "E:\Users\profs\"
$smb_documents_profs = "$($smb_serveur)profs\"
$smb_profile_profs = "$($smb_serveur)profil\profs\"
$smb_netlogon = "$($smb_serveur)netlogon\"

$path_web_root = "C:\inetpub\wwwroot"

# FIN DES MODIFICATIONS

########################################################################################################

#Import du fichier CSV
$csv_users = Import-Csv .\profs.csv
$current_time = Get-Date –f "yyyy-MM-dd-HH:mm:ss"

#Fichier de log
$log_result_create = ".\$(get-date -f yyyy-MM-dd-HH-mm) - ResultProfs.csv"
"## Fichier de log - CreateProfs - Execution du $current_time" >> $log_result_create

Function user_exists($ola)
{
	$LdapFilter = "(&(objectcategory=user)(cn=$ola))"
	$SearchRoot_profs = $ldap_domain_ou_profs
	$SearchRoot_eleves = $ldap_domain_ou_eleves
	$Searcher_profs = New-Object DirectoryServices.DirectorySearcher($SearchRoot_profs, $LdapFilter)
	$Searcher_eleves = New-Object DirectoryServices.DirectorySearcher($SearchRoot_eleves, $LdapFilter)
	$result_search_profs = $Searcher_profs.FindAll()
	$result_search_eleves = $Searcher_eleves.FindAll()
	if(($result_search_profs -ne $null) -or ($result_search_eleves -ne $null))
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
	$SearchRoot = $ldap_domain_ou_profs
	$Searcher = New-Object DirectoryServices.DirectorySearcher($SearchRoot, $LdapFilter)
	$result_search_grp = $Searcher.FindAll()
	if($result_search_grp -ne $null)
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

    for ($i = 0; $i -lt $objD.Length; $i++) 
	{
        $c = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($objD[$i])
        if($c -ne [Globalization.UnicodeCategory]::NonSpacingMark) 
		{
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
	$NewPassword = $line.password.Replace(" ","")
		
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
	"$($nom_famille),$($prenom),$($login),$($NewPassword)" >> $log_result_create
	
	# Sortie écran pour repère
	Write-Host "$($nom_famille) $($prenom) - Login : $login"
	Write-Host " Password : $($NewPassword)"

	#################################################################################################
	#################################################################################################
	#	CREATION DES DOSSIERS
	#   -> Dossier Classe
	#  	-> Dossier Commun
	#  	-> Dossier Utilisateur
	# 
	#	AD : Groupe Classe
	#	AD : Droit de sécurité du groupe classe sur dossier commun
	#
	#################################################################################################
	#################################################################################################

	# Creation du dossier classe dans l'arborescence + Groupe classe AD
	$path_groupeprofs = Join-Path $smb_documents_profs -childpath $line.groupe
	if(!(Test-Path $path_groupeprofs))
	{
		# Le dossier classe n'existe pas -> on le crée
		New-Item $path_groupeprofs -type directory | out-null		
	}
		
	$GroupName = $line.groupe
	$Groupexists = group_exists("$GroupName")
	if($Groupexists -eq $false)
	{
		$objOU = $ldap_domain_ou_profs
		$objGroup = $objOU.Create("group","CN="+$GroupName)
		$objGroup.Put("sAMAccountName", $GroupName )
		$objGroup.SetInfo()
	}
		
		
	# Creation dossier documents utilisateur
	$docs_profs = Join-Path $smb_documents_profs -childpath $login
	if(!(Test-Path $docs_profs))
	{
		# Le dossier utilisateur n'existe pas -> on le crée
		New-Item $docs_profs -type directory | out-null 
	}
	
	# Creation dossier profil utilisateur
	$profil_user = Join-Path $smb_profile_profs -ChildPath $login
	if(!(Test-Path $profil_user))
	{
		New-Item $profil_user -type directory | out-null
	}

	#################################################################################################
	#################################################################################################
	#	Creation des Utilisateurs
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
		$newUser = $ldap_domain_ou_profs.Create("user","cn=$($login)")
		$newUser.put("sAMAccountName","$($login)")
		$newUser.put("givenName","$($prenom)")
		$newUser.put("sn","$($nom_famille)")
		$newUser.put("title", "Prof")
		$newUser.put("description", "$($line.groupe)")
		$newUser.put("displayName","$($nom_famille) $($prenom)")
		
		# Activation du profil
		$newUser.SetInfo()
		$newUser.psbase.InvokeSet("Accountdisabled",$false)
		$newUser.psbase.CommitChanges()

		# Creation du Mot de Passe
		$Userpwd = ([ADSI]"LDAP://CN=$login,$($ou_profs)")
		$Userpwd.SetPassword($NewPassword)
		$Userpwd.Put("userAccountControl", "65536")
		$Userpwd.SetInfo()
		
		# Ajout au groupe classe
		$Group = [adsi]"LDAP://CN=$GroupName,$($ou_profs)"
		$User = "LDAP://CN=$login,$($ou_profs)"
		$Group.Add($User)
	}
	else
	{
		Write-Error "Utilisateur $login existe deja !"
	}
	
	##################################################################################################
	##################################################################################################
	#	Partages reseaux
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
		$path_groupeprofs_drive = Join-Path $path_documents_profs -childpath $line.classe
		$ShareName = $line.classe+"$"
		$Type = 0
		$objWMI = [wmiClass] 'Win32_share'
		$objWMI.create($path_groupeprofs_drive, $ShareName, $Type) | Out-Null
	}
	
	# Partage réseau samba du dossier user
	$ShareName = $login+"$"
	$checkShare = (Get-WmiObject Win32_Share -Filter "Name='$ShareName'") 
    if ($checkShare -eq $null)
	{
		$path_profs_drive = Join-Path $path_documents_profs -childpath $login
		$ShareName = $login+"$"
		$Type = 0
		$objWMI = [wmiClass] 'Win32_share'
		$objWMI.create($path_profs_drive, $ShareName, $Type) | Out-Null
	}

	# Droit de sécurité sur dossier user
	$acl = Get-Acl $path_profs_drive
	$permission = "$($domaine)\$login","FullControl","Allow"
	$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
	$acl.SetAccessRule($accessRule)
	$acl | Set-Acl $path_profs_drive
	
	# Droit de sécurité sur dossier user
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
		$Userpwd = [ADSI]"LDAP://CN=$login,$($ou_profs)"
		
		# Dossier de profil
		$Userpwd.put("profilePath","$profil_user")
		$Userpwd.put("ScriptPath", "$($login).vbs")
		
		# Dossier de base
		$Userpwd.put("homeDrive","H:")
		$Userpwd.put("homeDirectory", "$docs_profs")
		$Userpwd.SetInfo()
	}
	else
	{
		Write-Host "--- Attributs de profil itinerant ---"
		Write-Host "Utilisateur $login introuvable !"
	}
	
	#################################################################################################
	#################################################################################################
	#	
	#	Création du fichier .vbs lancé a la connexion
	#
	#################################################################################################
	#################################################################################################	


	$fichier = get-content "$($smb_netlogon)exemple_profs.vbs" |foreach {$_ -replace "SERVEURSMB",$smb_serveur -replace "LOGIN",$login} 
	set-content "$($smb_netlogon)$($login).vbs" $fichier
	
	#################################################################################################
	#################################################################################################
	#	
	#	Last but not least,
	#	Lien symbolique vers /wwwroot/webdav/$user - ok
	#	Paramétrage des droits corrects  - nok
	#	Ajout de la fonctionnalité DAV sur le dossier  - nok
	#	
	#
	#################################################################################################
	#################################################################################################	
	
	# Concatenation de la variable path web user - ex : C:\inetpub\wwwroot\ + loginuser\
	$path_web_user =  Join-Path $path_web_root -childpath $login;
		
	# Creation du lien symbolique
	if(!(Test-Path $path_web_user))
	{
		$result = New-Symlink -LiteralPath $path_web_user -TargetPath $path_profs_drive;
		echo "Symlink $path_web_user to $path_profs_drive has been created !";
	}
	else
	{
		echo "Symlink to user directory already exists!";
	}
		
	#############################
	#	RAZ des variables
	#############################

	$NewPassword = ""
	$id = ""
	

	
	
}



