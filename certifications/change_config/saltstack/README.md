# Salt Stack

SaltStack is a popular change configuration automation platform with orchestration capabilities.  It can operate in agent (pull) or agentless (push) mode.  VMWare acquired SaltStack in October 13, 2020 ([source](https://blogs.vmware.com/management/2020/10/vmware-completes-saltstack-acquisition-to-bolster-software-configuration-management-and-infrastructure-automation.html)) for likely around ~$40 million given they raised about $27 million, $12 from  venture capital groups Album VC, Epic VC, as well as DeepFork out of the Bay Area, and Service Provider Capital out of Denver, and later $15.5 million Seed A round led by local venture capital group, Mercato Partners ([source](https://techbuzz.news/saltstack-to-be-acquired-by-vmware/)).

Though, VMWare made a commitment to support open source Salt Stack (see [SaltStack’s Open Source Future Under VMware](https://thenewstack.io/saltstacks-open-source-future-under-vmware/)), VMWare has not grown the business, with marketing, commercial offerings, and certification. 

Broadcom's recently acquired of VMWare for $69 billion, where BroadCom is killing off their product offerings in their *portfolio simplification* strategy (see [Why Broadcom Is Killing off VMware’s Standalone Products](https://thenewstack.io/why-broadcom-is-killing-off-vmwares-standalone-products/)).  There is hope that SaltStack might see further development commercially.


In 2014 SaltStack anncounced development of these certifications.

* SaltStack Certified Engineer (SSCE)
* SaltStack Certified Architect (SSCA)

Source: [SaltStack Certification](https://web.archive.org/web/20150319204408/http://www.saltstack.com/certification/)


## SSCE 

Topics included


* Common Salt execution modules – Usage and knowledge of execution modules like ‘test.ping’ ‘sys.doc’ ‘git’ and ‘grains’
* Common Salt state modules – Usage and knowledge of state modules like ‘pkg’ and ‘network’
* Using Salt states – How to apply Salt states to solve various problems in the Salt ecosystem
* Using SaltStack pillar – Data storage, matching and manipulation with the Salt pillar subsystem
* Command line usage – Running Salt commands from the CLI
* SaltStack configuration – Configuration parameters for Salt masters and minions
* Salt key – Authentication of Salt masters and minions
* Salt security – Encryption, message transport and privacy of data within Salt
* Templating – Using Jinja and other template techniques to generate and drive Salt processes

SaltStack offered SaltStack Enterprise training for $2195 (source [training](https://web.archive.org/web/20150315013614/http://saltstack.com/training/)).  The table of syllabus was from: 

* [SaltStack-Enterprise-training-syllabus.pdf](./SaltStack-Enterprise-training-syllabus.pdf)


# Linux Academy Training: SaltStack Certified Engineer

From: [Linux Academy: SaltStack Certified Engineer (M3U8)](https://linuxacademy.com/devops/training/course/name/saltstack-certified-engineer)

Instruction:
 * Elle Krout - Elle is a Course Author at Linux Academy and Cloud Assessments with a focus on DevOps and Linux. She's a SaltStack Certified Engineer, and particularly enjoys working with configuration management. Prior to working as a Course Author, she was Linux Academy's technical writer for two years, producing and editing written content; before that, she worked in cloud hosting and infrastructure. Outside of tech, she likes cats, video games, and writing fiction.

The source code might be from here:

 *  [content-ssce-files](https://github.com/linuxacademy/content-ssce-files)

## Contents

* Introduction
  * Getting Started
    * Course Introduction
    * About the Training Architect
    * End State Goals
  * Salt Concepts
    * Salt Overview
    * Salt Components
* Salt Installation and Configuration
  * Installation
    * Package Install
    * Bootstrapping Salt
  * Configuration
    * Key Management
    * Master Configuration
    * Minion Configuration
    * Salt Mine
    * Security Suggestions
  * Infrastructure Variations
    * Multi-Master Setup
    * Masterless Setup
* Remote Execution
  * Execution Modules
    * Remote Exuection
    * Targeting
    * `salt-call`
  * Common Modules
    * The sys Module
    * The test Module
    * The pkg Module
    * The user and group Modules
    * The grains Module
    * The cmd Module
    * The git Module
* Salt States and Formulas
  * States and Formulas
    * Anatomy of a Salt State
    * The Salt File Server
    * Requisites
    * The init.sls File
    * The top.sls File
  * Templating
    * Jinja
    * The map.jinja File
  * Pillar
    * Pillar
    * The GPG Renderer
    * Pillar and Jinja
* Events
  * Event Sysstem
    * Event System Overview
    * Event Types
  * Beacons adn Reactors
    * Beacons
    * Reactor
* Runners and Orchestration
  * Salt Runners
    * The salt-run Command
    * Jobs
    * Orchestration
* Additional Components
  * Salt SSH
    * Salt SSH Setup
    * Using Salt SSH
  * Salt Cloud
    * Salt Cloud Setup
    * Using Salt Cloud with Orchestration
* Cloud Server Troubleshooting
  * Troubleshooting
    * Help! My Salt Master is Running Out of Memory
* Conclusion
  * Practice Exam
    * Final Exam Review
  * Conclusion
    * Next Steps

# Random Articles

* [How SaltStack Reinvented Itself for a Cloud-Dominated World](https://thenewstack.io/how-saltstack-reinvented-itself-for-a-cloud-dominated-world/) by B. Cameron Gain (The New Stack) on June 16, 2020.
* [Future-proofing SaltStack](https://blog.cloudflare.com/future-proofing-saltstack) by Lenka Mareková (CloudFlare) on March 31, 2022