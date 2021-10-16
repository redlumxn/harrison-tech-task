locals {
  region           = "ap-southeast-2"
  harrison_profile = "opendata-root"
  annalise_profile = "redlumxn"
}

resource "random_string" "random" {
  length  = 16
  special = false
  lower   = true
  upper   = false
}