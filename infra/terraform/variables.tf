variable "project_id" {
  type        = string
  description = "Google Cloud のプロジェクト ID"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "api_image" {
  type        = string
  description = "API（Rails）のコンテナイメージ。例: asia-northeast1-docker.pkg.dev/PROJECT/payroll-lab/api:SHA"
}

variable "web_image" {
  type        = string
  description = "フロントエンド（Next.js）のコンテナイメージ"
}

variable "web_origin" {
  type        = string
  description = "API の CORS で許可するフロントエンドのオリジン（例: https://payroll-lab-web-xxxx.a.run.app）"
  default     = ""
}

variable "payroll_shard_count" {
  type        = number
  description = "給与計算を何タスクに分けて並列実行するか"
  default     = 4
}

variable "db_tier" {
  type    = string
  default = "db-custom-1-3840"
}
