module "vpc" {
  source = "../../../modules/vpc"

  app_name             = var.app_name
  environment          = var.environment
  cidr_block           = var.cidr_block
  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  subnet_newbits       = var.subnet_newbits
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = var.tags
}
