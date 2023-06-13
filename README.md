
# HelloID-Conn-Prov-Target-ThreeShips-Cumlaude

| :warning: Warning |
|:---------------------------|
| Note that this connector is "a work in progress" and therefore not ready to use in your production environment. |

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/cumlaudelearning-logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-ThreeShips-Cumlaude](#helloid-conn-prov-target-threeships-cumlaude)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
      - [HelloID Provisioning agent](#helloid-provisioning-agent)
      - [Mandatory password](#mandatory-password)
      - [Account object](#account-object)
      - [Person rec\_status](#person-rec_status)
      - [Creation / correlation process](#creation--correlation-process)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

HelloID-Conn-Prov-Target-ThreeShips-Cumlaude is a target connector. ThreeShips-Cumlaude offers web services APIs that allow developers to access and integrate the functionality of ThreeShips-Cumlaude with other applications and systems.

The ThreeShips Cumlaude API uses a WSDL / SOAP architecture. A WSDL (Web Services Description Language) is an XML-based language that is used for describing the functionality of a web service. A WSDL file defines the methods that are exposed by the web service, along with the data types that are used by those methods and the messages that are exchanged between the web service and its clients.

ThreeShips Cumlaude uses three different WSDL files.

| WSDL     | Description |
| ------------ | ----------- |
| Security     | For authentication |
| IMSEnterpriseImport | For creating and updating user objects |
| UserServices | For querying data |

The following lifecycle events are available:

| Event  | Description | Notes |
|---	 |---	|---	|
| create.ps1 | Create (or update) and correlate an Account | - |

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting| Description| Example   | Mandatory |
| ------------ | -----------| ----------- | ----------- |
| UserName| The UserName to connect to the ThreeShips Cumlaude webservice | - | Yes
| Password| The Password to connect to the the ThreeShips Cumlaude webservice  | - | Yes
| BaseUrl| The URL to the API| https://webservice.threeships.nl/ | Yes
| Source| The name of the source where the users are created | - | Yes

### Prerequisites

> :exclamation: This connector has been created and tested on Windows PowerShell 5.1. Due to the functions and .NET methods being used, the connector might not work on PowerShell Core or without using the HelloID provisioning agent.

### Remarks

#### HelloID Provisioning agent

In order to use this connector, Windows PowerShell 5.1 and the HelloID provisioning agent must be installed.

#### Mandatory password

Currently, the account object contains a password. This is a mandatory property in our test environment. However, this depends on the ThreeShips Cumlaude configuration.

#### Account object

Currently, the account object contains a minimal set of properties. It will create a standard user without special attributes that are used to differentiate between an employee or student.

If you need to extend to account object with properties specific for a student, these properties will also need be added to the XML code.

```xml
<enterprise>
  <properties>
    <datasource></datasource>
    <target></target>
    <datetime></datetime>
  </properties>
  <person recstatus="1">
    <userid password=""</userid>
    <sourcedid>
      <source></source>
      <id></id>
    </sourcedid>
    <name>
      <fn></fn>
    </name>
    <email />
    <systemrole />
    <extension>
      <threeships>
        <studyprogress />
        <forcechangepassword>0</forcechangepassword>
        <personalfolder recstatus="" diskquota="" />
        <postofficeforward>0</postofficeforward>
        <postofficeuseemailaddressassender>0</postofficeuseemailaddressassender>
        <postofficeuseemailaddressintoandcc>0</postofficeuseemailaddressintoandcc>
        <mailboxquota>0</mailboxquota>
        <attributeset name="Attributes" recstatus="1">
          <attribute groupname="Personal details" name="Phone number" datatype="0" recstatus="1"></attribute>
        </attributeset>
      </threeships>
    </extension>
    <eckid />
  </person>
</enterprise>
```

#### Person rec_status

As shown in the XML code above, the person element contains an attribute called `<person recstatus="1">`. In the example its value is set to `1` indicating the person must be created.

In order to update a person, the value must be set to `2` and to remove a person the value must be set to `3`.

#### Creation / correlation process

A new functionality is the possibility to update the account in the target system during the correlation process. By default, this behavior is disabled. Meaning, the account will only be created or correlated.

You can change this behavior in the `create.ps1` by setting the boolean `$updatePerson` to the value of `$true`.

> Be aware that this might have unexpected implications.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
