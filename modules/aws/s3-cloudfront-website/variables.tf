variable "hosted_zone_name" {
  type = string
}

variable "certificate_domain_name" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "record_aliases" {
  type = list(string)
}

variable "error_document" {
  type = string
  default = "index.html"
}