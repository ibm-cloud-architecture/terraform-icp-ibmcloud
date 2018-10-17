# /var/lib/registry
resource "ibm_storage_file" "fs_registry" {
  type            = "${var.fs_registry["type"]}"
  datacenter      = "${var.datacenter}"
  capacity        = "${var.fs_registry["size"]}"
  iops            = "${var.fs_registry["iops"]}"
  hourly_billing  = "${var.fs_registry["hourly_billing"]}"

  tags = [
    "${var.deployment}",
    "fs-registry",
    "${random_id.clusterid.hex}"
  ]

  notes = "/var/lib/registry for ICP cluster ${random_id.clusterid.hex}"
}

#/var/lib/icp/audit
resource "ibm_storage_file" "fs_audit" {
  type            = "${var.fs_audit["type"]}"
  datacenter      = "${var.datacenter}"
  capacity        = "${var.fs_audit["size"]}"
  iops            = "${var.fs_audit["iops"]}"
  hourly_billing  = "${var.fs_audit["hourly_billing"]}"

  tags = [
    "${var.deployment}",
    "fs-audit",
    "${random_id.clusterid.hex}"
  ]

  notes = "/var/lib/icp/audit for ICP cluster ${random_id.clusterid.hex}"
}
