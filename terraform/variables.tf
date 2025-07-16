variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "jenkins-bluegreen"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}
