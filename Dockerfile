#   Licensed to the Apache Software Foundation (ASF) under one or more
#   contributor license agreements.  See the NOTICE file distributed with
#   this work for additional information regarding copyright ownership.
#   The ASF licenses this file to You under the Apache License, Version 2.0
#   (the "License"); you may not use this file except in compliance with
#   the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

FROM java:8-jre-alpine

LABEL maintainer="jouni.tuominen@aalto.fi"

RUN apk add --update curl pwgen bash wget ca-certificates findutils coreutils ruby && rm -rf /var/cache/apk/*

# Update below according to https://jena.apache.org/download/
ENV FUSEKI_SHA512 cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e
ENV FUSEKI_VERSION 3.8.0
ENV JENA_SHA512 0ebf2ecef04bd3534d471fc004425df905ee19d0d9def67d7b1531b49c9de20557dc5a53ae455b2ec7abc6592bfd8c70d6e68cba40cc4380e9313b669cae3383
ENV JENA_VERSION 3.8.0

ENV MIRROR http://www.eu.apache.org/dist/
ENV ARCHIVE http://archive.apache.org/dist/
ENV ASF_MIRROR http://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=
ENV ASF_ARCHIVE http://archive.apache.org/dist/


# Config and data
ENV FUSEKI_BASE /fuseki-base

# Fuseki installation
ENV FUSEKI_HOME /jena-fuseki

ENV JENA_HOME /jena
ENV JENA_BIN $JENA_HOME/bin

WORKDIR /tmp
# sha512 checksum
RUN echo "$FUSEKI_SHA512  fuseki.tar.gz" > fuseki.tar.gz.sha512

RUN     (curl --location --silent --show-error --fail --retry-connrefused --retry 3 --output fuseki.tar.gz ${ASF_MIRROR}jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz || \
         curl --fail --silent --show-error --retry-connrefused --retry 3 --output fuseki.tar.gz $ASF_ARCHIVE/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz) && \
        tar zxf fuseki.tar.gz && \
        mv apache-jena-fuseki* $FUSEKI_HOME && \
        rm fuseki.tar.gz* && \
        cd $FUSEKI_HOME && rm -rf fuseki.war && chmod 755 fuseki-server


# Get tdbloader2 from Jena
# sha512 checksum
RUN echo "$JENA_SHA512  jena.tar.gz" > jena.tar.gz.sha512
# Download/check/unpack/move Jena in one go (to reduce image size)
RUN (curl --location --silent --show-error --fail --retry-connrefused --retry 3 --output jena.tar.gz ${ASF_MIRROR}jena/binaries/apache-jena-$JENA_VERSION.tar.gz || \
         curl --fail --silent --show-error --retry-connrefused --retry 3 --output jena.tar.gz $ASF_ARCHIVE/jena/binaries/apache-jena-$FUSEKI_VERSION.tar.gz) && \
        tar zxf jena.tar.gz && \
        mkdir -p ${JENA_BIN} && \
	    mv apache-jena*/lib $JENA_HOME && \
	    mv apache-jena*/bin/tdbloader2* $JENA_BIN && \
        rm -rf apache-jena* && \
        rm jena.tar.gz*

# As "localhost" is often inaccessible within Docker container,
# we'll enable basic-auth with a random admin password
# (which we'll generate on start-up)
COPY shiro.ini /jena-fuseki/shiro.ini
COPY docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

# SeCo extensions
# Fuseki config
ENV MODEL_CATALOG $FUSEKI_BASE/configuration/model_catalog.ttl
COPY model_catalog.ttl $MODEL_CATALOG
ENV CONFIG $FUSEKI_BASE/config.ttl
COPY fuseki-config.ttl $CONFIG
RUN mkdir -p $FUSEKI_BASE/databases

# Set permissions to allow fuseki to run as an arbitrary user
RUN chgrp -R 0 $FUSEKI_BASE \
    && chmod -R g+rwX $FUSEKI_BASE

# Tools for loading data
ENV JAVA_CMD java -cp "$FUSEKI_HOME/fuseki-server.jar:/javalibs/*"
ENV TDBLOADER $JAVA_CMD tdb.tdbloader --desc=$MODEL_CATALOG
ENV TDBLOADER2 $JENA_BIN/tdbloader2 --loc=$FUSEKI_BASE/databases/tdb
ENV TDB2TDBLOADER $JAVA_CMD tdb2.tdbloader --desc=$MODEL_CATALOG
ENV TEXTINDEXER $JAVA_CMD jena.textindexer --desc=$MODEL_CATALOG
ENV TDBSTATS $JAVA_CMD tdb.tdbstats --desc=$MODEL_CATALOG
ENV TDB2TDBSTATS $JAVA_CMD tdb2.tdbstats --desc=$MODEL_CATALOG

WORKDIR /jena-fuseki
EXPOSE 3030
USER 9008

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "org.apache.jena.fuseki.cmd.FusekiCmd"]
