{{/*
Return the chart name.
*/}}
{{- define "order-service.name" -}}
{{- .Chart.Name -}}
{{- end }}

{{/*
Return the fully qualified application name.
*/}}
{{- define "order-service.fullname" -}}
{{- include "order-service.name" . -}}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "order-service.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "order-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "order-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "order-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}