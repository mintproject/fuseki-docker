# Fuseki

Apache [Jena Fuseki](https://jena.apache.org/documentation/fuseki2/index.html) with SeCo extensions.

Available in Docker Hub: [secoresearch/fuseki](https://hub.docker.com/r/secoresearch/fuseki/).

## Run

```bash
$ docker-compose up -d
```
## Import a backup

The fuseki instance must be running

```bash
$ docker-compose up -d endpoint
```

Import the backup into a new dataset.

```bash
$ curl https://github.com/mintproject/fuseki-docker/blob/master/backups/modelCatalog-1.7.0_2021-05-20_14-02-34.nq.gz?raw=true -o /tmp/modelCatalog-1.7.0_2021-05-20_14-02-34.nq.gz
```

```bash
$ docker-compose exec endpoint \
    /jena/bin/tdbloader2   \
        --loc=/fuseki-base/databases/new_dataset \
        /tmp/modelCatalog-1.7.0_2021-05-20_14-02-34.nq.gz
```

Remove the old dataset (modelCatalog-1.7.0) and link the newest.
```bash
$ docker-compose exec endpoint \
    rm -rf /fuseki-base/databases/modelCatalog-1.7.0
$ docker-compose exec endpoint \
    ln -s /fuseki-base/databases/new_dataset /fuseki-base/databases/modelCatalog-1.7.0
```

Restart endpoint

```bash
$ docker restart endpoint
```
