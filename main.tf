provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# -----------------------------
# Compartments & Availability Domain
# -----------------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# -----------------------------
# VCN
# -----------------------------
resource "oci_core_vcn" "web_vcn" {
  cidr_block     = "10.0.0.0/16"
  display_name   = "web-vcn"
  compartment_id = var.compartment_ocid
}

# -----------------------------
# Internet Gateway
# -----------------------------
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.web_vcn.id
  display_name   = "web-igw"
  enabled        = true
}

# -----------------------------
# Route Table
# -----------------------------
resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.web_vcn.id

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# -----------------------------
# Security List
# -----------------------------
resource "oci_core_security_list" "web_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.web_vcn.id

  # Allow SSH
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Allow HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Egress (all)
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# -----------------------------
# Public Subnet
# -----------------------------
resource "oci_core_subnet" "public_subnet" {
  cidr_block              = "10.0.1.0/24"
  display_name            = "public-subnet"
  compartment_id          = var.compartment_ocid
  vcn_id                  = oci_core_vcn.web_vcn.id
  route_table_id          = oci_core_route_table.rt.id
  security_list_ids       = [oci_core_security_list.web_sl.id]
  prohibit_public_ip_on_vnic = false
}

# -----------------------------
# Compute Instance (Free Tier)
# -----------------------------
resource "oci_core_instance" "web_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "web-server"

  shape = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    #source_id   = var.image_ocid
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key)
  }
}
