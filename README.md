# kube-gelf

[Fluentd](https://www.fluentd.org/) [CoreOS](https://coreos.com/) Kubernetes container logs & [journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) log collector with [Graylog](https://www.graylog.org/) output.
Configurable through [ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) and with provided cron example to mitigate some fluentd bugs as well as providing option for config reloads

## Notes

This project is automaticly built at [Docker Hub](https://hub.docker.com/r/roffe/kube-gelf/)

This image has only been tested with CoreOS but should work with any other distribution as long as the paths in fluent.conf & the daemonset is adjusted accordingly.

## Installation

```sh
kubectl create -f rbac.yaml

kubectl create configmap \
    --namespace kube-system kube-gelf \
    --from-file fluent.conf \
    --from-file certs/graylogCA.pem \
    --from-literal GELF_HOST=<server address> \
    --from-literal GELF_PORT=12201 \
    --from-literal GELF_PROTOCOL=<udp|tcp>

kubectl create -f daemonset.yaml

# optional, see notes below
kubectl create -f cron.yaml
```

The graylogCA.pem is optional. Adding it will allow you to use custom ssl certificates. See section about Custom certificates.

After updating the configmap reloading fluentd config on all pods can be done with kubectl access.
Please allow atleast a minute to pass before issuing the command due to Kubernetes not real-time syncing configmap updates to volumes.

```sh
for POD in `kubectl get pod --namespace kube-system -l app=kube-gelf | tail -n +2 | awk '{print $1}'`; do echo RELOAD ${POD}; kubectl exec --namespace kube-system ${POD} -- /bin/sh -c 'kill -1 1'; done
```

## Cron

As of Kubernetes 1.8 batch/v1beta1 is enabled by default and no additional changes are needed.

If you are on < 1.8:

Enable `batch/v2alpha1=true` in the apiserver(s) `--runtime-config=` & restart apiservers + controller-manager.
Also change the apiVersion from `batch/v1beta1` to `batch/v2alpha1`

The cron.yaml can be used to deploy a cronJob that periodicly tells kube-gelf to reload it's configuration to also works around some fluend bugs.

I have several images made for different Kubernetes versions and you could adapt your cron.yaml by using any of my avail image tags here: <https://hub.docker.com/r/roffe/kubectl/tags/>

## Custom ( Self signed ) certificates

You can use self signed certificates to encrypt and authenticate the connection between the FlientD instance in the kube-gelf pod and the Graylog server. 
To have a secure setup you will need to use certificates both to authenticate the server and the client. Without client authenticate you let anyone send data to Graylog on behalf of any server. 

Securing the Graylog server is out of scope for this article. I will only mention that if you have a self signed certificate on your graylog server, you can add the CA file to the kube-gelf pod and it will use that to authenticate the server for the client. 

In the same way you can create a self signed certificate and add this to the kube-gelf pods. You can let the Graylog server authenticate the kube-gelf pod if you also add the certificate as a trusted certificate on the Graylog server.

```sh
# To create a selfsigned certificate and its key
openssl req -nodes -x509 -newkey rsa:4096 -keyout graylog_client.key -out graylog_client.crt -days 365
```

## Fluentd Bugs

in_tail prevents docker from removing container
<https://github.com/fluent/fluentd/issues/1680>.

in_tail removes untracked file position during startup phase. It means the content of pos_file is growing until restart when you tails lots of files with dynamic path setting. I will fix this problem in the future. Check this issue.
<https://github.com/fluent/fluentd/issues/1126>.

## Changelog

### 1.3

* Updated packages to newest stable versions

### 1.2

* Introduced new ENV variable GELF_PROTOCOL for protocol selection. Valid values are "udp" or "tcp". This requires a update of you configmap from earlier verisons
* Changed output plugin to <https://github.com/bodhi-space/fluent-plugin-gelf-hs>

### 1.1

Got rid of hostNetwork and added a NODENAME env variable utilizing the downward api. All log entries will contain the field `hostname: <your nodename in kubernetes>`
