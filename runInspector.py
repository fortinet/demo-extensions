# Python script to trigger inspector run
# Based off outputs of terraform file

from datetime import datetime
import boto3
region_name = '${region}'
client = boto3.client('inspector', region_name=region_name)


def main():
    try:
        response = client.start_assessment_run(
            assessmentRunName='${template_name}',
            assessmentTemplateArn='${template_arn}')
        print(response)
    except Exception as e:
        print("Error Running Template: ", e)


main()
