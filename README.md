
# Bash Utils

### Inspiration

Weary after spending several hours installing Moodle 5.1 on Debian 13.10, I thought there ought to be a better way. Surely significant parts of the process could be automated?

Bash Utilities is a collection of Bash scripts to automate common tasks.

### WARNING

DO NOT USE IN A PRODUCTION ENVIRONMENT. Some of the functions can do serious damage to your system. We accept no liability for any damage resulting from your use of these scripts.

### Approach

The general approach is to create a series of highly customisable utilities that can work independently to accomplish small tasks. These can be strung together to accomplish bigger jobs.

For example, the Apache2 virtual hosts utilities (*vhost*) can be used as follows:

#### vhost create
Creates a ‘vanilla’ Apache2 virtual host structure

#### vhost create-self-signed-cert
Creates a self-signed certificate

#### vhost configure
Configures a ‘vanilla’ Apache2 website with SSL and port http redirect to https

#### vhost remove
Removes an Apache2 vhost (**use with care**)

There is a similar vanilla utility to install commonly used databases.

### Roadmap

These utilities are highly configurable. Therefore, it should be possible to use them as a basis to created automatons for specific jobs. For example, a task to install Moodle go conceptually be constructed like this:

*moodle check-dependencies* – installs dependencies for Moodle

*db install mariadb* – installs MariaDb (and creates a user)

*vhost create* – creates a ‘vanilla’ Apache2 virtual host structure

*vhost create-self-signed-cert* – creates a self-signed certificate

*moodle get* – download Moodle

*moodle configure* – configure module (as per a specified template)

### Contributing

Please make modifications to improve this. Share utilities that have served you well, so that others may benefit.

Guidelines and code structure (and pattern) are explained in the Wiki. The main thing is to maintain a consistent pattern, comment code well and include as many *failsafe* features as possible.

### Style Guide
More in the wiki - TO DO, but in essence:
  - Comment well so others can follow your thinking
  - Prioritise readability
  - Maintain consistency

There is a useful style guide by Google [here](https://google.github.io/styleguide/shellguide.html)

### Queries

Direct queries to Justin Njoh – justin@lisol.co.uk
