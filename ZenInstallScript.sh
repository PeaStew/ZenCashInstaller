#!/usr/bin/env bash

# Author: @PeaStew
# Credits: Lukas Bures, Rolf Versluis
#############################################
#References:
# test hostname and IP  ping -a $(hostname -I | awk '{print$1}') | head -n 1 | awk '{print$2}'
# get balance curl https://explorer.zensystem.io/insight-api-zen/addr/
# https://stackoverflow.com/questions/1955505/parsing-json-with-unix-tools
# curl -s https://explorer.zensystem.io/insight-api-zen/addr/znnV3Mb9TPbRAK6CR2pgunW23V91f2RU1h6 | python -c "import sys, json; print json.load(sys.stdin)[ 'balance' ]" | tail -n1
# -----------------------------------------------------------------------------------------------------------------
# YOU CAN MANUALLY SET THESE VARIABLES OR SET THEM BY RUNNING THE SCRIPT:
# Fully Qualified Domain Name
## Get IP address from ifconfig. Assumption: usually first result
declare -a basicSetupPackages=("curl" "pwgen" "bc")
declare -a basicSetupPackagesDescription=("to check ZEN balance and Blockchain Status" "for psuedo-random user/password generation" "for mathematical calculations")
STEP_THROUGH_INSTALL='y'
PREAMBLE_DISPLAYED='n'
SERVER_IP_ADDR=$(ifconfig -a | head -n 2 | grep inet | awk '{print$2}' | sed 's/addr\://')
SERVER_IP_ADDR_MANUAL=""
## Username for running zend daemon and homke directory
RUN_USER=$USER
ACCEPT_RUN_USER='y'
RUN_USER_VALID='n'
FQDN=''
FQDN_IP_ADDR=''
FQDN_AND_IP_ADDR_VALID='n'
ACCEPT_FQDN=y
USESSHPUBLICKEY='y'
SSHPUBLICKEY=""
ACCEPT_SSHPUBLICKEY='y'
MIN_STAKE_BALANCE=42
STAKE_ADDR=""
STAKE_ADDR_VALID='n'
STAKE_ADDR_BALANCE=0
STAKE_ADDR_BALANCE_FLOAT=''
ACCEPT_STAKE_ADDR='y'
SETUPACCEPTED='n'
USERNAME=$(pwgen -s 16 1)
PASSWORD=$(pwgen -s 64 1)



### Functions

## Display Functions
displayKVBlueWhite2col () {
    echo -e $'\e[96m'$1$'\e[39m'$2
}
displayKeyValueGreenWhite2col () {
    echo -e $'\e[96m'$1$'\e[39m'$2
}

##Comparison functions 
#accepts 2 strings and compares them, returns FALSE/TRUE with appropriate colours
stringComparison () {
    if [ "$1" == "$2" ]
    then
        echo -e "\e[92mTRUE\e[39m"
    else
        echo -e "\e[91mFALSE\e[39m"
    fi
}

numberComparisonA_gte_B () {
   if (( $1 >= $2 ))
    then
        echo -e "\e[92mTRUE\e[39m"
    else
        echo -e "\e[91mFALSE\e[39m"
    fi 
}

displayBreakLine () {
    echo "---------------------------------------------------------------------"
}

displayPreamble () {
if [ $PREAMBLE_DISPLAYED == 'n' ]
then
    clear
    echo -e "\e[96mThis setup was created for the ZenCash community and"
    echo -e "tries to simplify the standard setup provided by blockops"
    echo -e "while increasing the security aspects.\n"
    echo -e "The setup is designed to be run on Ubuntu 16.04 LTS, on a VPS"
    echo -e "with minimum 4GB of RAM. If you have less, the setup will"
    echo -e "add Swap space until a total of 6GB (RAM + Swap) has been"
    echo -e "achieved. There is no guarantee that any VPS with less than"
    echo -e "4GB of RAM will be able to pass the challenges in the required"
    echo -e "time, ymmv.\n"
    echo -e "The minimum following detail is required before starting:\e[39m\e[93m"
    echo -e "* A domain name in the Fully Qualified Domian Name (FQDN)\n  format e.g. xyz.yourdomain.com which has\n  been mapped with an A record on your domain host\n  to your server IP (auto retrieved\n, please check with your host if it doesn't seem right): $SERVER_IP_ADDR"
    echo -e "* A new username if you start the installation as root"
    echo -e "* A public Zen address \e[4mon your local wallet\e[24m\n  with 42 ZEN for staking\n\e[39m"
    echo -e "Optional but recommended:\e[39m\e[93m"
    echo -e "* An SSH private/public key (only public key needed for this setup)"
    echo -e "  details can be found at these links for your \e[4mlocal\e[24m operating system:"
    echo -e "  Linux: https://www.howtoforge.com/linux-basics-how-to-install-ssh-keys-on-the-shell"
    echo -e "  Windows: https://www.ssh.com/ssh/putty/windows/puttygen"
    echo -e "  MacOSX: https://www.macworld.co.uk/how-to/mac-software/how-generate-ssh-keys-3521606/\e[39m"
    echo -e "  \e[96mActual setup of the public key on this server will be done for you\n  and instructions on how to access the server afterwards will be given.\n\e[39m"
    read -p "If you are ready to continue please press any key now. If you want to cancel press ctrl+c." CONTINUE
    PREAMBLE_DISPLAYED='y'
    displayBreakLine
fi
}




