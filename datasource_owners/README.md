# Getting started with the Hortivation Hub Data Source
Hortivation Hub is a data exchange platform that aims to standardise communication
between different parties in the Greenhouse Technology Sector. Dataset sharing across the
platform is enabled by the Hortivation Hub Data Source, which is a server that is hosted
by dataset owners. This guide provides all the documentation for getting started with
sharing your data on the Hortivation Hub.

## 0. Requirements
The Data Source server is hosted through Docker. For easy installation we recommend using a server that runs ubuntu or debian. The following dependencies should be installed on your server:

* Docker (20.10.12) - installation documentation for ubuntu can be found
[here](https://docs.docker.com/engine/install/ubuntu/)
* Docker Compose (1.29.2) - installation documentation for ubuntu can be found
[here](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)

For debian/ubuntu servers don't forget to add your user to the docker group
(terminal restart is required before this change is active)

```bash
sudo usermod -aG docker $USER
```

## 1. Create your data source on the Hortivation Hub
The first step to serving your data on the Hortivation Hub is to login through the
[Hortivation Hub portal](https://test.hortivation.sobolt.com/databronnen).

### Create your Data Source
After logging in, create your Data Source by going to the [datasource create](https://test.hortivation.sobolt.com/databronnen/aanmaken) page.
Provide a domain name to register your Data Source under on the Hortivation Hub. Successful registration will
download a Data Source credential `.json` file. This file is used to enable communication with the rest of the Hub.

## 2. Prepare the files
To run a data source, it is required that the following 4 elements are within your working directory:

* `docker-compose.yaml` which contains the configuration of all services that
  are required to run the data source.
* `datasets` directory which contains CGO-compliant data files.
* `datasource_description.yaml` which contains the description of your dataset
* Data Source credential .json file, which you just downloaded when creating the Data Source on the Hub Portal

The easiest way to prepare the files is to:
1. Clone the repository
2. Place your dataset in the datasets folder
3. Copy the credentials .json file to your working directory
4. Edit the `docker-compose.yaml` file to include the path to the credentials file
5. Edit the `datasource_description.yaml` with a suitable description of your dataset

### 2.1 Clone the repository and navigate to the datasource_owners directory

```bash
git clone https://github.com/Hortivation/getting-started.git
cd getting-started/datasource_owners
```

### 2.2 Place your dataset in the `datasets` folder
The template already comes with a small dataset, located here: `datasets/dataset1/data.ttl`. You can replace the `data.ttl` file with your own `.ttl` file.

### 2.3 Copy the credentials .json file to your working directory
Place the `datasource-credentials-####.json` file in the `getting-started/datasource_owners` directory. For example you can use this scp command from your local machine:
```bash
scp datasource-credentials-8b27f0b2-2993-4d15-a2d6-d6e99b23332f.json IP_OF_YOUR_SERVER:PATH_TO_YOUR_WORKING_DIRECTORY/getting-started/datasource_owners
```

### 2.4. Edit the `docker-compose.yaml` file to include the path to your credentials file
Copy the name of your `datasource-credentials-####.json` file and open the `docker-compose.yaml` in an editor (example uses nano).
```bash
nano docker-compose.yaml
```

Place the name of the `datasource-credentials-####.json` at the `ADD_FILEPATH_HERE` at the bottom.
```yaml
secrets:
  credentials:
    file: ./ADD_FILEPATH_HERE
```

Save the file and close the editor.

### 2.5 Edit the `datasource_description.yaml` with a suitable description of your dataset
```bash
nano datasource_description.yaml
```

Fill in the details, making sure to put in the correct `type` (can be *file* or *fuseki*) and `path` (the path from the working directory to your `data.ttl` file
```yaml
Name of your dataset:
  about: Describe your dataset
  contact: Fill in contact details (including an email)
  additional_info: Add additional information
  type: file # don't edit this unless following the advanced steps
  path: /datasets/dataset1/data.ttl # path to your dataset file
```

## 3. Start up your Data Source
Once all files are in place, you can start you Data Source using the following command

```bash
HOSTNAME=YOUR-HOSTNAME docker-compose up -d
```

where

* `YOUR-HOSTNAME` is the domain name where the datasource will be hosted.

It can take a couple of minutes before the dataset(s) are online. After waiting, you can view your Data Source [here](https://test.hortivation.sobolt.com/mijn-datasets) on the Hub Portal. If the status is **Online**, you have succesfully setup your Data Source!

## Managing your Data Source
### View logs
You can view logs of all running services. If there are issues with setting up your datasource and/or
datasets the details are also available in these logs. You can view the logs using:

```bash
  docker-compose logs -f
```

#### Turn-off the Data Source with:
```bash
  docker-compose down
```

> Important: Please refrain from using the `-v --remove-orphans` flags when bringing down your Data Source, as this also removes all certificates. When  bringing the Data Source back up after using these flags, new certificates have to be issued, which can only be done a couple of times before running into limits.

### View Swagger UI
Access additional documentation regarding the endpoints provided by the Data Source
through [http://YOUR-HOSTNAME/docs](https://my-datasource-domain/docs)

## Addtional information

### Create datasets
Currently two types of datasets are supported, these are `file` and `fuseki`. Creating and
editing these datasets is slightly different between the two types, essentially this comes
down to uploading/creating an rdf data model and editing the `datasource_description.yaml`
file. Creating `file` datasets will be further explained in this section, `fuseki` datasets
are explained in the `Advanced` section. The datasource description yaml file contains objects
with the following properties:

* `about`: description of the dataset
* `contact`: person to contact
* `additional_info`: additional information about the dataset
* `type`: One of: `file`, `fuseki`
* `path`: path to the dataset file or the name of the fuseki dataset

Any changes to this .yaml file will also automatically be detected and updated online.

### File Storage
In order to create a `file` dataset you need to create a turtle (`.ttl`) file in the `datasets`
directory. After that you have to add a yaml object to the datasource desciption file.

NOTE: The `datasets` directory is mounted in the server on the `/datasets` directory. Therefore the
`path` should be relative from that directory. Examples:

1. In the `datasets` directory I have a `data.ttl` file. In this case the path should be `/datasets/data.ttl`
2. In the `datasets` directory I have another directory called `dataset1` and in that directory a `data.ttl`
  file. In this case the path should be `/datasets/dataset1/data.ttl`

### Data categories
[Hortivation Hub](https://test.hortivation.sobolt.com) allows you to give access to certain parts of your dataset.
If you want to make use of this feature you have to add a
`<https://www.tno.nl/agrifood/ontology/common-greenhouse-ontology#>:hasCategory` predicate to every subject in
your ontology. Currently the following categories are supported:

* `Construction`
* `Water`
* `Heating`
* `Crop`
* `Glass`
* `Other`

## A. Advanced - Create fuseki dataset
For more advanced users there is an `docker-compose-advanced.yaml` file that supports
additional features. One of these features are the fuseki datasets.

### A.0 Add credentials file to `docker-compose.yaml` and `docker-compose-advanced.yaml`
Before starting to setup your fuseki dataset, make sure that you have added the path to your credentials file in the `docker-compose.yaml` file, as described in step [2.4](https://github.com/Hortivation/getting-started/edit/master/datasource_owners/README.md#24-edit-the-docker-composeyaml-file-to-include-the-path-to-your-credentials-file). Furthermore, also add the same path to the `docker-compose-advanced.yaml` file.

### A.1 Create fuseki directory
For persistent datasets (no data loss when bringing the server down) create a `.fuseki` directory:

```bash
mkdir .fuseki
```

### A.2 Bring up the Data source
The command below can then be used to bring your Data Source live to the Hortivation Hub.

**IMPORTANT**: This will run an Apache Jena Fuseki server on port 3030

```bash
HOSTNAME=YOUR-HOSTNAME FUSEKI_PW=YOUR_PASSWORD ACME_EMAIL=YOUR_ACME_EMAIL docker-compose -f docker-compose-advanced.yaml up -d
```

where

* `HOSTNAME` is the domain name where the datasource will be hosted.
* `FUSEKI_PW` is the admin user password to the apache jena fuseki server. Please use a password manager
  to generate your password
* `ACME_EMAIL` is the email used for domain name registration. This email will receive notification if there
  are issues with hosting the datasource on your domain.

### A.3 Log into the Apache Jena Fuseki server
After bringing up the Data Source, you can access the [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2) server
through port-forwarding the Data Source to your local host:
```bash
ssh IP_OF_YOUR_SERVER -L 3030:127.0.0.1:3030
```
After port forwarding, you can access the server by navigating to [localhost:3030](http://localhost:3030) in your browser and logging in with `admin` and your password (`FUSEKI_PW`).

### A.4 Create a fuseki dataset
In the fuseki server, create a dataset on the [manage dataset](http://localhost:3030/manage.html) page. Copy the name of the dataset you just created.

### A.5 Edit the `datasource_description.yaml` with a suitable description of your dataset
```bash
nano datasource_description.yaml
```

Fill in the details, make sure `type` is set to *fuseki* and the `path` corresponds to the name of the dataset you just created on the Apache Jena Fuseki server.
```yaml
Name of your dataset:
  about: Describe your dataset
  contact: Fill in contact details (including an email)
  additional_info: Add additional information
  type: fuseki
  path: fuseki-dataset-name # path to your dataset file
```
After a couple minutes you can view your Fuseki Data Source [here](https://test.hortivation.sobolt.com/mijn-datasets) on the Hub Portal.

### Updates
On new releases and or updates please pull the latest docker images with the following command:

```bash
docker-compose -f docker-compose-advanced.yaml pull
```

-----
Hortivation Hub Data Source - v0.1.0
