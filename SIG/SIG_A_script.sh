#!/bin/bash

GO_VER="1.13.9"

remote_sig_AS="18-ffaa:1:d13"
remote_sig_IPnet="172.16.12.0"

sigID="sigA"
sigIP="172.16.0.11"
LOCAL_IP="127.0.0.1"

START_DIR=$(pwd)

if ! [ -d /etc/scion ]; then
    sudo apt-get install -yqq apt-transport-https ca-certificates
    echo "deb [trusted=yes] https://packages.netsec.inf.ethz.ch/debian all main" | sudo tee /etc/apt/sources.list.d/scionlab.list
    sudo apt-get update -qq
    sudo apt-get install -yqq scionlab

    sudo scionlab-config --host-id=72805bf4c956422b9a087af7ff512628 --host-secret=ce3462d2903347059aa1fae225e74ca4
fi

export SC=/etc/scion
export LOG=/var/log/scion
export ISD=$(ls /etc/scion/gen/ | grep ISD | awk -F 'ISD' '{ print $2 }')
export AS=$( ls /etc/scion/gen/ISD${ISD}/ | grep AS | awk -F 'AS' '{ print $2 }')
export IAd=$(echo $AS | sed 's/_/\:/g')
export IA=${ISD}-${AS}

sudo systemctl start scionlab.target

#Webapp
sudo apt install -yqq scion-apps-webapp
sudo systemctl start scion-webapp

# configure golang build environment
if ! grep -q GOPATH ~/.profile; then
    echo 'export GOPATH="$HOME/go"' >> ~/.profile
    echo 'export PATH="$HOME/.local/bin:$GOPATH/bin:/usr/local/go/bin:$PATH"' >> ~/.profile
fi
source ~/.profile
mkdir -p "$GOPATH"

# install golang
if ! [ -f ~/go${GO_VER}.linux-amd64.tar.gz ]; then
    cd ~
    curl -O https://dl.google.com/go/go${GO_VER}.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go${GO_VER}.linux-amd64.tar.gz
fi

# download scionlab's fork of scion and build and install sig
if ! [ -d ~/scion ]; then
    cd ~
    git clone -b scionlab https://github.com/netsec-ethz/scion
fi

cd ~/scion/go/sig
go install

sudo mkdir -p ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/

if ! [ -f ~/scion/go/sig/main.go ]; then
    go build -o $GOPATH/bin/sig ~/scion/go/sig/main.go
fi

sudo setcap cap_net_admin+eip $GOPATH/bin/sig

sudo sysctl net.ipv4.conf.default.rp_filter=0
sudo sysctl net.ipv4.conf.all.rp_filter=0
sudo sysctl net.ipv4.ip_forward=1

cd $START_DIR

# sig.conf
if ! [ -f ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config ]; then
    sudo touch ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    cat sig.config | sudo tee -a ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${IA}/${IA}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${IAd}/${IAd}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${AS}/${AS}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${ISD}/${ISD}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${SC}/\/etc\/scion/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${LOG}/\/var\/log\/scion/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${sigID}/${sigID}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config
    sudo sed -i "s/\${sigIP}/${sigIP}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config        
fi

#sig.json
if ! [ -f ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.json ]; then 
    sudo touch ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.json
    cat sig.json | sudo tee -a ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.json
    sudo sed -i "s/\${remote_sig_AS}/${remote_sig_AS}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.json
    sudo sed -i "s/\${remote_sig_IPnet}/${remote_sig_IPnet}/g" ${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.json    
fi

#update *.topology files
if ! grep -q sig${IAd}-1 topology.json; then
    sed -i "s/\${ISD}/${ISD}/g" topology.json
    sed -i "s/\${IAd}/${IAd}/g" topology.json    
fi
if ! grep -q sig${IAd}-1 ${SC}/gen/ISD${ISD}/AS${AS}/endhost/topology.json; then
    sudo sed -i '/$IAd/e cat topology.json' ${SC}/gen/ISD${ISD}/AS${AS}/endhost/topology.json
fi
if ! grep -q sig${IAd}-1 ${SC}/gen/ISD${ISD}/AS${AS}/br${IA}-1/topology.json; then
   sudo sed -i '/$IAd/e cat topology.json' ${SC}/gen/ISD${ISD}/AS${AS}/br${IA}-1/topology.json
fi
if ! grep -q sig${IAd}-1 ${SC}/gen/ISD${ISD}/AS${AS}/cs${IA}-1/topology.json; then
   sudo sed -i '/$IAd/e cat topology.json' ${SC}/gen/ISD${ISD}/AS${AS}/cs${IA}-1/topology.json
fi


# setup
sudo modprobe dummy

# host A
if ! $(ip link | grep -q dummy11); then
    sudo ip link add dummy11 type dummy
    sudo ip addr add ${sigIP}/32 brd + dev dummy11 label dummy11:0
    sudo ip rule add to ${remote_sig_IPnet}/24 lookup 11 prio 11
fi


#start-up SIG
sudo mkdir -p $SC/logs/sig${IA}-1
sudo touch $SC/logs/sig${IA}-1.log
$GOPATH/bin/sig -config=${SC}/gen/ISD${ISD}/AS${AS}/sig${IA}-1/${sigID}.config &

# teting
# Host A
if ! $(ip link | grep -q client); then
    sudo ip link add client type dummy
    sudo ip addr add 172.16.11.1/24 brd + dev client label client:0
fi

curl --interface 172.16.11.1 172.16.12.1:8081/hello.html

echo 'SIG setup complete'
