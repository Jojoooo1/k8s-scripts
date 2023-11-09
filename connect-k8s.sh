#!/bin/bash
set -e

unset GTK_PATH # needed if using VSCode

HOST_PROJECT_ID="$1"
SERVICE_PROJECT_ID="$2"

[[ ! -x "$(command -v gcloud)" ]] && echo "gcloud not found, you need to install gcloud" && exit 1
[[ -z "${HOST_PROJECT_ID}" ]] && printf "HOST_PROJECT_ID is not set \nPlease start scripts as follow: ./connect.sh project-service-test project-shared-host" && exit 1
[[ -z "${SERVICE_PROJECT_ID}" ]] && printf "SERVICE_PROJECT_ID is not set \nPlease start scripts as follow: ./connect.sh project-service-test project-shared-host" && exit 1

if $(nc -z 127.0.0.1 8888); then
    message "Tunnel is already open!"
    exit 0
fi

message() {
    echo -e "\n######################################################################"
    echo "# >>> $1"
    echo "######################################################################"
}

display_message() {
    echo "$1"
    echo
}

verify_if_single_resource() {
    local resource_name="$1"
    local resource_type="$2"

    if [[ $resource_name == *$'\n'* ]]; then
        message "Identified more than one resource of type '$resource_type'"
        printf "\n%s\n\n" "$resource_name"

        read -r -p "Enter the name of the resource you want to use: " response

        case $resource_type in
        "BASTION_NAME")
            BASTION_NAME="$response"
            ;;
        "CLUSTER_NAME")
            CLUSTER_NAME="$response"
            ;;
        *)
            message "Unknown resource type: $resource_type"
            ;;
        esac
    fi
}

message "Searching for bastion name"
BASTION_NAME=$(gcloud compute instances list --filter="name~'.*bastion.*'" --format="value(NAME)" --project="${HOST_PROJECT_ID}")
verify_if_single_resource "${BASTION_NAME}" "BASTION_NAME"
printf "\n\t${BASTION_NAME}\n"

message "Searching for bastion zone"
BASTION_ZONE=$(gcloud compute instances list --filter="name=${BASTION_NAME}" --format="value(ZONE)" --limit 1 --project="${HOST_PROJECT_ID}")
printf "\n\t${BASTION_ZONE}\n"

message "Searching for cluster name"
CLUSTER_NAME=$(gcloud container clusters list --format="value(NAME)" --project="${SERVICE_PROJECT_ID}")
verify_if_single_resource "${CLUSTER_NAME}" "CLUSTER_NAME"
printf "\n\t${CLUSTER_NAME}\n"

message "Searching for cluster zone"
CLUSTER_ZONE=$(gcloud container clusters list --filter="name=${CLUSTER_NAME}" --format="value(ZONE)" --limit 1 --project="${SERVICE_PROJECT_ID}")
printf "\n\t${CLUSTER_ZONE}\n"

# Add credentials to ~/.kube/config
gcloud container clusters get-credentials --project="${SERVICE_PROJECT_ID}" ${CLUSTER_NAME} --zone="${CLUSTER_ZONE}" --no-user-output-enabled
message "Opening SSH tunnel"
gnome-terminal -- /bin/sh -c "gcloud compute ssh --project="${HOST_PROJECT_ID}" ${BASTION_NAME} --zone="${BASTION_ZONE}" --tunnel-through-iap -- -L8888:127.0.0.1:8888"

message "Completed!"
message "To use kubectl export variable HTTPS_PROXY"
echo
echo "export HTTPS_PROXY=localhost:8888"
echo
