# Getting started with Hortivation Hub Applications
Hortivation Hub is a data exchange platform that aims to standardise communication
between different parties in the Greenhouse Technology Sector. Applications are
3rd party software solutions that enable datasource owners to gain useful insights
in their data. This guide provides all the documentation for getting started with
connecting your application software to the Hortivation Hub.

## Register your application
To register your application send an email to hortivation with the following information
about your application:

* Name of the application
* Description of what the application is about
* Description of what the application does
* Pricing
* Links to terms of delivery and privacy statement
* Domain of your licence server (see Licence server section for details)

Hortivation administrators will now review your application and approve it if it meets the
following requirements:

* The application has a unique name
* Category of the application
* About section describing the application is written
* Usage section explaining what the application does
* A price per year is given
* Link to the terms of delivery
* Link to the privacy statement
* Licence server with an `"/licences"` endpoint that returns all licences of that application.

## Licence server
If your application has licences and you want to connect those licences to Hortivation Hub
you have to setup a licence server. Essentially this has to be an API that is hosted online
with a `/licences` endpoint. This endpoint should return a list of JSON objects with the
following properties:

* `application_slug` : Slugified name of an application in the hub (for example: `siom`, `kis` or `casta-kassenbouw`)
* `organizations_slug` : Slugified name of an organization in the hub (for example: `hortivation` or `sobolt`)
* `start_date` : a datetime string (for example: `2022-01-01T00:00:00`)
* `end_date` : a datetime string (for example: `2023-01-01T00:00:00`)

