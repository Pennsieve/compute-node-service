package main

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

func main() {
	log.Println("Running compute node provisioner")
	_ = context.Background()

	accountId := os.Getenv("ACCOUNT_ID")
	action := os.Getenv("ACTION")
	env := os.Getenv("ENV")

	// Initializing environment
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("LoadDefaultConfig: %v\n", err)
	}

	provisioner := NewProvisioner(iam.NewFromConfig(cfg),
		sts.NewFromConfig(cfg),
		accountId,
		action,
		env)
	provisioner.Run()

	log.Println("provisioning complete")
}
