# Civic Generator
> Rails template for projects at Civica Digital.

## How to use it?
You need to have the following dependencies installed:
- NodeJS
- Rails
- PostgreSQL
- Git
- [GPG tools](https://gpgtools.org/)
- [git-crypt](https://github.com/AGWA/git-crypt/blob/master/INSTALL.md)

```bash
# Create
rails new myapp -m https://raw.githubusercontent.com/civica-digital/civic-generator/master/civicops.rb

# Update
rails app:template LOCATION=https://raw.githubusercontent.com/civica-digital/civic-generator/master/civicops.rb
```

### Docker
You can use the following image to **create** an application:
```bash
# Create a new application with `myapp` as name
civicadigitaldocker/civicops myapp
```

_MacOS_:
```bash
docker run --rm -ti -v $PWD:/usr/src civicadigitaldocker/civicops myapp
```

_Linux_:
```bash
# If you are using Linux, you need to specify the user
docker run --rm -ti -v $PWD:/usr/src -u $(id -u):$(id -g) civicadigitaldocker/civicops myapp
```
