package parser_test

import (
	"context"
	"testing"

	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/parser"
	"github.com/stretchr/testify/assert"
)

func TestOutputParser(t *testing.T) {
	parser := parser.NewOutputParser("./test-data/outputs_test.json")
	outputs, _ := parser.Run(context.Background())
	assert.Equal(t, "https://some-gateway-url.aws/", outputs.ComputeNodeGatewayUrl.Value)
	assert.Equal(t, "fs-some-efs-id", outputs.EfsId.Value)
	assert.Equal(t, "https://sqs.region.amazonaws.com/some-sql-url", outputs.QueueUrl.Value)
}
