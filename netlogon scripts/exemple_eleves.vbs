On Error Resume Next
Set objNetwork = WScript.CreateObject("Wscript.Network")
WScript.sleep 1000
objNetwork.MapNetworkDrive "H:" , "SERVEURSMBLOGIN$"
objNetwork.MapNetworkDrive "T:" , "SERVEURSMBCLASSE$"
objNetwork.MapNetworkDrive "X:" , "SERVEURSMBPublic"
objNetwork.MapNetworkDrive "U:" , "SERVEURSMBProfs_vers_eleves"
objNetwork.MapNetworkDrive "Y:" , "SERVEURSMBApps"
