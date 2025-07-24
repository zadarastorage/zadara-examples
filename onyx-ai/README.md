# Zadara Examples - Onyx AI

## Introduction

This folder contains examples and reference projects for use with [Zadara Terraform Modules](https://registry.terraform.io/namespaces/zadarastorage) to deploy [Onyx AI Assistant](https://www.onyx.app/).

These examples require a **Zadara zCompute Account** and an S3-Compatible Storage Endpoint. They will deploy a multinode Kubernetes cluster with resources and configurations necessary to run Onyx.

The code examples provided in this repository are for educational and illustrative purposes only. They may require further modifications and testing before being used in production environments. Use these examples as a reference and adapt them to meet your specific needs and requirements.

## Guides

It is advised to complete at least  **General > [Preparing zCompute Account](docs/01_setup-zcompute.md)** prior to trying to deploy a project.

* General
   * [Preparing zCompute Account](docs/01_setup-zcompute.md)
   * [Obtaining Credentials from Zadara Object Storage](https://guides.zadara.com/zios-guide/latest/object-storage-clients.html#authentication-information)
* Projects
   * [Deploying Onyx Assistant - Minimal](docs/zcompute-k8s_gpu-preload_onyx.md)
   * [Deploying Onyx Assistant - High Availability](docs/zcompute-k8s_gpu-preload_argo-onyx.md)

## Quick usage

This folder contains 3 convenience scripts and a couple example folders.

```
./configure.sh <folder-name>
```

> [!WARNING]
> "Sensitive" fields will not echo-back your input for security purposes, for example the “AWS Secret Key” will accept text but will not answer it back.

This script reads through all the .tf files to find any variables that require user input, prompts the user accordingly and saves the results to `<folder-name>/config.auto.tfvars`.   
Can be run multiple times incase a project is updated/modified, only prompts for input if the variable is not already configured.   
Make changes after the fact by adjusting the `config.auto.tfvars` file directly.

```
./deploy.sh <folder-name>
```
This script will download terraform(if not found), initialize the project folder and apply the configuration. This script does NOT auto-apply, so it will prompt the user to type `yes` before it makes any changes.

```
./cleanup.sh <folder-name>
```
This script is meant to help with the teardown of a deployed project, it will require user confirmation and is only capable of destroying resources created by Terraform. Resources created by Kubernetes operators may prevent this script from completing successfully on the first try.

Further notes about using this exist within each project doc.
