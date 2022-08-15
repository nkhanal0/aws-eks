# aws-eks notes

* DNS Support defaults to true using a vpc resource.
* Adding tags is strongly recommended.
* Refactor subnets and azs into a count passed from variables.
* Change instance size for node groups.
* Endpoint public access is true by default.
* Note: For nodes that are in a private subnet backed by a NAT gateway, it's a best practice to create the NAT gateway in a public subnet.

# To Do
* The Node Groups are not able to connect to the k8 cluster. Need to troubleshoot that
* Need to deploy the two services. Possibly by grabbing nginx containers publicly and creating the deployments. Possibly using terraform/helm and some ci/cd.
* Need to look into the cluster networking to make sure the endpoint is publically available. 

# Path to Current Form
* Started out by looking into the vpc module and eks module. I wasn't sure what was needed to be done so, started from scratch and built on top of VPC, subnets, route tables etc to deploy the cluster. 
* Found a few articles that would do what we needed but needed some tweaks so in the interest of time, chose to ignore them and work with what I knew. 
* Spent some time looking into EKS cluster as I had never worked with it with terraform. 
* I assumed this is some kind of airgapped environment and was a little confused on the wordings.

# How to Run?
It is expected that we have a iam user with admin permissions and the secret/access key. Once that is available please run. 
* `aws configure`
* `terraform init`
* `terraform plan`
* `terraform apply`

