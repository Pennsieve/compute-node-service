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
    elif http_method == 'GET':
        print("get method")
        if "/logs" in path:
            contents = ''
            if "queryStringParameters" in event and 'integrationId' in event['queryStringParameters'] and 'applicationId' in event['queryStringParameters']:
                integration_id = event['queryStringParameters']['integrationId']
                application_id = event['queryStringParameters']['applicationId']

                cloudwatch_client = boto3_client("logs")
                s3_client = boto3_client('s3')
                sts_client = boto3_client("sts")

                account_id = sts_client.get_caller_identity()["Account"]
                print(account_id)

                bucket_name = "tfstate-{0}".format(account_id)
                print(bucket_name)
                prefix = "{0}/logs/{1}".format(environment,integration_id)
                print(prefix)

                response = s3_client.list_objects(Bucket=bucket_name, Prefix=prefix)
                print(response)
                if response.get('Contents'):
                    for o in response.get('Contents'):
                        if "processors.csv" in o.get('Key'):
                            data = s3_client.get_object(Bucket=bucket_name, Key=o.get('Key'))
                            csv_bytes = data['Body'].read()
                            print(contents)
                            csv_string = csv_bytes.decode('utf-8')
                            rows = [row for row in csv.reader(csv_string.splitlines())]
                            print(rows)
                            log_events = ''
                            for row in rows[1:]:
                                if row[4] == application_id:
                                    log_events = cloudwatch_client.get_log_events(
                                        logGroupName=row[2],
                                        logStreamName=row[3])
                                    print(log_events['events'])
                    if log_events:    
                        return {
                            'statusCode': 200,
                            'body': json.dumps({ 'message': log_events})
                        }
                    else:
                        return {
                            'statusCode': 200,
                            'body': json.dumps({ 'message': str("no logs found")})
                        }
                else:
                    return {
                        'statusCode': 404,
                        'body': json.dumps({ 'message': str("no logs found")})
                    }
            if "queryStringParameters" in event and 'integrationId' in event['queryStringParameters']:
                integration_id = event['queryStringParameters']['integrationId']
                print(integration_id)
                s3_client = boto3_client('s3')
                sts_client = boto3_client("sts")
                account_id = sts_client.get_caller_identity()["Account"]
                print(account_id)

                bucket_name = "tfstate-{0}".format(account_id)
                print(bucket_name)
                prefix = "{0}/logs/{1}".format(environment,integration_id)
                print(prefix)

                response = s3_client.list_objects(Bucket=bucket_name, Prefix=prefix)
                print(response)
                if response.get('Contents'):
                    for o in response.get('Contents'):
                        if "events.log" in o.get('Key'):
                            data = s3_client.get_object(Bucket=bucket_name, Key=o.get('Key'))
                            contents = data['Body'].read()
                            print(contents.decode("utf-8"))
                        
                    return {
                        'statusCode': 200,
                        'body': json.dumps({ 'message' : str(contents.decode("utf-8"))})
                    }
                else:
                    return {
                        'statusCode': 404,
                        'body': json.dumps({ 'message': str("no logs found")})
                    }

            else:
                return {
                    'statusCode': 400,
                    'body': json.dumps({ 'message': str("integrationId is required")})
                }