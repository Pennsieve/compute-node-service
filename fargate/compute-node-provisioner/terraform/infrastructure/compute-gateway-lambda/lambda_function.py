from boto3 import client as boto3_client
import json
import base64
import os

def lambda_handler(event, context):
    if event['isBase64Encoded'] == True:
        body = base64.b64decode(event['body']).decode('utf-8')
        event['body'] = body
        event['isBase64Encoded'] = False
    json_body = json.loads(event['body'])
    integration_id = json_body['integrationId']
    sqs_url = os.environ['SQS_URL']

    message = {"integrationId": integration_id}
    sqs = boto3_client('sqs')
    response = sqs.send_message(QueueUrl=sqs_url, MessageBody=json.dumps(message))
    
    print("Workflow started for ", integration_id)
    return {
        'statusCode': 202,
        'body': json.dumps(str(response))
    }