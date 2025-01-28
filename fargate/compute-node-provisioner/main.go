package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/google/uuid"
	aws "github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/aws"
	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/parser"
	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/store_dynamodb"
	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/utils"
)

func main() {
	log.Println("Running compute node provisioner")
	ctx := context.Background()

	computeNodeId := os.Getenv("COMPUTE_NODE_ID")
	action := os.Getenv("ACTION")

	accountUuid := os.Getenv("ACCOUNT_UUID")
	accountId := os.Getenv("ACCOUNT_ID")
	accountType := os.Getenv("ACCOUNT_TYPE")
	organizationId := os.Getenv("ORG_ID")
	userId := os.Getenv("USER_ID")
	env := os.Getenv("ENV")
	nodeName := os.Getenv("NODE_NAME")
	nodeDescription := os.Getenv("NODE_DESCRIPTION")
	wmTag := os.Getenv("WM_TAG")

	computeNodesTable := os.Getenv("COMPUTE_NODES_TABLE")

	// Initializing environment
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("LoadDefaultConfig: %v\n", err)
	}

	nodeIdentifier := fmt.Sprint(utils.GenerateHash(organizationId))
	err = os.Setenv("NODE_IDENTIFIER", nodeIdentifier)
	if err != nil {
		log.Fatal("error setting node identifier", err.Error())
	}

	var tagValue string
	if wmTag == "" {
		tagValue = "latest"
	} else {
		tagValue = wmTag
	}
	err = os.Setenv("WM_TAG", tagValue)
	if err != nil {
		log.Fatal("error setting workflow manager tag value", err.Error())
	}

	provisioner := aws.NewAWSProvisioner(cfg, accountId, action, env, nodeIdentifier)
	err = provisioner.Run(ctx)
	if err != nil {
		log.Fatal("error running provisioner", err.Error())
	}

	// after provisioning actions
	switch action {
	case "CREATE":
		// parse output file created after infrastructure creation
		parser := parser.NewOutputParser("/usr/src/app/terraform/infrastructure/outputs.json")
		outputs, err := parser.Run(ctx)
		if err != nil {
			log.Fatal("error running output parser", err.Error())
		}

		// persist to dynamodb
		dynamoDBClient := dynamodb.NewFromConfig(cfg)
		computeNodesStore := store_dynamodb.NewNodeDatabaseStore(dynamoDBClient, computeNodesTable)

		nodes, err := computeNodesStore.Get(ctx, accountUuid, env, nodeIdentifier)
		if err != nil {
			log.Fatal(err.Error())
		}
		if len(nodes) > 1 {
			log.Fatal("expected only one compute node entry")
		}
		if len(nodes) == 1 {
			log.Fatalf("compute node with account uuid: %s, env: %s, identifier: %s already exists",
				nodes[0].AccountUuid, nodes[0].Env, nodes[0].Identifier)

		}

		id := uuid.New()
		computeNodeId := id.String()
		store_nodes := store_dynamodb.Node{
			Uuid:                  computeNodeId,
			Name:                  nodeName,
			Description:           nodeDescription,
			ComputeNodeGatewayUrl: outputs.ComputeNodeGatewayUrl.Value,
			EfsId:                 outputs.EfsId.Value,
			QueueUrl:              outputs.QueueUrl.Value,
			Env:                   env,
			AccountUuid:           accountUuid,
			AccountId:             accountId,
			AccountType:           accountType,
			OrganizationId:        organizationId,
			UserId:                userId,
			CreatedAt:             time.Now().UTC().String(),
			Identifier:            nodeIdentifier,
		}
		err = computeNodesStore.Insert(ctx, store_nodes)
		if err != nil {
			log.Fatal(err.Error())
		}
	case "DELETE":
		log.Println("Deleting", computeNodeId)
		dynamoDBClient := dynamodb.NewFromConfig(cfg)
		computeNodesStore := store_dynamodb.NewNodeDatabaseStore(dynamoDBClient, computeNodesTable)

		err = computeNodesStore.Delete(ctx, computeNodeId)
		if err != nil {
			log.Fatal(err.Error())
		}

	default:
		log.Fatalf("action not supported: %s", action)
	}

	log.Println("provisioning complete")
}
