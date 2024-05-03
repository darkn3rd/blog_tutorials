# Dgraph Getting Started Using Access Key


```bash
export DGRAPH_HTTP="http://localhost:8080"
export DGRAPH_ADMIN_USER="groot"
export DGRAPH_ADMIN_PSWD="password"
# Fetch DGRAPH_TOKEN
../login.sh # sets DGRAPH_TOKEN
# Load Data
./1.data_json.sh # or run ./1.data_rds.sh
# Load Schema
./2.schema.sh
# Demo Queries
./3.query-starring_edge.sh
./4.query_movies_after_1980.sh
```