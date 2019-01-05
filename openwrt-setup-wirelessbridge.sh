##!/bin/ash
#openwrt squasfs/os uses ash shell
# remove first #-character from line 1 (one) if necessary

#helper function
lastCommandResult(){
    action="$1"
    if [ $? -gt 0 ] ; then 
        echo " ERROR: $action seems to have given some problems. Please check " 
        exit 1
    else 
        echo " ok" 
    fi
}

setupSystem(){
	echo -n "Setting up hostname & timezone to OpenWrt & America/Toronto"
	{ uci set system.@system[0].hostname='OpenWrt'  && \
	uci set system.@system[0].zonename='America/Toronto' && \
	uci set system.@system[0].timezone='EST5EDT,M3.2.0,M11.1.0' ;}
	lastCommandResult "setting up system"
	uci commit system
}

#In order to download necessary programs we need to connect to internet.
#Here we do so via router's wifi. So, let's set it up
connectInternetViaWifi(){
    #config: /etc/config/wireless
	
	#Enable radio0
	echo -n "Enabling radio0 ..."
	uci set wireless.radio0.disabled='0'
	lastCommandResult "enabling radio0"
	#uci set wireless.@wifi-device[0].disabled=0
	wifi

	uci commit wireless
    
    echo "Enter SSID of wifi you want to connect to internet through. Use quotation marks if the name includes white spaces:"
    read rawSSID
    # sanitize ssid by removing (double/single) quotation marks
    SSID="`echo "$rawSSID"| sed 's@^"\|^\\047@@g' | sed 's@"$\|\\047$@@g'`"
    echo "Enter passphrase for wifi. Just press enter if none. Use quotation marks if the passphrase includes white spaces:"
    read rawWifiPASSWD
    # sanitize rawWifiPASSWD by removing (double/single) quotation marks
    wifiPASSWD="`echo "$rawWifiPASSWD"| sed 's@^"\|^\\047@@g' | sed 's@"$\|\\047$@@g'`"
    #
	echo "Choose country # (for wifi dev set up):"
	echo "1) Canada"
	echo "2) US"
	read country
	echo "...$country"
	case $country in
		1) country="CA" ;;
		2) country="US" ;;
		*) echo "ERROR: unrecognized country" ; exit ;;
	esac
	#
    echo -n "Automatically determining primary channel ..."
    channel="xxx"
    channel=`iw dev wlan0 scan | grep "SSID\|primary channel" | grep -A 1 "$SSID"| grep channel| awk '{print $NF}'`
    lastCommandResult "determinging channel $channel"
    #
	echo -n "Create network for internet (wan) access ..."
	{ uci set network.wwan=interface && \
	uci set network.wwan.proto='dhcp' ;}
	lastCommandResult "creating wwan network"
	uci commit network
	#
    echo -n "Setting up internet access via wifi ..."
    { uci set wireless.radio0.channel=$channel && \
	uci set wireless.radio0.country=$country && \
    uci set wireless.@wifi-iface[0].network='wwan' && \
    uci set wireless.@wifi-iface[0].mode=sta && \
    uci set wireless.@wifi-iface[0].encryption=psk2 && \
    uci set wireless.@wifi-iface[0].ssid="$SSID" && \
    uci set wireless.@wifi-iface[0].key="$wifiPASSWD" ;}
    lastCommandResult "setting up internet access via wifi" 
    uci commit wireless 
    #
    echo -n "Restarting wifi ..."
    #{ wifi down  && \
	{ ifup wwan && \
    wifi ;}
    lastCommandResult "restarting wifi"
	#
	#echo -n "Restarting dhcpd"
	#/etc/init.d/odhcpd restart
	#lastCommandResult "restarting dhcpd"
    echo "Testing IP assigned (may take a little: waiting 10 sec for AP to assign IP) ..."
	sleep 10 && ping -c 4 8.8.8.8
}

