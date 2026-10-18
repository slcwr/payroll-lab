terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # チームで使う場合は GCS に state を置く
  # backend "gcs" {
  #   bucket = "your-tfstate-bucket"
  #   prefix = "payroll-lab"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
