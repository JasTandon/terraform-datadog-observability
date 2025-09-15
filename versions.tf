terraform {
  required_version = ">= 1.3.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = ">= 3.30.0"
    }
  }
}