#install required relay packages: relayd and, for luci, luci-proto-relay
installRelayPkgs(){
    echo -n "Updating list of packages..."
    opkg update
    lastCommandResult "updating package list"
    #
    echo -n "installing relayd"
    opkg install relayd
    lastCommandResult "installing relayd"
    #
    echo -n "installing luci-ssl for https access"
	opkg install luci-ssl 
    lastCommandResult "installing lucy-ssl"
    #
	echo -n "installing ipset ..."
	opkg install ipset
    lastCommandResult "installing ipset"
    #
    echo -n "Disabling http access. Only encrypted HTTPS or ssh (if already set) will be possible"
    uci delete uhttpd.main.listen_http 
    lastCommandResult "disabling http"
    uci commit 
    #
    echo -n "Do you want to install luci (GUI) support (luci-proto-relay) for relay config? [Y/n] "
    read wantlucirelay
    case $wantlucirelay in
        n*|N*) echo " ... no" ;;
        *) opkg install luci-proto-relay 
            lastCommandResult "installing lucy-proto-relay" ;;
    esac
    #
    echo -n "Enabling relayd ..."
    /etc/init.d/relayd enable
    lastCommandResult "enabling relayd"
}

## GLOBAL variable: relay interface name 'relayIF' used by other functions !
# setupRelayInterface
# setupClientAndBridgeNetworkIP
#
relayIF="wirelessBridge" 
#
setupRelayInterface(){
    #config: /etc/config/network

    #Declaring relay interface
    echo -n "Declaring relay interface $relayIF ..."
    { uci set network.${relayIF}=interface && \
    uci set network.${relayIF}.proto=relay && \
    uci set network.${relayIF}.network="lan wwan" ;}
    lastCommandResult "declaring relay iface" 

    #add gateway and dns to lan interface
    #Find the IP address of default gateway for the network you will be repeating
    { defaultGwIP=`route -n|grep UG| awk '{print $2}'` && \
    uci set network.lan.gateway=$defaultGwIP && \
    uci set network.lan.dns=$defaultGwIP ;}
    lastCommandResult "setting up default gw IP"
    #
    echo -n "Committing network relay and lan gw Ip and dns configuration ..."
    uci commit network
    lastCommandResult "committing configuration"
}

disableDHCP(){
    #Since DHCP requests from LAN will be answered by the wireless AP the router is connecting to, the local DHCP server must be disabled in order to avoid collisions later on.
    #Edit /etc/config/dhcp and locate the existing DHCP pool for LAN and mark it as ignored:
    
    echo "Disabling DHCP from LAN and setting IPv6 to relay ..."
    { uci set dhcp.lan.ignore=1
    #
    #For enabling IPv6 properly These options have to be set for lan interface to
    uci set dhcp.lan.ra=relay && \
    uci set dhcp.lan.ndp=relay && \
    uci set dhcp.lan.dhcpv6=relay ;}
    lastCommandResult "disabling DHCP/setting IPv6"
    #
    echo -n "Committing dhcp config ..."
    uci commit dhcp
    lastCommandResult "committing dhcp config"
}

setupLANFirewall(){
    #In contrast to true bridging, packets forwarded by relayd are handled by the normal routing system internally, this means they're also affected by firewall policies set on LAN.
    #Edit /etc/config/firewall and locate the existing LAN zone definition, add the new wwan to it in order to apply the same policies on LAN and the wireless client.

    echo -n "Setting up LAN firewall to accept ..."
    { uci set firewall.@zone[0].forward=ACCEPT && \
    uci set firewall.@zone[0].network="lan wwan" && \
    uci commit firewall ;}
    lastCommandResult "set & commit LAN fw config"
}

