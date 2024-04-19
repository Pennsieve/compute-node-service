package main

import (
	"context"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"
	"github.com/aws/aws-sdk-go-v2/service/iam"
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
	fmt.Println("running")
	p.AssumeRole()

}

func (p *Provisioner) AssumeRole() {
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
	fmt.Println(credentials)

}
