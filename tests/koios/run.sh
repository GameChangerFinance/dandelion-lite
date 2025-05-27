
source "../../.env"

./tests.sh report 2>&1 | tee "${NETWORK}.report"