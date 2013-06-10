TICE-create-users
=================

Powershell script creating user accounts for teachers and students from a CSV file

The aim of that script is to bulk create accounts for students and teachers with these features :
- Active Directory account
- Folders creation
- Folder redirection
- Network share of user folder
- Class network share + class group creation
- Netlogon script creation
- One-time password creation
- Export the list of new users in a Timestamped CSV with passwords

Pre-requisites 
--------------
- 2 Organizational Units - 1 for teachers - 1 for students
- 1 Directory for Students profiles
- 1 Directory for Students documents
- 1 Directory for Teachers profiles
- 1 Directory for Teachers documents
- All the steps mentioned before can be executed automatically by launching init_paths_ou.ps1
- Extensions for Powershell : CmdLets for Active Directory : http://www.quest.com/powershell/activeroles-server.aspx

The created profiles are roaming profiles. 
If you want to create mandatory profiles, rework the code

I use PowerGUI Script Editor to develop and debug my code, feel free to use it as well, it helps a lot !
http://powergui.org/downloads.jspa

Files
--------------
- CreateProfs.ps1 : create teachers accounts from csv file
- CreateEleves.ps1 : create students accounts from csv file
- netlogon scripts/exemple_eleves.vbs : template of students netlogon script
- netlogon scripts/exemple_profs.vbs : template of teachers netlogon script
- eleves.csv : CSV source file for students
- profs.csv : CSV source file for teachers
- init_paths_ou.ps1 : create folder structure + Active Directory OU before creation of users

Additional notes
--------------
- I forced one time password for students as Toto1234, easier for everyone
- I forced passwords in teachers CSV file to keep password from a year to another, or to force it with Toto1234

Update - 2013-06-10
--------------
- Added init_paths_ou.ps1 : create folder structure + Active Directory OU before creation of users

TODO
--------------
- Add WebDav access to user documents (WIP)
- Add XML source
- Add GUI
