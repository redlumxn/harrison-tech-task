# S3 bucket reader and SQS publisher

Response to Harrison.ai Tech Task - [Question 2](https://github.com/harrison-ai/data-eng-sol-architect-tech-task#question-two). 

## Description

Provides a script that lists all objects in an S3 bucket and places a message on an SQS queue for each object in the bucket. The SQS message format is as follows:

```
{'bucket:' 'my-s3-bucket', 'key': 'my-object'}
```

The naming format of all objects in the bucket is as follows:

```
<sha256 hash digest>.ext
```

e.g:

```
f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2.ext
```

## Key Design Decisions
The script leverages the following AWS features:
* **SQS FIFO queue for Exactly-once processing** - this avoids sending duplicate messages. This helps make the publishing process idempotent.
* **SQS batch message publishing** - to reduce the number of AWS API calls (10 messages per batch). 

## Getting Started

### Dependencies

* Python 3
* [virtualenv](https://virtualenv.pypa.io/en/latest/)
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
* Terraform 1.0.9 (optional)
* [tfenv](https://github.com/tfutils/tfenv)

### Installing requirements

```sh
$ pip3 install virtualenv 
$ python3 -m virtualenv venv
$ source venv/bin/activate
$ pip install -r requirements.txt 
```

The provided Terraform resource files setup the AWS resources (SQS queue, S3 Bucket and sample S3 bucket objects) required to test the script. If desired, the below commands will create the resources.

**Note**: AWS S3 and SQS permissions are required. Please configure your `ENV VARS` accordingly (e.g. `AWS_PROFILE`).

```sh
$ brew install tfenv
$ tfenv install 1.0.9
$ tfenv use 1.0.9
$ export AWS_PROFILE=<replace> && export AWS_REGION=ap-southeast-2
$ terraform init
$ terraform plan -out=tfplan
$ terraform apply tfplan 
```

**NOTE:** 500 objects are created by default. To modify this number you can pass the `` Terraform variable.
```sh
$ terraform plan -var 'object_count=100' -out=tfplan
$ terraform apply tfplan
```

### Executing program

```sh
$ /message_publisher.py <BUCKET_NAME) <QUEUE_URL>
```
**NOTE:** Make sure `message_publisher.py` is executable (e.g. `chmod  +x message_publisher.py`)

If the AWS resources were created using the provided terraform files, you can grab the required values from the terraform output.
```sh
$ /message_publisher.py $(terraform output -raw bucket_name) $(terraform output -raw queue_url)
```

Sample run:
```sh
./message_publisher.py $(terraform output -raw bucket_name) $(terraform output -raw queue_url)
INFO:botocore.credentials:Found credentials in shared credentials file: ~/.aws/credentials
INFO:root:Reading objects from bucket [question-2-bucket7el6g9mqfwh1jd5l] and publishing messages to queue [https://sqs.ap-southeast-2.amazonaws.com/209852133120/question2-queue.fifo]
INFO:root:Begin bucket object listing...
INFO:root:Executing S3 List Object v2...
INFO:root:KeyCount:  500
INFO:root:Response is Truncated? False
INFO:root:Publishing messages to SQS in batches...
INFO:root:Message publishing complete. 500 messages were published in total.
INFO:root:Total execution time: [1.4208719730377197] secs
```