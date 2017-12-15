# Hound

Hound is an extremely fast source code search engine. See some details here:
https://hub.docker.com/r/etsy/hound/

and the code here:
https://github.com/etsy/hound

# How to

* To build the docker image:

  ```
  make image
  ```

* Try the image using docker:
 
  ```
  docker run -d -p 8080:8080 --name hound k8scode/hound:v0.1.0
  ```

* To deploy in kubernetes use the deployment.yaml and service.yaml

NOTE: hound takes a while to fetch data from github and only after that it starts listening on
the port 8080, so look at the logs to see if the endpoint has started. When it is done you will
see the following:

```
2017/12/15 14:55:58 All indexes built!
2017/12/15 14:55:58 running server at http://localhost:8080...
2017/12/15 15:02:01 Rebuilding kubernetes-bootcamp for af23e77ef9e90c4563d1a3bbb2c7313eec7ffb23
2017/12/15 15:02:01 merge 0 files + mem
2017/12/15 15:02:01 11802 data bytes, 35923 index bytes
```
