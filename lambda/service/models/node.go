package models

type Node struct {
	Uuid                  string  `json:"uuid"`
	Name                  string  `json:"name"`
	Description           string  `json:"description"`
	ComputeNodeGatewayUrl string  `json:"computeNodeGatewayUrl"`
	EfsId                 string  `json:"efsId"`
	QueueUrl              string  `json:"queueUrl"`
	WorkflowManagerEcrUrl string  `json:"workflowManagerUrl"`
	Env                   string  `json:"environment"`
	Account               Account `json:"account"`
	CreatedAt             string  `json:"createdAt"`
	OrganizationId        string  `json:"organizationId"`
	UserId                string  `json:"userId"`
}

type Account struct {
	Uuid        string `json:"uuid"`
	AccountId   string `json:"accountId"`
	AccountType string `json:"accountType"`
}
