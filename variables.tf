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
variable "image_id" {}
variable "subnet_id" {}
