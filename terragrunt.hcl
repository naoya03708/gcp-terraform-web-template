# Terragrunt ラッパー: state 用 GCS バケットの自動作成と、環境ごとの tfvars 切替を担う。
#
# 使い方:
#   export GCP_PROJECT=<your-gcp-project-id>   # 必須（リポジトリには書かない）
#   ENV=dev  terragrunt plan                    # dev.tfvars を使用（ENV 未指定時も dev）
#   ENV=prod terragrunt apply                   # prod.tfvars を使用
#
# リージョンは GCP_REGION で上書き可能（既定: asia-northeast1）。
# 認証はローカルでは ADC（gcloud auth application-default login）、CI では Workload Identity Federation。

locals {
  # 環境変数が未設定でも空文字でも既定値になるよう coalesce を使う
  env    = coalesce(get_env("ENV", ""), "dev")
  region = coalesce(get_env("GCP_REGION", ""), "asia-northeast1")
  name   = "gcp-tf-web"

  # プロジェクト ID は公開リポジトリに書かない。未設定ならここでエラーにする。
  gcp_project = get_env("GCP_PROJECT")
}

# GCS バケットが無ければ Terragrunt が作成する（バージョニング有効）。
# Terragrunt 0.77.22 で、実機（東京、均一なバケットレベルのアクセス、バージョニング有効）の作成を確認済み（ADR 0001）。
# 組織ポリシー storage.uniformBucketLevelAccess に合わせ、均一なバケットレベルのアクセスで作る。
# ロックは GCS バックエンドが自動で行う。
remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    project  = local.gcp_project
    location = local.region
    bucket   = "${local.name}-tfstate-${local.gcp_project}"
    prefix   = local.env

    enable_bucket_policy_only = true
  }
}

terraform {
  extra_arguments "env_tfvars" {
    commands  = get_terraform_commands_that_need_vars()
    arguments = ["-var-file=${get_terragrunt_dir()}/${local.env}.tfvars"]
  }
}

inputs = {
  project        = local.name
  env            = local.env
  region         = local.region
  gcp_project_id = local.gcp_project
}
