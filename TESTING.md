# Testing

## Have redis installed

- Todo: use a fake redis
- for now: install and run redis

e.g. on OSX 

```
brew install redis
redis-server /usr/local/etc/redis.conf
```

## run rspec

```
bundle exec rspec
```

## Local Testing With the Shell Adapter
### Install redis
````
`brew install redis`             # install a redis server
`redis-server /usr/local/etc/redis.conf`  # start a non-daemonized redis server listening on port 6379
````

### Set up a skeleton lita project
Install the `lita` gem however you like to install your gems and use it to create a new project.  I create a minimal Gemfile and use bundler:
````
bundle install lita   # install the lita gem

bundle exec lita new  # create a new lita project with the default shell adapter
````
This will create a subdirectory called `lita` in the current directory; `lita` contains skeleton files for a `lita` project.

### Load the lita-gitlab gem
Point the Gemfile in `lita` to the `lita-gitlab` plugin.

````
source "https://rubygems.org"

gem "lita"
gem 'lita-gitlab', path: '/Users/......../src/lita-projects/lita-gitlab'
````

Fill out `lita_config.rb` to use your `redis` installation and set the config parameters that `lita-gitlab` needs.

### Run the plugin using the shell adapter
In the `lita` directory, install the necessary gems and run `lita`:

````
$ cd lita
$ bundle install
$ bundle exec lita

lita
[2016-02-03 15:04:48 UTC] WARN: Struct-style access of config.redis is deprecated and will be removed in Lita 5.0. config.redis is now a hash.
[2016-02-03 15:04:48 UTC] WARN: Struct-style access of config.redis is deprecated and will be removed in Lita 5.0. config.redis is now a hash.
Type "exit" or "quit" to end the session.
Lita > 
````

To talk to the shell adapter, type

`@lita <your plugin command>`

````
Lita > @lita: artifact builds

Artifact builds:
  [15] : GitLab Merge Request #30 : new-branch => master
  [14] :
  [13] : GitLab Merge Request #28 : new-index => master
  [12] : GitLab Merge Request #28 : new-index => master
  [11] : GitLab Merge Request #28 : new-index => master
  [10] : GitLab Merge Request #27 : cooles-neues-feature => master
  [9] : GitLab Merge Request #25 : a-test => master
  [8] : GitLab Merge Request #23 : a-test => master
````




