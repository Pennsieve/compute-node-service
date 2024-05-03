package models

type Node struct {
	Uuid                  string  `json:"uuid"`
	ComputeNodeGatewayUrl string  `json:"computeNodeGatewayUrl"`
	EfsId                 string  `json:"efsId"`
	SqsUrl                string  `json:"sqsUrl"`
	WorkflowManagerEcrUrl string  `json:"workflowManagerUrl"`
	Env                   string  `json:"environment"`
	Account               Account `json:"account"`
}

type Account struct {
	AccountId   string `json:"accountId"`
	AccountType string `json:"accountType"`
}
