ARG UBI_IMAGE
ARG GO_IMAGE
ARG TAG="1.19.1"
ARG ARCH="amd64"
FROM ${UBI_IMAGE} as ubi
FROM ${GO_IMAGE} as base-builder
# setup required packages
RUN set -x \
 && apk --no-cache add \
    file \
    gcc \
    git \
    make

# setup the dnsNodeCache build
FROM base-builder as dnsNodeCache-builder
ARG SRC=github.com/kubernetes/dns
ARG PKG=github.com/kubernetes/dns
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
ARG TAG
ARG ARCH
ARG K3S_ROOT_VERSION="v0.9.1"
ADD https://github.com/k3s-io/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-${ARCH}.tar /opt/k3s-root/k3s-root.tar
RUN tar xvf /opt/k3s-root/k3s-root.tar -C /opt/k3s-root --wildcards --strip-components=2 './bin/aux/*tables*'
WORKDIR $GOPATH/src/${PKG}
RUN git tag --list
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN GOARCH=${ARCH} GO_LDFLAGS="-linkmode=external -X ${PKG}/pkg/version.VERSION=${TAG}" \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o . ./...
RUN go-assert-static.sh node-cache
RUN go-assert-boring.sh node-cache
RUN install -s node-cache /usr/local/bin

FROM ubi as dnsNodeCache
RUN yum install -y nc which && \
    rm -rf /var/cache/yum
COPY --from=dnsNodeCache-builder /usr/local/bin/node-cache /node-cache
COPY --from=dnsNodeCache-builder /opt/k3s-root/aux/ip* /usr/sbin/
COPY --from=dnsNodeCache-builder /opt/k3s-root/aux/xtables* /usr/sbin/
ENTRYPOINT ["/node-cache"]
