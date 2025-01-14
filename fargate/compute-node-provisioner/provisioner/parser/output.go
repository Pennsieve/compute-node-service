package parser

type OutputValue struct {
	Value string `json:"value"`
}

type Output struct {
	ComputeNodeGatewayUrl OutputValue `json:"compute_gateway_url"`
	EfsId                 OutputValue `json:"efs_id"`
	QueueUrl              OutputValue `json:"queue_url"`
}
