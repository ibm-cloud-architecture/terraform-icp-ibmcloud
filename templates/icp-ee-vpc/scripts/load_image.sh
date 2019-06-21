#!/bin/bash

while getopts ":p:r:u:c:" arg; do
    case "${arg}" in
      p)
        package_location=${OPTARG}
        ;;
      r)
        registry=${OPTARG}
        ;;
      u)
        regusername=${OPTARG}
        ;;
      c)
        regpassword=${OPTARG}
        ;;
    esac
done

if [ -n "${registry}" -a -n "${regusername}" -a -n "${regpassword}" ]; then
  # docker login external registry
  sudo docker login -u ${regusername} -p ${regpassword} ${registry}
fi

if [ -z "${package_location}" ]; then
  # no image file, do nothing
  exit 0
fi

# find my private IP address, which will be on the interface the default route is configured on
myip=`ip route get 10.0.0.11 | awk 'NR==1 {print $NF}'`

if [ -n ${registry} ]; then
  echo "${myip} ${registry}" | sudo tee -a /etc/hosts
fi

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
  sourcedir="/opt/ibm/cluster/images"
  image_file="/tmp/$(basename ${package_location})"
  sudo mkdir -p ${sourcedir}
  sudo mv ${image_file} ${sourcedir}/
fi

echo "Unpacking ${image_file} ..."
pv --interval 10 ${image_file} | tar zxf - -O | sudo docker load

