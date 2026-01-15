terraform {
  backend "s3" {
    bucket = "terraform-state-1768505102"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"
  }
}
