# Multi-Stage: Base dependencies
FROM alpine:3.11.2

ARG VCS_REF
ARG BUILD_DATE
ARG VERSION

# Metadata
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.name="inugami" \
      org.label-schema.vcs-url="https://github.com/caretak3r/inugami.git" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

# Environment Vars
# Note: Latest version of kubectl may be found at:
# https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html#w243aac27b9b9b3
ENV KUBE_LATEST_VERSION="1.14.6"

# Note: Latest version of helm may be found at:
# https://github.com/kubernetes/helm/releases
ENV HELM_VERSION="v3.0.2"

# Note: Latest version of terraform may be found at:
# https://releases.hashicorp.com/terraform/0.12.19/terraform_0.12.19_linux_amd64.zip
ENV TERRAFORM_VERSION="0.12.19"

# Repository setup and core packages
RUN sed -i 's|http://dl-cdn.alpinelinux.org|https://alpine.global.ssl.fastly.net|g' /etc/apk/repositories
RUN apk add --no-cache ca-certificates bash git openssh curl unzip gcc libffi-dev gcc linux-headers musl-dev \
    openssl-dev make build-dependencies and-build-dependencies

# todo: Tools to install as a multi-stage setup
# FROM cloudposse/packages:latest AS packages
# COPY --from=packages /packages/bin/kubectl /usr/local/bin/
# COPY --from=packages /packages/bin/terraform /usr/local/bin/
# COPY --from=packages /packages/bin/helm /usr/local/bin/
# COPY --from=packages /packages/bin/direnv /usr/local/bin/
# COPY --from=packages /packages/bin/tfenv /usr/local/bin/
# COPY --from=packages /packages/bin/chamber /usr/local/bin/
# COPY --from=packages /packages/bin/aws_iam_authenticator /usr/local/bin/

# Add kubectl
RUN wget -q https://amazon-eks.s3-us-west-2.amazonaws.com/${KUBE_LATEST_VERSION}/2019-08-22/bin/linux/amd64/kubectl \
    -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Add helm (v3)
RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - \
    | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

# Add terraform
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && chmod +x /usr/local/bin/terraform

# Multi-Stage: Python Dependencies
FROM alpine:3.11.2 as python

# This hack is widely applied to avoid python printing issues in docker containers.
# See: https://github.com/Docker-Hub-frolvlad/docker-alpine-python3/pull/13
ENV PYTHONUNBUFFERED=1

RUN echo "**** install Python ****" && \
    apk add --no-cache python3 python3-dev && \
    if [ ! -e /usr/bin/python ]; then ln -sf python3 /usr/bin/python ; fi && \
    \
    echo "**** install pip ****" && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools wheel && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi

COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt --install-option="--prefix=/dist" --no-build-isolation

#
#
#

# Base working directory
WORKDIR /conf

# Entrypoint
CMD bash