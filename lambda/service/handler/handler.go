package handler

import (
	"context"
	"log/slog"

	"github.com/aws/aws-lambda-go/events"
	"github.com/pennsieve/compute-node-service/service/logging"
)

var logger = logging.Default

func init() {
	logger.Info("init()")
}

func ComputeNodeServiceHandler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (*events.APIGatewayV2HTTPResponse, error) {
	logger = logger.With(slog.String("requestID", request.RequestContext.RequestID))

	apiResponse, err := handleRequest()

	return apiResponse, err
}

func handleRequest() (*events.APIGatewayV2HTTPResponse, error) {
	logger.Info("handleRequest()")
	apiResponse := events.APIGatewayV2HTTPResponse{Body: "{'response':'hello'}", StatusCode: 200}

	return &apiResponse, nil
}
