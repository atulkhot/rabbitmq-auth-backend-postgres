This plugin enables RabbitMQ to perform authentication (determining who can log in) and 
authorisation (determining what permissions they have) by connecting to a postgresql database.
   Right now, only the authentication part is implemented. The authorisation is in progress. 

Note: it's at an early stage of development, and could be made rather more robust.

# Downloading

Currently the plugin is under review. You can build it yourself, and use it.

# Building

You can build and install it like any other plugin (see the plugin development guide).

# Enabling the plugin

To enable the plugin, set the value of the auth_backends configuration item for the rabbit application to include _rabbit_pgauth_worker_. The _auth_backends_ is a list of authentication providers to try in order. 

# Configuring the plugin

You need to configure the plugin to know how to connect to the postgres database.  

Here is a `rabbitmq.conf` example  
```
rabbitmq_pg_auth,
    [
      { postgres_host, "localhost" },
      { postgres_user, "Your postgres username here" },
      { postgres_passwd, "Your postgres password here" },
      { postgres_db, "atul" },
      { postgres_query_timeout, 4000 },
      { predef_user_name, "rabbi" },
      { predef_user_password, "ibbar" }
    ]
  }
```
The configuration also provides a _predefined_ username and password. This is useful as an _escape hatch_, 
for example, when the postgresql is down for some reason.  