optionalCreateWifiNetworkForRepeating(){
    #If your equipment is multi-SSID capable, besides the wired interface, you can also bridge the network into a new wireless network. Just create a new network in access point (AP) mode under /etc/config/wireless:

    echo -n "Do you want to create optional Wireless network for repeating(bridging) as well? [y/N] "
    read wantwifirepeat
    case $wantwifirepeat in
        y*|Y*) echo " ... yes";;
        *) echo " ... no" ; return 0;;
    esac
    echo -n "Enabling wifi network for relaying ..."
    { uci add wireless wifi-iface && \
    uci set wireless.@wifi-iface[1].device=radio0 && \
    uci set wireless.@wifi-iface[1].network=lan && \
    uci set wireless.@wifi-iface[1].mode=ap && \
    uci set wireless.@wifi-iface[1].ssid=RepeaterWirelessNetwork && \
    uci set wireless.@wifi-iface[1].encryption=psk2 && \
    uci set wireless.@wifi-iface[1].key=RepeaterWirelessPassword && \
    uci commit wireless ;}
    lastCommandResult "setting up optional relay wifi"
}

#GLOBAL variable used later by function
# restartAllSystems
# ip_wwan
ip_wwan="x.x.x.x"
determineBridgeIP(){
    echo "Determining bridge network IP ..."
    { . /lib/functions/network.sh && \
    network_get_ipaddr ip_wwan wwan && \
    echo -n $ip_wwan ;}
    lastCommandResult "determining bridge network IP"
    echo "Router WWAN IP : $ip_wwan"
}

setupClientAndBridgeNetworkIP(){
    determineBridgeIP
	#
    #Enable access from client network
    #You will have trouble reaching the router from the client network if the client ip is not changed. To get to it you'll need to manually set the IP address on your computer to an IP address on the same subnet (like 192.168.2.201 if you set the router lan ip to 192.168.2.1).
    #Either you make sure the main router is statically assigning the relay router the same IP address all the time
    # OR
    #do it automatically by adding the following lines to /etc/hotplug.d/iface/<xx>-relay:
    hotplugPath=/etc/hotplug.d/iface
    hotplugFnum=30
    hotplugFn=${hotplugPath}/${hotplugFnum}-relay
    { test -e $hotplugFn && \
    echo -n "WARNING file $hotplugFn already exists. Will try to fix automatically ..." && \
    hotplugFnum=69 && \
    hotplugFn=${hotplugPath}/${hotplugFnum}-relay && \
    test -e $hotplugFn && \
    echo -e "\nFATAL ERROR: fixing filename to $hotplugFn didn't work" && return 1 ;}
    #
    echo -n "Enabling automatic access from client network ..."
    cat<<EOS > $hotplugFn
    # enable access from client network
    [ "\$INTERFACE" = wwan ] || exit 0
    [ "\$ACTION" = ifup -o "\$ACTION" = ifupdate ] || exit 0

    . /lib/functions/network.sh; network_get_ipaddr ip wwan;

    uci set network.${relayIF}.ipaddr=\$ip
    uci commit network
EOS
    #
    echo -n "Making sure the lan interface on this router is in another subnet than your main network ..."
    lanet=`echo $ip_wwan | awk -F '.' '{s=100;if( $3>s){$3-=s}else{$3+=s};printf("%d.%d.%d.%d\n",$1,$2,$3,$4)}'`
    #
    { uci set network.lan.ipaddr=$lanet && \
    uci commit network ;}
    lastCommandResult "setting lan ip"
}

restartAllSystems(){
	if [ $ip_wwan = "x.x.x.x" ] ; then determineBridgeIP ; fi
	#
    echo -n "Restart dnsmasq, firewall & wifi ..."
    { /etc/init.d/dnsmasq restart && \
    /etc/init.d/firewall restart ;}
    lastCommandResult "restarting services"
    #
    echo "System ready for reboot. Access this router through new WWAN IP: $ip_wwan"
    #
    echo "Reboot needed. If you choose not to reboot now, most likely you will lose your ssh connection... Hard reboot your router then."
    echo -n "Proceed manually if you answer here no. Reboot now? [Y/n] "
    read rboot
    case $rboot in
        n*|N*) rboot="true"; echo "NO. Do it manually then. Most likely you will lose your ssh connection now...Hard reboot your router then.";;
        *) echo " yes. Rebooting router now."; rboot="reboot" ;;
    esac
    wifi down ; wifi
	$rboot 
}

