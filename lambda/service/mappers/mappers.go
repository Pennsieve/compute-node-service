package mappers

import (
	"github.com/pennsieve/compute-node-service/service/models"
	"github.com/pennsieve/compute-node-service/service/store_dynamodb"
)

func DynamoDBNodeToJsonNode(dynamoNodes []store_dynamodb.Node) []models.Node {
	nodes := []models.Node{}

	for _, c := range dynamoNodes {
		nodes = append(nodes, models.Node{
			Uuid:                  c.Uuid,
			Name:                  c.Name,
			Description:           c.Description,
			ComputeNodeGatewayUrl: c.ComputeNodeGatewayUrl,
			EfsId:                 c.EfsId,
			QueueUrl:              c.QueueUrl,
			Account: models.Account{
				Uuid:        c.AccountUuid,
				AccountId:   c.AccountId,
				AccountType: c.AccountType,
			},
			CreatedAt:          c.CreatedAt,
			OrganizationId:     c.OrganizationId,
			UserId:             c.UserId,
			Identifier:         c.Identifier,
			WorkflowManagerTag: c.WorkflowManagerTag,
		})
	}

	return nodes
}
