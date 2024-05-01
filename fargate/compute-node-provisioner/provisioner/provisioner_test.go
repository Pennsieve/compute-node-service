package provisioner_test

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	aws "github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/aws"
	"github.com/stretchr/testify/assert"
)

func TestAWSProvisioner(t *testing.T) {
	provisioner := aws.NewAWSProvisioner(&iam.Client{}, &sts.Client{}, "someAccountId", "UNKNOWN_ACTION", "dev")
	err := provisioner.Run(context.Background())
	assert.Equal(t, "action not supported: UNKNOWN_ACTION", err.Error())
}
