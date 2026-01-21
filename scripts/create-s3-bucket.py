#!/usr/bin/env python3
"""
S3 Bucket Creation

Usage:
    # Create an S3 bucket with basic settings
    python scripts/create-s3-bucket.py --bucket-name my-tf-state --region us-west-2
    
    # Create an S3 bucket with KMS encryption and tags
    python scripts/create-s3-bucket.py --bucket-name my-tf-state --region us-east-1 \
        --kms-key-id alias/test-bucket --tags env=dev owner=platform
    
    # Create an S3 bucket without enforcing TLS
    python scripts/create-s3-bucket.py --bucket-name my-tf-state --region us-west-2 --skip-tls-enforcement
"""

import re
import sys
import json
import boto3
import logging
import argparse
import ipaddress
from typing import Dict, List, Optional, Tuple
from botocore.exceptions import ClientError, NoCredentialsError

LOG_FORMAT = "%(levelname)s: %(message)s"
logging.basicConfig(level=logging.WARNING, format=LOG_FORMAT)
logger = logging.getLogger(__name__)

def parse_tags(raw_tags: Optional[List[str]]) -> List[Dict[str, str]]:
    if not raw_tags:
        return []
    tags: List[Dict[str, str]] = []
    for item in raw_tags:
        if "=" not in item:
            raise ValueError(f"\nInvalid tag '{item}'. Use key=value format.")
        key, value = item.split("=", 1)
        if not key or not value:
            raise ValueError(f"\nInvalid tag '{item}'. Use key=value format.")
        tags.append({"Key": key, "Value": value})
    return tags

