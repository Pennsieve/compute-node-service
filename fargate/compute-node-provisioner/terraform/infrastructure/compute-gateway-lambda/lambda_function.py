import json
import base64

def lambda_handler(event, context):
    if event['isBase64Encoded'] == True:
        body = base64.b64decode(event['body']).decode('utf-8')
        event['body'] = body
        event['isBase64Encoded'] = False
    json_body = json.loads(event['body'])
    integration_id = json_body['integrationId']
    
    print("Workflow started for ", integration_id)
    return {
        'statusCode': 202,
        'body': json.dumps(integration_id)
    }