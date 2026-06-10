output "vpc_id"            { value = aws_vpc.main.id }
output "public_subnet_id"  { value = aws_subnet.public.id }
output "app_subnet_id"     { value = aws_subnet.app.id }
output "tools_subnet_id"   { value = aws_subnet.tools.id }
output "data_subnet_id"    { value = aws_subnet.data.id }
output "nat_gateway_id"    { value = aws_nat_gateway.main.id }
output "igw_id"            { value = aws_internet_gateway.main.id }
output "public_subnet_2_id" { value = aws_subnet.public_2.id }