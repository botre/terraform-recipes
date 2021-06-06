variable "hosted_zone_id" {
  type = string
}

variable "certificate_arn" {
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