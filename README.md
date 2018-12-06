## Deploying an Express Handler to Knative

* [Installing Knative (for Kubernetes in Docker for Mac)](#installing-knative)
* [Installing the Express build template](#Installing-the-Express-build-template)
* [Build and deploy your handler](#Build-and-deploy-your-handler)
* [Testing your Handler](#Testing-your-Handler)


### Installing Knative

1. Ramp up memory usage of Kubernetes
  * Click on the Docker logo in the toolbar and select **Preferences...**
  * Move the Memory slider to at least **6.0GiB**
  * Click **Apply & Restart**

2. Install Istio using **NodePort** rather than **LoadBalancer** (there is no LoadBalancer in the embedded Kubernetes in Docker for Mac):

  ```
  curl -L https://storage.googleapis.com/knative-releases/serving/latest/istio.yaml | sed 's/LoadBalancer/NodePort/' | kubectl apply -f -
  ```
  
3. Enable Istio injection:
  
  ```
  kubectl label namespace default istio-injection=enabled
  ```
  
4. Wait for Istio to come up:
  
  ```
  $ kubectl get pods --namespace=istio-system
  ```
  
5. Install Knative*-Lite* with **NodePort** rather than **LoadBalancer**:

  ```
  curl -L https://storage.googleapis.com/knative-releases/serving/latest/release-lite.yaml | sed 's/LoadBalancer/NodePort/' | kubectl apply -f -
  ```
  
6. Wait for Knative Serving and Knative Build to come up:

  ```
  kubectl get pods --namespace=knative-serving
  kubectl get pods --namespace=knative-build
  ```
  
### Installing the Express build template  
  
1. Create the following as `express.yaml` for the “express” build template:

  ```
  apiVersion: build.knative.dev/v1alpha1
  kind: BuildTemplate
  metadata:
    name: express 
  spec:
    parameters:
    - name: IMAGE
      description: The name of the image to push
    - name: DOCKERFILE
      description: Path to the Dockerfile to build.
      default: /workspace/Dockerfile

    steps:
    - name: build-and-push 
      image: gcr.io/kaniko-project/executor
      imagePullPolicy: IfNotPresent
      args:
      - --dockerfile=/workspace/Dockerfile
      - --destination=${IMAGE}
  ```

2. Install the template:

  ```
  kubectl apply -f express.yaml
  ```
  
### Build and deploy your handler

1. Create the following as `express-action.yaml` your applications build definition:  

  ```
  apiVersion: serving.knative.dev/v1alpha1
  kind: Service
  metadata:
    name: express-action 
    namespace: default
  spec:
    runLatest:
      configuration:
        build:
          apiVersion: build.knative.dev/v1alpha1
          kind: Build
          spec:
            serviceAccountName: build-bot
            source:
              git:
                url: https://github.com/seabaylea/action.git
                revision: master
            template:
              name: express 
              arguments:
                - name: IMAGE
                  value: docker.io/seabaylea/express-action:latest
        revisionTemplate:
          spec:
            container:
              image: docker.io/seabaylea/express-action:latest
              imagePullPolicy: IfNotPresent
  ```

2. Build and install your application:

  ```
  kubectl apply -f express-action.yaml
  ```
  
3. Check the deployments and make sure its listed

  ```
  kubectl get deployments
  ```
  
  Should respond with:
  
  ```
  NAME                              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
express-action-00001-deployment   1         1         1            1           1m
  ```
  
4. Get the deployed service

  ```
  kubectl get service express-action
  ```
  
  Should respond with:
  
  ```
  NAME             TYPE           CLUSTER-IP   EXTERNAL-IP                                             PORT(S)   AGE
express-action   ExternalName   <none>       knative-ingressgateway.istio-system.svc.cluster.local   <none>    1m
  ```
  
### Testing your Handler

1. Find the NodePort for your application:

  ```
  kubectl get svc knative-ingressgateway -n istio-system
  ```
  
  Should respond with:
  
  ```
  NAME                     TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                                                                   AGE
  knative-ingressgateway   NodePort   10.111.249.41   <none>        80:32380/TCP,443:32390/TCP,31400:32400/TCP,15011:30535/TCP,8060:30364/TCP,853:32032/TCP,15030:32150/TCP,15031:30732/TCP   1h
  ```
  
  Grab the port mapped to `80`, in this case `32380`.
  
2. Access the service using cURL:

  ```
  curl -v -H "Host: express-action.default.example.com" http://127.0.0.1:32380
  ```
  
  The structure for Host is `{service-name}.{namespace}.example.com`
  
3. Check that you get the expected response:

  ```
  * Rebuilt URL to: http://127.0.0.1:32380/
  *   Trying 127.0.0.1...
  * TCP_NODELAY set
  * Connected to 127.0.0.1 (127.0.0.1) port 32380 (#0)
  > GET / HTTP/1.1
  > Host: express-action.default.example.com
  > User-Agent: curl/7.61.1
  > Accept: */*
  > 
  < HTTP/1.1 200 OK
  < content-length: 20
  < content-type: text/html; charset=utf-8
  < date: Thu, 06 Dec 2018 11:46:48 GMT
  < etag: W/"14-VKC9Q8ZTduiYvUDeKbM7TN/QrTA"
  < server: envoy
  < x-envoy-upstream-service-time: 8244
  < x-powered-by: Express
  < 
  * Connection #0 to host 127.0.0.1 left intact
  Hello Knative World!
  ```
