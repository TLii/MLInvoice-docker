# MLInvoice Docker image
## General information

**This is an unnaffiliated project without links or input from MayaLabs, the main developer of MLInvoice**

This repository contains source code of an unofficial Docker image for MLInvoice, a Finnish invoicing software for SMEs and sole proprietors. The image is built from the official [upstream source code](https://github.com/emaijala/MLInvoice).

**There is no guaranteed support.**  If you don't know how to run this or break it while running, you get to keep the pieces. I aim to produce a kubernetes-ready image. 

**This is still very much experimental, and might break at any point.** Contributions are welcome, but might ultimately not get included. I'm trying to keep the application as close to upstream source as possible and only replace or add to the codebase at container level if necessary for configuring the container. If you want to make more changes, I suggest using this as parent image.

## Changes to vanilla source code
As you might have noticed, we're not using upstream Dockerfile. The Dockerfile here is completely restructured.

## Installation and usage
This image only builds the MLInvoice application and serves it, depending on your target stage, either with php-fpm or apache2.

For apache2 images, you must provide a database and port forwarding. The image only exposes port 80, so it is highly recommended to run a reverse proxy with TLS termination in front of it.

For php-fpm images, this image will provide php-fpm and the app filesystem. In addition to external database, you need to configure a web server with pass-through of php to the fpm provided by this image.

You **must** provide the image with the following environment variables:

- DATABASE_NAME: The name of database in the external db server.
- DATABASE_USER: The username on the external db server.
- DATABASE_PASSWORD: The password for the external db server.
- DATABASE_SERVER: The hostname for the external db server.

You *should* also provide SITE_URL. Otherwise "localhost" will be used, and you probably don't want this.   

In addition to the mandatory environment variables there are some optional ones:
- DEVELOPER_MODE: Enable php development config by setting this to any value (eg. `yes`)
- ENCRYPTION_KEY: Use predefined encryption key for MLInvoice. **IMPORTANT**: If you don't define an encryption key, a random one will be used. If you then lose your config file, **all encrypted content will be lost.** Make sure you back up your config file (`/var/www/html/config.php`).
- FORCE_HTTPS: MLInvoice can enforce the use of https. If you set this to any non-null value (eg. `yes`), https enforcing will be set in MLInvoice config. *Note: You probably want to leave this null and enforce HTTPS in the reverse proxy of your choice.*

## Helm chart?!
Not yet.

## Development
By building with target stage `final-base` you can create a base image that finalizes the source tree, but *does not install* any flavor of PHP. You can use it as a base image, but have to install, enable etc. all php-related stuff yourself. The source code is located in `/usr/src/mlinvoice`.

## License
This image is licensed under AGPL3.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.  
