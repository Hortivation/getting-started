# Getting started with the Hortivation Hub Data Source
Hortivation Hub is a data exchange platform that aims to standardise communication
between different parties in the Greenhouse Technology Sector. Dataset sharing across the
platform is enabled by the Hortivation Hub Datasource, which is a server that is hosted
by dataset owners. This guide provides all the documentation for getting started with
sharing your data on the Hortivation Hub.

## Requirements
The Data Source server is hosted through Docker. For easy installation we recommend ubuntu or debian
serverd. The following dependencies should be installed on your server:

* Docker (20.10.12) - installation documentation for ubuntu can be found
[here](https://docs.docker.com/engine/install/ubuntu/)
* Docker Compose (1.29.2) - installation documentation for ubuntu can be found
[here](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)

For debian/ubuntu servers don't forget to add your user to the docker group
(terminal restart is required before this change is active)

```bash
sudo usermod -aG docker $USER
```

## Hortivation Hub login
The first step to serving your data on the Hortivation Hub is to login through the
[portal](test.hortivation.sobolt.com/databronnen).

## Create your Data Source
To create your Data Source go to the [datasource create](test.hortivation.sobolt.com/databronnen/aanmaken) page.
Provide a domain name to register your Data Source under on the Hortivation Hub. Successful registration will
download a Data Source credential file needed to enable communication with the rest of the Hub.

## Start up your Data Source
For start up ensure that these 4 elements are within your working directory:

* `docker-compose.yaml` which contains the configuration of all services that
  are required to run the data source.
* `datasets` directory in you working directory containing CGO-compliant data files.
* `datasource_description.yaml` which contains the manual addition datasets descriptions
* Data Source credential .json file, make sure to add the path to this credential file at
  the bottom of the `docker-compose.yaml` file.

A template of these files can be downloaded [here](https://test.hortivation.sobolt.com/api/getting-started-datasource)
or use the command below in your terminal. This template contains a dataset that already exists,
please edit the `datasource_description.yaml` before running the datasource.

```bash
sudo apt-get install unzip nano
curl https://test.hortivation.sobolt.com/api/getting-started-datasource.zip --output getting-started-datasource.zip
unzip getting-started-datasource.zip
cd getting-started
```

Make sure to add the path to your credentials file to the `docker-compose.yaml` file:

```bash
nano docker-compose.yaml
```

The following command can then be used to bring your Data Source live to the Hortivation Hub:

```bash
HOSTNAME=YOUR-HOSTNAME docker-compose up -d
```

where

* `HOSTNAME` is the domain name where the datasource will be hosted.

It can take a couple of minutes before the dataset(s) are online.

You can also view logs of all running services with. If there are issues with setting up your datasource and/or
datasets the details are also available in these logs.

```bash
  docker-compose logs -f
```

Turn-off the Data Source with:

```bash
  docker-compose down
```

## Functionality
Access additional documentation regarding the endpoints provided by the Data Source
through [http://YOUR-HOSTNAME/docs](https://my-datasource-domain/docs)

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

#### File Storage
In order to create a `file` dataset you need to create a turtle (`.ttl`) file in the `datasets`
directory. After that you have to add a yaml object to the datasource desciption file.

NOTE: The `datasets` directory is mounted in the server on the `/datasets` directory. Therefore the
`path` should be relative from that directory. Examples:

1. In the `datasets` directory I have a `data.ttl` file. In this case the path should be `/datasets/data.ttl`
2. In the `datasets` directory I have another directory called `dataset1` and in that directory a `data.ttl`
  file. In this case the path should be `/datasets/dataset1/data.ttl`

## Data categories
[Hortivation Hub](test.hortivation.sobolt.com) allows you to give access to certain parts of your dataset.
If you want to make use of this feature you have to add a
`<https://www.tno.nl/agrifood/ontology/common-greenhouse-ontology#>:hasCategory` predicate to every subject in
your ontology. Currently the following categories are supported:

* `Construction`
* `Water`
* `Heating`
* `Crop`
* `Glass`
* `Other`

## Advanced
For more advanced users there is an `docker-compose-advanced.yaml` file that supports
additional features. One of these features are the fuseki datasets. For persistent
datasets (no data loss when bringing the server down) create a `.fuseki` directory:

```bash
mkdir .fuseki
```

The command below can then be used to bring your Data Source live to the Hortivation Hub.

**IMPORTANT**: This will run an Apache Jena Fuseki server on port 3030

```bash
HOSTNAME=YOUR-HOSTNAME FUSEKI_PW=YOUR_PASSWORD ACME_EMAIL=YOUR_ACME_EMAIL docker-compose up -d
```

where

* `HOSTNAME` is the domain name where the datasource will be hosted.
* `FUSEKI_PW` is the admin user password to the apache jena fuseki server. Please use a password manager
  to generate your password
* `ACME_EMAIL` is the email used for domain name registration. This email will receive notification if there
  are issues with hosting the datasource on your domain.

Access the [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2) server
through [localhost:3030](http://localhost:3030) and login with `admin` and your
password (`FUSEKI_PW`).

### Create fuseki dataset
In order to create a `fuseki` dataset you need to [login on the Apache Jena Fuseki server](http://localhost:3030)
and create a dataset. Similar to the File storage example above you have to add a yaml object to the
datasource description file. The only difference is that the `path` property should be the name of the
dataset on the Apache Jena Fuseki server.

### Updates
On new releases and or updates please pull the latest docker images with the following command:

```bash
docker-compose -f docker-compose-advanced.yaml pull
```

-----
Hortivation Hub Data Source - v0.1.0
