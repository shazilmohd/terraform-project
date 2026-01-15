terraform {
  backend "s3" {
    bucket = "terraform-state-1768505102"
    key    = "stage/terraform.tfstate"
    region = "ap-south-1"
  }
}
