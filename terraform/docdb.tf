# Configuração do provider AWS
# Define a região onde os recursos serão criados.
provider "aws" {
  region = "us-east-1"
}

# Criação da VPC
# Define a VPC principal com suporte a DNS e CIDR 10.0.0.0/16.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true  # Permite a resolução de DNS por nome de host.
  enable_dns_support   = true  # Habilita suporte ao DNS dentro da VPC.

  tags = {
    Name = "microservice-vpc"  # Nome descritivo da VPC.
    "kubernetes.io/cluster/eks-cliente" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-produto" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-pedidopgto" = "shared"  # Integração com o cluster EKS.
  }
}

# Subnets Públicas
# São subnets acessíveis pela internet, usadas para recursos públicos como Load Balancers.
resource "aws_subnet" "public_subnet_1" {
  depends_on = [aws_vpc.main]
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"  # Faixa de IP para esta subnet.
  availability_zone       = "us-east-1a"   # Zona de disponibilidade.
  map_public_ip_on_launch = true           # Garante IP público para instâncias.

  tags = {
    Name = "microservice-public-subnet-1"  # Nome descritivo.
    "kubernetes.io/role/elb"             = "1"  # Identifica como subnet para ELB.
    "kubernetes.io/cluster/eks-cliente" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-produto" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-pedidopgto" = "shared"  # Integração com o cluster EKS.
  }
}

resource "aws_subnet" "public_subnet_2" {
  depends_on = [aws_vpc.main]
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "microservice-public-subnet-2"
    "kubernetes.io/role/elb"             = "1"
    "kubernetes.io/cluster/eks-cliente" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-produto" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-pedidopgto" = "shared"  # Integração com o cluster EKS.
  }
}

# Subnets Privadas
# Subnets que não são diretamente acessíveis pela internet, usadas para segurança.
resource "aws_subnet" "private_subnet_1" {
  depends_on = [aws_vpc.main]
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "microservice-private-subnet-1"
    "kubernetes.io/role/internal-elb"    = "1"  # Identifica como subnet para ELB interno.
    "kubernetes.io/cluster/eks-cliente" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-produto" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-pedidopgto" = "shared"  # Integração com o cluster EKS.
  }
}

resource "aws_subnet" "private_subnet_2" {
  depends_on = [aws_vpc.main]
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "microservice-private-subnet-2"
    "kubernetes.io/role/internal-elb"    = "1"
    "kubernetes.io/cluster/eks-cliente" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-produto" = "shared"  # Integração com o cluster EKS.
    "kubernetes.io/cluster/eks-pedidopgto" = "shared"  # Integração com o cluster EKS.
  }
}

# Internet Gateway
# Usado para permitir acesso à internet para subnets públicas.
resource "aws_internet_gateway" "main" {
  depends_on = [aws_vpc.main]
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "microservice-igw"
  }
}

# Tabela de Rotas Públicas
# Define como as subnets públicas se conectam à internet via Internet Gateway.
resource "aws_route_table" "public" {
  depends_on = [aws_internet_gateway.main]
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"  # Todo o tráfego é roteado para a internet.
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "microservice-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP para NAT Gateway
resource "aws_eip" "nat" {
  tags = {
    Name = "microservice-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  depends_on = [aws_eip.nat, aws_subnet.public_subnet_1]
  allocation_id = aws_eip.nat.id  # Usa o ID do Elastic IP criado acima.
  subnet_id     = aws_subnet.public_subnet_1.id  # Subnet pública para o NAT Gateway.

  tags = {
    Name = "microservice-nat"
  }
}
# Tabela de Rotas Privadas
# Define como as subnets privadas se conectam à internet via NAT Gateway.
resource "aws_route_table" "private" {
  depends_on = [aws_nat_gateway.nat]
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "microservice-private-rt"
  }
}

resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private.id
}

# Security Group para Kubernetes
# Permite tráfego interno na VPC e saída para a internet.
resource "aws_security_group" "eks_cliente" {
  depends_on = [aws_vpc.main]
  name        = "eks-sg-cliente"
  description = "Security group for cliente EKS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite tráfego interno na VPC.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite saída irrestrita.
  }
}

# Security Group para Kubernetes
# Permite tráfego interno na VPC e saída para a internet.
resource "aws_security_group" "eks_produto" {
  depends_on = [aws_vpc.main]
  name        = "eks-sg-produto"
  description = "Security group for produto EKS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite tráfego interno na VPC.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite saída irrestrita.
  }
}

# Security Group para Kubernetes
# Permite tráfego interno na VPC e saída para a internet.
resource "aws_security_group" "eks_pedidopgto" {
  depends_on = [aws_vpc.main]
  name        = "eks-sg-pedidopgto"
  description = "Security group for pedidopgto EKS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite tráfego interno na VPC.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite saída irrestrita.
  }
}

# Security Group para DocumentDB
# Garante que apenas recursos na VPC tenham acesso ao banco.
resource "aws_security_group" "docdb" {
  depends_on = [aws_vpc.main]
  name        = "docdb-sg"
  description = "Security group for DocumentDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Permite tráfego interno na VPC.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Endpoint para S3 na VPC
# Usado para acessar o S3 sem usar a internet.
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    aws_route_table.private.id  # Associado à tabela de rotas privadas.
  ]

  tags = {
    Name = "microservice-s3-endpoint"
  }
}

