package store_dynamodb

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/expression"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go/aws"
)

type DynamoDBStore interface {
	GetById(context.Context, string) (Node, error)
	Get(context.Context, string) ([]Node, error)
}

type NodeDatabaseStore struct {
	DB        *dynamodb.Client
	TableName string
}

func NewNodeDatabaseStore(db *dynamodb.Client, tableName string) DynamoDBStore {
	return &NodeDatabaseStore{db, tableName}
}
func (r *NodeDatabaseStore) GetById(ctx context.Context, uuid string) (Node, error) {
	account := Node{Uuid: uuid}
	response, err := r.DB.GetItem(ctx, &dynamodb.GetItemInput{
		Key: account.GetKey(), TableName: aws.String(r.TableName),
	})
	if err != nil {
		return account, fmt.Errorf("error getting account: %w", err)
	}

	err = attributevalue.UnmarshalMap(response.Item, &account)
	if err != nil {
		return account, fmt.Errorf("error unmarshaling account: %w", err)
	}

	return account, nil
}

func (r *NodeDatabaseStore) Get(ctx context.Context, filter string) ([]Node, error) {
	accounts := []Node{}
	filt := expression.Name("organizationId").Equal((expression.Value(filter)))
	expr, err := expression.NewBuilder().WithFilter(filt).Build()
	if err != nil {
		return accounts, fmt.Errorf("error building expression: %w", err)
	}

	response, err := r.DB.Scan(ctx, &dynamodb.ScanInput{
		ExpressionAttributeNames:  expr.Names(),
		ExpressionAttributeValues: expr.Values(),
		FilterExpression:          expr.Filter(),
		ProjectionExpression:      expr.Projection(),
		TableName:                 aws.String(r.TableName),
	})
	if err != nil {
		return accounts, fmt.Errorf("error getting accounts: %w", err)
	}

	err = attributevalue.UnmarshalListOfMaps(response.Items, &accounts)
	if err != nil {
		return accounts, fmt.Errorf("error unmarshaling accounts: %w", err)
	}

	return accounts, nil
}
