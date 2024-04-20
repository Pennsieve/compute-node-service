package main

import (
	"context"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

type Provisioner struct {
	IAMClient *iam.Client
	STSClient *sts.Client
	AccountId string
}

func NewProvisioner(iamClient *iam.Client, stsClient *sts.Client, accountId string) *Provisioner {
	return &Provisioner{iamClient, stsClient, accountId}
}

func (p *Provisioner) Run() {
	fmt.Println("provisioning")
	creds := p.AssumeRole()
	p.Create(creds)

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

	// test: list s3 buckets
	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.Credentials = creds
	})
	resp, err := client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
	if err != nil {
		panic(err)
	}

	for _, b := range resp.Buckets {
		fmt.Println(*b.Name)
	}
}
