#!/usr/bin/env bash
set -e

export ENVIRONMENT=$1
export ACTION=$2
export AWS_PARTITION="aws"
export CLUSTER_NAME="ofc-${ENVIRONMENT}"
export KUBERNETES_VERSION="1.27"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export AWS_ASG_POLICY_NAME=ofc_asg_${ENVIRONMENT}
export AWS_ASG_POLICY_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_ASG_POLICY_NAME}

export AWS_MOUNT_EFS_POLICY_NAME=ofc_efs_mount_${ENVIRONMENT}
export AWS_MOUNT_EFS_POLICY_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_MOUNT_EFS_POLICY_NAME}


function createCluster {
    read -p "Are you sure you want to create a cluster ${CLUSTER_NAME} in region ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        #### Create cluster
        envsubst <cluster.yaml | eksctl create cluster -f -

        #### Create required policies
        envsubst <policy.json >tmp.policy.json
        aws iam create-policy --policy-name ${AWS_ASG_POLICY_NAME} --policy-document file://tmp.policy.json

        #### Create nodeGroups for the cluster
        envsubst <nodeGroups.yaml | eksctl create nodegroup -f -

        #### Get cluster credentials
        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
        kubectl cluster-info

        #### Install ebs-csi addons
        kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
        kubectl get pods -n kube-system | grep ebs-csi

        kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
        kubectl get pods -n kube-system | grep efs-csi

        ### Install autoscaler for web nodes
        envsubst <asg-autodiscover.yaml | kubectl apply -f -
        kubectl get pods --namespace=kube-system | grep autoscaler

        #### Update aws-auth
        kubectl get configmap aws-auth -n kube-system -o yaml >aws-auth.yaml
        echo "Update manually aws-auth.yaml, use as example mapUsers.yaml"
        echo "kubectl apply -f aws-auth.yaml"
    fi

}

function deleteCluster {
    read -p "Are you sure you want to delete the cluster ${CLUSTER_NAME} in region ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        eksctl delete cluster --region=${AWS_REGION} --name=${CLUSTER_NAME}
        envsubst <nodeGroups.yaml | eksctl delete nodegroup --approve -f -
        aws iam delete-policy --policy-arn ${AWS_ASG_POLICY_ARN}
        aws iam delete-policy --policy-arn ${AWS_MOUNT_EFS_POLICY_ARN}
    fi
}

### Main
ACTION=${ACTION:-default}
if [ "$ACTION" == "create" ]; then
    createCluster
elif [ "$ACTION" == "delete" ]; then
    deleteCluster
else
    echo "The action is unknown."
fi
