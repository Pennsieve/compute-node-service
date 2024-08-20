from boto3 import client as boto3_client
from boto3 import session as boto3_session
from botocore.exceptions import ClientError
import json
import base64
import os

def lambda_handler(event, context):
    print(event)
    if event['isBase64Encoded'] == True:
        body = base64.b64decode(event['body']).decode('utf-8')
        event['body'] = body
        event['isBase64Encoded'] = False
    json_body = json.loads(event['body'])
    integration_id = json_body['integrationId']
    sqs_url = os.environ['SQS_URL']

    # gets api key secrets
    secret_name = os.environ['API_KEY_SM_NAME']
    region_name = os.environ['REGION']

    # Create a Secrets Manager client
    session = boto3_session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    # Decrypts secret using the associated KMS key.
    secret = get_secret_value_response['SecretString']
    d = json.loads(secret)
    api_key, api_secret = list(d.items())[0]
    print(api_key, api_secret)

    message = {"integrationId": integration_id, "api_key": api_key, "api_secret" : api_secret}
    sqs = boto3_client('sqs')
    response = sqs.send_message(QueueUrl=sqs_url, MessageBody=json.dumps(message))
    
    print("Workflow started for ", integration_id)
    return {
        'statusCode': 202,
        'body': json.dumps(str(response))
    }