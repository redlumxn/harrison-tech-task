#!/usr/bin/env python3
import boto3
import botocore
import os
import sys
import json
import logging
import hashlib
import time

start_time = time.time()

# Set Logging level based on env var
LOGLEVEL = os.environ.get('LOGLEVEL', 'INFO').upper()
logging.basicConfig(level=LOGLEVEL)

s3 = boto3.client('s3')
sqs = boto3.client('sqs')

# Set up our logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Check arguments
args = [arg for arg in sys.argv[1:] if not arg.startswith("-")]

if len(args) == 2:
    bucket_name = args[0]
    queue_url = args[1]
    logger.info('Reading objects from bucket [%s] and publishing messages to queue [%s]',
        bucket_name, queue_url)
else:
    raise SystemExit(f"Usage: {sys.argv[0]} <BUCKET_NAME) <QUEUE_URL>")

def list_bucket_objects(continuationToken = None):
    logger.info('Executing S3 List Object v2...')
    if continuationToken == None:
        obj_list = s3.list_objects_v2(
            Bucket = bucket_name
        )
    else:
        obj_list = s3.list_objects_v2(
            Bucket = bucket_name,
            ContinuationToken = continuationToken
        )

    continuationToken = obj_list['NextContinuationToken'] if 'NextContinuationToken' in obj_list else 'None'
    logger.info('KeyCount:  %i', obj_list['KeyCount'])
    logger.info('Response is Truncated? %s', obj_list['IsTruncated'])
    logger.debug('ContinuationToken %s', continuationToken)

    return obj_list

try: 
    isTruncated = True
    continuationToken = None

    logger.info('Begin bucket object listing...')
    total_objects = 0

    while isTruncated:
        list_obj_res = list_bucket_objects(continuationToken)
        
        # Keep counter for batching purposes
        object_count = 0
        retrieved_objects = list_obj_res['KeyCount']

        # Total objects listed for reporting purposes
        total_objects += retrieved_objects

        logger.info('Publishing messages to SQS in batches...')
        messageBatch = []
        for object in list_obj_res['Contents']:
            object_count += 1
            object_key = object['Key']
            dedupId = hashlib.sha256(object_key.encode()).hexdigest()
            logger.debug('Key [%s], Hash/DedupId [%s]', object_key, dedupId)
            
            messageBatch.append({
                'Id': object_key[:object_key.index('.')],
                'MessageBody': json.dumps({
                    'bucket': list_obj_res['Name'],
                    'key': object_key
                }),
                'MessageGroupId': 'Group1',
                'MessageDeduplicationId': dedupId
            })

            if len(messageBatch) == 10 or object_count == retrieved_objects:
                logger.debug('Sending messageBatch \n %s', messageBatch)
                response = sqs.send_message_batch(
                    QueueUrl = queue_url,
                    Entries = messageBatch
                )
                logger.debug('Batch response \n %s' , response)
                logger.debug('Batch publishing results Succesful[%i] Failed[%i]',
                        len(response['Successful']),
                        len(response['Failed']) if 'Failed' in response else 0)
                

                messageBatch.clear()

        continuationToken = list_obj_res['NextContinuationToken'] if 'NextContinuationToken' in list_obj_res else 'None'
        isTruncated = list_obj_res['IsTruncated']
    
    logger.info('Message publishing complete. %i messages were published in total.', total_objects)
except botocore.exceptions.ClientError as err:
    if err.response['Error']['Code'] == 'NoSuchBucket':
        logger.warning('NoSuchBucket. Error Message: %s', err.response['Error']['Message'])
    elif err.response['Error']['Code'] == 'AWS.SimpleQueueService.NonExistentQueue':
        logger.warning('NonExistentQueue. Error Message: %s', err.response['Error']['Message'])
    else:
        logger.error(err.response)
        raise err
logger.info('Total execution time: [%s] secs', time.time() - start_time)
