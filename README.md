# das-pre-infra-vultr
Scripts/assets to provision and instantiate required hardware in Vultr

## Resources:
- Instances on Vultr cloud

## Objective:
Create instances on Vultr cloud to deploy the Redis DB, Mongo DB and functions on OpenFaas server. The instances in production env are a Bare Metal Type

## Configuration

Copy the `secret.tf.example` file to `secret.tf`:

- Configure the Vultr provider by adding the `VULTR_API_KEY`.
- Configure the Terraform S3 backend by adding the `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` of the `tfstate` user.

Edit the `config.tfvars` file to configure the stack.

```shell
# init providers and backend
terraform init

# check configuration files format
terraform fmt -check -diff -recursive .

# format configuration files
terraform fmt -diff -recursive .

# validate configuration
terraform validate
```

## Create/update stack

Notes:

- If you update the `ssh_key_ids` configuration, the instances will be **replaced**.
- If you update a installation script, the corresponding instance will be **replaced**.

```shell
# plan
terraform plan -var-file=config.tfvars -out tfplan

# apply
terraform apply tfplan
```

## Prepare your SSH key to connect to the instances

Add your Vultr SSH private key:

```shell
eval "$(ssh-agent -s)"
chmod 400 VULTR_SSH_PRIVATE_KEY
ssh-add VULTR_SSH_PRIVATE_KEY
```

## Connect to OpenFaaS instance

```shell
# connect to openfaas instance
ssh root@$(terraform output -raw openfaas_instance_ip)

# see the openfaas installation logs
cat ~/install-openfaas.log
```

## Connect to Redis instance

```shell
# connect to redis instance
ssh root@$(terraform output -raw redis_instance_ip)

# see the redis installation logs
cat ~/install-redis.log
```

## Destroy stack

```shell
# plan destroy
terraform plan -destroy -var-file=config.tfvars -out tfplan-destroy

# apply destroy
terraform apply tfplan-destroy
```

## Configure OpenFaas server before up the stack.yml

create ssh:
```
ssh-keygen -t rsa
cat ~/.ssh/id_rsa.pub
```
add the public key on github

Clonning repositories:
```
git clone link-of-function-repo
git clone git@github.com:singnet/das-infra-stack-vultr.git
```

configure aws, putting the credential to aws:
```
aws configure
```

Connecting docker on aws ecr registry (if other private registry, see faasd documentation):
```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 038760728819.dkr.ecr.us-east-1.amazonaws.com/das
```

generating credentials folder to faas stack:
```
cd DAS-deployment-openFaas

faas-cli registry-login --ecr --region us-east-1 --account-id 038760728819
```

login to faas gateway:
```
sudo cat /var/lib/faasd/secrets/basic-auth-password

faas-cli login -u admin -p password
```

copy the docker config auth to faas config auth:
```
sudo cp ~/.docker/config.json /var/lib/faasd/.docker/config.json
```

up functions:
```
faas-cli up -f das-function.yml
```