variable "region" {
    type = string 
}
variable "account_id" {
    type = string 
}
variable "env" {
    type = string 
}
variable "wm_cpu" {
    type = number
}
variable "wm_memory" {
    type = number
}
variable "az" {
    type = list
}
variable "node_identifier" {
    type = string 
}

variable "workflow_manager_image_url" {
  default = "pennsieve/workflow-manager"
}

variable "workflow_manager_image_tag" {
  type = string
}
variable "provisioner_account_id" {
    type = string
}

variable "authorization_type" {
    type    = string
    default = "NONE"
    description = "Authorization type for Lambda function URL (NONE or AWS_IAM)"
}
