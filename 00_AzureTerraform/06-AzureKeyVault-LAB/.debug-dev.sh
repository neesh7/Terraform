# set the subscription
export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"


# set the application / environment
export TF_VAR_application_name="devops"
export TF_VAR_environment_name="dev"


# set the backend
export BACKEND_RESOURCE_GROUP="rg-tfstate-dev"
export BACKEND_STORAGE_ACCOUNT="steh52icsuob"
export BACKEND_STORAGE_CONTAINER="tfstate"
export BACKEND_KEY=$TF_VAR_application_name-$TF_VAR_environment_name


# run terraform
terraform init \
    -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP}" \
    -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT}" \
    -backend-config="container_name=${BACKEND_STORAGE_CONTAINER}" \
    -backend-config="key=${BACKEND_KEY}" \
    -reconfigure
terraform validate


if [ "$1" = "apply" ] || [ "$1" = "destroy" ]; then
    terraform "$@" --auto-approve
else
    terraform "$@"
fi


# clean up providers after work done
rm -rf .terraform
# before running this script give this script authority to run: chmod +x ./.debug-dev.sh
# How to run the script: ./.debug-dev.sh plan or ./.debug-dev.sh apply or ./.debug-dev.sh destroy 