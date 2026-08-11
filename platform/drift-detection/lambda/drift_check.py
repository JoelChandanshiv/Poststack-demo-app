import json
import os
import boto3

s3 = boto3.client("s3")
sns = boto3.client("sns")

REPORT_BUCKET = os.environ["REPORT_BUCKET"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def _publish(pipeline_name, message):
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[Drift Check] {pipeline_name}",
        Message=message,
    )


def handler(event, context):
    """
    Triggered by an EventBridge rule on "CodePipeline Pipeline Execution
    State Change" events, filtered to this project's drift-check pipelines.

    Does NOT apply anything. Only reads the report the buildspec wrote to
    S3 and decides whether a human needs to be told about it.
    """
    detail = event.get("detail", {})
    pipeline_name = detail.get("pipeline", "unknown")
    state = detail.get("state", "UNKNOWN")

    if state == "FAILED":
        _publish(
            pipeline_name,
            f"The Terraform plan step itself failed for {pipeline_name} "
            f"(not necessarily drift - could be a real error, e.g. a "
            f"transient AWS API issue or a bug in the config). Check the "
            f"CodeBuild logs for this pipeline's most recent execution.",
        )
        return

    if state != "SUCCEEDED":
        # STARTED / STOPPED / SUPERSEDED - nothing to report yet.
        return

    report_key = f"drift-reports/{pipeline_name}/latest.json"

    try:
        obj = s3.get_object(Bucket=REPORT_BUCKET, Key=report_key)
        report = json.loads(obj["Body"].read())
    except Exception as e:
        _publish(
            pipeline_name,
            f"Drift check build succeeded but the report at "
            f"s3://{REPORT_BUCKET}/{report_key} could not be read: {e}",
        )
        return

    if not report.get("drift_detected"):
        # No drift, no notification - avoids alert fatigue from a daily
        # "all clear" email nobody reads.
        return

    message = (
        f"DRIFT DETECTED for {pipeline_name}.\n\n"
        f"Actual AWS infrastructure differs from the Terraform-defined "
        f"desired state.\n\n"
        f"--- plan summary (truncated) ---\n"
        f"{report.get('plan_summary', '(no summary captured)')}\n"
        f"--- end summary ---\n\n"
        f"This does NOT auto-apply. Review the plan, then either:\n"
        f"  1. If the change was intentional, update the Terraform "
        f"configuration to match it, or\n"
        f"  2. If the change was unintended (manual edit, out-of-band "
        f"action), run a normal apply through the pipeline to revert it.\n"
    )
    _publish(pipeline_name, message)
