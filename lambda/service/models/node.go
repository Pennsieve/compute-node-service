package models

type Node struct {
	Uuid                  string  `json:"uuid"`
	Name                  string  `json:"name"`
	Description           string  `json:"description"`
	ComputeNodeGatewayUrl string  `json:"computeNodeGatewayUrl"`
	EfsId                 string  `json:"efsId"`
	QueueUrl              string  `json:"queueUrl"`
	WorkflowManagerEcrUrl string  `json:"workflowManagerUrl"`
	Account               Account `json:"account"`
	CreatedAt             string  `json:"createdAt"`
	OrganizationId        string  `json:"organizationId"`
	UserId                string  `json:"userId"`
	Tag                   string  `json:"tag"`
}

type Account struct {
	Uuid        string `json:"uuid"`
	AccountId   string `json:"accountId"`
	AccountType string `json:"accountType"`
}

type NodeResponse struct {
	Message string `json:"message"`
}
