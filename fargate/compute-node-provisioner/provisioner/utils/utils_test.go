package utils_test

import (
	"fmt"
	"testing"

	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner/utils"
	"github.com/stretchr/testify/assert"
)

func TestGenerateHash(t *testing.T) {
	s := "N:organization:050fae39-4412-43ef-a514-703ed8e299d5"
	result := utils.GenerateHash(s)
	assert.Equal(t, "3688351936", fmt.Sprint(result))
}
