

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

