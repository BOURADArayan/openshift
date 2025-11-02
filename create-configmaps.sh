#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          CREATING IMS CONFIGMAPS FOR OPENSHIFT               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

BASE_DIR="$HOME/docker_open5gs"

echo -e "${YELLOW}Creating namespace 'ims'...${NC}"
oc create namespace ims --dry-run=client -o yaml | oc apply -f -
echo -e "${GREEN}✓ Namespace 'ims' ready${NC}"
echo ""

echo -e "${YELLOW}Creating SCSCF ConfigMap...${NC}"
if [ -d "$BASE_DIR/scscf" ]; then
    oc create configmap scscf-config \
        --from-file=$BASE_DIR/scscf/ \
        --namespace=ims \
        --dry-run=client -o yaml | oc apply -f -
    echo -e "${GREEN}✓ ConfigMap scscf-config created${NC}"
else
    echo -e "${RED}✗ Directory $BASE_DIR/scscf not found${NC}"
fi
echo ""

echo -e "${YELLOW}Creating ICSCF ConfigMap...${NC}"
if [ -d "$BASE_DIR/icscf" ]; then
    oc create configmap icscf-config \
        --from-file=$BASE_DIR/icscf/ \
        --namespace=ims \
        --dry-run=client -o yaml | oc apply -f -
    echo -e "${GREEN}✓ ConfigMap icscf-config created${NC}"
else
    echo -e "${RED}✗ Directory $BASE_DIR/icscf not found${NC}"
fi
echo ""

echo -e "${YELLOW}Creating PCSCF ConfigMap...${NC}"
if [ -d "$BASE_DIR/pcscf" ]; then
    oc create configmap pcscf-config \
        --from-file=$BASE_DIR/pcscf/ \
        --namespace=ims \
        --dry-run=client -o yaml | oc apply -f -
    echo -e "${GREEN}✓ ConfigMap pcscf-config created${NC}"
else
    echo -e "${RED}✗ Directory $BASE_DIR/pcscf not found${NC}"
fi
echo ""

echo -e "${YELLOW}Creating HSS ConfigMap...${NC}"
if [ -d "$BASE_DIR/pyhss" ]; then
    oc create configmap hss-config \
        --from-file=$BASE_DIR/pyhss/ \
        --namespace=ims \
        --dry-run=client -o yaml | oc apply -f -
    echo -e "${GREEN}✓ ConfigMap hss-config created${NC}"
elif [ -d "$BASE_DIR/hss" ]; then
    oc create configmap hss-config \
        --from-file=$BASE_DIR/hss/ \
        --namespace=ims \
        --dry-run=client -o yaml | oc apply -f -
    echo -e "${GREEN}✓ ConfigMap hss-config created${NC}"
else
    echo -e "${RED}✗ Directory $BASE_DIR/pyhss or $BASE_DIR/hss not found${NC}"
fi
echo ""

echo -e "${YELLOW}Creating PCRF ConfigMap...${NC}"
if [ -d "$BASE_DIR/pcrf" ]; then
    oc create configmap pcrf-config \
        --from-file=$BASE_DIR/pcrf/ \
        --namespace=ims \
        --dry-run=client -o yaml | oc apply -f -
    echo -e "${GREEN}✓ ConfigMap pcrf-config created${NC}"
else
    echo -e "${YELLOW}⚠ Directory $BASE_DIR/pcrf not found (optional)${NC}"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               CONFIGMAPS CREATION COMPLETED                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
