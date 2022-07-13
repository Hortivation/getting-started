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
sudo apt-get install unzip nano
curl https://test.hortivation.sobolt.com/api/getting-started-licence-server.zip --output getting-started-licence-server.zip
unzip getting-started-licence-server.zip
cd getting-started
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
