{{/*
Expand the name of the chart.
*/}}
{{- define "ActiveMQ-JDBC.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ActiveMQ-JDBC.fullname" -}}
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
{{- define "ActiveMQ-JDBC.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ActiveMQ-JDBC.labels" -}}
helm.sh/chart: {{ include "ActiveMQ-JDBC.chart" . }}
{{ include "ActiveMQ-JDBC.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ActiveMQ-JDBC.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ActiveMQ-JDBC.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ActiveMQ-JDBC.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ActiveMQ-JDBC.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "gen.secret" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace "amq-admin-secret" -}}
{{- if $secret -}}
{{/*
   Reusing existing secret data
*/}}
{{- $secretData := (get $secret "data") | default dict }}
{{- $jwtSecret := (get $secretData "amq-admin-secret")  }}
amq-admin-secret: {{ $jwtSecret | quote }}
{{- $jwtSecret := (get $secretData "monitor-role-pass") }}
monitor-role-pass: {{ $jwtSecret | quote }}
{{- $jwtSecret := (get $secretData "control-role-pass") }}
control-role-pass: {{ $jwtSecret | quote }}
{{- else -}}
{{/*
    Generate new data
*/}}
amq-admin-secret: {{ randAlphaNum 32 }}
monitor-role-pass: {{ randAlphaNum 32 }}
control-role-pass: {{ randAlphaNum 32 }}
{{- end -}}
{{- end -}}


{{- define "users.secret" -}}
{{- $secretusers := lookup "v1" "Secret" .Release.Namespace "amq-users-secret" -}}
{{- if $secretusers -}}
{{/*
   Reusing existing secret data
*/}}
{{- $secretDatausers := (get $secretusers "data") | default dict }}
{{- $jwtSecretusers := (get $secretDatausers "admin")  }}
admin: {{ $jwtSecretusers | quote }}
{{- $jwtSecretusers := (get $secretDatausers "system") }}
system: {{ $jwtSecretusers | quote }}
{{- $jwtSecretusers := (get $secretDatausers "user") }}
user: {{ $jwtSecretusers | quote }}
{{- $jwtSecretusers := (get $secretDatausers "application") }}
application: {{ $jwtSecretusers | quote }}
{{- $jwtSecretusers := (get $secretDatausers "guest") }}
guest: {{ $jwtSecretusers | quote }}
{{- else -}}
{{/*
    Generate new data
*/}}
admin: {{ randAlphaNum 32 }}
system: {{ randAlphaNum 32 }}
user: {{ randAlphaNum 32 }}
application: {{ randAlphaNum 32 }}
guest: {{ randAlphaNum 32 }}
{{- end -}}
{{- end -}}


{{- define "groups.secret" -}}
{{- $secretgroups := lookup "v1" "Secret" .Release.Namespace "amq-groups-secret" -}}
{{- if $secretgroups -}}
{{/*
   Reusing existing secret data
*/}}
{{- $secretDatagroups := (get $secretgroups "data") | default dict }}
{{- $jwtSecretgroups := (get $secretDatagroups "admins")  }}
admins: {{ $jwtSecretgroups | quote }}
{{- $jwtSecretgroups := (get $secretDatagroups "users") }}
users: {{ $jwtSecretgroups | quote }}
{{- $jwtSecretgroups := (get $secretDatagroups "applications") }}
applications: {{ $jwtSecretgroups | quote }}
{{- else -}}
{{/*
    Generate new data
*/}}
admins: admin,system
users: user,admin
applications: application
{{- end -}}
{{- end -}}