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
	Insert(context.Context, Node) error
	Get(context.Context, string, string, string) ([]Node, error)
	Delete(context.Context, string) error
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

func (r *NodeDatabaseStore) Get(ctx context.Context, accountUuid string, environment string, tag string) ([]Node, error) {
	nodes := []Node{}
	filt1 := expression.Name("accountUuid").Equal((expression.Value(accountUuid)))
	filt2 := expression.Name("environment").Equal((expression.Value(environment)))
	filt3 := expression.Name("tag").Equal((expression.Value(tag)))
	expr, err := expression.NewBuilder().WithFilter(filt1.And(filt2).And(filt3)).Build()
	if err != nil {
		return nodes, fmt.Errorf("error building expression: %w", err)
	}

	response, err := r.DB.Scan(ctx, &dynamodb.ScanInput{
		ExpressionAttributeNames:  expr.Names(),
		ExpressionAttributeValues: expr.Values(),
		FilterExpression:          expr.Filter(),
		ProjectionExpression:      expr.Projection(),
		TableName:                 aws.String(r.TableName),
	})
	if err != nil {
		return nodes, fmt.Errorf("error getting nodes: %w", err)
	}

	err = attributevalue.UnmarshalListOfMaps(response.Items, &nodes)
	if err != nil {
		return nodes, fmt.Errorf("error unmarshaling nodes: %w", err)
	}

	return nodes, nil
}

func (r *NodeDatabaseStore) Delete(ctx context.Context, computeNodeId string) error {
	key, err := attributevalue.MarshalMap(DeleteNode{Uuid: computeNodeId})
	if err != nil {
		return fmt.Errorf("error marshaling for delete: %w", err)
	}

	_, err = r.DB.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		Key:       key,
		TableName: aws.String(r.TableName),
	})
	if err != nil {
		return fmt.Errorf("error deleting node: %w", err)
	}

	return nil
}
