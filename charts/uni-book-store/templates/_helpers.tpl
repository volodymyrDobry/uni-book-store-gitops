{{/*
Chart base name (overridable via nameOverride).
*/}}
{{- define "uni-book-store.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name, built from the RELEASE name so the chart can be
installed multiple times in one cluster without object-name collisions.
*/}}
{{- define "uni-book-store.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Component-specific object names (release-based). Each component's Service name is
also its in-cluster DNS name, which peers and the frontend gateway rely on.
*/}}
{{- define "uni-book-store.bookManagement.fullname" -}}
{{- printf "%s-book-management" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.orderService.fullname" -}}
{{- printf "%s-order-service" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.frontend.fullname" -}}
{{- printf "%s-frontend" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.postgres.fullname" -}}
{{- printf "%s-postgres" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.keycloak.fullname" -}}
{{- printf "%s-keycloak" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.keycloakDb.fullname" -}}
{{- printf "%s-keycloak-db" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.activemq.fullname" -}}
{{- printf "%s-activemq" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uni-book-store.localstack.fullname" -}}
{{- printf "%s-localstack" (include "uni-book-store.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Secret names. When `existingSecret` / `existingKeycloakSecret` is set, the chart
does not render that Secret (it is created out-of-band, e.g. `kubectl create secret`)
and every reference points at the provided name — so no plaintext secret lives in Git.
*/}}
{{- define "uni-book-store.secretName" -}}
{{- .Values.existingSecret | default (include "uni-book-store.fullname" .) -}}
{{- end -}}

{{- define "uni-book-store.keycloakSecretName" -}}
{{- .Values.existingKeycloakSecret | default (include "uni-book-store.keycloak.fullname" .) -}}
{{- end -}}

{{/*
Chart name and version, used as a label.
*/}}
{{- define "uni-book-store.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every object.
*/}}
{{- define "uni-book-store.labels" -}}
helm.sh/chart: {{ include "uni-book-store.chart" . }}
app.kubernetes.io/name: {{ include "uni-book-store.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels for a component. Call with a dict:
  (dict "ctx" . "component" "book-management")
*/}}
{{- define "uni-book-store.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uni-book-store.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
hostAliases block so backend pods resolve the Keycloak ingress host to the node
and validate JWTs against the SAME issuer URL the browser uses. Rendered only
when .Values.keycloak.hostAliasIp is set.
*/}}
{{- define "uni-book-store.keycloakHostAliases" -}}
{{- if .Values.keycloak.hostAliasIp }}
hostAliases:
  - ip: {{ .Values.keycloak.hostAliasIp | quote }}
    hostnames:
      - {{ .Values.ingress.keycloakHost | quote }}
{{- end }}
{{- end -}}
