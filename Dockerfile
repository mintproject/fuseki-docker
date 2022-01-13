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

FROM openjdk:14-alpine AS base

LABEL maintainer="jouni.tuominen@aalto.fi"

RUN apk add --update pwgen bash wget ca-certificates findutils coreutils ruby && rm -rf /var/cache/apk/*

# Update below according to htps://jena.apache.org/download/
ENV FUSEKI_SHA512 b0f877ac79bf1ea4cc60c4adf5ae3745e70fedb4041b136d9d13e5aa24539b50eb3fb55ccb9f7aedb718b085d617203844540b38a091fa18b419819224693b71
ENV FUSEKI_VERSION 4.3.2
ENV JENA_SHA512 39fc5b5b3103d1c861605f93f5ea867a24d0fb36590a4cfc8144cd701cced9558d2b06298ad466f002d21417077b68b943a8ee284a3d3f5a9d0a0fbbc4c3b008
ENV JENA_VERSION 4.3.2

ENV MIRROR https://dlcdn.apache.org
ENV ARCHIVE http://archive.apache.org/dist

# Config and data
ENV FUSEKI_BASE /fuseki-base

# Fuseki installation
ENV FUSEKI_HOME /jena-fuseki

ENV JENA_HOME /jena
ENV JENA_BIN $JENA_HOME/bin

WORKDIR /tmp
# sha512 checksum
RUN echo "$FUSEKI_SHA512  fuseki.tar.gz" > fuseki.tar.gz.sha512
# Download/check/unpack/move Fuseki in one go (to reduce image size)
RUN wget -O fuseki.tar.gz $MIRROR/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz || \
    wget -O fuseki.tar.gz $ARCHIVE/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz && \
    sha512sum -c fuseki.tar.gz.sha512 && \
    tar zxf fuseki.tar.gz && \
    mv apache-jena-fuseki* $FUSEKI_HOME && \
    rm fuseki.tar.gz* && \
    cd $FUSEKI_HOME && rm -rf fuseki.war

# Get tdbloader2 from Jena
# sha512 checksum
RUN echo "$JENA_SHA512  jena.tar.gz" > jena.tar.gz.sha512
# Download/check/unpack/move Jena in one go (to reduce image size)
RUN wget -O jena.tar.gz $MIRROR/jena/binaries/apache-jena-$JENA_VERSION.tar.gz || \
    wget -O jena.tar.gz $ARCHIVE/jena/binaries/apache-jena-$JENA_VERSION.tar.gz && \
    sha512sum -c jena.tar.gz.sha512 && \
    tar zxf jena.tar.gz && \
	mkdir -p $JENA_BIN && \
	mv apache-jena*/lib $JENA_HOME && \
    mv apache-jena*/bin/tdb* $JENA_BIN && \
	mv apache-jena*/bin/xload* $JENA_BIN && \
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
RUN chown -R 9008:9008 $FUSEKI_BASE && \
    chmod -R 775 $FUSEKI_BASE

USER 9008
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

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "org.apache.jena.fuseki.cmd.FusekiCmd"]
