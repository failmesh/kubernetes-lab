#!/usr/bin/env bash
#
# script.sh
#
# EKS Practice Lab generator. Generates a scenario's faulty manifest file.
# Does NOT apply it - that's a manual step for the user.
#
# Usage:
#   ./script.sh <scenario-name>
#
# Example:
#   ./script.sh scenario1
#   -> writes scenario1-dep.yaml in the current directory

set -euo pipefail

SCENARIO_NAME="${1:-}"

if [[ -z "${SCENARIO_NAME}" ]]; then
    echo "Usage: $0 <scenario-name>" >&2
    exit 1
fi

OUTPUT_FILE="./${SCENARIO_NAME}-dep.yaml"

case "${SCENARIO_NAME}" in

  scenario1)
    cat > "${OUTPUT_FILE}" << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: vaccum
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: scenario1-config
  namespace: vaccum
data:
  APP_NAME: "eks-lab-scenario1"
---
apiVersion: v1
kind: Secret
metadata:
  name: scenario1-secret
  namespace: vaccum
type: Opaque
data:
  # This does NOT decode to the correct password
  APP_PASSWORD: d3JvbmdwYXNzd29yZA==
---
apiVersion: v1
kind: Service
metadata:
  name: scenario1-svc
  namespace: vaccum
spec:
  selector:
    app: eks-lab-scenario1-v2
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scenario1-deployment
  namespace: vacuum
spec:
  replicas: 1
  selector:
    matchLabels:
      app: eks-lab-scenario1
  template:
    metadata:
      labels:
        app: eks-lab-scenario1
    spec:
      containers:
        - name: scenario1-app
          image: r0xhit/eks-lab-scenario1:latest
          imagePullPolicy: Always
          env:
            - name: APP_NAME
              valueFrom:
                configMapKeyRef:
                  name: scenario1-config
                  key: APP_NAM
            - name: APP_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: scenario1-secret
                  key: APP_PASSWORD
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
EOF
    ;;

  *)
    echo "Unknown scenario: ${SCENARIO_NAME}" >&2
    exit 1
    ;;

esac

echo "Created ${OUTPUT_FILE}"
