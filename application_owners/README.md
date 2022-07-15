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

A template licence server can be downloaded [here](https://test.hortivation.sobolt.com/api/getting-started-licence-server.zip)
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
request to the API of the Hub, [documentation of the endpoint that should be used can be found here](https://test.hortivation.sobolt.com/api/docs#/datasource/create_dataset_datasets_post)
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
