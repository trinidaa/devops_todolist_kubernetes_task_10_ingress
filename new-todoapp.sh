#!/bin/bash

# Функция для проверки и применения манифеста
apply_manifest() {
    local file=$1
    local resource_type=$2
    local resource_name=$3
    local namespace=$4

    # Проверяем, существует ли ресурс
    if [ -z "$namespace" ]; then
        if ! kubectl get "$resource_type" "$resource_name" > /dev/null 2>&1; then
            echo "Applying $file..."
            kubectl apply -f "$file"
        else
            echo "$resource_type/$resource_name already exists, skipping..."
        fi
    else
        if ! kubectl get "$resource_type" "$resource_name" -n "$namespace" > /dev/null 2>&1; then
            echo "Applying $file..."
            kubectl apply -f "$file"
        else
            echo "$resource_type/$resource_name in namespace $namespace already exists, skipping..."
        fi
    fi
}

# Имя кластера (извлекаем из cluster.yml)
CLUSTER_NAME=$(grep 'name:' cluster.yml | awk '{print $2}')

# Проверка существования кластера
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already exists, skipping creation..."
else
    echo "Creating cluster $CLUSTER_NAME..."
    kind create cluster --config cluster.yml

    # Ожидание готовности кластера
    echo "Waiting for the cluster to be ready..."
    while ! kubectl get nodes | grep -q "Ready"; do
        echo "Cluster is not ready yet, waiting..."
        sleep 10
    done
    echo "Cluster is ready!"
fi

# Применение манифестов для MySQL
apply_manifest ".infrastructure/mysql/ns.yml" "namespace" "mysql" ""
apply_manifest ".infrastructure/mysql/configMap.yml" "configmap" "mysql" "mysql"
apply_manifest ".infrastructure/mysql/secret.yml" "secret" "mysql-secrets" "mysql"
apply_manifest ".infrastructure/mysql/service.yml" "service" "mysql" "mysql"
apply_manifest ".infrastructure/mysql/statefulSet.yml" "StatefulSet" "mysql" "mysql"

# Применение манифестов для приложения
apply_manifest ".infrastructure/app/ns.yml" "namespace" "todoapp" ""
apply_manifest ".infrastructure/app/pv.yml" "persistentvolume" "pv-data" "todoapp"
apply_manifest ".infrastructure/app/pvc.yml" "persistentvolumeclaim" "pvc-data" "todoapp"
apply_manifest ".infrastructure/app/secret.yml" "secret" "app-secret" "todoapp"
apply_manifest ".infrastructure/app/configMap.yml" "configmap" "app-config" "todoapp"
apply_manifest ".infrastructure/app/clusterIp.yml" "service" "todoapp-service" "todoapp"
apply_manifest ".infrastructure/app/nodeport.yml" "service" "todoapp-nodeport" "todoapp"
apply_manifest ".infrastructure/app/hpa.yml" "horizontalpodautoscaler" "todoapp" "todoapp"
apply_manifest ".infrastructure/app/deployment.yml" "Deployment" "todoapp" "todoapp"

# Установка Ingress Controller
echo "Installing Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Ожидание готовности Ingress Controller
echo "Waiting for Ingress Controller to be ready..."
while ! kubectl get pods -n ingress-nginx | grep -q "Running"; do
    echo "Ingress Controller is not ready yet, waiting..."
    sleep 10
done
echo "Ingress Controller is ready!"

# Применение Ingress
apply_manifest ".infrastructure/ingress/ingress.yml" "ingress" "new-ingress" "todoapp"

echo "Setup completed!"