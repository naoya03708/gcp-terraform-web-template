mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
}

variables {
  gcp_project_id = "test-project"
}

run "trust_is_limited_to_the_repository" {
  command = plan

  module {
    source = "./bootstrap/wif"
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository == \"naoya03708/gcp-terraform-web-template\""
    error_message = "プロバイダは、対象リポジトリのトークンだけを受け付けること"
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "GitHub Actions の OIDC 発行元を信頼すること"
  }
}

run "plan_sa_is_read_only_and_pull_request_only" {
  command = plan

  module {
    source = "./bootstrap/wif"
  }

  assert {
    condition     = endswith(google_service_account_iam_member.plan_wif.member, "/subject/repo:naoya03708/gcp-terraform-web-template:pull_request")
    error_message = "plan 用 SA は pull_request のトークンだけが使えること"
  }

  assert {
    condition     = toset([for m in google_project_iam_member.plan : m.role]) == toset(["roles/viewer", "roles/iam.securityReviewer"])
    error_message = "plan 用 SA は閲覧のロールだけを持つこと"
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.plan_state) == 0
    error_message = "state_bucket が未指定なら、バケットの権限を付けないこと"
  }
}

run "plan_sa_gets_state_bucket_access_when_given" {
  command = plan

  module {
    source = "./bootstrap/wif"
  }

  variables {
    state_bucket = "some-bucket"
  }

  assert {
    condition     = google_storage_bucket_iam_member.plan_state[0].role == "roles/storage.objectUser"
    error_message = "state_bucket を指定したら、ロック取得のためのオブジェクト操作を付与すること"
  }
}

run "apply_sa_is_limited_to_environments" {
  command = plan

  module {
    source = "./bootstrap/wif"
  }

  assert {
    condition     = length(google_service_account_iam_member.apply_wif) == 2
    error_message = "apply 用 SA は dev と prod の Environment だけを信頼すること"
  }

  assert {
    condition     = alltrue([for m in google_service_account_iam_member.apply_wif : strcontains(m.member, ":environment:")])
    error_message = "apply 用 SA は、Environment のトークンだけが使えること（ブランチや PR は不可）"
  }

  assert {
    condition     = !contains([for m in google_project_iam_member.apply : m.role], "roles/owner") && !contains([for m in google_project_iam_member.apply : m.role], "roles/editor")
    error_message = "apply 用 SA にオーナー / エディタを付与しないこと"
  }
}

run "immutable_subject_prefix_is_used_when_given" {
  command = plan

  module {
    source = "./bootstrap/wif"
  }

  variables {
    github_subject_prefix = "repo:owner@1/repo@2"
  }

  assert {
    condition     = endswith(google_service_account_iam_member.plan_wif.member, "/subject/repo:owner@1/repo@2:pull_request")
    error_message = "不変のサブジェクトの接頭辞を指定したら、plan 用 SA の信頼条件に使うこと"
  }

  assert {
    condition     = alltrue([for m in google_service_account_iam_member.apply_wif : strcontains(m.member, "/subject/repo:owner@1/repo@2:environment:")])
    error_message = "apply 用 SA の信頼条件にも、同じ接頭辞を使うこと"
  }
}

run "rejects_malformed_repository" {
  command = plan

  module {
    source = "./bootstrap/wif"
  }

  variables {
    github_repository = "not-a-repo"
  }

  expect_failures = [var.github_repository]
}
