package main

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
)

type Provisioner struct {
	IAMClient     *iam.Client
	STSClient     *sts.Client
	AccountId     string
	BackendExists bool
	Action        string
	Env           string
}

func NewProvisioner(iamClient *iam.Client, stsClient *sts.Client, accountId string, action string, env string) *Provisioner {
	return &Provisioner{IAMClient: iamClient, STSClient: stsClient,
		AccountId: accountId, Action: action, Env: env}
}

func (p *Provisioner) Run() {
	fmt.Println("provisioning")
	creds := p.AssumeRole()

	switch p.Action {
	case "CREATE":
		p.Create(creds)
	case "DELETE":
		p.Delete(creds)
	default:
		log.Println("action not supported:", p.Action)
	}

}

func (p *Provisioner) AssumeRole() aws.Credentials {
	fmt.Println("assuming role")

	callerIdentityInput := &sts.GetCallerIdentityInput{}
	deployAccountId, err := p.STSClient.GetCallerIdentity(context.Background(),
		callerIdentityInput)
	if err != nil {
		log.Println(err)
	}

	roleArn := fmt.Sprintf("arn:aws:iam::%s:role/ROLE-%s", p.AccountId, *deployAccountId.Account)
	appCreds := stscreds.NewAssumeRoleProvider(p.STSClient, roleArn)
	credentials, err := appCreds.Retrieve(context.TODO())
	if err != nil {
		log.Println(err)
	}

	return credentials
}

func (p *Provisioner) Create(c aws.Credentials) {
	fmt.Println("creating infrastructure")

	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(err)
	}
	creds := credentials.NewStaticCredentialsProvider(c.AccessKeyID, c.SecretAccessKey, c.SessionToken)

	// list s3 buckets
	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.Credentials = creds
	})
	resp, err := client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
	if err != nil {
		panic(err)
	}

	for _, b := range resp.Buckets {
		if *b.Name == fmt.Sprintf("tfstate-%s", p.AccountId) {
			p.BackendExists = true
			break
		}
	}

	if !p.BackendExists {
		// create s3 backend
		cmd := exec.Command("/bin/sh", "/usr/src/app/scripts/create-backend.sh",
			p.AccountId, c.AccessKeyID, c.SecretAccessKey, c.SessionToken)
		out, err := cmd.Output()
		if err != nil {
			log.Fatalf("error %s", err.Error())
		}
		output := string(out)
		fmt.Println(output)
	}

	// create infrastructure
	cmd := exec.Command("/bin/sh", "/usr/src/app/scripts/infrastructure.sh",
		p.AccountId, c.AccessKeyID, c.SecretAccessKey, c.SessionToken)
	out, err := cmd.Output()
	if err != nil {
		log.Fatalf("error %s", err.Error())
	}
	output := string(out)
	fmt.Println(output)

}

func (p *Provisioner) Delete(c aws.Credentials) {
	fmt.Println("deleting infrastructure")

	// create infrastructure
	cmd := exec.Command("/bin/sh", "/usr/src/app/scripts/destroy-infrastructure.sh",
		p.AccountId, c.AccessKeyID, c.SecretAccessKey, c.SessionToken)
	out, err := cmd.Output()
	if err != nil {
		log.Fatalf("error %s", err.Error())
	}
	output := string(out)
	fmt.Println(output)

}
