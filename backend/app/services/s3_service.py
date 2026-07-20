"""S3 access for F3 project-card screenshots.

Presigned PUT/GET so the browser uploads/downloads directly against S3 without
proxying bytes through the API. The client is built EXPLICITLY from settings
creds (the builderplaza account that owns the bucket) rather than the ambient
default AWS profile, which belongs to a different account.
"""

import uuid

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from app.core.config import settings

# content_type -> file extension. These three image types are the only ones we
# accept for screenshots; anything else is rejected upstream with a 400.
_CONTENT_TYPE_EXT = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}

_client = None


def _s3():
    """Lazily build (and memoise) the boto3 S3 client from explicit creds."""
    global _client
    if _client is None:
        _client = boto3.client(
            "s3",
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            region_name=settings.aws_region,
            # SigV4 + regional virtual-hosted endpoint: without this boto3 signs
            # presigned URLs against the global s3.amazonaws.com host, which 307s
            # to the region and forces clients to follow a redirect on PUT.
            config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
        )
    return _client


def ext_for_content_type(content_type: str) -> str | None:
    """Map an allowed image content type to its extension, or None if unsupported."""
    return _CONTENT_TYPE_EXT.get(content_type)


def screenshot_key(project_id, content_type: str) -> str:
    """Build a screenshot object key: screenshots/{project_id}/{uuid4}.{ext}.

    Caller must have validated ``content_type`` already (ext_for_content_type
    returns None for unsupported types).
    """
    ext = ext_for_content_type(content_type)
    return f"screenshots/{project_id}/{uuid.uuid4()}.{ext}"


def presigned_put(key: str, content_type: str, expires: int = 600) -> str:
    return _s3().generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": settings.s3_bucket_name, "Key": key, "ContentType": content_type},
        ExpiresIn=expires,
    )


def presigned_get(key: str, expires: int = 600) -> str:
    return _s3().generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": settings.s3_bucket_name, "Key": key},
        ExpiresIn=expires,
    )


def object_exists(key: str) -> bool:
    try:
        _s3().head_object(Bucket=settings.s3_bucket_name, Key=key)
        return True
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") in ("404", "NoSuchKey", "NotFound"):
            return False
        raise


def delete_object(key: str) -> None:
    """Best-effort delete; callers ignore failures so a missing object is fine."""
    _s3().delete_object(Bucket=settings.s3_bucket_name, Key=key)
