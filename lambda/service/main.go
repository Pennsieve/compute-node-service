package main

import (
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/pennsieve/compute-node-service/service/handler"
)

func main() {
	lambda.Start(handler.ComputeNodeServiceHandler)
}
