package main

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/google/uuid"
	aws "github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/aws"
	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/parser"
	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/store_dynamodb"
)

func main() {
	log.Println("Running compute node provisioner")
	ctx := context.Background()

	accountId := os.Getenv("ACCOUNT_ID")
	action := os.Getenv("ACTION")
	env := os.Getenv("ENV")
	computeNodesTable := os.Getenv("COMPUTE_NODES_TABLE")

	// Initializing environment
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("LoadDefaultConfig: %v\n", err)
	}

	provisioner := aws.NewAWSProvisioner(iam.NewFromConfig(cfg), sts.NewFromConfig(cfg),
		accountId, action, env)
	err = provisioner.Run(ctx)
	if err != nil {
		log.Fatal("error running provisioner", err.Error())
	}

	parser := parser.NewOutputParser("/usr/src/app/terraform/infrastructure/outputs.json")
	outputs, err := parser.Run(ctx)
	if err != nil {
		log.Fatal("error running output parser", err.Error())
	}

	dynamoDBClient := dynamodb.NewFromConfig(cfg)
	computeNodesStore := store_dynamodb.NewNodeDatabaseStore(dynamoDBClient, computeNodesTable)
	id := uuid.New()
	registeredAccountId := id.String()
	// persist to dynamodb
	store_nodes := store_dynamodb.Node{
		Uuid:                  registeredAccountId,
		ComputeNodeGatewayUrl: outputs.ComputeNodeGatewayUrl.Value,
		EfsId:                 outputs.EfsId.Value,
		SqsUrl:                outputs.SqsUrl.Value,
		WorkflowManagerEcrUrl: outputs.WorkflowManagerEcrUrl.Value,
	}
	err = computeNodesStore.Insert(ctx, store_nodes)
	if err != nil {
		log.Fatal(err.Error())
	}

	log.Println("provisioning complete")
}
