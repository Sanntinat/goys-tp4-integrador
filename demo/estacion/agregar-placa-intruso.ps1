# Agrega a la estacion la placa del INTRUSO (H4), para quien ya creo la VM con crear-vm.ps1 antes de H4.
# Uso, con la VM apagada:  powershell -ExecutionPolicy Bypass -File demo\estacion\agregar-placa-intruso.ps1
#
# Placa 3: tunel UDP hacia la nube INTRUSO de GNS3 (puertos 45003 -> 45002), cableada a ISP-1 e1.
# En promiscuo para que lleguen las tramas dirigidas al container INTRUSO (macvlan, otra MAC).
param([string] $Nombre = "ESTACION-TP4")
$ErrorActionPreference = "Stop"
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

$estado = (& $vbm showvminfo $Nombre --machinereadable | Select-String '^VMState=').Line
if ($estado -notmatch '"poweroff"|"aborted"') {
  throw "La VM tiene que estar apagada ($estado). Dentro de la estacion: sudo poweroff"
}

& $vbm modifyvm $Nombre --nic3 generic --nictype3 82540EM --nicgenericdrv3 UDPTunnel `
  --cableconnected3 on --nicpromisc3 allow-all
& $vbm modifyvm $Nombre --nicproperty3 dest=127.0.0.1 --nicproperty3 sport=45003 --nicproperty3 dport=45002

& $vbm showvminfo $Nombre | Select-String '^NIC 3'
