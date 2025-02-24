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

variable "viz_image_url" {
  default = "pennsieve/visualization-app"
}

variable "viz_image_tag" {
  type = string
}