doBasicSetup ()
{
    echo -e "Checking if needed packages are installed:"
    
    echo -e "Installing the following packages:"
    ITER=0
        for I in ${basicSetupPackages[@]}
        do  
            displayKVBlueWhite2col "${I} " "${basicSetupPackagesDescription[${ITER}]}"
            ITER=$(expr $ITER + 1)
        done
    sudo apt-get install curl pwgen bc -y > /dev/null
    displayBreakLine
}

## Gets username and checks for invalid
getUserName () {
displayPreamble
if [ "$RUN_USER" == "root" ]
then
    while [ "$RUN_USER_VALID" != "y" ]
    do
        read -rep $'\e[96mThis script will not install ZenCash SecureNode as root,\nplease enter a new user name to install with (min 6 characters)\nand press [enter]:\e[39m ' RUN_USER 
        ################# 
        if [ "$RUN_USER" == "root" ] || [ "$RUN_USER" == "" ] || [ ${#RUN_USER} -lt 6 ]
        then
            echo -e "\e[91mUser name is still root, blank or too short, please try again.\e[39m"
            continue
        else
            RUN_USER_VALID='y'
        fi
    done
else
    echo -e "\e[96mCurrent username is \"$RUN_USER\", do you want to"
    read -rep $'use this user to install ZenCash SecureNode? (y/n):\e[39m ' ACCEPT_RUN_USER 
    if [ "$ACCEPT_RUN_USER" != "y" ]
    then
        read -rep $'\e[96mPlease enter a new user name to install\nwith (min 6 characters) and press [enter]:\e[39m ' RUN_USER 
        if [ "$RUN_USER" == "root" ] || [ "$RUN_USER" == "" ] || [ ${#RUN_USER} -lt 6 ]
        then
            echo -e "\e[91mUsername invalid restarting...\e[39m"
            RUN_USER=$USER
            getUserName
        fi
    fi        
fi
displayBreakLine
}

## Gets FQDN
getFQDN () {
displayPreamble
while [ "$FQDN_AND_IP_ADDR_VALID" != "y" ]
do
    # Initial check after loop
    if [ "$FQDN_IP_ADDR" == "$SERVER_IP_ADDR" ]
    then
        FQDN_AND_IP_ADDR_VALID=y
        echo -e "\e[92mFQDN IP Address and server IP Address match.\e[39m"
        break
    fi

    read -rep $'\e[96mPlease enter your Fully Qualified Domain Name (FQDN)\ne.g. secnode1.yourdommain.com and press [enter]:\e[39m ' FQDN
    FQDN_IP_ADDR=$(getIPAddressFromFQDN $FQDN)
    if [ "$FQDN_IP_ADDR" == 0 ]
    then
        echo -e "\e[91mFQDN does not return any result, please ensure that\nyou have added an A record on your domain host for\nthe FQDN and the IP address of this server. Restarting...\e[39m"
        continue
    fi
    if [ "$FQDN_IP_ADDR" != "$SERVER_IP_ADDR" ]
        then
            echo -e "\e[91mThe auto retrieved IP address $SERVER_IP_ADDR and\nFQDN IP address $FQDN_IP_ADDR do not match, please ensure\nthat you have added an A record on your\ndomain host for the FQDN and the IP address of this server.\n\e[39m"
            read -rep $'\e[96mIf you are sure you have done this correctly\nalready and want to continue, please enter the IP\naddress of your server now and press [enter]\n, or just leave entry blank and press [enter] to try again:\e[39m ' SERVER_IP_ADDR_MANUAL
            if [ "$SERVER_IP_ADDR_MANUAL" == "" ]
            then
                SERVER_IP_ADDR=$(ifconfig -a | head -n 2 | grep inet | awk '{print$2}' | sed 's/addr\://')
                continue
            else
                SERVER_IP_ADDR=$SERVER_IP_ADDR_MANUAL
                continue
            fi
        else
            echo -e "\e[92mFQDN IP Address and server IP Address match.\e[39m"
            FQDN_AND_IP_ADDR_VALID='y'
    fi
done
displayBreakLine
}

## Get IP address from FQDN
getIPAddressFromFQDN () {
displayPreamble
FQDN_TEST=$(ping -a $1 | head -n 1 | awk '{print$3}' | sed s/\(// | sed s/\)//)
if echo $FQDN_TEST | grep -q "." &&  ! echo $FQDN_TEST | grep -q "Usage" && ! echo $FQDN_TEST | grep -q "unknown" 
then
    echo $FQDN_TEST
else
    return 0 
fi
}

setZENtAddressBalance () {
    STAKE_ADDR_BALANCE_FLOAT=$(curl -s https://explorer.zensystem.io/insight-api-zen/addr/$1 | python -c "import sys, json; print json.load(sys.stdin)[ 'balance' ]" | tail -n1)
    STAKE_ADDR_BALANCE=$(( ${STAKE_ADDR_BALANCE_FLOAT%.*} + 0 ))
}

## Gets Stake Address
getStakeAddress () {
displayPreamble
while [ "$STAKE_ADDR_VALID" != "y" ]
do
    read -rep $'\e[96mPlease enter your public ZenCash Stake Address\nwith 42 ZEN on it which starts with \"zn...\" and is 35\ncharacters long, (this should be in your local wallet,\nnot on the node!) and press [enter]:\e[39m ' STAKE_ADDR 
    ################# Test if Stake Address format matches expected t_addr type
    if [ ${#STAKE_ADDR} -ne 35 ] || (( $(echo -e "$STAKE_ADDR" | cut -c-2) != "zn" ))
    then
        echo -e "\e[91mIncorrect address length or type, stake addresses\nmust be public ZenCash addresses (t addr, 35 chars long)\nand from a wallet on the main blockchain.\e[39m"
        continue
    else 
        ################# Test stake address using explorer insight api
        setZENtAddressBalance "$STAKE_ADDR"
        if [[ $STAKE_ADDR_BALANCE -lt 42 ]]
        then
            echo -e "\e[91mCurrent stake address balance is invalid: $STAKE_ADDR_BALANCE_FLOAT which is below the required 42 ZEN\e[39m"
        else
            echo -e "\e[92mCurrent stake address balance is valid: $STAKE_ADDR_BALANCE_FLOAT\e[39m"
            STAKE_ADDR_VALID='y'
        fi
    fi
done
displayBreakLine
}

## Gets public key if wanted
getSSHPublicKey () {
displayPreamble
read -rep $'\e[96mIt is recommended that you use a public/private SSH key with this node\nfor logging, do you want to enter one now? (y/n) and press [enter]:\e[39m ' USESSHPUBLICKEY 

if [ "$USESSHPUBLICKEY" == 'y' ]
then
    while [ ${#SSHPUBLICKEY} == 0 ] || [ "$SSHPUBLICKEY" == "" ] && [ "$USESSHPUBLICKEY" == 'y' ]
    do
        read -rep $'\e[96mPlease enter public key now and press [enter]:\e[39m ' SSHPUBLICKEY 
        if [ ${#SSHPUBLICKEY} == 0 ] || [ "$SSHPUBLICKEY" == "" ]
        then
            read -rep $'\e[91mSSH public key is invalid please try entering again and pressing [enter] or press n and [enter] to cancel: \e[39m' CONTINUE
            if [ $CONTINUE == 'n']
            then
                USESSHPUBLICKEY='n'
            fi    
        fi
    done
fi
displayBreakLine
}

getTotalRAM () {
    local RAM=$(free -h | tail -n2 | head -n1 | awk '{print$2}' | sed 's/G//')
    echo $RAM
}

getTotalSwap () {
    local Swap=$(free -h | tail -n1 | awk '{print$2}' | sed 's/G//')
    echo $Swap
}

#shows current details
showSetupDetails () {
    displayKVBlueWhite2col "Username: " $RUN_USER
    displayKVBlueWhite2col "FQDN: " $FQDN
    displayKVBlueWhite2col "FQDN IP Address: " $FQDN_IP_ADDR
    displayKVBlueWhite2col "Server IP Address: " $SERVER_IP_ADDR
    displayKVBlueWhite2col "FQDN IP Address and Server IP Address Match: " "$(stringComparison $FQDN_IP_ADDR $SERVER_IP_ADDR)"
    displayKVBlueWhite2col "Stake Address: " $STAKE_ADDR
    displayKVBlueWhite2col "Stake Address Balance: " $STAKE_ADDR_BALANCE_FLOAT
    displayKVBlueWhite2col "Stake Address Balance Valid: " "$(numberComparisonA_gte_B $STAKE_ADDR_BALANCE 42)"
}

################# Start collecting needed variables
displayPreamble
doBasicSetup
while [ "$SETUPACCEPTED" != 'y' ]
do
    getUserName
    ################# Get FQDN
    getFQDN
    ################# Get Stake Address
    getStakeAddress
    ################# Get public key for ssh
    getSSHPublicKey
    ################# Show details recorded so far and confirm
    showSetupDetails
    read -rep "Are the details above correct? (y/n) + [enter]:" SETUPACCEPTED
    if [ "$SETUPACCEPTED" == 'y' ]
    then
        break
    fi
done
#echo $RUN_USER ":" $FQDN  ":" $SERVER_IP_ADDR ":" $STAKE_ADDR