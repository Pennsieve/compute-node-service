package handler

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ecs"
	"github.com/aws/aws-sdk-go-v2/service/ecs/types"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/pennsieve/compute-node-service/service/runner"
	"github.com/pennsieve/pennsieve-go-core/pkg/authorizer"
)

func DeleteComputeNodeHandler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	handlerName := "DeleteComputeNodeHandler"
	uuid := request.PathParameters["id"]

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Println(err.Error())
		return events.APIGatewayV2HTTPResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       handlerError(handlerName, ErrConfig),
		}, nil
	}

	TaskDefinitionArn := os.Getenv("TASK_DEF_ARN")
	subIdStr := os.Getenv("SUBNET_IDS")
	SubNetIds := strings.Split(subIdStr, ",")
	cluster := os.Getenv("CLUSTER_ARN")
	SecurityGroup := os.Getenv("SECURITY_GROUP")
	envValue := os.Getenv("ENV")
	TaskDefContainerName := os.Getenv("TASK_DEF_CONTAINER_NAME")

	claims := authorizer.ParseClaims(request.RequestContext.Authorizer.Lambda)
	organizationId := claims.OrgClaim.NodeId
	userId := claims.UserClaim.NodeId

	client := ecs.NewFromConfig(cfg)
	log.Println("Initiating new Provisioning Fargate Task.")
	computeNodeIdKey := "COMPUTE_NODE_ID"
	envKey := "ENV"
	organizationIdKey := "ORG_ID"
	organizationIdValue := organizationId
	userIdKey := "USER_ID"
	userIdValue := userId
	actionKey := "ACTION"
	actionValue := "DELETE"
	tableKey := "COMPUTE_NODES_TABLE"
	tableValue := os.Getenv("COMPUTE_NODES_TABLE")

	runTaskIn := &ecs.RunTaskInput{
		TaskDefinition: aws.String(TaskDefinitionArn),
		Cluster:        aws.String(cluster),
		NetworkConfiguration: &types.NetworkConfiguration{
			AwsvpcConfiguration: &types.AwsVpcConfiguration{
				Subnets:        SubNetIds,
				SecurityGroups: []string{SecurityGroup},
				AssignPublicIp: types.AssignPublicIpEnabled,
			},
		},
		Overrides: &types.TaskOverride{
			ContainerOverrides: []types.ContainerOverride{
				{
					Name: &TaskDefContainerName,
					Environment: []types.KeyValuePair{
						{
							Name:  &computeNodeIdKey,
							Value: &uuid,
						},
						{
							Name:  &envKey,
							Value: &envValue,
						},
						{
							Name:  &actionKey,
							Value: &actionValue,
						},
						{
							Name:  &tableKey,
							Value: &tableValue,
						},
						{
							Name:  &organizationIdKey,
							Value: &organizationIdValue,
						},
						{
							Name:  &userIdKey,
							Value: &userIdValue,
						},
					},
				},
			},
		},
		LaunchType: types.LaunchTypeFargate,
	}

	runner := runner.NewECSTaskRunner(client, runTaskIn)
	if err := runner.Run(ctx); err != nil {
		log.Println(err)
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       handlerError(handlerName, ErrRunningFargateTask),
		}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: http.StatusAccepted,
		Body:       string("Compute node deletion initiated"),
	}, nil
}
