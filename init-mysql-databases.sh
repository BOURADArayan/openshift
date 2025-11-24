#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        MYSQL DATABASE INITIALIZATION FOR IMS                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}=== PART 1: WAITING FOR MYSQL POD ===${NC}"

# Attendre que le pod MySQL existe
echo -e "${YELLOW}Checking if MySQL pod exists...${NC}"
attempt=0
max_attempts=60
while [ $attempt -lt $max_attempts ]; do
    mysql_pod=$(oc get pod -l app=mysql -n ims -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$mysql_pod" ]; then
        echo -e "${GREEN}✓ MySQL pod found: $mysql_pod${NC}"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -ne "Waiting for MySQL pod... ($attempt/$max_attempts)\r"
    sleep 2
done

if [ -z "$mysql_pod" ]; then
    echo -e "${RED}✗ MySQL pod not found after $max_attempts attempts${NC}"
    echo "Please ensure MySQL deployment is running:"
    echo "  oc get pods -n ims"
    exit 1
fi

echo ""

# Vérifier que le pod est en état Running
echo -e "${YELLOW}Checking if MySQL pod is running...${NC}"
attempt=0
while [ $attempt -lt $max_attempts ]; do
    pod_status=$(oc get pod $mysql_pod -n ims -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [ "$pod_status" = "Running" ]; then
        echo -e "${GREEN}✓ MySQL pod is running${NC}"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -ne "Pod status: $pod_status - Waiting... ($attempt/$max_attempts)\r"
    sleep 2
done

if [ "$pod_status" != "Running" ]; then
    echo -e "${RED}✗ MySQL pod is not running. Current status: $pod_status${NC}"
    exit 1
fi

echo ""

# Attendre que MySQL soit prêt à accepter les connexions
echo -e "${YELLOW}Waiting for MySQL to be ready to accept connections...${NC}"
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if oc exec $mysql_pod -n ims -- mysql -u root -plinux -e "SELECT 1" &>/dev/null; then
        echo -e "${GREEN}✓ MySQL is ready and accepting connections${NC}"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -ne "Testing MySQL connection... ($attempt/$max_attempts)\r"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}✗ MySQL did not become ready in time${NC}"
    echo "Check MySQL logs:"
    echo "  oc logs $mysql_pod -n ims"
    exit 1
fi

echo ""

# Silent cleanup of existing databases
oc exec $mysql_pod -n ims -- sh -c 'export MYSQL_PWD=linux; mysql -u root -e "
DROP DATABASE IF EXISTS pcscf;
DROP DATABASE IF EXISTS scscf;
DROP DATABASE IF EXISTS icscf;
DROP DATABASE IF EXISTS kamailio;
"' &>/dev/null

echo -e "${YELLOW}=== PART 2: CREATING IMS DATABASES ===${NC}"

oc exec $mysql_pod -n ims -- sh -c 'export MYSQL_PWD=linux; mysql -u root -e "
CREATE DATABASE IF NOT EXISTS pcscf;
CREATE DATABASE IF NOT EXISTS scscf;
CREATE DATABASE IF NOT EXISTS icscf;
CREATE DATABASE IF NOT EXISTS kamailio;
"'

echo -e "${GREEN}✓ IMS databases created${NC}"
echo ""

echo -e "${YELLOW}=== PART 3: IMPORTING KAMAILIO SQL SCHEMAS ===${NC}"

KAMAILIO_SQL_DIR="$HOME/kamailio/utils/kamctl/mysql"
KAMAILIO_ICSCF_DIR="$HOME/kamailio/misc/examples/ims/icscf"

if [ ! -d "$KAMAILIO_SQL_DIR" ]; then
    echo -e "${RED}✗ Kamailio SQL directory not found: $KAMAILIO_SQL_DIR${NC}"
    echo "Please ensure Kamailio is cloned"
    exit 1
fi

echo -e "${YELLOW}Importing PCSCF schemas...${NC}"
cd $KAMAILIO_SQL_DIR

oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root pcscf' < standard-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root pcscf' < presence-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root pcscf' < ims_usrloc_pcscf-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root pcscf' < ims_dialog-create.sql

echo -e "${GREEN}✓ PCSCF schemas imported${NC}"
echo ""

echo -e "${YELLOW}Importing SCSCF schemas...${NC}"

oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root scscf' < standard-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root scscf' < presence-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root scscf' < ims_usrloc_scscf-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root scscf' < ims_dialog-create.sql
oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root scscf' < ims_charging-create.sql

echo -e "${GREEN}✓ SCSCF schemas imported${NC}"
echo ""

echo -e "${YELLOW}Importing ICSCF schemas...${NC}"

if [ -f "$KAMAILIO_ICSCF_DIR/icscf.sql" ]; then
    cd $KAMAILIO_ICSCF_DIR
    oc exec -i -n ims $mysql_pod -- sh -c 'export MYSQL_PWD=linux; mysql -u root icscf' < icscf.sql
    echo -e "${GREEN}✓ ICSCF schemas imported${NC}"
else
    echo -e "${RED}✗ ICSCF SQL file not found${NC}"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          MYSQL DATABASE INITIALIZATION COMPLETED             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
