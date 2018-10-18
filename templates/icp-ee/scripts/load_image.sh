#!/bin/bash

while getopts ":p:r:c:" arg; do
    case "${arg}" in
      p)
        package_location=${OPTARG}
        ;;
      r)
        registry=${OPTARG}
        ;;
      c)
        regpassword=${OPTARG}
        ;;
    esac
done

# find my private IP address, which will be on the interface the default route is configured on
myip=`ip route get 10.0.0.11 | awk 'NR==1 {print $NF}'`

echo "${myip} ${registry}" | sudo tee -a /etc/hosts

sourcedir="/tmp/icpimages"
# Get package from remote location if needed
if [[ "${package_location:0:4}" == "http" ]]; then

  # Extract filename from URL if possible
  if [[ "${package_location: -2}" == "gz" ]]; then
    # Assume a sensible filename can be extracted from URL
    filename=$(basename ${package_location})
  else
    # TODO We'll need to attempt some magic to extract the filename
    echo "Not able to determine filename from URL ${package_location}" >&2
    exit 1
  fi

  # Download the file using auth if provided
  echo "Downloading ${image_url}" >&2
  mkdir -p ${sourcedir}
  wget --continue ${username:+--user} ${username} ${password:+--password} ${password} \
   -O ${sourcedir}/${filename} "${image_url}"

  # Set the image file name if we're on the same platform
  if [[ ${filename} =~ .*$(uname -m).* ]]; then
    echo "Setting image_file to ${sourcedir}/${filename}"
    image_file="${sourcedir}/${filename}"
  fi
elif [[ "${package_location:0:3}" == "nfs" ]]; then
  # Separate out the filename and path
  sourcedir="/opt/ibm/cluster/images"
  nfs_mount=$(dirname ${package_location:4})
  image_file="${sourcedir}/$(basename ${package_location})"
  sudo mkdir -p ${sourcedir}

  # Mount
  sudo mount.nfs $nfs_mount $sourcedir
  if [ $? -ne 0 ]; then
    echo "An error occurred mounting the NFS server. Mount point: $nfs_mount"
    exit 1
  fi

else
  # This must be uploaded from local file, terraform should have copied it to /tmp
  image_file="/tmp/$(basename ${package_location})"

fi

echo "Unpacking ${image_file} ..."
pv --interval 10 ${image_file} | tar zxf - -O | sudo docker load

sudo mkdir -p /registry
sudo mkdir -p /etc/docker/certs.d/${registry}
sudo cp /etc/registry/registry-cert.pem /etc/docker/certs.d/${registry}/ca.crt

# Create authentication
sudo mkdir /auth
sudo docker run \
  --entrypoint htpasswd \
  registry:2 -Bbn icpdeploy ${regpassword} | sudo tee /auth/htpasswd

sudo docker run -d \
  --restart=always \
  --name registry \
  -v /etc/registry:/certs \
  -v /registry:/registry \
  -v /auth:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry-cert.pem \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry-key.pem  \
  -p 443:443 \
  registry:2

# Retag images for private registry
sudo docker images | grep -v REPOSITORY | grep -v ${registry} | awk '{print $1 ":" $2}' | xargs -n1 -I{} sudo docker tag {} ${registry}/{}

# ICP 3.1.0 archives also includes the architecture in image names which is not expected in private repos, also tag a non-arched version
sudo docker images | grep ${registry} | grep "amd64" | awk '{gsub("-amd64", "") ; print $1 "-amd64:" $2 " " $1 ":" $2 }' | xargs -n2  sh -c 'sudo docker tag $1 $2' argv0

# Push all images and tags to private docker registry
sudo docker login --password ${regpassword} --username icpdeploy ${registry}
while read image; do
  echo "Pushing ${image}"
  sudo docker push ${image} >> /tmp/imagepush.log
done < <(sudo docker images | grep ${registry} | awk '{print $1 ":" $2}' | sort | uniq)
