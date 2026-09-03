{{/*
Expand the name of the chart.
*/}}
{{- define "core-ui-middleware.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "core-ui-middleware.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "core-ui-middleware.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "core-ui-middleware.labels" -}}
helm.sh/chart: {{ include "core-ui-middleware.chart" . }}
{{ include "core-ui-middleware.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "core-ui-middleware.selectorLabels" -}}
app.kubernetes.io/name: {{ include "core-ui-middleware.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "core-ui-middleware.redisSecret" -}}
{{- if .Values.overrides.redisSecret -}}
{{- .Values.overrides.redisSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "core-ui-middleware-redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "core-ui-middleware.s3Secret" -}}
{{- if .Values.s3.auth.existingSecret -}}
{{- .Values.s3.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "core-ui-middleware-s3" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the storage backend for asset bytes (see ADR 0010, unify-cache-backends).
'auto' (the default) derives the backend from whether S3 is configured, so a
fresh install that supplies S3 (an endpoint or internal MinIO) gets the S3 path,
while a carried-forward 2.x values file (no S3, no MinIO) keeps running on Redis.
's3' or 'redis' force the choice explicitly.
*/}}
{{- define "core-ui-middleware.storageBackend" -}}
{{- if ne .Values.storage.backend "auto" -}}
{{- .Values.storage.backend -}}
{{- else if or .Values.s3.endpoint .Values.minio.enabled -}}
s3
{{- else -}}
redis
{{- end -}}
{{- end -}}

{{/*
S3 environment block, shared by the serving and updater containers. Emitted only
when the resolved storage backend is 's3'; callers gate on
core-ui-middleware.storageBackend.
*/}}
{{- define "core-ui-middleware.s3Env" -}}
- name: S3_ENDPOINT
  value: "{{ .Values.s3.endpoint | default (printf "http://%s-%s:9000" .Release.Name "minio") }}"
{{- if eq .Values.minio.enabled true }}
- name: S3_CREATE_BUCKET
  value: "true"
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name "minio" }}
      key: root-user
- name: S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name "minio" }}
      key: root-password
{{- else }}
- name: S3_CREATE_BUCKET
  value: "{{ .Values.s3.createBucket }}"
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "core-ui-middleware.s3Secret" . }}
      key: {{ .Values.s3.auth.userSecretKey }}
- name: S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "core-ui-middleware.s3Secret" . }}
      key: {{ .Values.s3.auth.passwordSecretKey }}
{{- end }}
- name: S3_BUCKET_NAME
  value: "{{ .Values.s3.bucketName }}"
{{- end -}}
