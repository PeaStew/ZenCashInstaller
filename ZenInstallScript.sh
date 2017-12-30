#!/usr/bin/env bash

# Author: @PeaStew
# Credits: Lukas Bures, Rolf Versluis
#############################################
#References:
# test hostname and IP  ping -a $(hostname -I | awk '{print$1}') | head -n 1 | awk '{print$2}'
# get balance curl https://explorer.zensystem.io/insight-api-zen/addr/
# https://stackoverflow.com/questions/1955505/parsing-json-with-unix-tools
# curl -s https://explorer.zensystem.io/insight-api-zen/addr/znnV3Mb9TPbRAK6CR2pgunW23V91f2RU1h6 | python -c "import sys, json; print json.load(sys.stdin)[ 'balance' ]" | tail -n1
# curl -s https://explorer.zensystem.io/insight-api-zen/blocks?limit=1 | python -c "import sys, json; print json.load(sys.stdin)[ 'blocks' ][ 0 ][ 'height' ] " | tail -n1
# https://github.com/niieani/bash-oo-framework/blob/master/lib/util/tryCatch.sh
# -----------------------------------------------------------------------------------------------------------------

## Try Catch 

# no dependencies
declare -ig __oo__insideTryCatch=0
declare -g __oo__presetShellOpts="$-"

# in case try-catch is nested, we set +e before so the parent handler doesn't catch us instead
alias try='[[ $__oo__insideTryCatch -eq 0 ]] || set +e; __oo__presetShellOpts="$-"; __oo__insideTryCatch+=1; ( set -e; true; '
alias catch='); declare __oo__tryResult=$?; __oo__insideTryCatch+=-1; [[ $__oo__insideTryCatch -lt 1 ]] || set -${__oo__presetShellOpts:-e} && Exception::Extract $__oo__tryResult || '

Exception::SetupTemp() {
  declare -g __oo__storedExceptionLineFile="$(mktemp -t stored_exception_line.$$.XXXXXXXXXX)"
  declare -g __oo__storedExceptionSourceFile="$(mktemp -t stored_exception_source.$$.XXXXXXXXXX)"
  declare -g __oo__storedExceptionBacktraceFile="$(mktemp -t stored_exception_backtrace.$$.XXXXXXXXXX)"
  declare -g __oo__storedExceptionFile="$(mktemp -t stored_exception.$$.XXXXXXXXXX)"
}

Exception::CleanUp() {
  rm -f $__oo__storedExceptionLineFile $__oo__storedExceptionSourceFile $__oo__storedExceptionBacktraceFile $__oo__storedExceptionFile || exit 1
  exit 0
}

Exception::ResetStore() {
  > $__oo__storedExceptionLineFile
  > $__oo__storedExceptionFile
  > $__oo__storedExceptionSourceFile
  > $__oo__storedExceptionBacktraceFile
}

Exception::GetLastException() {
  if [[ -s $__oo__storedExceptionFile ]]
  then
    cat $__oo__storedExceptionLineFile
    cat $__oo__storedExceptionFile
    cat $__oo__storedExceptionSourceFile
    cat $__oo__storedExceptionBacktraceFile

    Exception::ResetStore
  else
    echo -e "${BASH_LINENO[1]}\n \n${BASH_SOURCE[2]#./}"
  fi
}

