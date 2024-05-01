package parser

type OutputValue struct {
	Value string `json:"value"`
}

type Output struct {
	ComputeNodeGatewayUrl OutputValue `json:"compute_gateway_url"`
	EfsId                 OutputValue `json:"efs_id"`
	SqsUrl                OutputValue `json:"sqs_url"`
	WorkflowManagerEcrUrl OutputValue `json:"workflow_manager_ecr_repository"`
}
