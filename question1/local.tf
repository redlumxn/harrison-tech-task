locals {
  region           = "ap-southeast-2"
  harrison_profile = "<CHANGE_ME>"
  annalise_profile = "<CHANGE_ME>"
}

resource "random_string" "random" {
  length  = 16
  special = false
  lower   = true
  upper   = false
}