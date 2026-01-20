package models

type Node struct {
	Uuid                  string  `json:"uuid"`
	Name                  string  `json:"name"`
	Description           string  `json:"description"`
	ComputeNodeGatewayUrl string  `json:"computeNodeGatewayUrl"`
	EfsId                 string  `json:"efsId"`
	QueueUrl              string  `json:"queueUrl"`
	Account               Account `json:"account"`
	CreatedAt             string  `json:"createdAt"`
	OrganizationId        string  `json:"organizationId"`
	UserId                string  `json:"userId"`
	Identifier            string  `json:"identifier"`
	WorkflowManagerTag    string  `json:"workflowManagerTag"`
}

type Account struct {
	Uuid        string `json:"uuid"`
	AccountId   string `json:"accountId"`
	AccountType string `json:"accountType"`
}

type NodeResponse struct {
	Message string `json:"message"`
}

type NodeUpdateRequest struct {
	WorkflowManagerTag string `json:"workflowManagerTag"`
	WmCpu              int    `json:"wmCpu"`
	WmMemory           int    `json:"wmMemory"`
	AuthorizationType  string `json:"authorizationType"` // "NONE" or "AWS_IAM"
}
