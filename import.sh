#!/bin/bash
docker-compose up -d endpoint
docker-compose exec endpoint \
    wget \ 
    https://github.com/mintproject/fuseki-docker/blob/master/backups/modelCatalog-1.7.0_2021-05-20_14-02-34.nq.gz?raw=true \
    -O /tmp/modelCatalog-1.7.0_2021-05-20_14-02-34.nq.gz
docker-compose exec endpoint \
    /jena/bin/tdbloader2   \
        --loc=/fuseki-base/databases/new_dataset \
        /tmp/modelCatalog-1.7.0_2021-05-20_14-02-34.nq.gz
docker-compose exec endpoint \
    rm -rf /fuseki-base/databases/modelCatalog-1.7.0
docker-compose exec endpoint \
    ln -s /fuseki-base/databases/new_dataset /fuseki-base/databases/modelCatalog-1.7.0
docker restart endpoint
