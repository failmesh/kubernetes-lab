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

  scenario2)
    # -------------------------------------------------------------------
    # Multi-app scheduling + networking chase, built for a 2-node
    # Killercoda cluster (nodes: controlplane, node01 - 1 CPU / 2Gi each).
    #
    # Unlike scenario1, this one applies everything itself: it writes
    # application-a/, application-b/, application-c/ (YAML only) into the
    # current directory, then runs kubectl to create namespaces, taint
    # node01, create a PriorityClass, apply the three app folders, and
    # create the "instructions" deployment purely via kubectl CLI verbs
    # (create/set/patch - no YAML file for it).
    #
    # Resource requests below are best-guess for a 1 CPU / 2Gi node and
    # may need tuning against the real cluster's Allocatable capacity
    # (kubectl describe node node01) - bump INSTR_CPU/INSTR_MEM up if
    # application-a schedules immediately (node01 had headroom), or down
    # if the instructions pods themselves can't all fit.
    # -------------------------------------------------------------------

    command -v kubectl >/dev/null 2>&1 || {
        echo "kubectl is required for scenario2 (this scenario applies itself)" >&2
        exit 1
    }

    NODE01_NAME="${NODE01_NAME:-node01}"
    NODE01_TAINT_KEY="${NODE01_TAINT_KEY:-lab.scenario2/node01}"
    CONTROL_PLANE_TAINT_KEY="${CONTROL_PLANE_TAINT_KEY:-node-role.kubernetes.io/control-plane}"

    PRIORITY_CLASS_NAME="scenario2-critical"
    PRIORITY_CLASS_VALUE=1000000

    INSTR_IMAGE="${SCENARIO2_INSTR_IMAGE:-r0xhit/eks-lab-scenario2-instructions:latest}"
    APP_A_IMAGE="${SCENARIO2_APP_A_IMAGE:-r0xhit/eks-lab-scenario2-application-a:latest}"
    APP_B_IMAGE="${SCENARIO2_APP_B_IMAGE:-r0xhit/eks-lab-scenario2-application-b:latest}"
    APP_C_IMAGE="${SCENARIO2_APP_C_IMAGE:-r0xhit/eks-lab-scenario2-application-c:latest}"

    INSTR_REPLICAS="${INSTR_REPLICAS:-4}"
    INSTR_CPU="${INSTR_CPU:-250m}"
    INSTR_MEM="${INSTR_MEM:-300Mi}"

    APP_CPU="${APP_CPU:-150m}"
    APP_MEM="${APP_MEM:-200Mi}"

    echo "Generating manifests for scenario2 ..."
    mkdir -p application-a application-b application-c

    cat > application-a/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: application-a
