from email import message
import boto3
import json
import os
import requests
import time

boto_client_secrets = boto3.client('secretsmanager')
boto_client_pipeline = boto3.client('codepipeline')
boto_client_build = boto3.client('codebuild')

secrets = boto_client_secrets.get_secret_value(SecretId=os.environ['SECRETS_ARN'],)
secret_value = json.loads(secrets['SecretString'])
gh_username = secret_value['GH_USERNAME']
gh_token = secret_value['GH_TOKEN']
# use the token instead
# slack_app = secret_value["SLACK_URL"]
slack_token = secret_value["SLACK_TOKEN"]
slack_email_domain_filter = secret_value["SLACK_EMAIL_DOMAIN_FILTER"]

#################################################################################################
#     Slack Message Text
#################################################################################################

def format_slack_message(slack_channel, aws_type, should_add_color, aws_name, aws_status_text, message_text):
    status_icon = ''
    status_color = ''

    if should_add_color:
        if "SUCCEEDED" == aws_status_text:
            status_icon = ':white_check_mark:'
            status_color = '#36a64f' # green
        elif "FAILED" == aws_status_text:
            status_icon = ':octagonal_sign:'
            status_color = '#BF391F' # red

    return {
        "channel": slack_channel,
        "blocks": [
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*{aws_type} `{aws_name}` {aws_status_text} {status_icon}*"
                }
            }
        ],
        "attachments": [
            {
                "color": f"{status_color}",
                "blocks": [
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": message_text
                        }
                    }
                ]
            }
        ]
    }

    # return {
    #         "channel": slack_channel,
    #         "blocks": [
    #             {
    #                 "type": "section",
    #                 "text": {
    #                 "type": "mrkdwn",
    #                 "text": f"*CodePipeline `{pipeline_name}` {pipeline_state} {status_icon}*"
    #                 }
    #             },
    #             {
    #                 "type": "section",
    #                 "text": {
    #                 "type": "mrkdwn",
    #                 "text": message_text
    #                 }
    #             }
    #         ]
    # }

#################################################################################################
#     Helper Functions
#################################################################################################

def lookup_slack_channel(tags):
    slack_channel = ''
    for tag in tags:
        if tag['key'] == 'slack_notification_channel':
            slack_channel = tag['value']
            break

    if slack_channel == '':
        msg = f"Could not find destination slack channel from resource tags"
        print(msg)
        raise Exception(msg)

    return slack_channel

def lookup_github_commit_info(full_repo, source_version, aws_status_text):
    message_text = ''

    request_url = 'https://api.github.com/repos/'+ full_repo + '/commits/' + source_version

    r = requests.get(request_url, auth=(gh_username, gh_token))

    try:
        response = json.loads(r.text)

        author = response['commit']['author']['email']
        commit_message = response['commit']['message']

        # format message using commit
        message_text = "*Commit ID:* " + source_version + "\n"
        message_text += "*Commit Author:* " + author + "\n"
        message_text += "*Commit Message:* " + commit_message + "\n"

        # if used a qualified email address, at mention them in slack
        if "FAILED" == aws_status_text:
            if author.endswith(f"@{slack_email_domain_filter}"):
                cc = author.replace(f"@{slack_email_domain_filter}","")
                message_text += f"cc: @{cc}\n"
            else:
                message_text += f"cc: author is not {slack_email_domain_filter} email\n"

    except Exception as e:
        print('error loading json')
        print(e)
    
    return message_text

#################################################################################################
#     CodeBuild Functions
#################################################################################################

def lookup_codebuild_payload_sourceversion_codebuild(payload, full_repo, build_status):
    try:
        source_version = payload['detail']['additional-information']['source-version']

        message_text = lookup_github_commit_info(full_repo, source_version, build_status)

    except:
        print('Error Loading SNS Payload for CodeBuild. Could be a Build via Pipeline Job.')
        message_text = ''
    
    return message_text


def lookup_codebuild_payload_sourceversion_pipeline(full_repo, build_id, build_status):
    try:
        response = boto_client_build.batch_get_builds(ids=[build_id])

        source_version = response['builds'][0]['resolvedSourceVersion']

        message_text = lookup_github_commit_info(full_repo, source_version, build_status)

    except:
        print('Error Loading SNS Payload for CodeBuild via Pipeline Job.')
        message_text = ''
    
    return message_text

