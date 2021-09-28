variable "api_name" {
  type = string
}

variable "stage_name" {
  type    = string
  default = "production"
}

variable "logging_level" {
  type    = string
  default = "ERROR"
}

variable "function_name" {
  type = string
}

variable "alias_name" {
  type    = string
  default = ""
}