A template licence server can be downloaded [here](https://hub.hortivation.cloud/api/getting-started-licence-server.zip)
or use the commands below in
your terminal:

```bash
git clone https://github.com/Hortivation/getting-started.git
cd getting-started/application_owners
```

Please remove/edit the licence objects in the .json file:

```bash
nano licences.json
```

The following command can then be used to bring your licence server online:

```bash
HOSTNAME=YOUR-HOSTNAME docker-compose up -d
```

where

* `HOSTNAME` is the domain name where the licence server will be hosted.

It can take a couple of minutes before the licences are visible in the hub.

You can also view logs of the licence server. If there are issues with setting up your licence server and/or
licences the details are also available in these logs.

```bash
  docker-compose logs -f
```

Turn-off the licence server with:

```bash
  docker-compose down
```

## Advanced - Hub Protocol
More advanced applications might want to build upon our licence server and [datasource templates](../datasource_owners/README.md). 
For those users the following sections explain how the Hub Protocol works. 

### Access Tokens
Communication to the Hub is secured using [JWT access tokens](https://jwt.io/introduction) that have to be added 
to the Authorization Bearer header of every request. After creating a datasource in the portal you'll receive a 
credentials file that contains the datasource UUID and a secret that are required to create and verify JWT access 
tokens. We use the [python PyJWT library](https://pyjwt.readthedocs.io/en/stable/) to create and verify these tokens. 
See example code below to create an access token that expires after 5 minutes:

```python
import jwt
import datetime

secret = '1234567890abcdefghijklmnopqrstuvwxyz' # Replace with your secret
datasource_uuid = '3fa85f64-5717-4562-b3fc-2c963f66afa6' # Replace with your datasource uuid

payload = {
    "iss": f"hortivation-hub-datasource:{datasource_uuid}",
    "sub": f"Datasource {datasource_uuid}",
    "aud": "hortivation-hub-portal-api",
    "iat": datetime.datetime.now(tz=datetime.timezone.utc),
    "exp": datetime.datetime.now(tz=datetime.timezone.utc) + datetime.timedelta(minutes=5)
}

access_token = jwt.encode(payload, secret, algorithm="HS256")
```

See example code below to verify an access token received from hortivation hub:

```python
access_token = "INCOMING-ACCESS-TOKEN" # Replace with access token from authorization bearer header.

secret = '1234567890abcdefghijklmnopqrstuvwxyz' # Replace with your secret
dataset_uuid = '3fa85f64-5717-4562-b3fc-2c963f66afa6' # Replace with dataset uuid that is being accessed

verified_payload = jwt.decode(
  access_token,
  secret,
  algorithms=["HS256"],
  audience=f"hortivation-hub-dataset:{dataset_uuid}",
  issuer="hortivation-hub-portal-api",
  options={"require": ["iss", "sub", "aud", "exp", "iat", "scopes"]},
)

ALLOWED_SCOPES = [
    "Dataset.ReadConstruction",
    "Dataset.ReadWater",
    "Dataset.ReadHeating",
    "Dataset.ReadCrop",
    "Dataset.ReadGlass",
    "Dataset.ReadOther",
    "Dataset.ReadAll",
]
for scope in verified_payload['scopes']:
    if scope not in ALLOWED_SCOPES:
        raise Exception(
          f"Forbidden: invalid scopes in access_token! scope '{s}' is not known!",
        )
```

### Registering/creating datasets
Every datasource is responsible for registering datasets to the hub. Essentially this comes down to sending a POST
request to the API of the Hub, [documentation of the endpoint that should be used can be found here](https://hub.hortivation.cloud/api/docs#/datasource/create_dataset_datasets_post)
THis POST request will return a uuid of the dataset, among other information. 

**Important**: when you send a post request don't forget to add the access token to the Authorization Bearer header

### Datasource requirements - Service discovery
Hortivation Hub will try to access your datasets every now and then in order to check if they are online and/or
CGO-compliant (this process is called Service discovery). Hortivation hub expects every datasource to have the following
endpoints:

#### GET `/`
Endpoint that returns a 200 response if the datasource is online. 

**No access token authorization should be implemented on this endpoint**

#### GET `/datasets/{dataset_id}?sparql_query="ANY-SPARQL-QUERY"`
Endpoint that runs a SPARQL query on a dataset and returns the result of that query as text. See some example
SPARQL queries below:

```
SELECT * 
WHERE { ?subject ?predicate ?object } 
LIMIT 10

CONSTRUCT { ?subject ?predicate ?object } 
WHERE { ?subject ?predicate ?object . }
```

If you want to make use of authorisations for specific parts of your data you'll have to use the scopes in the 
access token of the incoming request. We suggest run a construct query on the whole dataset based on the scopes 
in the access token and executing the SPARQL query on the result of that construct query. For example if the access 
token of the incoming request contains the `Dataset.ReadWater` scope you can filter on all water data with the 
following CONSTRUCT query:

```
PREFIX cgo: <https://www.tno.nl/agrifood/ontology/common-greenhouse-ontology#>

CONSTRUCT { ?subject ?predicate ?object } 
WHERE { 
  ?subject ?predicate ?object . 
  FILTER EXISTS(?subject cgo:hasCategory "Water")
}
```

On the resulting graph you can execute the incoming SPARQL query. See more details about the different data categories
[here](../datasource_owners/README.md#Data-categories).

**Important**: the `dataset_id` should correspond with the uuid received after registering a dataset!

#### GET `/datasets/{dataset_id}/metadata`
Endpoint that returns metadata of your dataset. The returned JSON object is expected to have the following properties:

* `dataset_id` : UUID of the dataset
* `name` : Name of the dataset
* `about` : Description of your dataset
* `contact` : Contact details
* `additional_info` : Additional information

**Important**: the `dataset_id` should correspond with the uuid received after registering a dataset!


## Advanced - Subscribe to updates
Hortivation Hub uses [RabbitMQ](https://www.rabbitmq.com/) (an open-source message-broker) to exchange information between users, 
applications and datasources about updates to datasets. The message broker employs a publish-subscribe pattern where authenticated 
users can subscribe to messages on a certain topic. Users can subscribe to organizations, applications/datasources and to specific 
datasets, each of these topics broadcast different kind of messages. See more details about the topics in their respective sections below.

It is required to get rabbitmq credentials before you can subscribe to updates, the Hub Protocol is used for this. With a JWT access token
you can get your rabbitmq credentials at the [/rabbitmq-credentials]() endpoint. This endpoint resets the rabbitmq credentials if you already
created credentials with your account. Before subscribing to updates you have to call the [/rabbitmq-subscribe]() endpoint that sets up the 
subscription for you. For publishing messages you have to use the [/rabbitmq-publish]() endpoint.

We provide an example implementation in python that can be used to integrate this publish-subscribe pattern in your application. See 
[this folder](publish-and-subscribe). See instructions on how to use the example python class in the section below. RabbitMQ also supports 
other programming languages like Java, Ruby, PHP, C#, etc. You can find tutorials for those [here](https://www.rabbitmq.com/getstarted.html).

### Example python implementation
First open a terminal and make sure to install python 3.4+ (use [venv](https://docs.python.org/3/tutorial/venv.html) or 
[anaconda](https://docs.anaconda.com/anaconda/install/index.html)) and install [the requirements](publish-and-subscribe/requirements.txt): 

```bash
pip install -r requirements.txt
```

Now we need a JWT access token to setup RabbitMQ subscriptions and publish messages. Either create a JWT access token with the instructions above 
about the Hub Protocol or use the [/retrieve_token](http://hub.hortivation.cloud/api/docs#/authentication/retrieve_token_retrieve_token_get) endpoint 
(make sure that you are logged in before using this endpoint). When you have this access token you can use the python script as follows:

```bash
python pubsub.py -t REPLACE-WITH-YOUR-ACCESS-TOKEN
```

This should result in the following output in your terminal:

```
[organization.sobolt] received 'MESSAGE 1'
[organization.sobolt] received 'MESSAGE 2'
[organization.sobolt] received 'MESSAGE 3'
```

### Topic - Organization
All users can subscribe to updates of certain organizations. Messages published to this topic can be one of the following:

* `New datasource: <DATASOURCE_UUID>`
* `Deleted datasource: <DATASOURCE_UUID>`

Organization topic names have the following pattern: `organization.<ORGANIZATION_SLUG>`

Organization slugs can be found on the details page in the dashboard of an organization. If you would like to subscribe to another organization, please ask
a contact person within that organization about the slug.

### Topic - Application or Datasource
Beside organization-wide updates it is also possible to subscribe to datasources or applications. The following
messages can be published to this topic:

* `New dataset: <DATASET_UUID>`
* `Deleted dataset: <DATASET_UUID>`

Datasource topic names have the following pattern: `datasource.<DATASOURCE_UUID>`

The datasource UUID can be retrieved in multiple ways. Either through subscribing to a organization: once subscribed a message containing the 
UUID will be published when the datasource is created. Alternatively, you can [fetch metadata of a dataset through the Portal API](https://hub.hortivation.cloud/api/docs#/datasource/get_dataset_by_slug_datasets__dataset_slug__get), 
this endpoint returns a json object containing a `datasource` key that is the UUID of the datasource where the dataset is hosted.

### Topic - Dataset
The third type of topic that Hortivation Hub supports are datasets, only authorized users will be able to subscribe and publish messages to dataset 
topics. Messages published to this topic can be one of the following:

* `Dataset updated`

Dataset topic names have the following pattern: `dataset.<DATASET_UUID>`

Beside the general topic it is also possible to subscribe to specific authorisations, see the list of those topic names below:

* `dataset.<DATASET_UUID>.Construction`
* `dataset.<DATASET_UUID>.Water`
* `dataset.<DATASET_UUID>.Heating`
* `dataset.<DATASET_UUID>.Crop`
* `dataset.<DATASET_UUID>.Glass`
* `dataset.<DATASET_UUID>.Roof`
* `dataset.<DATASET_UUID>.VenloGreenhouse`

The dataset UUID can be retrieved by [fetching metadata of a dataset through the Portal API](https://hub.hortivation.cloud/api/docs#/datasource/get_dataset_by_slug_datasets__dataset_slug__get), 
this endpoint returns a json object containing a `dataset_id` key that is the UUID of the dataset.

### Customize messages
The Hortivation Hub portal and datasource templates implemented above messages, however it is possible to customize messages that are published.
You can publish any type of message to organization, datasource and/or dataset topics.
