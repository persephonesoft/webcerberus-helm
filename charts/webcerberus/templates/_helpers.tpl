{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "psnservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "psnservice.namespace" -}}
{{- default "persephone" .Values.namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define Solr service name
*/}}
{{- define "psnservice.solrName" -}}
{{- default "solr" .Values.solr.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define Solr service HTTP port
*/}}
{{- define "psnservice.solrServiceHttpPort" -}}
{{- default "8983" .Values.solr.service.ports.http | trunc 5 -}}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "psnservice.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "psnservice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create Solr URL string.
*/}}
{{- define "psnservice.solrUrl" -}}
{{- if .Values.env.ENVPSN_Solr_URL -}}
{{- .Values.env.ENVPSN_Solr_URL | lower -}}
{{- else -}}
{{- printf "http://%s-%s:%s/solr" .Release.Name (include "psnservice.solrName" .) (include "psnservice.solrServiceHttpPort" -}}
{{- end -}}