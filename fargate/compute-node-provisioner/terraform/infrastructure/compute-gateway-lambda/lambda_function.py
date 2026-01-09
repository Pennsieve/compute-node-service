from boto3 import client as boto3_client
from boto3 import session as boto3_session
from botocore.exceptions import ClientError
import json
import base64
import os
import csv
from datetime import datetime, timedelta
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError


def get_user_from_session_token(session_token, environment):
    """
    Retrieve user information from the Pennsieve API using a session token.
    Returns user dict on success, None on failure.
    """
    if environment == 'prod':
        api_base = 'https://api.pennsieve.io'
    else:
        api_base = 'https://api.pennsieve.net'

    request = Request(
        f'{api_base}/user',
        headers={'Authorization': f'Bearer {session_token}'}
    )

    try:
        with urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode('utf-8'))
    except HTTPError as e:
        print(f"Failed to get user from session token: HTTP {e.code}")
        return None
    except URLError as e:
        print(f"Failed to get user from session token: {e.reason}")
        return None

def lambda_handler(event, context):
    print(event)
    http_method = event['requestContext']['http']['method']
    path = event['requestContext']['http']['path']
    environment = os.environ['ENV']

    if http_method == 'POST':
        # Retrieve tokens from headers
        # Note: Using x-session-token instead of Authorization because AWS SigV4 signing
        # overwrites the Authorization header with the AWS signature
        headers = event.get('headers', {})
        session_token_header = headers.get('x-session-token', '')
        refresh_token = headers.get('x-refresh-token', '')

        # Strip "Bearer " prefix from session token header (case-insensitive)
        if session_token_header.lower().startswith('bearer '):
            session_token = session_token_header[7:]  # Remove first 7 chars ("Bearer " or "bearer ")
        else:
            session_token = session_token_header

        # Debug: log token presence (not the actual token for security)
        print(f"X-Session-Token header present: {bool(session_token_header)}, length: {len(session_token_header)}")
        print(f"Session token extracted, length: {len(session_token)}")

        # Get user info from session token
        user_info = get_user_from_session_token(session_token, environment)
        if user_info:
            print(f"User identified: {user_info.get('firstName', '')} {user_info.get('lastName', '')} ({user_info.get('email', 'unknown')})")
            print(f"User ID: {user_info.get('id', 'unknown')}")
            print(f"Organization: {user_info.get('preferredOrganization', 'unknown')}")
            print(f"Is integration user: {user_info.get('isIntegrationUser', False)}")
        else:
            print("Warning: Could not identify user from session token")

        if event['isBase64Encoded'] == True:
            body = base64.b64decode(event['body']).decode('utf-8')
            event['body'] = body
            event['isBase64Encoded'] = False
        json_body = json.loads(event['body'])
        integration_id = json_body.get('integrationId', None)
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

        message = {"integrationId": integration_id, "api_key": api_key, "api_secret" : api_secret, "session_token": session_token, "refresh_token": refresh_token}
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
                    end_time = datetime.now() - timedelta(minutes=1)
                    for row in rows[1:]:
                        try:
                            log_events = cloudwatch_client.get_log_events(
                            logGroupName=row[2],
                            logStreamName=row[3],
                            startFromHead=True,
                            endTime=int(end_time.timestamp() * 1000))
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