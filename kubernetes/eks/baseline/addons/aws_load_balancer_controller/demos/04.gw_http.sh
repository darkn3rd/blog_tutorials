kubectl create deployment demo-alb-app --image=nginx:alpine
kubectl expose deployment demo-alb-app --port=80
