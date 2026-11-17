terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.80" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # Estado local por ahora. Para trabajo en equipo, mover a S3 con bloqueo:
  # backend "s3" { bucket = "kutnz-tfstate-<cuenta>", key = "kutnz.tfstate", region = "us-east-1", use_lockfile = true }
}

# Todo en us-east-1: CloudFront exige que su certificado ACM y su Web ACL de WAF vivan aquí.
provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "kutnz", ManagedBy = "terraform", Course = "Disenio-Sistemas-Escalables" }
  }
}
