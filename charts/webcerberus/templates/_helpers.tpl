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
Define Solr service name
*/}}
{{- define "psnservice.solrName" -}}
{{- default "solr" .Values.solr.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define Solr service HTTP port
*/}}
{{- define "psnservice.solrServiceHttpPort" -}}
{{- if .Values.solr.service.ports.http -}}
    {{- .Values.solr.service.ports.http | toString -}}
{{- else -}}
    {{- printf "8983" -}}
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
{{- printf "http://%s-%s:%s/solr" .Release.Name (include "psnservice.solrName" .) (include "psnservice.solrServiceHttpPort" .) -}}
{{- end -}}
{{- end -}}

{{/*
This allows us to check if the registry of the image is specified or not.
*/}}
{{- define "webcerberus.imageName" -}}
{{- $registryName := .Values.webcerberus.image.registry -}}
{{- $repository := .Values.webcerberus.image.repository -}}
{{- $tag := .Values.webcerberus.image.tag | default .Chart.AppVersion -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repository $tag -}}
{{- else }}
{{- printf "%s:%s" $repository $tag -}}
{{- end }}
{{- end -}}

{{/*
This allows us to check if the registry of the image is specified or not.
*/}}
{{- define "persephoneshell.imageName" -}}
{{- $registryName := .Values.persephoneshell.image.registry -}}
{{- $repository := .Values.persephoneshell.image.repository -}}
{{- $tag := .Values.persephoneshell.image.tag | default .Chart.AppVersion -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repository $tag -}}
{{- else }}
{{- printf "%s:%s" $repository $tag -}}
{{- end }}
{{- end -}}
