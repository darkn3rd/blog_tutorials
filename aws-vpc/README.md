# **AWS Building Your First Amazon VPC**

## Lab overview
* **Task 1**: Create a VPC
* **Task 2**: Create Your Public Subnets
* **Task 3**: Create an Internet Gateway
* **Task 4**: Create a Route Table, Add Routes, And Associate Public Subnets
* **Task 5**: Create a Security Group for your Web Server
* **Task 7**: Create Private Subnets for your MySQL Server
* **Task 6**: Launch a Web Server in your Public Subnet
* **Task 8**: Create a Security Group for your Database Server
* **Task 9**: Create a Database Subnet Group
* **Task 10**: Create an Amazon RDS Database
* **Task 11**: Connect Your Address Book Application to Your Database

## Code

https://s3-us-west-2.amazonaws.com/us-west-2-aws-training/awsu-spl/spl-13/scripts/app.tgz

## Notes

## Part I: Network and Web Server

1. Create VPC
   * VPC `10.0.0.0/16` as `My VPC`
1. Create Subnets
   * Subnet `10.0.1.0/24` as `Public 1`, VPC `My VPC`, AZ A
     * `Enable auto-assign public IPv4 address`
   * Subnet `10.0.2.0/24` as `Public 2`, VPC `My VPC`, AZ B
     * `Enable auto-assign public IPv4 address`
1. Create Gateway
   * Gateway `My IG`, attached to `My VPC`
1. Create/Add Routes associated to Public Subnets
   * Route Tables `Public Route Table`
     * Add Route `0.0.0.0/0`, target `My IG`
     * Subnet Associations `Public 1`, `Public 2`
1. Create Security Groups
   * SG `Web Server` to VPC `My VPC`
     * Inbound, type `HTTP`, Source `Anywhere`
1. Launch Web Server
   * EC2 `Amazon Linux AMI`, `t2.micro`
   * VPC `MyVPC`
   * User Data
     ```bash
     #!/bin/bash -ex
     yum -y update
     yum -y install httpd php mysql php-mysql
     chkconfig httpd on
     service httpd start
     cd /var/www/html
     wget https://s3-us-west-2.amazonaws.com/us-west-2-aws-training/awsu-spl/spl-13/scripts/app.tgz
     tar xvfz app.tgz
     chown apache:root /var/www/html/rds.conf.php
     ```  
   * default storage
   * SG `Web Server`
   * Tags  
     * `Name=Web Server`

### Part II

1. Create Subnets
   * Subnet `10.0.3.0/24` as `Private 1`, VPC `My VPC`, AZ A
   * Subnet `10.0.4.0/24` as `Private 2`, VPC `My VPC`, AZ B
1. Create Security Groups
   * SG `Database` to VPC `My VPC`
     * Inbound, type `MYSQL/Aurora`, Source: `Custom`, web server sg-id `sg-xxxxxxxxxxxxxxxxx`
1. Create DB SG
   * Name `My Subnet Group`, VPC `My VPC`
   * Subnets AZ A `10.0.3.0/24`, AZ B `10.0.4.0/24`
1. Create DB
   * `MySQL`, `Dev/Test`, default of `5.6.40` is fine
   * `db.t2.micro` w/ database id `myDB`
   * master user name: `admin`, master passwd: `lab-password`
   * database name: `myDB`
   * * Subnet group `My Subnet Group` (from above)
   * SG group `Database`
   * Backup Retention Period: `0 days`
   

### Part III

1. Get Endpoint, Databases, `mydb`, copy endpoint, e.g. `mydb.cdbjcgp3cst7.us-west-2.rds.amazonaws.com`

## Exploring Results

### AWS CLI

```bash
# base infrastructure
aws ec2 describe-vpcs > vpc.useast2.json
aws ec2 describe-subnets > sn.useast2.json
aws ec2 describe-internet-gateways > igw.useast2.json
aws ec2 describe-route-tables > rt.useast2.json
aws ec2 describe-security-groups > sg.useast2.json
# application
aws ec2 describe-instances > ec2.useast2.json
```

### Terraforming

```bash
# INFRASTRUCTURE
terraforming vpc \
 --profile=$AWS_DEFAULT_PROFILE \
 --region=us-east-2 > vpc.useast2.tf

terraforming sn \
--profile=$AWS_DEFAULT_PROFILE \
--region=us-east-2 > sn.useast2.tf

terraforming igw \
 --profile=$AWS_DEFAULT_PROFILE \
 --region=us-east-2 > igw.useast2.tf

terraforming rt \
 --profile=$AWS_DEFAULT_PROFILE \
 --region=us-east-2 > rt.useast2.tf

 terraforming rta \
  --profile=$AWS_DEFAULT_PROFILE \
  --region=us-east-2 > rta.useast2.tf

terraforming sg \
 --profile=$AWS_DEFAULT_PROFILE \
 --region=us-east-2 > sg.useast2.tf

# APPLICATION
terraforming ec2 \
 --profile=$AWS_DEFAULT_PROFILE \
 --region=us-east-2 > ec2.useast2.tf

# DATABASE
terraforming dbsn \
 --profile=$AWS_DEFAULT_PROFILE \
 --region=us-east-2 > dbsn.useast2.tf
```


## Check List

- [ ] `vpc`
- [ ] `sn` public
- [ ] `igw`
- [ ] `rt`
- [ ] `rta`
- [ ] `sg` http
- [ ] `ec2` + user_data
- [ ] `sn` private
- [ ] `sg` db
- [ ] `rds`
