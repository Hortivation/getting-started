# Getting started with the Hortivation Hub Data Source

Hortivation Hub is a data exchange platform that aims to standardise communication
between different parties in the Greenhouse Technology Sector. Dataset sharing across the
platform is enabled by the Hortivation Hub Data Source, which is a server that is hosted
by dataset owners. This guide provides all the documentation for getting started with
sharing your data on the Hortivation Hub.

## 0. Requirements

The Data Source server is hosted through Docker. For easy installation we recommend using a server that runs ubuntu or debian. The following dependencies should be installed on your server:

- Docker (20.10.12) - installation documentation for ubuntu can be found
  [here](https://docs.docker.com/engine/install/ubuntu/)
- Docker Compose (1.29.2) - installation documentation for ubuntu can be found
  [here](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)

For debian/ubuntu servers don't forget to add your user to the docker group
(terminal restart is required before this change is active)

```bash
sudo usermod -aG docker $USER
```

**IMPORTANT**: Incoming HTTP and HTTPS ports need to be enabled on your server, because the Hortivation Hub
works using a pull protocol when authorized users try to access your data. 

## 1. Create your data source on the Hortivation Hub

## 1.1 The first step to serving your data on the Hortivation Hub is to login through the

[Hortivation Hub portal](https://hub.hortivation.cloud/databronnen).

### Create your Data Source

After logging in, create your Data Source by going to the [datasource create](https://hub.hortivation.cloud/databronnen/aanmaken) page.
After creating a datasource in the Hortivation Hub Portal you'll receive a Data Source credential `.json` file. This file is used to enable communication with the rest of the Hub.

If you want to use your own domain name, type it into the _Hostnaam_ field. It is also possible to receive a domain name from Hortivation Hub, if you want that leave the _Hostnaam_ field empty and register
the IP address of your datasource server with the commands below. Your datasource will then be reachable at `ORGANIZATION_NAME.DATASOURCE_NAME.hortivation.cloud`.

## 2. Prepare the files

To run a data source, it is required that the following 4 elements are within your working directory:

- `docker-compose.yaml` file which contains the configuration of all services that
  are required to run the data source.
- Data Source credential .json file, which you just downloaded when creating the Data Source on the Hub Portal

The easiest way to prepare the files is to:

1. Clone the repository
2. Copy the credentials .json file to your working directory
3. Edit the `docker-compose.yaml` file to include the path to the credentials file

### 2.1 Clone the repository and navigate to the datasource_owners directory

```bash
git clone https://github.com/Hortivation/getting-started.git
cd getting-started/datasource_owners
```

### 2.2 Copy the credentials .json file to your working directory

Place the `datasource-credentials-####.json` file in the `getting-started/datasource_owners` directory. For example you can use this scp command from your local machine to a server:

```bash
scp datasource-credentials-8b27f0b2-2993-4d15-a2d6-d6e99b23332f.json IP_OF_YOUR_SERVER:PATH_TO_YOUR_WORKING_DIRECTORY/getting-started/datasource_owners
```

### 2.3 Edit the `docker-compose.yaml` file to include the path to your credentials file

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

## 3. Setup hostname

Make sure that the `.env` file contains the `HOSTNAME` variable that is set to the hostname of your datasource.

### 3.1 Register hostname through Hortivation

> Only perform this step if you want to receive a domain name from Hortivation and left the _Hostnaam_ field empty during registration on the hub.

First, get the public IP of your VM.

```bash
PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
```

Then, run the following command, placing the path of your `datasource-credentials-####.json` file into the command:

```bash
docker run -it --rm \
  -v ${PWD}:/data \
  -v PATH_TO_YOUR_DATASOURCE_CREDENTIAL_JSON_FILE:/run/secrets/credentials/datasource-credentials.json \
  -e HUB_PORTAL='https://hub.hortivation.cloud' \
  sobolt/hortivation-hub-datasource-init:latest \
  python main.py --ip ${PUBLIC_IP} -o /data/.env
```

After the command is executed, your ip is registered with Hortivation Hub and you will find a `.env` file in your working directory that should be used to start up your data source.

### 3.2 Use your own hostname

> Only perform this step if you want to use your own domain name and filled in the _Hostnaam_ field during registration on the hub.

Edit the `.env` file and makesure the `HOSTNAME` environment variable is set to your hostname.

## 4. Start up your Data Source

Once all files are in place, you can start you Data Source using the following command

```bash
docker-compose -f docker-compose.yaml --env-file .env pull
docker-compose -f docker-compose.yaml --env-file .env up -d --no-build
```

It can take a couple of seconds before the datasource is online. After waiting, you can navigate to your Data Source from [here](https://hub.hortivation.cloud/databronnen) on the Hub Portal. You should be able to create, edit and remove datasets from the datasource webpage.

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

> Important: Please refrain from using the `-v --remove-orphans` flags when bringing down your Data Source, as this also removes all certificates. When bringing the Data Source back up after using these flags, new certificates have to be issued, which can only be done a couple of times before running into limits.

### View Swagger UI

Access additional documentation regarding the endpoints provided by the Data Source
through [https://YOUR-HOSTNAME/docs](https://my-datasource-domain/docs)

## Addtional information

### Create datasets

Currently three types of datasets are supported, these are `file`, `fuseki` and `xml`. Creating and
editing these datasets is slightly different between the two types, essentially this comes
down to uploading/creating an rdf data model and editing the `datasource_description.yaml`
file. Creating `file` datasets will be further explained in this section, `fuseki` and `xml` datasets
are explained in the `Advanced` section. The datasource description yaml file contains objects
with the following properties:

- `about`: description of the dataset
- `contact`: person to contact
- `additional_info`: additional information about the dataset

### Data categories

[Hortivation Hub](https://hub.hortivation.cloud) allows you to give access to certain parts of your dataset.
If you want to make use of this feature you have to add a
`<https://www.tno.nl/agrifood/ontology/common-greenhouse-ontology#>:hasCategory` predicate to every subject in
your ontology. Currently the following categories are supported:

- `Construction`
- `Water`
- `Heating`
- `Crop`
- `Glass`
- `Other`

## A. Advanced - Create Apache Jena Fuseki server dataset

For more advanced users there is an `docker-compose-advanced.yaml` file that supports
additional features. One of these features is running an Apache Jena Fuseki server dataset. What follows are instructions on how to set up such a dataset.

### A.0 Add credentials file to `docker-compose.yaml` and `docker-compose-advanced.yaml`

Before starting to setup your fuseki dataset, make sure that you have added the path to your credentials file in the `docker-compose.yaml` file, as described in step [2.4](https://github.com/Hortivation/getting-started/edit/master/datasource_owners/README.md#24-edit-the-docker-composeyaml-file-to-include-the-path-to-your-credentials-file). Furthermore, also add the same path to the `docker-compose-advanced.yaml` file.

#### A.0.0 Do you already have a Fuseki server?

If you already have your own Apache Jene Fuseki server with datasets you can remove the `fuseki` service from the `docker-compose-advanced.yaml` file (lines 59-68). In this case you have
to provide additional environment variables, see the command below on how to bring the data source online:

```bash
HOSTNAME=YOUR-HOSTNAME FUSEKI_HOST=YOUR_FUSEKI_HOST FUSEKI_USER=YOUR_FUSEKI_USER FUSEKI_PW=YOUR_PASSWORD ACME_EMAIL=YOUR_ACME_EMAIL docker-compose -f docker-compose-advanced.yaml up -d
```

where

- `HOSTNAME` is the domain name where the datasource will be hosted.
- `FUSEKI_HOST` is the domain + port where the apache jena fuseki server is running.
- `FUSEKI_USER` is the user name to the apache jena fuseki server.
- `FUSEKI_PW` is the user password to the apache jena fuseki server.
- `ACME_EMAIL` is the email used for domain name registration. This email will receive notification if there
  are issues with hosting the datasource on your domain.

You can now skip steps A.1, A.2 and A.3.

### A.1 Create fuseki directory

For persistent datasets (no data loss when bringing the server down) create a `.fuseki` directory:

```bash
mkdir .fuseki
```

### A.2 Bring up the Data Source

The command below can then be used to bring your Data Source live to the Hortivation Hub.

**IMPORTANT**: This will run an Apache Jena Fuseki server on port 3030

```bash
HOSTNAME=YOUR-HOSTNAME FUSEKI_PW=YOUR_PASSWORD ACME_EMAIL=YOUR_ACME_EMAIL docker-compose -f docker-compose-advanced.yaml up -d
```

where

- `HOSTNAME` is the domain name where the datasource will be hosted.
- `FUSEKI_PW` is the admin user password to the apache jena fuseki server. Please use a password manager
  to generate your password
- `ACME_EMAIL` is the email used for domain name registration. This email will receive notification if there
  are issues with hosting the datasource on your domain.

### A.3 Log into the Apache Jena Fuseki server

After bringing up the Data Source, you can access the [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2) server
through port-forwarding the Data Source to your local host:

```bash
ssh IP_OF_YOUR_SERVER -L 3030:127.0.0.1:3030
```

After port forwarding, you can access the server by navigating to [localhost:3030](http://localhost:3030) in your browser and logging in with `admin` and your password (`FUSEKI_PW`).

### A.4 Create a fuseki dataset

In the fuseki server, create a dataset on the [manage dataset](https://localhost:3030/manage.html) page. Copy the name of the dataset you just created.

### A.5 Edit the `datasource_description.yaml` with a suitable description of your dataset

```bash
nano datasource_description.yaml
```

Fill in the details, make sure `type` is set to _fuseki_ and the `path` corresponds to the name of the dataset you just created on the Apache Jena Fuseki server.

```yaml
Name of your dataset:
  about: Describe your dataset
  contact: Fill in contact details (including an email)
  additional_info: Add additional information
  type: fuseki
  path: fuseki-dataset-name # path to your dataset file
```

After a couple minutes you can view your Fuseki Data Source [here](https://hub.hortivation.cloud/mijn-datasets) on the Hub Portal.

## B. Advanced - Using XML Datasets

Not only ontology turtle files can be used, but alternative XML formats as well. We support a default format, but additional ones can be implemented upon request to the Hortivation team.

### B.1 Creating the `datasource_description.yaml`

To use an XML file, follow the instructions specified in the previous section: `Create datasets`. The only two differences are that the `type` specified in your `datasource_description.yaml` and the extension of the file itself should be `xml`.

### B.2 XML Format

The default XML template can be found as [data.xml](./datasets/dataset1/data.xml). You can replace the `data.xml` file with your own `.xml` file.

Your XML file only needs to specify the tags that are relevant to your data. If you require a different XML format, please communicate with the Hortivation team.

## Updates

On new releases and or updates please pull the latest docker images with the following command:

```bash
docker-compose -f docker-compose-advanced.yaml pull
```

---

Hortivation Hub Data Source - v1.0.3