usage(){
cat<<EOU
Usage: $0  [--help | --run [stage] | --full-help | --info | --minimize]

Sets up an openwrt-compatible router as a wireless bridge

This script requires user intervention.
EOU
}

info(){
cat<<EOFH


NOTE

In the following instructions, you may want to add the following option to any use of scp or ssh:
    -o 'StrictHostKeyChecking no'
if you did an upgrade or a reset. This will avoid a failed secured connection due to the router's new host-id being
different that the previously one stored in your computer.
Alternatively, you may remove the offending key (192.168.1.1) from your computer's ~/.ssh/known_hosts file.

These instructions/this script do/does the job, but you may want to do some steps differently. See 

   https://oldwiki.archive.openwrt.org/doc/recipes/relayclient

   https://openwrt.org/docs/guide-user/network/wifi/relay_configuration


SCRIPT INSTRUCTIONS

1) If you just simply installed/sysupgraded openwrt or reset the router via reset button at the back:

    1.0) Copy this script from your computer to the router via scp
        scp openwrt-setup-wirelessbridge.sh root@192.168.1.1:

    1.1) Setup a ssh-key (otherwise no more ssh logins possible). Requires you have already or generate first a pair of public-private ssh keys. Google.
        -cli: IF you haven't yet changed the router's root password, store the authorized_keys file under /etc/dropbear
        a) scp ~/.ssh/id_rsa.pub root@192.168.1.1:/tmp 
        b) ssh root@192.168.1.1
        3) cat /tmp/id_rsa.pub >> /etc/dropbear/authorized_keys

        -GUI: Go to 'System->Admin'. Paste content of id_dsa.pub in the textbox at the bottom. Press 'Save&apply'.

    1.2) Change root password. Connect to router via ethernet and:
        -cli: 
        a)  ssh root@192.168.1.1
        b)  passwd 

        -GUI: open browser at http://192.168.1.1 and click on button "change password" either on front page or within 'System->Administration'

    1.3) Run this script and follow instructions
        a) ssh root@192.168.1.1
        b) chmod +x openwrt-setup-wirelessbridge.sh
        c) ./openwrt-setup-wirelessbridge.sh  

2) If your missing a step and want to apply it: read the script (modify it if you feel like) and apply the corresponding code/run modified script


TOPOLGOY of the WIRELESS BRIDGE 

. LAN                     router-bridging-to-main-hotspot_or_AP               AP          other-computers_or_internet-aka-wan 
. 
. --------                   -----------------------------               ------------------               @@@@@@@@@@@@@@
. | c1   | ------------------|     LAN     |    WWAN      |              |   Hotspot      |              @     wan      @
. |      |                   | ether ports |  wlan-#1     | ~ ~~~ ~~~ ~~ |  (e.g., phone) | ~~~~ ~~~ ~~~ @      e.g.    @
. | dhcp |                   |    or       |              |              |      or        |              @ SIP-Internet @
. --------                   |  wlan-#2    | dhcp/fixed   |              |   main AP      | \             @@@@@@@@@@@@@
. 192.168.43.104             | 192.168.3.1 | 192.168.43.43|              ------------------  \ 
.                           -----------------------------                  192.168.43.1       \ 
.                                                                                             -----------
.                                                                                             |  c2     |
.                                                                                             -----------
.                                                                                               192.168.43.201

Once your router is set as wireless bridge:
1) Computers on the LAN/wlan-#2 side, transparently get IP's given by the AP -not your router!
2) Your router will have one of its wlan interfaces working as a client with an IP provided by the AP, e.g., 192.168.43.43
3) The LAN, and other wlan interfaces if you choose so, must have an IP-net different from that of the AP's one, e.g., 192.168.3.1

For this to work with openwrt, this script uses relayd.

It will download the following packages (all minimal footprint):
 1) relayd
 2) luci-ssl
 3) luci-proto-relay
 4) ipset

FULL PROCEDURE OVERVIEW

openwrt + wireless bridge

