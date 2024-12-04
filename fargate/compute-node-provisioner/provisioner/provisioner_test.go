package provisioner_test

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	provisioner "github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/aws"
	"github.com/stretchr/testify/assert"
)

func TestAWSProvisioner(t *testing.T) {
	provisioner := provisioner.NewAWSProvisioner(aws.Config{}, "someAccountId", "UNKNOWN_ACTION", "dev", "ih")
	err := provisioner.Run(context.Background())
	assert.Equal(t, "action not supported: UNKNOWN_ACTION", err.Error())
}
