FROM golang:1 AS build

ARG VERSION="0.3.6"
ARG CHECKSUM="bb9f8dbbdd9b9241dc04f96061a7ccebc71dfad23f286df7edfc2d0f6e82319b"

ADD https://github.com/knovus/metrics-server/archive/v$VERSION.tar.gz /tmp/metrics-server.tar.gz

RUN [ "$CHECKSUM" = "$(sha256sum /tmp/metrics-server.tar.gz | awk '{print $1}')" ] && \
    mkdir -p /go/src/github.com/kubernetes-incubator && \
    tar -C /go/src/github.com/kubernetes-incubator -xf /tmp/metrics-server.tar.gz && \
    mv /go/src/github.com/kubernetes-incubator/metrics-server-$VERSION /go/src/github.com/kubernetes-incubator/metrics-server && \
    cd /go/src/github.com/kubernetes-incubator/metrics-server && \
      go run vendor/k8s.io/kube-openapi/cmd/openapi-gen/openapi-gen.go --logtostderr -i k8s.io/metrics/pkg/apis/metrics/v1beta1,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/version -p github.com/kubernetes-incubator/metrics-server/pkg/generated/openapi/ -O zz_generated.openapi -h /go/src/github.com/kubernetes-incubator/metrics-server/hack/boilerplate.go.txt -r /dev/null && \
      CGO_ENABLED=0 go build -o /tmp/metrics-server github.com/kubernetes-incubator/metrics-server/cmd/metrics-server

RUN mkdir -p /rootfs/etc /rootfs/apiserver.local.config && \
    cp /tmp/metrics-server /rootfs/ && \
    echo "nogroup:*:100:nobody" > /rootfs/etc/group && \
    echo "nobody:*:100:100:::" > /rootfs/etc/passwd


FROM scratch

COPY --from=build --chown=100:100 /rootfs /

USER 100:100
EXPOSE 8443/tcp
ENTRYPOINT ["/metrics-server"]
CMD ["--logtostderr", "--secure-port=8443"]