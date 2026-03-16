import os
import boto3


def _load_ssm_secrets() -> None:
    """Fetch secrets from SSM Parameter Store at cold-start and inject into env.
    Only runs inside Lambda (AWS_LAMBDA_FUNCTION_NAME is set by the runtime).
    Locally, python-dotenv loads values from .env instead.
    """
    ssm = boto3.client("ssm", region_name=os.environ.get("AWS_REGION", "eu-west-1"))
    param = ssm.get_parameter(
        Name="/climbing-conditions/openweather-api-key",
        WithDecryption=True,
    )
    os.environ["OPENWEATHER_API_KEY"] = param["Parameter"]["Value"]


if os.environ.get("AWS_LAMBDA_FUNCTION_NAME"):
    _load_ssm_secrets()


from mangum import Mangum  # noqa: E402
from main import app  # noqa: E402

handler = Mangum(app, lifespan="off")
