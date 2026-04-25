{{/*
Nombre completo del chart
*/}}
{{- define "passprotect.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Nombre del chart
*/}}
{{- define "passprotect.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels comunes
*/}}
{{- define "passprotect.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: passprotect
{{- end }}

{{/*
Selector labels para un componente
*/}}
{{- define "passprotect.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .release }}
{{- end }}

{{/*
Dominio Vaultwarden generado con nip.io
*/}}
{{- define "passprotect.vwDomain" -}}
vault.{{ .Values.global.vpsIp }}.nip.io
{{- end }}

{{/*
Dominio Keycloak generado con nip.io
*/}}
{{- define "passprotect.kcDomain" -}}
auth.{{ .Values.global.vpsIp }}.nip.io
{{- end }}

{{/*
Dominio Dashboard (configurable via .Values.dashboard.host)
*/}}
{{- define "passprotect.dashboardDomain" -}}
{{- .Values.dashboard.host | default (printf "dashboard.%s.nip.io" .Values.global.vpsIp) -}}
{{- end }}

{{/*
Security context comun para pods
*/}}
{{- define "passprotect.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 1000
fsGroup: 1000
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
Security context comun para containers
*/}}
{{- define "passprotect.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
{{- end }}
