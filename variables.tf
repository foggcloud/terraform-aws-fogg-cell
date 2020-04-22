variable "name" {}
variable "cluster" {}
variable "zerotier_network" {}
variable "vpc_id" {}
variable "instance_types" {
  default = ["t3.nano", "t3a.nano"]
}
variable "key_name" {
  default = "default"
}
variable "ami_owner" {
  default = "self"
}
variable "ami_filter" {}
variable "subnet_id" {}
