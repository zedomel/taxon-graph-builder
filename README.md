# Global Biotic Interactions Taxon Graph Builder

[![DOI](https://zenodo.org/badge/135750605.svg)](https://zenodo.org/badge/latestdoi/135750605)

Builds a new, up-to-date, Global Biotic Interaction Taxon Graph using a previously published taxon graph, [nomer](https://github.com/globalbioticinteractions/nomer) and [elton](https://github.com/globalbioticinteractions/elton). 

For an example of a published taxon graph, please see [doi:10.5281/zenodo.755513](https://doi.org/10.5281/zenodo.755513) .

## Prerequisites
 
 * [make](https://en.wikipedia.org/wiki/Make_(software)) 
 * [bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell))
 * [git](https://en.wikipedia.org/wiki/Git)
 * internet connection

## Build

To build a taxon graph, run:

``` console
$ git clone https://github.com/globalbioticinteractions/taxon-graph-builder
$ cd taxon-graph-builder
$ make
[...  hours later ...]
$ ls -1 dist/taxon-graph.tar.gz
dist/taxon-graph.tar.gz
```

## Deploy

To deploy a GloBI taxon graph, you can use:

### Maven

To package and deploy the taxon graph using a maven repository:

```
sudo mvn --settings /etc/globi/.m2/settings.xml deploy:deploy-file -DartifactId=taxon -DgroupId=org.globalbioticinteractions -Dversion=[some version] -Dfile=[some file path] -Dpackaging=zip -DrepositoryId=globi-datasets -Durl=s3://globi/datasets
```


### Zenodo

Create a Zenodo deposit (e.g., https://zenodo.org/record/4753955), then upload dist artifacts (excluding the prepackaged zip) using 

```
ls -1 | xargs -L1 bash ~/zenodo-upload/zenodo_upload.sh [some deposit id]
```
