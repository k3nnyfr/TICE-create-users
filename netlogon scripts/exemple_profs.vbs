On Error Resume Next
Set objNetwork = WScript.CreateObject("Wscript.Network")
WScript.sleep 1000
objNetwork.MapNetworkDrive "H:" , "SERVEURSMBLOGIN$"
objNetwork.MapNetworkDrive "T:" , "SERVEURSMBEleves"
objNetwork.MapNetworkDrive "U:" , "SERVEURSMBProfs_vers_eleves"
objNetwork.MapNetworkDrive "X:" , "SERVEURSMBPublic"
objNetwork.MapNetworkDrive "Y:" , "SERVEURSMBApps"
objNetwork.MapNetworkDrive "P:" , "\\Serveur2003\CHARLEMAGNE"
objNetwork.MapNetworkDrive "S:" , "SERVEURSMBCOMMUN_PROF"