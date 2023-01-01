# Web Application with VPC + RDS

This is terraform code to bring up web application on AWS infrastructure. This code is valid around 2019-Jun-10. 

This was based on steps from a QwikLab that does not see available in the catalog any longer.  The current AWS QwikLabs have been relocated to https://amazon.qwiklabs.com/.  

It looks like the lab 

## Check Key Pair

```bash
KEYNAME="deploy-aws"
aws ec2 describe-key-pairs \
  --query 'KeyPairs[*].[KeyName]' \
  --output text | grep $KEYNAME
```

## Logging in to Server

```bash
KEYNAME="deploy-aws"
ssh -i ~/.ssh/$KEYNAME.pem $AWS_HOST_IP
```

## Blogs

* https://joachim8675309.medium.com/building-aws-infra-with-terraform-96387481b9d7
* https://joachim8675309.medium.com/building-aws-infra-with-terraform-2-ca60146666f8
* https://joachim8675309.medium.com/building-aws-infra-with-terraform-3-1d21f3c40bb0

## Original Qwik Lab

This was based on a QwikLab done in the web console.  

* [Building Your First Amazon Virtual Private Cloud (VPC)](https://www.qwiklabs.com/focuses/3629?parent=catalog) (accessed in 2019)
* [Building Your First Amazon Virtual Private Cloud (VPC)](https://amazon.qwiklabs.com/focuses/50937?parent=catalog) (accessed in 2023)