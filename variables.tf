variable "canary_name" {
  type        = string
  description = "The name of the canary."
  validation {
    condition     = length(var.canary_name) < 22
    error_message = "The canary_name value must be <=  21 charachters long."
  }
}
variable "bucket_name" {
  type        = string
  description = "The S3 canary bucket"
}

variable "secretsmanager_secret_arns" {
  type        = list(string)
  default     = []
  description = "A list of AWS SM Secrets this canary should be allowed to read"
}

variable "kms_key_arn" {
  type        = string
  description = "kms key arn to encrypt data with, if none provided one will be created."
  default     = ""
}

variable "log_retention_in_days" {
  type        = number
  description = "How long lambda logs are retained"
  default     = 14
}