class S3BucketManager:
    """Create and harden an S3 bucket"""

    def __init__(self, region: str, profile: Optional[str] = None) -> None:
        try:
            session = boto3.session.Session(profile_name=profile, region_name=region)
            self.s3_client = session.client("s3")
            self.sts_client = session.client("sts")
            self.region = region
            self.profile = profile
            account_id = self.sts_client.get_caller_identity()["Account"]
            self._announce_context()
            logger.debug("AWS credentials verified. Account ID: %s", account_id)
        except NoCredentialsError:
            logger.error(
                "AWS credentials not found. Run 'aws configure' or set "
                "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
            )
            sys.exit(1)
        except ClientError as exc:
            logger.error("Failed to initialize AWS client: %s", exc)
            sys.exit(1)

    def _announce_context(self) -> None:
        print(f"\nUsing region '{self.region}'.")
        if self.profile:
            print(f"\nUsing AWS profile '{self.profile}'.")
        print("\nAWS credentials verified.")

    @staticmethod
    def validate_bucket_name(bucket_name: str) -> None:
        if len(bucket_name) < 3 or len(bucket_name) > 63:
            raise ValueError("\nBucket name must be between 3 and 63 characters.")
        if not re.fullmatch(r"[a-z0-9][a-z0-9.-]+[a-z0-9]", bucket_name):
            raise ValueError(
                "Bucket name must use lowercase letters, numbers, dots, or hyphens "
                "and must start/end with a letter or number."
            )
        if ".." in bucket_name or ".-" in bucket_name or "-." in bucket_name:
            raise ValueError("\nBucket name cannot contain '..', '.-', or '-.'.")
        try:
            ipaddress.ip_address(bucket_name)
            raise ValueError("\nBucket name must not be formatted like an IP address.")
        except ValueError:
            pass

    def bucket_exists(self, bucket_name: str) -> Tuple[bool, bool]:
        try:
            self.s3_client.head_bucket(Bucket=bucket_name)
            return True, True
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "")
            if code in {"404", "NoSuchBucket"}:
                return False, False
            if code in {"403", "AccessDenied", "301", "PermanentRedirect"}:
                return True, False
            raise

    def get_bucket_region(self, bucket_name: str) -> str:
        response = self.s3_client.get_bucket_location(Bucket=bucket_name)
        location = response.get("LocationConstraint")
        if location is None:
            return "us-east-1"
        if location == "EU":
            return "eu-west-1"
        return location

    def create_bucket(self, bucket_name: str) -> None:
        params: Dict[str, object] = {"Bucket": bucket_name}
        if self.region != "us-east-1":
            params["CreateBucketConfiguration"] = {
                "LocationConstraint": self.region
            }
        self.s3_client.create_bucket(**params)
        print(f"Bucket '{bucket_name}' created.")

    def ensure_bucket(self, bucket_name: str) -> None:
        exists, owned = self.bucket_exists(bucket_name)
        if exists and not owned:
            raise ValueError(
                f"\nBucket '{bucket_name}' already exists and is not owned by this account."
            )
        if not exists:
            self.create_bucket(bucket_name)
            return
        current_region = self.get_bucket_region(bucket_name)
        if current_region != self.region:
            raise ValueError(
                f"\nBucket '{bucket_name}' already exists in region '{current_region}' "
                f"(requested '{self.region}')."
            )
        print(
            f"\nBucket '{bucket_name}' already exists and is owned by this account."
        )

    # def enable_versioning(self, bucket_name: str) -> None:
    #     self.s3_client.put_bucket_versioning(
    #         Bucket=bucket_name,
    #         VersioningConfiguration={"Status": "Enabled"},
    #     )
    #     logger.info("Enabled versioning for '%s'", bucket_name)

    def enable_encryption(self, bucket_name: str, kms_key_id: Optional[str]) -> None:
        if kms_key_id:
            rules = {
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "aws:kms",
                            "KMSMasterKeyID": kms_key_id,
                        },
                        "BucketKeyEnabled": True,
                    }
                ]
            }
            encryption_label = f"SSE-KMS ({kms_key_id})"
        else:
            rules = {
                "Rules": [
                    {"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}
                ]
            }
            encryption_label = "SSE-S3"

        self.s3_client.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration=rules,
        )
        print(f"\nEncryption enabled: {encryption_label}.")

    def block_public_access(self, bucket_name: str) -> None:
        self.s3_client.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            },
        )
        print("\nPublic access blocked.")

    def enforce_bucket_ownership(self, bucket_name: str) -> None:
        self.s3_client.put_bucket_ownership_controls(
            Bucket=bucket_name,
            OwnershipControls={
                "Rules": [{"ObjectOwnership": "BucketOwnerEnforced"}]
            },
        )
        print("\nBucket ownership enforced.")

    def enforce_tls(self, bucket_name: str) -> None:
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "DenyInsecureTransport",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "s3:*",
                    "Resource": [
                        f"arn:aws:s3:::{bucket_name}",
                        f"arn:aws:s3:::{bucket_name}/*",
                    ],
                    "Condition": {"Bool": {"aws:SecureTransport": "false"}},
                }
            ],
        }
        self.s3_client.put_bucket_policy(
            Bucket=bucket_name, Policy=json.dumps(policy)
        )
        print("\nTLS-only access enforced.")

    def configure_tls_enforcement(self, bucket_name: str, enforce: bool) -> None:
        if enforce:
            self.enforce_tls(bucket_name)
        else:
            print("\nTLS-only access skipped.")

    def apply_tags(self, bucket_name: str, tags: List[Dict[str, str]]) -> None:
        if not tags:
            print("\nNo tags applied.")
            return
        self.s3_client.put_bucket_tagging(
            Bucket=bucket_name,
            Tagging={"TagSet": tags},
        )
        tag_summary = ", ".join(f"{tag['Key']}={tag['Value']}" for tag in tags)
        print(f"\nTags applied: {tag_summary}.")

    def report_ready(self, bucket_name: str) -> None:
        print(f"\nBucket '{bucket_name}' is ready.\n")

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Create a best-practice S3 bucket"
    )
    parser.add_argument("--bucket-name", required=True, help="S3 bucket name.")
    parser.add_argument(
        "--region",
        default="us-east-1",
        help="AWS region for the bucket (default: us-east-1).",
    )
    parser.add_argument(
        "--profile",
        help="AWS CLI profile name to use.",
    )
    parser.add_argument(
        "--kms-key-id",
        help="KMS key ID or alias for SSE-KMS encryption.",
    )
    parser.add_argument(
        "--tags",
        nargs="*",
        help="Optional tags as key=value pairs.",
    )
    parser.add_argument(
        "--skip-tls-enforcement",
        action="store_true",
        help="Skip enforcing TLS-only access on the bucket.",
    )
    return parser

def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    try:
        S3BucketManager.validate_bucket_name(args.bucket_name)
        tags = parse_tags(args.tags)
        manager = S3BucketManager(region=args.region, profile=args.profile)
        manager.ensure_bucket(args.bucket_name)

        # manager.enable_versioning(args.bucket_name)
        manager.enable_encryption(args.bucket_name, args.kms_key_id)
        manager.block_public_access(args.bucket_name)
        manager.enforce_bucket_ownership(args.bucket_name)
        manager.configure_tls_enforcement(
            args.bucket_name, enforce=not args.skip_tls_enforcement
        )
        manager.apply_tags(args.bucket_name, tags)
        manager.report_ready(args.bucket_name)
    except ValueError as exc:
        logger.error("%s", exc)
        sys.exit(1)
    except ClientError as exc:
        logger.error("AWS error: %s", exc)
        sys.exit(1)

if __name__ == "__main__":
    main()
