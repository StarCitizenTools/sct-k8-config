<div align="center">
☸️
<h1>Star Citizen Wiki Kubernetes</h1>

[Docker Hub](https://hub.docker.com/r/starcitizentools/mediawiki) | [Docker images](https://github.com/StarCitizenTools/sct-docker-images)
</div>

The Kubernetes configuration powering https://starcitizen.tools

## Commands
### Cert Manager
```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
```

### Elastic Search
```sh
kubectl create -f https://download.elastic.co/downloads/eck/2.5.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.5.0/operator.yaml
```

### Ingress
```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install -f ingress-values.yaml ingress-nginx ingress-nginx/ingress-nginx
```