# Subnet Group para DocumentDB
# Define as subnets usadas pelo DocumentDB.
resource "aws_docdb_subnet_group" "default" {
  name       = "docdb-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "microservice-docdb-subnet-group"
  }
}

# Cluster Parameter Group
# Configurações avançadas do DocumentDB.
resource "aws_docdb_cluster_parameter_group" "default" {
  family = "docdb5.0"
  name   = "docdb-cluster-params"

  parameter {
    name  = "tls"
    value = "disabled"  # Desativa o TLS (não recomendado para produção).
  }

  tags = {
    Name = "microservice-eks-docdb-params"
  }
}

# DocumentDB Cluster
# Cluster principal do DocumentDB para o microserviço Cadastro de Clientes.
resource "aws_docdb_cluster" "microservice_cliente" {
  depends_on = [aws_docdb_subnet_group.default, aws_security_group.docdb, aws_docdb_cluster_parameter_group.default]
  cluster_identifier              = "docdb-microservice-cliente"
  master_username                 = var.db_master_username
  master_password                 = var.db_master_password
  db_subnet_group_name            = aws_docdb_subnet_group.default.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  skip_final_snapshot             = true
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.default.name

  tags = {
    Name = "microservice-cliente-docdb-cluster"
  }
}

# DocumentDB Instance
# Instância do cluster DocumentDB para o microserviço Cadastro de Clientes.
resource "aws_docdb_cluster_instance" "microservice_cliente_instances" {
  count              = 1
  identifier         = "docdb-microservice-cliente-${count.index}"
  cluster_identifier = aws_docdb_cluster.microservice_cliente.id
  instance_class     = "db.t3.medium"

  tags = {
    Name = "microservice-cliente-docdb-instance"
  }
}

# Outputs
# Exibe o endpoint do DocumentDB no Terraform para o microserviço Cadastro de Clientes.
output "docdb_microservice_cliente_endpoint" {
  value       = aws_docdb_cluster.microservice_cliente.endpoint
  description = "DocumentDB Cluster Endpoint para o microserviço Cadastro de Clientes"
}

# DocumentDB Cluster
# Cluster principal do DocumentDB para o microserviço Cadastro de Produtos.
resource "aws_docdb_cluster" "microservice_produtos" {
  depends_on = [aws_docdb_subnet_group.default, aws_security_group.docdb, aws_docdb_cluster_parameter_group.default]
  cluster_identifier              = "docdb-microservice-produtos"
  engine                          = "docdb"
  master_username                 = var.db_master_username
  master_password                 = var.db_master_password
  db_subnet_group_name            = aws_docdb_subnet_group.default.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  skip_final_snapshot             = true
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.default.name

  tags = {
    Name = "microservice-produtos-docdb-cluster"
  }
}

# DocumentDB Instance
# Instância do cluster DocumentDB para o microserviço Cadastro de Produtos.
resource "aws_docdb_cluster_instance" "microservice_produtos_instances" {
  count              = 1
  identifier         = "docdb-microservice-produtos-${count.index}"
  cluster_identifier = aws_docdb_cluster.microservice_produtos.id
  instance_class     = "db.t3.medium"

  tags = {
    Name = "microservice-produtos-docdb-instance"
  }
}

# Outputs
# Exibe o endpoint do DocumentDB no Terraform para o microserviço Cadastro de Produtos.
output "docdb_microservice_produtos_endpoint" {
  value       = aws_docdb_cluster.microservice_produtos.endpoint
  description = "DocumentDB Cluster Endpoint para o microserviço Cadastro de Produtos"
}

# DocumentDB Cluster
# Cluster principal do DocumentDB para o microserviço Pedidos e Pagamentos.
resource "aws_docdb_cluster" "microservice_pedidopgto" {
  depends_on = [aws_docdb_subnet_group.default, aws_security_group.docdb, aws_docdb_cluster_parameter_group.default]
  cluster_identifier              = "docdb-microservice-pedidopgto"
  engine                          = "docdb"
  master_username                 = var.db_master_username
  master_password                 = var.db_master_password
  db_subnet_group_name            = aws_docdb_subnet_group.default.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  skip_final_snapshot             = true
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.default.name

  tags = {
    Name = "microservice-pedidopgto-docdb-cluster"
  }
}

# DocumentDB Instance
# Instância do cluster DocumentDB para o microserviço Pedidos e Pagamentos.
resource "aws_docdb_cluster_instance" "microservice_pedidopgto_instances" {
  count              = 1
  identifier         = "docdb-microservice-pedidopgto-${count.index}"
  cluster_identifier = aws_docdb_cluster.microservice_pedidopgto.id
  instance_class     = "db.t3.medium"

  tags = {
    Name = "microservice-pedidopgto-docdb-instance"
  }
}

# Outputs comentário
# Exibe o endpoint do DocumentDB no Terraform para o microserviço Pedidos e Pagamentos.
output "docdb_microservice_pedidopgto_endpoint" {
  value       = aws_docdb_cluster.microservice_pedidopgto.endpoint
  description = "DocumentDB Cluster Endpoint para o microserviço Pedidos e Pagamentos"
}

variable "db_master_username" {
  description = "Nome do usuário para o DocumentDB"
}

variable "db_master_password" {
  description = "Senha para o DocumentDB"
}