EOF

    cat > application-a/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application-a
  namespace: application-a
  labels:
    app: application-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: application-a
  template:
    metadata:
      labels:
        app: application-a
    spec:
      tolerations:
        - key: "${NODE01_TAINT_KEY}"
          operator: Equal
          value: "true"
          effect: NoSchedule
      containers:
        - name: application-a
          image: ${APP_A_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: B_HOST
              value: "application-b-svc.application-b.svc.cluster.local"
            - name: B_PORT
              value: "8080"
          resources:
            requests:
              cpu: "${APP_CPU}"
              memory: "${APP_MEM}"
            limits:
              cpu: "${APP_CPU}"
              memory: "${APP_MEM}"
EOF

    cat > application-a/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: application-a-svc
  namespace: application-a
spec:
  selector:
    app: application-a
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
EOF

    cat > application-b/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: application-b
EOF

    cat > application-b/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application-b
  namespace: application-b
  labels:
    app: application-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: application-b
  template:
    metadata:
      labels:
        app: application-b
    spec:
      containers:
        - name: application-b
          image: ${APP_B_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: C_HOST
              value: "application-c-svc.application-c.svc.cluster.local"
            - name: C_PORT
              value: "8080"
          resources:
            requests:
              cpu: "${APP_CPU}"
              memory: "${APP_MEM}"
            limits:
              cpu: "${APP_CPU}"
              memory: "${APP_MEM}"
EOF

    cat > application-b/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: application-b-svc
  namespace: application-b
spec:
  selector:
    app: application-b
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
EOF

    cat > application-b/networkpolicy.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: application-b-ingress
  namespace: application-b
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
EOF

    cat > application-c/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: application-c
EOF

    cat > application-c/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application-c
  namespace: application-c
  labels:
    app: application-c
spec:
  replicas: 1
  selector:
    matchLabels:
      app: application-c
  template:
    metadata:
      labels:
        app: application-c
    spec:
      tolerations:
        - key: "${NODE01_TAINT_KEY}"
          operator: Equal
          value: "true"
          effect: NoSchedule
        - key: "${CONTROL_PLANE_TAINT_KEY}"
          operator: Exists
          effect: NoSchedule
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: instructions
              topologyKey: kubernetes.io/hostname
      containers:
        - name: application-c
          image: ${APP_C_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: A_HOST
              value: "application-a-svc"
            - name: A_PORT
              value: "8080"
          resources:
            requests:
              cpu: "${APP_CPU}"
              memory: "${APP_MEM}"
            limits:
              cpu: "${APP_CPU}"
              memory: "${APP_MEM}"
EOF

    echo "Applying namespaces ..."
    kubectl apply -f application-a/namespace.yaml
    kubectl apply -f application-b/namespace.yaml
    kubectl apply -f application-c/namespace.yaml

    echo "Tainting ${NODE01_NAME} ..."
    kubectl taint nodes "${NODE01_NAME}" "${NODE01_TAINT_KEY}=true:NoSchedule" --overwrite

    echo "Creating PriorityClass ${PRIORITY_CLASS_NAME} ..."
    cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ${PRIORITY_CLASS_NAME}
value: ${PRIORITY_CLASS_VALUE}
globalDefault: false
description: "Reserved for the scenario2 instructions pods."
EOF

    echo "Applying application-a ..."
    kubectl apply -f application-a/deployment.yaml
    kubectl apply -f application-a/service.yaml

    echo "Applying application-b ..."
    kubectl apply -f application-b/deployment.yaml
    kubectl apply -f application-b/service.yaml
    kubectl apply -f application-b/networkpolicy.yaml

    echo "Applying application-c (no service.yaml on purpose) ..."
    kubectl apply -f application-c/deployment.yaml

    if kubectl get deployment instructions -n default >/dev/null 2>&1; then
        echo "instructions deployment already exists in default namespace, skipping creation"
        echo "(run 'kubectl delete deployment instructions -n default' first to regenerate it)"
    else
        echo "Creating the instructions deployment via kubectl CLI (no YAML file) ..."
        kubectl create deployment instructions \
          --image="${INSTR_IMAGE}" \
          --replicas="${INSTR_REPLICAS}" \
          -n default

        kubectl set resources deployment/instructions -n default \
          --requests="cpu=${INSTR_CPU},memory=${INSTR_MEM}" \
          --limits="cpu=${INSTR_CPU},memory=${INSTR_MEM}"

        kubectl patch deployment instructions -n default --type=merge -p "$(cat <<PATCH
{
  "spec": {
    "template": {
      "spec": {
        "priorityClassName": "${PRIORITY_CLASS_NAME}",
        "nodeSelector": {
          "kubernetes.io/hostname": "${NODE01_NAME}"
        },
        "tolerations": [
          {"key": "${NODE01_TAINT_KEY}", "operator": "Equal", "value": "true", "effect": "NoSchedule"}
        ]
      }
    }
  }
}
PATCH
)"
    fi

    echo ""
    echo "scenario2 is live. Start here:"
    echo "  kubectl logs -n default -l app=instructions --tail=50"
    exit 0
    ;;

  *)
    echo "Unknown scenario: ${SCENARIO_NAME}" >&2
    exit 1
    ;;

esac

echo "Created ${OUTPUT_FILE}"