def build_message_codebuild(payload):
    project = payload['detail']['project-name']
    build_status = payload['detail']['build-status']
    build_id = payload['detail']['build-id']
    build_number = payload['detail']['additional-information']['build-number']
    log_stream = payload['detail']['additional-information']['logs']['stream-name']
    source_type = payload['detail']['additional-information']['source']['type']

    # Get the Slack Channel from the CodeBuild Tags
    response_build_project = boto_client_build.batch_get_projects(names=[project])

    slack_channel = lookup_slack_channel(response_build_project['projects'][0]['tags'])

    # Add Build Info to the Message (plus some extra space before the commit info)
    message_text = f"*Build Number:* {build_number:.0f}\n\n"

    # Lookup the Commit Info
    source_repo_url = response_build_project['projects'][0]['source']['location']
    tmp = source_repo_url.split('/')
    full_repo = tmp[-2] + "/" + tmp[-1].replace('.git','')

    commit_info_text = lookup_codebuild_payload_sourceversion_codebuild(payload, full_repo, build_status)

    if commit_info_text == '':
        commit_info_text = lookup_codebuild_payload_sourceversion_pipeline(full_repo, build_id, build_status)

        if commit_info_text == '':
            print('Error Loading SNS Payload for CodeBuild. Could be a Build via Pipeline Job.')
            commit_info_text = "*Commit ID:* :octagonal_sign: _could not lookup source info_\n"

    message_text += commit_info_text + "\n"

    yesterday_epoch_seconds = int(time.time()) - 86400
    dd="https://app.datadoghq.com/logs?query=%40aws.awslogs.logStream%3A" + log_stream + "&from_ts=" + str(yesterday_epoch_seconds) + "000"

    message_text += f"*DataDog Logs:* <{dd}|{log_stream}>\n"
    message_text += f"*Commit Source Type:* {source_type}\n"

    # print("Sending Build Message: " + message_text)

    return format_slack_message(slack_channel, "CodeBuild", True, project, build_status, message_text)

#################################################################################################
#     CodePipeline Functions
#################################################################################################

def lookup_codepipeline_payload_sourceversion(pipeline_name, pipeline_execution_id, pipeline_state):
    # wait for the commit association to happen
    backoff = 3
    message_text=''
    for i in range(5):
        try:
            print(f"Sleeping for {backoff} seconds waiting for pipeline source info")
            time.sleep(backoff)
            response = boto_client_pipeline.get_pipeline_execution(
                pipelineName=pipeline_name,
                pipelineExecutionId=pipeline_execution_id
            )

            commit_id = response['pipelineExecution']['artifactRevisions'][0]['revisionId']
            if commit_id != '':
                response = boto_client_pipeline.get_pipeline(name=pipeline_name)

                repository_id = response['pipeline']['stages'][0]['actions'][0]['configuration']['FullRepositoryId']

                message_text = lookup_github_commit_info(repository_id, commit_id, pipeline_state)

                # we found the info, exit the for loop
                break

        except IndexError as e:
            print('commit not associated yet, trying again')
            backoff = backoff * 2
    
    if message_text == '':
        print('Error Loading Source Info from SNS Payload for CodePipeline.')
        message_text = "*Commit ID:* :octagonal_sign: _could not lookup source info_\n"
    
    return message_text


def build_message_codepipeline(payload):
    pipeline_arn = payload['resources'][0]
    pipeline_name = payload['detail']['pipeline']
    pipeline_state = payload['detail']['state']
    pipeline_execution_id = payload['detail']['execution-id']

    # Get the Slack Channel from the CodePipeline Tags
    response = boto_client_pipeline.list_tags_for_resource(resourceArn=pipeline_arn)

    slack_channel = lookup_slack_channel(response['tags'])
  
    # Lookup the Commit Info
    message_text = lookup_codepipeline_payload_sourceversion(pipeline_name, pipeline_execution_id, pipeline_state)
   
    # print("Sending Pipeline Message: " + message_text)

    return format_slack_message(slack_channel, "CodePipeline", False, pipeline_name, pipeline_state, message_text)

#################################################################################################
#     SNS Handler Functions
#################################################################################################
def build_message(payload):

    message_source = payload['source'] # aws.codebuild or aws.codepipeline

    if message_source == "aws.codepipeline":
        print("Processing a Pipeline Message")
        jsonOutput = build_message_codepipeline(payload)
    elif message_source == "aws.codebuild":
        print("Processing a Build Message")
        jsonOutput = build_message_codebuild(payload)
    else:
        print("Unexpected message source: " + message_source)
        raise Exception("Unexpected message source: " + message_source)

    # print("JSON Output:")
    # print(jsonOutput)

    return jsonOutput

def lambda_handler(event, context):

    #load message
    payload = json.loads(event['Records'][0]['Sns']['Message'], strict=False)
    # print('build notify payload keys:')
    # print(payload)

    jsonOutput = build_message(payload)
  
    #print("Sending json to: " + slack_app)
    # print(jsonOutput)
    
    ##########################################################
    # slack app incoming webhooks are tied to a channel
    # use the bot and chat.postMessage API to allow different 
    # channels for the same app
    ##########################################################
    # response = requests.post(slack_app,
    #     json=jsonOutput,
    #     headers={ "Content-Type": "application/json"}
    # )

    response = requests.post("https://slack.com/api/chat.postMessage",
        json=jsonOutput,
        headers={ "Content-Type": "application/json", "Authorization": "Bearer " + slack_token}
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Done!')
    }
