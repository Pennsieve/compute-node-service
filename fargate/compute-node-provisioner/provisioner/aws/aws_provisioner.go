package provisioner

import (
	"context"
	"fmt"
	"log"
	"os/exec"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/pennsieve/compute-node-service/compute-node-provisioner/provisioner"
)

type AWSProvisioner struct {
	IAMClient     *iam.Client
	STSClient     *sts.Client
	AccountId     string
	BackendExists bool
	Action        string
	Env           string
}

func NewAWSProvisioner(iamClient *iam.Client, stsClient *sts.Client, accountId string, action string, env string) provisioner.Provisioner {
	return &AWSProvisioner{IAMClient: iamClient, STSClient: stsClient,
		AccountId: accountId, Action: action, Env: env}
}

func (p *AWSProvisioner) Run(ctx context.Context) error {
	log.Println("Starting to provision infrastructure ...")
	creds, err := p.assumeRole(ctx)
	if err != nil {
		return err
	}

	switch p.Action {
	case "CREATE":
		return p.create(ctx, creds)
	case "DELETE":
		return p.delete(creds)
	default:
		return fmt.Errorf("action not supported: %s", p.Action)
	}

}

func (p *AWSProvisioner) assumeRole(ctx context.Context) (aws.Credentials, error) {
	log.Println("assuming role ...")

	deployAccountId, err := p.STSClient.GetCallerIdentity(ctx,
		&sts.GetCallerIdentityInput{})
	if err != nil {
		return aws.Credentials{}, err
	}

	roleArn := fmt.Sprintf("arn:aws:iam::%s:role/ROLE-%s", p.AccountId, *deployAccountId.Account)
	appCreds := stscreds.NewAssumeRoleProvider(p.STSClient, roleArn)
	credentials, err := appCreds.Retrieve(ctx)
	if err != nil {
		return aws.Credentials{}, err
	}

	return credentials, nil
}

func (p *AWSProvisioner) create(ctx context.Context, c aws.Credentials) error {
	log.Println("creating infrastructure ...")

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return err
	}
	creds := credentials.NewStaticCredentialsProvider(c.AccessKeyID, c.SecretAccessKey, c.SessionToken)

	// check for backend bucket
	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.Credentials = creds
	})
	resp, err := client.ListBuckets(ctx, &s3.ListBucketsInput{})
	if err != nil {
		return err
	}

	for _, b := range resp.Buckets {
		if *b.Name == fmt.Sprintf("tfstate-%s", p.AccountId) {
			p.BackendExists = true
			break
		}
	}

	if !p.BackendExists {
		// create s3 backend bucket
		cmd := exec.Command("/bin/sh", "/usr/src/app/scripts/create-backend.sh",
			p.AccountId, c.AccessKeyID, c.SecretAccessKey, c.SessionToken)
		out, err := cmd.Output()
		if err != nil {
			return err
		}
		fmt.Println(string(out))
	}

	// create infrastructure
	cmd := exec.Command("/bin/sh", "/usr/src/app/scripts/infrastructure.sh",
		p.AccountId, c.AccessKeyID, c.SecretAccessKey, c.SessionToken)
	out, err := cmd.Output()
	if err != nil {
		return err
	}
	fmt.Println(string(out))

	return nil
}

func (p *AWSProvisioner) delete(c aws.Credentials) error {
	fmt.Println("destroying infrastructure")

	cmd := exec.Command("/bin/sh", "/usr/src/app/scripts/destroy-infrastructure.sh",
		p.AccountId, c.AccessKeyID, c.SecretAccessKey, c.SessionToken)
	out, err := cmd.Output()
	if err != nil {
		return err
	}
	fmt.Println(string(out))

	return nil
}
