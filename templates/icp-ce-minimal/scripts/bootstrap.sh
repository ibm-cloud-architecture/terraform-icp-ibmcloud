#!/bin/bash

ubuntu_install(){
  # attempt to retry apt-get update until cloud-init gives up the apt lock
  until apt-get update; do
    sleep 2
  done

  until apt-get install -y \
    unzip \
    python \
    python-yaml \
    thin-provisioning-tools \
    nfs-client \
    lvm2; do
    sleep 2
  done
}

crlinux_install() {
  yum install -y \
    unzip \
    PyYAML \
    device-mapper \
    libseccomp \
    libtool-ltdl \
    libcgroup \
    iptables \
    device-mapper-persistent-data \
    nfs-util \
    lvm2
}

docker_install() {
  if docker --version; then
    echo "Docker already installed. Exiting"
    return 0
  fi

  if [ -z "${package_location}" -a "${OSLEVEL}" == "ubuntu" ]; then
    # if we're on ubuntu, we can install docker-ce off of the repo
    apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"

    apt-get update && apt-get install -y docker-ce
  elif [ ! -z "${package_location}" ]; then
    while [ ! -f "${package_location}" ]; do
      echo "Waiting for docker package at ${package_location} ... "
      sleep 1
    done

    echo "Install docker from ${package_location}"
    chmod u+x "${package_location}"

    # loop here until file provisioner is done copying the package
    until ${package_location} --install; do
      sleep 2
    done
  else
    return 0
  fi

  partprobe
  lsblk
  systemctl enable docker
  storage_driver=`docker info | grep 'Storage Driver:' | cut -d: -f2 | sed -e 's/\s//g'`
  echo "storage driver is ${storage_driver}"
  if [ "${storage_driver}" == "devicemapper" ]; then
    # check if loop lvm mode is enabled
    if [ -z `docker info | grep 'loop file'` ]; then
      echo "Direct-lvm mode is configured."
      return 0
    fi

    # TODO if docker block device is not provided, make sure we use overlay2 storage driver
    if [ -z "${docker_disk}" ]; then
      echo "docker loop-lvm mode is configured and a docker block device was not specified!  This is not recommended for production!"
      return 0
    fi

    echo "A docker disk ${docker_disk} is provided, setting up direct-lvm mode ..."

    # docker installer uses devicemapper already
    cat > /etc/docker/daemon.json <<EOF
{
  "storage-opts": [
    "dm.directlvm_device=${docker_disk}"
  ]
}
EOF
  elif [ ! -z "${docker_disk}" ]; then
    echo "Setting up ${docker_disk} and mounting at /var/lib/docker ..."

    sudo mkdir -p /var/lib/docker
    sudo parted -s -a optimal ${docker_disk} mklabel gpt -- mkpart primary ext4 1 -1

    sudo partprobe

    sudo mkfs.ext4 ${docker_disk}1
    echo "${docker_disk}1  /var/lib/docker   ext4  defaults   0 0" | sudo tee -a /etc/fstab

    sudo mount -a
  fi

  systemctl restart docker

  # docker takes a while to start because it needs to prepare the
  # direct-lvm device ... loop here until it's running
  _count=0
  systemctl is-active docker | while read line; do
    if [ ${line} == "active" ]; then
      break
    fi

    echo "Docker is not active yet; waiting 3 seconds"
    sleep 3
    _count=$((_count+1))

    if [ ${_count} -gt 10 ]; then
      echo "Docker not active after 30 seconds"
      return 1
    fi
  done

  echo "Docker is installed."
  docker info

  gpasswd -a ${docker_user} docker
}

##### MAIN #####
while getopts ":p:d:i:s:u:" arg; do
    case "${arg}" in
      p)
        package_location=${OPTARG}
        ;;
      d)
        docker_disk=${OPTARG}
        ;;
      u)
        docker_user=${OPTARG}
        ;;
    esac
done

#Find Linux Distro
OSLEVEL=other
if grep -q -i ubuntu /etc/*release; then
    OSLEVEL=ubuntu
fi
echo "Operating System is $OSLEVEL"

# pre-reqs
if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

docker_install

echo "Complete.."
