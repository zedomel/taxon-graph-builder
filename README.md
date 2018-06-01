# Global Biotic Interactions Taxon Graph Builder

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
$ ls -1 dist/taxon-graph.zip
dist/taxon-graph.zip
```
