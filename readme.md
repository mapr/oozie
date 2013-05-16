Apache Oozie
=============

What is Oozie
--------------

Oozie is an extensible, scalable and reliable system to define, manage, schedule, and execute complex Hadoop workloads via web services. More specifically, this includes:

  * XML-based declarative framework to specify a job or a complex workflow of dependent jobs.
  * Support different types of job such as Hadoop Map-Reduce, Pipe, Streaming, Pig, Hive and custom java applications.
  * Workflow scheduling based on frequency and/or data availability.
  * Monitoring capability, automatic retry and failure handing of jobs.
  * Extensible and pluggable architecture to allow arbitrary grid programming paradigms.
  * Authentication, authorization, and capacity-aware load throttling to allow multi-tenant software as a service.

Oozie Overview
----------

Oozie is a server based workflow engine specialized in running workflow jobs with actions that run Hadoop MapReduce and Pig jobs.

Oozie is a Java web application that runs in a Java servlet-container.

For the purposes of Oozie, a workflow is a collection of actions such as Hadoop MapReduce jobs or Pig jobs arranged in a control-dependency DAG (Direct Acyclic Graph). Control dependency between actions means that the second action can't run until the first action is complete.

Oozie workflows definitions are written in hPDL, an XML Process Definition Language similar to JBOSS JBPM jPDL.

Oozie workflow actions start jobs in remote systems (i.e. Hadoop, Pig). Once the job completes, the remote system uses a callback to notify Oozie of the action completion, and Oozie proceeds to the next action in the workflow.

Oozie workflows contain control flow nodes and action nodes.

Control flow nodes define the beginning and the end of a workflow (start, end, and fail nodes), and provide a mechanism to control the workflow execution path (decision, fork, and join nodes).

Action nodes are the mechanism by which a workflow triggers the execution of a computation/processing task. Oozie provides support for different types of actions: Hadoop map-reduce, Hadoop file system, Pig, SSH, HTTP, eMail and Oozie sub-workflow. Oozie can be extended to support additional type of actions.

Oozie workflows can be parametrized using variables such as `${inputDir}` within the workflow definition. When submitting a workflow job values for the parameters must be provided. Several identical workflow jobs can run concurrently when properly parametrized for separate output directories.

Documentation
-------------
The Oozie web service is bundles with detailed documentation.

More information is available at the [Oozie](http://oozie.apache.org/) website or at the [Oozie Quick Start](http://oozie.apache.org/docs/3.2.0-incubating/DG_QuickStart.html).


Supported Hadoop Versions
-------------------------

This version of Oozie was primarily tested against Hadoop 0.20.205.x. This will not work on earlier versions of Hadoop such as 0.20.x. and 0.21.

--------------------------------------

If you have any questions/issues, please send an email to [user@oozie.apache.org](), or subscribe to the [mailing list](http://oozie.apache.org/mail-lists.html).

