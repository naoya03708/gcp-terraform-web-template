# GCP Terraform Web Template

Google Cloud 上の Web アプリ向けインフラを、Terraform / Terragrunt で再利用できるテンプレートにするプロジェクトです。[AWS 版](https://github.com/naoya03708/aws-terraform-web-template)の GCP 版にあたります。

> **状態: 設計段階（実装前）。** 現在あるのは、要件定義・基本設計・ADR の文書だけで、Terraform のコードは未実装です。実機検証も、まだ行っていません。

## 目指すもの

- 構成の記述だけでなく、**運用（SLO ベースの監視、CI/CD、設計判断の記録、コスト）まで含めて**示す。
- コンピュートは、**第1段階: Cloud Run**、**第2段階: GKE Autopilot**（別モジュールとして追加）。
- 長期のサービスアカウントキーを使わない（ローカルは ADC、CI は Workload Identity Federation）。
- 実機で検証した範囲と、していない範囲を、正直に書く。

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [docs/requirements.md](docs/requirements.md) | 要件定義（スコープ、機能・非機能要件、受け入れ基準、AWS 版からの教訓） |
| [docs/design.md](docs/design.md) | 基本設計（構成図、モジュール、ネットワーク、セキュリティ、監視、CI/CD、検証計画） |
| [docs/adr/](docs/adr/) | 設計判断の記録 |

## フェーズ

| フェーズ | 内容 | 状態 |
| --- | --- | --- |
| 0 | 要件定義・基本設計 | 作業中 |
| 1 | Cloud Run 構成の実装 | 未着手 |
| 2 | GKE Autopilot の追加 | 未着手 |
| 3 | 実機検証と実績の記録 | 未着手 |

## ライセンス
MIT
