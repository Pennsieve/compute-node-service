package store_dynamodb

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go/aws"
)

type DynamoDBStore interface {
	Insert(context.Context, Node) error
}

type NodeDatabaseStore struct {
	DB        *dynamodb.Client
	TableName string
}

func NewNodeDatabaseStore(db *dynamodb.Client, tableName string) DynamoDBStore {
	return &NodeDatabaseStore{db, tableName}
}

func (r *NodeDatabaseStore) Insert(ctx context.Context, node Node) error {
	item, err := attributevalue.MarshalMap(node)
	if err != nil {
		return fmt.Errorf("error marshaling node: %w", err)
	}
	_, err = r.DB.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(r.TableName), Item: item,
	})
	if err != nil {
		return fmt.Errorf("error inserting node: %w", err)
	}

	return nil
}