Exception::Extract() {
  local retVal=$1
  unset __oo__tryResult

  if [[ $retVal -gt 0 ]]
  then
    local IFS=$'\n'
    __EXCEPTION__=( $(Exception::GetLastException) )

    local -i counter=0
    local -i backtraceNo=0

    while [[ $counter -lt ${#__EXCEPTION__[@]} ]]
    do
      __BACKTRACE_LINE__[$backtraceNo]="${__EXCEPTION__[$counter]}"
      counter+=1
      __BACKTRACE_COMMAND__[$backtraceNo]="${__EXCEPTION__[$counter]}"
      counter+=1
      __BACKTRACE_SOURCE__[$backtraceNo]="${__EXCEPTION__[$counter]}"
      counter+=1
      backtraceNo+=1
    done

    return 1 # so that we may continue with a "catch"
  fi
  return 0
}

Exception::SetupTemp
trap Exception::CleanUp EXIT INT TERM

## End Try Catch

#######################################################BASIC SETUP STARTTED####################################################
declare -a basicSetupPackages=("curl" "pwgen" "bc" "git")
declare -a basicSetupPackagesDescription=("to check ZEN balance and Blockchain Status" "for psuedo-random user/password generation" "for mathematical calculations" "to retrieve software from github")
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
STAKE_ADDR_BALANCE_VALID='n'
ACCEPT_STAKE_ADDR='y'
SETUPACCEPTED='n'

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
    echo -e "time, ymmv.\n\e[39m"
    echo -e "The minimum following detail is required before starting:\e[93m"
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
    echo -e "Updating system you may be asked for your sudo password by the system..."
    sudo apt-get update && sudo apt-get -y upgrade && sudo apt-get autoremove -y
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

getTAddressBalance ()
{
    addressBalance=$(curl -s https://explorer.zensystem.io/insight-api-zen/addr/$1 | python -c "import sys, json; print json.load(sys.stdin)[ 'balance' ]" | tail -n1)
    echo -e "$addressBalance"
}

setZENtAddressBalance () {
    STAKE_ADDR_BALANCE_FLOAT=$(getTAddressBalance $1)
    STAKE_ADDR_BALANCE=$(( ${STAKE_ADDR_BALANCE_FLOAT%.*} + 0 ))
}

checkIfValidPublicZenAddress () {
    if [ ${#1} == 35 ] && (( $(echo -e "$1" | cut -c-2) == "zn" ))
    then
        return 1
    else
        return 0
}

## Gets Stake Address
getStakeAddress () {
displayPreamble
while [ "$STAKE_ADDR_VALID" != "y" ]
do
    read -rep $'\e[96mPlease enter your public ZenCash Stake Address\nwith 42 ZEN on it which starts with \"zn...\" and is 35\ncharacters long, (this should be in your local wallet,\nnot on the node!) and press [enter]:\e[39m ' STAKE_ADDR 
    ################# Test if Stake Address format matches expected t_addr type
    checkAddr=$(checkIfValidPublicZenAddress $STAKE_ADDR)
    if [ $checkAddr == 0 ]
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
            STAKE_ADDR_BALANCE_VALID='y'
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

resetSetup ()
{
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
    STAKE_ADDR_BALANCE_VALID='n'
    ACCEPT_STAKE_ADDR='y'
    SETUPACCEPTED='n'
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
    if [ "$USESSHPUBLICKEY" == 'y' ]
    then
        displayKVBlueWhite2col "SSH Key in use: " "$(stringComparison "TRUE" "TRUE")"
        displayKVBlueWhite2col "SSH Key: " $SSHPUBLICKEY
    else
        displayKVBlueWhite2col "SSH Key in use: " "$(stringComparison "TRUE" "FALSE")"
    fi
    }

runInitialSetup () {
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
    if [ "$FQDN_AND_IP_ADDR_VALID" != 'y' ] || [ "$STAKE_ADDR_BALANCE_VALID" != 'y' ]
    then
        echo -e "Too many failures, cannot continue. Restarting..."
        PREAMBLE_DISPLAYED='n'
    else
        read -rep "Are the details above correct? (y/n) + [enter]:" SETUPACCEPTED
        if [ "$SETUPACCEPTED" == 'y' ]
        then
            break
        else
            resetSetup
        fi
    fi
done
}

runInitialSetup

#######################################################BASIC SETUP COMPLETED####################################################

#######################################################INSTALL STARTED####################################################

##Variables
USERNAME=$(pwgen -s 16 1)
PASSWORD=$(pwgen -s 64 1)
NODE_TLS_CERTIFIED='False'
NODE_Z_ADDR=''

##Functions
getProcessorName () {
    local processorName=$(cat /proc/cpuinfo | grep -e "model name" | uniq | awk '{for(i=4;i<=NF;i++)printf "%s",$i (i==NF?ORS:OFS)}')
    echo $processorName
}

getCPUCount ()
{
    local cpuCount=$(cat /proc/cpuinfo | grep "physical id" | sort -u | wc -l)
    echo $cpuCount
}

getCoreCount () {
    local coreCount=$(nproc --all)
    echo $coreCount
}

getTotalRAM () {
    local RAM=$(free -h | tail -n2 | head -n1 | awk '{print$2}' | sed 's/G//')
    RAM=3
    echo $RAM
}

getTotalSwap () {
    local Swap=$(free -h | tail -n1 | awk '{print$2}' | sed 's/G//')
    echo $Swap
}

getTotalRAMPlusSwap ()
{
    local RAM=$(getTotalRAM)
    local Swap=$(getTotalSwap)
    total=$(bc <<< "$RAM + $Swap")
    echo $total
}

getRAMPlusSwapDeltaToRecommended () {
    local RAM=$(getTotalRAM)
    missing=$(bc <<< "6.0 - $RAM")
    echo -e "$missing"
}

testEnoughRAMplusSwap ()
{
    total=$(getTotalRAMPlusSwap)
    enough=$(bc <<< "$total >= 6.0")
    echo -e "$enough"
}

round()
{
    echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

showSystemStats () {
    clear
    echo "System statistics:"
    displayKVBlueWhite2col "Processor Name: " "$(getProcessorName)"
    displayKVBlueWhite2col "Physical CPUs: " "$(getCPUCount)"
    displayKVBlueWhite2col "Logical Cores: " "$(getCoreCount)"
    displayKVBlueWhite2col "RAM: " "$(getTotalRAM)"
    displayKVBlueWhite2col "Swap: " "$(getTotalSwap)"
    displayKVBlueWhite2col "Total RAM + Swap: " "$(getTotalRAMPlusSwap)"
}

allocateSwapFile () {
    delta=$(getRAMPlusSwapDeltaToRecommended)
    deltaRounded=$(round $delta 0)
    sudo fallocate -l "$deltaRounded"G /swapfile
    sudo chmod 600 /swapfile
    try
    {
        sudo mkswap /swapfile
        sudo swapon /swapfile
        sudo echo "/swapfile none swap sw 0 0" >> /etc/fstab
        sudo echo "vm.swappiness=10" >> /etc/sysctl.conf
    } catch {
        echo "Enabling Swap Failed!"
        sudo rm-rf /swapfile
    }
    
}

testMemory () {
    resultTestRamPlusSwap=$(testEnoughRAMplusSwap)
    if [ "$resultTestRamPlusSwap" == 0 ]
    then
        read -rep "There has not been enough RAM + Swap detected on this system to pass challenges.\nWould you like to increase your swap space\n(this will not work on OpenVZ based VPS, select n if this is you)? (y/n) + [enter]:" INCREASESWAP
        if [ "$INCREASESWAP" == 'y' ]
        then
            allocateSwapFile
            return 1
        else
            return 0
        fi
    fi   
}

createNewUser ()
{
    if [ "$ACCEPT_RUN_USER" != 'y' ] && [ "$USER" != "$RUN_USER" ]
    echo -e "Creating new user $RUN_USER please respond to the questions\nasked by the system, you do not need to answer more than your password\nyou can press [enter] for all other questions and the (y) to confirm."
    sudo adduser $RUN_USER
    sudo usermod -g sudo $RUN_USER 
    sudo su $RUN_USER > /dev/null

}

setupFirewall () {
    echo -e "Setting up firewall to block ports that aren't needed..."
    sudo ufw default allow outgoing > /dev/null
    sudo ufw default deny incoming > /dev/null
    sudo ufw allow ssh/tcp > /dev/null
    sudo ufw limit ssh/tcp > /dev/null
    sudo ufw allow http/tcp > /dev/null
    sudo ufw allow https/tcp > /dev/null
    sudo ufw allow 9033/tcp > /dev/null
    sudo ufw allow 19033/tcp > /dev/null
    sudo ufw logging on > /dev/null
    sudo ufw enable > /dev/null
    echo -e "Checking firewall status..."
    sudo ufw status
}

setupFail2Ban ()
{
    echo -e "Setting up fail2ban to slow down people trying to brute force login to your server..."
    sudo apt -y install fail2ban > /dev/null
    sudo systemctl enable fail2ban > /dev/null
    echo -e "Starting fail2ban..."
    sudo systemctl start fail2ban
    
}

setupRKHunter ()
{
    echo -e "Setting up RKHunter to scan system for root kits..."
    sudo apt -y install rkhunter > /dev/null 
}

createUpgradeScript () {
    echo -e " 
    #!/bin/bash
    sudo apt update
    sudo apt -y dist-upgrade
    sudo apt -y autoremove
    sudo rkhunter --propupd" > ~/upgrade_script.sh
    chmod u+x ~/upgrade_script.sh
}

doBasicSecuritySetup () {
    setupFirewall
    setupFail2Ban
    setupRKHunter
}

installZen () {
    echo "Installing Zen Node Software..."
    sudo apt-get install apt-transport-https lsb-release -y
    echo 'deb https://zencashofficial.github.io/repo/ '$(lsb_release -cs)' main' | sudo tee --append /etc/apt/sources.list.d/zen.list
    gpg --keyserver ha.pool.sks-keyservers.net --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669
    gpg --export 219F55740BBF7A1CE368BA45FB7053CE4991B669 | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install zen
    zen-fetch-params
    zend > /dev/null
}

createZenConfFile () {
    echo -e "rpcuser=$USERNAME
    rpcpassword=$PASSWORD
    rpcport=18231
    rpcallowip=127.0.0.1
    server=1
    daemon=1
    listen=1
    txindex=1
    logtimestamps=1
    ### testnet config
    #testnet=1" > ~/.zen/zen.conf
}

getLatestBlockOnExplorer () {
    latest=$(curl -s https://explorer.zensystem.io/insight-api-zen/blocks?limit=1 | python -c "import sys, json; print json.load(sys.stdin)[ 'blocks' ][ 0 ][ 'height' ] " | tail -n1)
    echo -e "$latest"
}

getLatestBlockOnLocal () {
    latest=$(zen-cli getinfo | python -c "import sys, json; print json.load(sys.stdin)[ 'blocks' ] " | tail -n1)
    echo -e "$latest"
}

getPercentageBlockCompletion () {
    latestExplorer=$(getLatestBlockOnExplorer)
    latestLocal=$(getLatestBlockOnLocal)
    percentageComplete=$(bc <<< "($latestLocal / $latestExplorer) * 100")
    echo -e "$percentageComplete %"
}

checkBlocksAreIncreasing () {
    lastBlock=$(getLatestBlockOnLocal)
    for (( i=1; i<=5; i++))
	do
        sleep 5s
        currentBlock=$(getLatestBlockOnLocal)
        latestExplorer=$(getLatestBlockOnExplorer)
        percentageComplete=$(getPercentageBlockCompletion)
        blocksIncreasing=$(numberComparisonA_gte_B $currentBlock $lastBlock)

		displayKVBlueWhite2col "Previous Local Block: " "$lastBlock"
        displayKVBlueWhite2col "Current Local Block: " "$currentBlock"
        displayKVBlueWhite2col "Current Explorer Block: " "$latestExplorer"
        displayKVBlueWhite2col "Percentage Completed: " "$percentageComplete"
        displayKVBlueWhite2col "Blocks Increasing: " "$blocksIncreasing"

        lastBlock=$currentBlock
	done
}

displayCurrentBlockStatus () {
        currentBlock=$(getLatestBlockOnLocal)
        latestExplorer=$(getLatestBlockOnExplorer)
        percentageComplete=$(getPercentageBlockCompletion)

        displayKVBlueWhite2col "Current Local Block: " "$currentBlock"
        displayKVBlueWhite2col "Current Explorer Block: " "$latestExplorer"
        displayKVBlueWhite2col "Percentage Completed: " "$percentageComplete"
}

installTLSCertificate () {
    echo "Installing acme.sh software for TLS certificate..."
    sudo apt install socat -y > /dev/null
    cd ~/
    git clone https://github.com/Neilpang/acme.sh.git > /dev/null
    cd acme.sh
    ./acme.sh --install > /dev/null
   
    echo "Generating TLS certificate..."
    sudo ~/.acme.sh/acme.sh --issue --standalone -d $FQDN > /dev/null
    
    echo "Installing cron job to renew TLS certificate automatically..."
    cd ~/
    touch ".selected_editor"
    sudo echo "SELECTED_EDITOR=\"/bin/nano\"" >> /home/$RUN_USER/.selected_editor
    (crontab -l -u $RUN_USER 2>/dev/null; echo "6 0 * * * \"/home/$RUN_USER/.acme.sh\"/acme.sh --cron --home \"/home/$RUN_USER/.acme.sh\" > /dev/null") | crontab -
    
    echo "Installing TLS Certificate..."
    sudo cp /home/$RUN_USER/.acme.sh/$FQDN/ca.cer /usr/share/ca-certificates/ca.crt
    sudo sh -c "echo 'ca.crt' >> /etc/ca-certificates.conf"
    sudo update-ca-certificates > /dev/null

    echo "Installing TLS Certificate into Zen node configuration file..."
    pkill -f zend
    zen-cli stop
    sudo echo -e "tlscertpath=/home/$RUN_USER/.acme.sh/$FQDN/$FQDN.cer\ntlskeypath=/home/$RUN_USER/.acme.sh/$FQDN/$FQDN.key" >> ~/.zen/zen.conf
}

checkZenNodeHasTLS () {
    certified=$(zen-cli getnetworkinfo | python -c "import sys, json; print json.load(sys.stdin)[ 'tls_cert_verified' ] " | tail -n1)
    certifiedDisplay=$(stringComparison $certified "True")
    displayKVBlueWhite2col "TLS Certified: " "$certifiedDisplay"
    echo -e "$certified"

}

getNewNodeZAddr () {
    NODE_Z_ADDR=$(zen-cli z_getnewaddress | head -n1)
    displayKVBlueWhite2col "New z_address: " "$NODE_Z_ADDR"
}

displayTxMessage () {
    echo -e "In order for the node to pass challenges you must transfer"
    echo -e "several small amounts of ZEN to the private address on the"
    echo -e "node. This script can autogenerate the commands necessary"
    echo -e "to do that if you would like."
    read -rep "Would you like to autogenerate the commands? (y/n) + [enter]" CONTINUE
    if [ "$CONTINUE" == 'y']
    then
        generateNodeTxCommands
    else
        echo -e "To provide enough ZEN for challenges over the next 3 years"
        echo -e "please sent 5 separate transactions of 0.03ZEN to the following "
        echo -e "private address (z addr) on the node."
        echo -e "Please do not send a single transaction as this will not achieve"
        echo -e "the desired result.\n"
        displayKVBlueWhite2col "z_addr: " "$NODE_Z_ADDR"
        echo -e "\nIt will not be possible to check the balance until the blockchain"
        echo -e "has fully synced. Also please be aware that if you send ZEN using"
        echo -e "your local wallet, it will automatically return any 'change' from"
        echo -e "the transaction to a new address. Please make sure at the end of"
        echo -e "the transactions your stake address has 42 ZEN in it." 
        displayKVBlueWhite2col "Stake Address: " "$STAKE_ADDR"
        displayCurrentBlockStatus
}
#TODO
generateNodeTxCommands () {
    read -rep "Please enter ZEN address you will be sending from preferably a public address: " FROM_ADDR
    checkAddr=$(checkIfValidPublicZenAddress $FROM_ADDR)
    if [ $checkAddr == 1 ]
    then
        echo -e "Address is a public address will retrieve balance now..."
        FROM_ADDR_CURRENT_BAL=$(getTAddressBalance $FROM_ADDR)
        balanceHighEnough=$(numberComparisonA_gte_B $FROM_ADDR_CURRENT_BAL "0.15")
        if [ $balanceHighEnough == 1 ]
        then
            echo -e "Address balance is sufficient to generate transactions."
            displayKVBlueWhite2col "Address Balance: " $FROM_ADDR_CURRENT_BAL
            echo -e "Generating transactions for you..."
        else

    else
        echo -e "Unable to retrieve balance automatically"
        read -rep "Please enter the current ZEN balance of that address e.g. 56.7092321: " FROM_ADDR_CURRENT_BAL
    fi

    for (( i=1; i<=5; i++))
	do
        read -rep "Please enter ZEN address you will be sending from: " 
}


############################## RUN ###############################
displayBreakLine
read -rep "Set up can now start, press any key to continue or ctrl+c to quit." CONTINUE
showSystemStats
MEMTEST=$(testMemory)
if [ $MEMTEST == 1 ]
then
    "Swap creation attempted."
    showSystemStats
fi
echo "Creating new user..."
createNewUser
echo "Doing basic security setup..."
doBasicSecuritySetup
echo "Creating upgrade script, after installation run with 'cd ~/ && ./upgrade_script.sh' ..."
createUpgradeScript
echo "Installing Zen..."
installZen
echo "Creating Zen configuration file..."
createZenConfFile
#start zend
echo "Starting Zen Node Software..."
zend
echo "Checking that Zen blockchain is syncing..."
checkBlocksAreIncreasing
echo "Installing software to enable ZenCash secure node..."
installTLSCertificate
#start zend
echo "Restarting Zen Node Software..."
zend
sleep 10s
echo "Checking that Zen is registering as TLS certified..."
checkZenNodeHasTLS
echo "Checking again that Zen blockchain is syncing..."
checkBlocksAreIncreasing
echo "Generating a shielded address..."
getNewNodeZAddr
displayTxMessage
