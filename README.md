This plugin enables RabbitMQ to perform authentication (determining who can log in) and 
authorisation (determining what permissions they have) by connecting to a postgresql database.
   Right now, only the authentication part is implemented. The authorisation is in progress. 

Note: it's at an early stage of development, and could be made rather more robust.

Downloading

Currently the plugin is under review. You can build it however, and use it.

Building

You can build and install it like any other plugin (see the plugin development guide).

Enabling the plugin

To enable the plugin, set the value of the auth_backends configuration item for the rabbit application to include <>. auth_backends is a list
of authentication providers to try in order. 



