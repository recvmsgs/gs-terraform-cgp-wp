provider "google" {
 project     = "groupsolver-lbogda-interview"
 region      = "us-west1"
}

provider "google-beta" {
 project     = "groupsolver-lbogda-interview"
 region      = "us-west1"
}

resource "google_compute_network" "this" {
  auto_create_subnetworks = false
  name                    = "example-12"
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name          = "example-12"
  ip_cidr_range = "192.168.24.0/24"
  region        = "us-west1"
  network       = google_compute_network.this.id
}

resource "google_compute_global_address" "this" {
  provider = google-beta

  name          = "private-ip-db-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "this" {
  provider = google-beta

  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.this.name]
}

resource "google_compute_address" "this" {
  name   = "example-12"
  region = "us-west1"
}

resource "google_compute_firewall" "wordpress_ingress" {
  name    = "example-http"
  network = google_compute_network.this.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "wordpress_ingress_ssh" {
  name    = "example-ssh"
  network = google_compute_network.this.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["88.212.37.130/32"]
}

resource "google_sql_database_instance" "this" {
  database_version = "MYSQL_5_6"
  name             = "example-wordpress-12"
  region           = "us-west1"

  depends_on = [
  google_service_networking_connection.this]

  settings {
    availability_type = "REGIONAL"
    disk_autoresize   = false
    disk_size         = 50
    disk_type         = "PD_HDD"
    tier              = "db-g1-small"
  //  tier              = "db-n1-standard-2"
    backup_configuration {
      enabled            = true
      start_time         = "04:00"
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.this.id
    }

    location_preference {
      zone = "us-west1-a"
    }

    database_flags {
      name  = "max_connections"
      value = 500
    }
  }
}

resource "google_sql_database" "this" {
  name      = "wordpress"
  instance  = google_sql_database_instance.this.name
  charset   = "utf8"
  collation = "utf8_general_ci"
}

resource "random_string" "this" {
 length    = 10
 special   = false
 min_upper = 5
 min_lower = 5
}

resource "random_password" "this" {
 length    = 24
 special   = false
 min_upper = 5
 min_lower = 5
}

resource "google_sql_user" "this" {
 name     = random_string.this.result
 password = random_password.this.result
 instance = google_sql_database_instance.this.name
}

output "sql_db_username" {
 value = random_string.this.result
 sensitive = true
}

output "sql_db_password" {
 value = random_password.this.result
 sensitive = true
}

resource "google_compute_instance" "this" {
 name                    = "example-wordpress"
 machine_type            = "e2-medium"
 zone                    = "us-west1-a"
  metadata_startup_script = templatefile("${path.module}/init.sh", {
    DB_USERNAME = random_string.this.result
    DB_PASSWORD = random_password.this.result
    DB_HOST     = google_sql_database_instance.this.private_ip_address
  })

 boot_disk {
   initialize_params {
     image = "debian-cloud/debian-10"
     size  = 50
   }
 }

 network_interface {
   subnetwork = google_compute_subnetwork.this.id

   access_config {
     nat_ip = google_compute_address.this.address
   }
 }

 service_account {
   scopes = ["userinfo-email", "compute-ro", "storage-ro"]
 }
}

resource "google_compute_resource_policy" "this" {
 name   = "example-wordpress"
 region = "us-west1"

 snapshot_schedule_policy {
  schedule {
    daily_schedule {
      days_in_cycle = 1
      start_time    = "02:00"
    }
  }

  retention_policy {
    max_retention_days    = 60
    on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
  }

  snapshot_properties {
    storage_locations = ["us"]
  }
 }
}

resource "google_compute_disk_resource_policy_attachment" "this" {
 name       = google_compute_resource_policy.this.name
 disk         = "example-wordpress"
 zone        = "us-west1-a"
 depends_on = [google_compute_instance.this]
}
