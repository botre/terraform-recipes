variable "name" {
  type = string
}

variable "protocol" {
  type = string
  default = 'https'
}

variable "hostname" {
  type = string
}

variable "path" {
  type = string
}

variable "timeout" {
  type = number
  default = 10
}

variable "rate" {
  type = string
  default = "rate(4 minutes)"
}