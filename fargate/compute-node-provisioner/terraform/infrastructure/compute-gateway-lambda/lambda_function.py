from boto3 import client as boto3_client
from boto3 import session as boto3_session
from botocore.exceptions import ClientError
import json
import base64
import os
import csv

def lambda_handler(event, context):
    print(event)
    http_method = event['requestContext']['http']['method']
    path = event['requestContext']['http']['path']
    environment = os.environ['ENV']

    if http_method == 'POST':
        if event['isBase64Encoded'] == True:
            body = base64.b64decode(event['body']).decode('utf-8')
            event['body'] = body
            event['isBase64Encoded'] = False
        json_body = json.loads(event['body'])
        integration_id = json_body['integrationId']

        # cancel always defaults to false
        # workflow manager will kill a process if cancel: true os sent
        cancel = False
        # Check if cancel was sent in body
        if 'cancel' in json_body:
            cancel = json_body['cancel']

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

        message = {"integrationId": integration_id, "api_key": api_key, "api_secret" : api_secret, "cancel": cancel}
        sqs = boto3_client('sqs')
        response = sqs.send_message(QueueUrl=sqs_url, MessageBody=json.dumps(message))
        
        print("Workflow started for ", integration_id)
        return {
            'statusCode': 202,
            'body': json.dumps(str(response))
        }
    elif http_method == 'GET':
        if "/logs" in path:
            contents = ''
            if "queryStringParameters" in event:
                if 'integrationId' in event['queryStringParameters']:
                    integration_id = event['queryStringParameters']['integrationId']
                else:
                    return {
                            'statusCode': 400,
                            'body': json.dumps({ 'messages': str("integrationId is required")})
                        }
                application_uuid = ''    
                if 'applicationUuid' in event['queryStringParameters']:    
                    application_uuid = event['queryStringParameters']['applicationUuid']
                    
                cloudwatch_client = boto3_client("logs")
                s3_client = boto3_client('s3')
                sts_client = boto3_client("sts")

                account_id = sts_client.get_caller_identity()["Account"]
                bucket_name = "tfstate-{0}".format(account_id)
                prefix = "{0}/logs/{1}".format(environment,integration_id)

                response = s3_client.list_objects(Bucket=bucket_name, Prefix=prefix)

                no_logs_found = {
                    'statusCode': 404,
                    'body': json.dumps({ 'messages': []})
                }
                if response.get('Contents'):
                    data = s3_client.get_object(Bucket=bucket_name, Key="{0}/processors.csv".format(prefix))
                    csv_bytes = data['Body'].read()
                    csv_string = csv_bytes.decode('utf-8')
                    rows = [row for row in csv.reader(csv_string.splitlines())]
                    log_events = {}
                    messages = {}
                    for row in rows[1:]:
                        try:
                            log_events = cloudwatch_client.get_log_events(
                            logGroupName=row[2],
                            logStreamName=row[3])
                        except ClientError as e:
                            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                                log_events['events'] = []
                            else:
                                raise e
                        
                        messages[row[4]] = log_events['events']  
   
                    if messages and application_uuid:
                        if application_uuid in messages:
                            return {
                                'statusCode': 200,
                                'body': json.dumps({ 'messages': messages[application_uuid]})
                            }
                        else:
                            return no_logs_found
                    elif messages:    
                        return {
                            'statusCode': 200,
                            'body': json.dumps({ 'messages': messages})
                        }    
                    else:
                        return no_logs_found
                else:
                    return no_logs_found