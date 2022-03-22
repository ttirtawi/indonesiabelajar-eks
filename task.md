1. Create mysql cdk deployment ==DONE==
2. Test the vpc peering script ==DONE==
3. Create deployment with the Kubernetes secret to store the password ==DONE==
4. Install ALB Controller
5. Deploy  

Expose the service using CLB:

```
kubectl expose deployment phonebook-deployment --port=80 --target-port=8080 --type=LoadBalancer
```

Get mysql db password:

```
aws secretsmanager get-secret-value --secret-id <SECRET_ID> --query SecretString --output text | jq -r .password
```

```
kubectl get secret dbsecret -o jsonpath='{.data.password}'
```


Demo step

1. Show the sample running application
2. Describe the application architecture, explain the RDS that already precreated
3. Explain the cluster creation using eksctl
4. Continue presentation
5. When cluster already created, create the peering
6. Populate db credential & create the Kubernetes secret  
7. Create deployment
8. Expose the service using CLB:

	```
	kubectl expose deployment phonebook-deployment --port=80 --target-port=8080 --type=LoadBalancer
	```

9. Setup application load balancer controller
10. Create service & ingress
11. Optional create https ingress
