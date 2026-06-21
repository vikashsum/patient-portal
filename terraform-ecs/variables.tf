variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "deployment_prefix" {
  type    = string
  default = "patient-portal"
}

variable "appointment_image" {
  type    = string
  default = "vikash3117/appointmentservice"
}

variable "patient_image" {
  type    = string
  default = "vikash3117/patientservice"
}

variable "doctor_image" {
  type    = string
  default = "vikash3117/doctorservice"
}

variable "portal_image" {
  type    = string
  default = "vikash3117/patient-portal"
}

variable "image_tag" {
  type    = string
  default = "latest"
}
