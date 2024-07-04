variable "aws_region" {
  type = string
  default = "us-west-2"
}
variable "availabilityzones" {
  type = list(string)
}
variable "vpc_cidr_block" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "subnetnames" {
  type = list(string)
}
variable "routetablenames" {
  type = list(string)
}
variable "Hostedzoneid" {
  type = string
}



