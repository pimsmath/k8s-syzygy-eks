OS_ENVIRONMENT="cc"
if [ $# == 1 ] ; then
    . openrc-$1.sh
    ulimit -n 1024
    export TF_VAR_os_password="${OS_PASSWORD}"
    export TF_VAR_os_username="${OS_USERNAME}"
    export TF_VAR_os_tenant_id="${OS_TENANT_ID}"
    export TF_VAR_os_tenant_name="${OS_TENANT_NAME}"
    export TF_VAR_os_auth_url="${OS_AUTH_URL}"
    export TF_VAR_os_region="${OS_REGION_NAME}"
else
    echo "Usage . init.sh [cc|cybera]"
fi


