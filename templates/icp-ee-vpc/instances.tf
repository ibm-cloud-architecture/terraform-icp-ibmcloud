data "ibm_is_image" "osimage" {
  name = "${var.os_image}"
}

data "ibm_is_instance_profile" "icp-boot-profile" {
  name = "${var.boot["profile"]}"
}

data "ibm_is_instance_profile" "icp-master-profile" {
  name = "${var.master["profile"]}"
}

data "ibm_is_instance_profile" "icp-proxy-profile" {
  name = "${var.proxy["profile"]}"
}

data "ibm_is_instance_profile" "icp-worker-profile" {
  name = "${var.worker["profile"]}"
}

data "ibm_is_instance_profile" "icp-mgmt-profile" {
  name = "${var.mgmt["profile"]}"
}

data "ibm_is_instance_profile" "icp-va-profile" {
  name = "${var.va["profile"]}"
}

resource "ibm_is_floating_ip" "icp-boot-pub" {
  name 	 = "${var.deployment}-boot-${random_id.clusterid.hex}-pubip"
  target = "${ibm_is_instance.icp-boot.primary_network_interface.0.id}"
}

##############################################
## Provision boot node
##############################################
resource "ibm_is_volume" "icp-boot-docker-vol" {
  name = "${var.deployment}-boot-docker-${random_id.clusterid.hex}"
  profile = "general-purpose"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  capacity = "${var.boot["docker_vol_size"]}"
}

resource "ibm_is_instance" "icp-boot" {
  name = "${var.deployment}-boot-${random_id.clusterid.hex}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, 0)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-boot-profile.name}"

  primary_network_interface = {
    subnet = "${element(ibm_is_subnet.icp_subnet.*.id, 0)}"
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${ibm_is_volume.icp-boot-docker-vol.id}"
  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
fs_setup:
- label: None
  filesystem: 'ext4'
  device: '/dev/xvdc'
  partition: 'auto'
mounts:
- [ 'xvdc', '/var/lib/docker' ]
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF
}

resource "ibm_is_volume" "icp-master-docker-vol" {
  count    = "${var.master["nodes"]}"
  name     = "${format("%s-master-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "general-purpose"
  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  capacity = "${var.master["docker_vol_size"]}"
}

resource "ibm_is_instance" "icp-master" {
  count = "${var.master["nodes"]}"
  name  = "${format("%s-master%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-master-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.master_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.icp-master-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
fs_setup:
- label: None
  filesystem: 'ext4'
  device: '/dev/xvdc'
  partition: 'auto'
mounts:
- [ 'xvdc', '/var/lib/docker' ]
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

}

resource "ibm_is_volume" "icp-mgmt-docker-vol" {
  count    = "${var.mgmt["nodes"]}"
  name     = "${format("%s-mgmt-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "general-purpose"
  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  capacity = "${var.mgmt["docker_vol_size"]}"
}

resource "ibm_is_instance" "icp-mgmt" {
  count = "${var.mgmt["nodes"]}"
  name  = "${format("%s-mgmt%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-mgmt-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.icp-mgmt-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
fs_setup:
- label: None
  filesystem: 'ext4'
  device: '/dev/xvdc'
  partition: 'auto'
mounts:
- [ 'xvdc', '/var/lib/docker' ]
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF
}

resource "ibm_is_volume" "icp-worker-docker-vol" {
  count    = "${var.worker["nodes"]}"
  name     = "${format("%s-worker-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "general-purpose"
  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  capacity = "${var.worker["docker_vol_size"]}"
}

resource "ibm_is_instance" "icp-worker" {
  count = "${var.worker["nodes"]}"
  name  = "${format("%s-worker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-worker-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.icp-worker-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
fs_setup:
- label: None
  filesystem: 'ext4'
  device: '/dev/xvdc'
  partition: 'auto'
mounts:
- [ 'xvdc', '/var/lib/docker' ]
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

}

resource "ibm_is_volume" "icp-proxy-docker-vol" {
  count    = "${var.proxy["nodes"]}"
  name     = "${format("%s-proxy-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "general-purpose"
  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  capacity = "${var.proxy["docker_vol_size"]}"
}

resource "ibm_is_instance" "icp-proxy" {
  count = "${var.proxy["nodes"]}"
  name  = "${format("%s-proxy%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-proxy-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id,
                               ibm_is_security_group.proxy_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.icp-proxy-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
fs_setup:
- label: None
  filesystem: 'ext4'
  device: '/dev/xvdc'
  partition: 'auto'
mounts:
- [ 'xvdc', '/var/lib/docker' ]
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF
}

resource "ibm_is_volume" "icp-va-docker-vol" {
  count    = "${var.va["nodes"]}"
  name     = "${format("%s-va-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  profile  = "general-purpose"
  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  capacity = "${var.va["docker_vol_size"]}"
}

resource "ibm_is_instance" "icp-va" {
  count = "${var.va["nodes"]}"
  name  = "${format("%s-va%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-va-profile.name}"

  primary_network_interface = {
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
  volumes = [
    "${element(ibm_is_volume.icp-va-docker-vol.*.id, count.index)}"
  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
fs_setup:
- label: None
  filesystem: 'ext4'
  device: '/dev/xvdc'
  partition: 'auto'
mounts:
- [ 'xvdc', '/var/lib/docker' ]
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

}