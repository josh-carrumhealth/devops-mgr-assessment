provider "aws" {
  alias  = "staging"
  region = "us-west-2"

}

provider "aws" {
  alias  = "production"
  region = "us-west-2""
}