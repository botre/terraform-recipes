variable "hosted_zone_name" {
  type = string
}

variable "certificate_domain_name" {
  type = string
}

variable "certificate_alternate_domain_names" {
  type = set(string)
}