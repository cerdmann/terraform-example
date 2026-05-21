terraform {
  required_providers {
    hashicups = {
      source  = "hashicorp.com/edu/hashicups"
    }
  }
  required_version = ">= 1.1.0"
}

provider "hashicups" {
  username = "education"
  password = "test123"
  host     = "http://localhost:19090"
}

resource "hashicups_order" "edu" {
  items = [{
    coffee = {
      id = 3
    }
    quantity = 2
    },
    {
      coffee = {
        id = 2
      }
      quantity = 3
  }]
}

resource "hashicups_order" "edu_two" {
  items = [{
    coffee = {
      id = 1
    }
    quantity = 1
    },
    {
      coffee = {
        id = 4
      }
      quantity = 2
  }]
}

output "edu_order" {
  value = hashicups_order.edu
}

output "edu_order_two" {
  value = hashicups_order.edu_two
}