1.-Install openwrt
2.-Set up wireless bridge

1.1.-Update to latest factory firware
1.2.-Flash openwrt factory.img
 1.2.1.-After router reboot & power led stable, reload http://192.168.1.1  in browser. New ui shows up!
 1.3.-Set up openwrt
 1,3,1.-Root passwd, sshd basic conf, ssh-pubkey
 1.3.2.-Scan radio0 and join desired AP
 1.3.2.1.-FW settings: zone unset
 1.3.2.2.-Country code
2.1.-Installing software
 2.1.1.-Update pkgs list
 2.1.1.-Install luci-ssl & setup https only
   2.1.1.2.-Disable http &restart uttpd
2.2.-Setup station (wwan-end of wifi-bridge)
 2.2.1.-Install luci-proto-relay (install also relayd)
 2.2.2.-enable relayd
 2.2.3.-Declare relay iface, i.e., wireless bridge
 2.2.4.-Add gw & dns to lan
 2.2.5.-Disable local dhcp server
 (skip 2.2.6.- enable ipv6 properly)
 2.2.6.-Set firewall for lan to all accept
 2.2.7.-Apply changes: restart dnsmasq, 
(Missing online:: 2.2.8.- restart relayd !)
 2.2.9.- Restart wifi (down; wifi)
 2.2.10.-Check lan ip.network != AP 
 2.2.11.-Set wBridge IP = IP-wwan & initd auto-conf
 2.2.11.-Reboot      

 

PROBLEMS (yet to confirm if already solved)

LAN/ether loses IP; requires discon/connect again cables. However, after a while, NO IP is assigned to a wired client ANYMORE -not even after reboot.
That is, lost all chance of connecting & managing router!


TESTED

Tested with a Linksys WRT1900AC ver1 (product label shows no v1; ver2 is the one actually showing v2 on it)

Good luck.

PS: Please report if you find any bug or is not working for you. 

EOFH
}

main(){
	STEP=0
	case $1 in
		--run) shift
            case $1 in
				connect*|internet*|system|sys*|Sys*) STEP=0;;
			    install*|pack*) STEP=1;;
                relay*|bridge) STEP=2;;
                disable*|dhcp|DHCP) STEP=3;;
                firewall|fw) STEP=4;;
                optional*|wireless*) STEP=5;;
                client*|IP*|ip*) STEP=6;;
                restart*|finish|reboot) STEP=7;;
			esac
			;;
        --full-help) info ; return 0;;
		--info) info | sed -n '/^SCR/,/^TOP/p' | grep -v TOP; cat $0| sed -n '/^#bsteps/,/^#esteps/p' | grep -v "steps"; return 0;;
        --min*) cat $0 | grep -v '#' | sed -n '/^setupSystem/,/^main/p'|grep -v '()\|lastCommandResult\|^}'| grep -v "^$" | sed 's@echo -n@echo@g' |sed 's@&& \\$@@g'| sed 's@;}@@g' | sed 's@{ @@g' | sed 's@^[[:space:]]*\(.\)@\1@g' | grep -v US | sed -n '1,/^\$rboot/p'| grep -v determineBridgeIP > $0-minimized ;
            echo "Created $0-minimized"
            echo "WARNING:: EXPERIMENTAL! :: Fix manually : test hotplug lines (aprox. 111-116) by appending '&& \' at end of each line (except last)";
            return 0 ;;
		*) usage $0 ; return 0;;
	esac
    while [ $STEP -ge 0 ] ; do
#bsteps
        case $STEP in
            0) setupSystem ; connectInternetViaWifi ;;
	        1) installRelayPkgs ;;
	        2) setupRelayInterface ;;
	        3) disableDHCP ;;
	        4) setupLANFirewall ;;
	        5) optionalCreateWifiNetworkForRepeating ;;
	        6) setupClientAndBridgeNetworkIP ;;
	        7) restartAllSystems ;;
#esteps
			*) STEP=-10 ;;
		esac
		STEP=$(( STEP + 1 ))
	done
}

main $@
