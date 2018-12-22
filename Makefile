SHELL=/bin/bash
BUILD_DIR=target
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

ELTON_VERSION:=0.5.6
ELTON_JAR:=$(BUILD_DIR)/elton.jar
ELTON:=java -Dgithub.client.id=$$GITHUB_CLIENT_ID -Dgithub.client.secret=$$GITHUB_CLIENT_SECRET -jar $(BUILD_DIR)/elton.jar

NOMER_VERSION:=0.1.5
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

NAMES:=$(BUILD_DIR)/names.tsv.gz
LINKS:=$(BUILD_DIR)/links.tsv.gz

TAXON_GRAPH_URL_PREFIX:=https://zenodo.org/record/1560665/files

TAXON_CACHE:=$(BUILD_DIR)/taxonCache.tsv.gz
TAXON_MAP:=$(BUILD_DIR)/taxonMap.tsv.gz

DIST_DIR:=dist
TAXON_GRAPH_ARCHIVE:=$(DIST_DIR)/taxon-graph.tar.gz

.PHONY: all clean update resolve normalize package

all: update resolve normalize package

clean:
	rm -rf $(BUILD_DIR)/* $(DIST_DIR)/*

$(STAMP):
	mkdir -p $(BUILD_DIR) && touch $@

$(ELTON_JAR): $(STAMP)
	wget -q "https://github.com/globalbioticinteractions/elton/releases/download/$(ELTON_VERSION)/elton.jar" -O $(ELTON_JAR)

$(NAMES): $(ELTON_JAR)
	$(ELTON) update --cache-dir=$(BUILD_DIR)/datasets
	$(ELTON) names --cache-dir=$(BUILD_DIR)/datasets | cut -f1-7 | gzip > $(BUILD_DIR)/globi-names.tsv.gz
	zcat $(BUILD_DIR)/globi-names.tsv.gz | sort | uniq | gzip > $(BUILD_DIR)/globi-names-sorted.tsv.gz
	mv $(BUILD_DIR)/globi-names-sorted.tsv.gz $(NAMES)

update: $(NAMES)

$(NOMER_JAR):
	wget -q "https://github.com/globalbioticinteractions/nomer/releases/download/$(NOMER_VERSION)/nomer.jar" -O $(NOMER_JAR)

$(BUILD_DIR)/term_link.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonMap.tsv.gz" -O $(BUILD_DIR)/term_link.tsv.gz

$(BUILD_DIR)/term.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonCache.tsv.gz" -O $(BUILD_DIR)/term.tsv.gz

resolve: update $(NOMER_JAR) $(BUILD_DIR)/term_link.tsv.gz $(TAXON_CACHE).update $(TAXON_MAP).update

$(TAXON_CACHE).update $(TAXON_MAP).update:
	cat $(BUILD_DIR)/term_link.tsv.gz | gunzip | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_link_names_sorted.tsv
	zcat $(NAMES) | cut -f1,2 | sort | uniq > $(BUILD_DIR)/names_sorted.tsv

	diff --changed-group-format='%>' --unchanged-group-format='' $(BUILD_DIR)/term_link_names_sorted.tsv $(BUILD_DIR)/names_sorted.tsv | gzip > $(BUILD_DIR)/names_new.tsv.gz

	zcat $(BUILD_DIR)/names_new.tsv.gz | $(NOMER) append globi-correct | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected.tsv.gz
	zcat $(BUILD_DIR)/names_new_corrected.tsv.gz | $(NOMER) append --properties=config/corrected.properties globi-enrich | gzip > $(BUILD_DIR)/term_resolved.tsv.gz
	zcat $(BUILD_DIR)/names_new_corrected.tsv.gz | $(NOMER) append --properties=config/corrected.properties globi-globalnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF)" | cut -f6-14 | gzip > $(BUILD_DIR)/term_match.tsv.gz
	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF)" | cut -f1,2,6,7 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz
	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep "NONE" | cut -f1,2 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved.tsv.gz
	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep "SIMILAR_TO" | sort | uniq | gzip > $(BUILD_DIR)/term_fuzzy.tsv.gz

	# validate newly resolved terms and their links
	zcat $(BUILD_DIR)/term_match.tsv.gz | $(NOMER) validate-term | grep "all validations pass" | gzip > $(BUILD_DIR)/term_match_validated.tsv.gz
	zcat $(BUILD_DIR)/term_link_match.tsv.gz | $(NOMER) validate-term-link | grep "all validations pass" | gzip > $(BUILD_DIR)/term_link_match_validated.tsv.gz

	zcat $(BUILD_DIR)/term_match_validated.tsv.gz | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_CACHE).update
	zcat $(BUILD_DIR)/term_link_match_validated.tsv.gz | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_MAP).update


$(TAXON_CACHE) $(TAXON_MAP): $(BUILD_DIR)/term.tsv.gz
	# swap working files with final result
	zcat $(BUILD_DIR)/term.tsv.gz | tail -n +2 | gzip > $(BUILD_DIR)/term_no_header.tsv.gz
	zcat $(BUILD_DIR)/term.tsv.gz | head -n1 | gzip > $(BUILD_DIR)/term_header.tsv.gz
	
	zcat $(BUILD_DIR)/term_link.tsv.gz | tail -n +2 | gzip > $(BUILD_DIR)/term_link_no_header.tsv.gz
	zcat $(BUILD_DIR)/term_link.tsv.gz | head -n1 | gzip > $(BUILD_DIR)/term_link_header.tsv.gz
	
	zcat $(TAXON_CACHE).update $(BUILD_DIR)/term_no_header.tsv.gz | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz
	zcat $(TAXON_MAP).update $(BUILD_DIR)/term_link_no_header.tsv.gz | sort | uniq | gzip > $(BUILD_DIR)/taxonMapNoHeader.tsv.gz

	cat $(BUILD_DIR)/term_link_header.tsv.gz $(BUILD_DIR)/taxonMapNoHeader.tsv.gz > $(TAXON_MAP)
	# normalize the ranks using nomer
	zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f3 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=config/name2id.properties globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=config/id2name.properties globi-taxon-rank > $(BUILD_DIR)/norm_ranks.tsv
	zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f7 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=config/name2id.properties globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=config/id2name.properties globi-taxon-rank > $(BUILD_DIR)/norm_path_ranks.tsv

	
	paste <(zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f1-2) <(cat $(BUILD_DIR)/norm_ranks.tsv) <(zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f4-6) <(cat $(BUILD_DIR)/norm_path_ranks.tsv) <(zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f8-) | gzip > $(BUILD_DIR)/taxonCacheNorm.tsv.gz
	cat $(BUILD_DIR)/term_header.tsv.gz $(BUILD_DIR)/taxonCacheNorm.tsv.gz > $(TAXON_CACHE)

normalize: $(TAXON_CACHE)

$(TAXON_GRAPH_ARCHIVE): $(TAXON_MAP) $(TAXON_CACHE)
	md5sum $(TAXON_MAP) | cut -d " " -f1 > $(TAXON_MAP).md5
	md5sum $(TAXON_CACHE) | cut -d " " -f1 > $(TAXON_CACHE).md5
	
	mkdir -p dist
	cp static/README static/prefixes.tsv $(TAXON_MAP) $(TAXON_MAP).md5 $(TAXON_CACHE) $(TAXON_CACHE).md5 dist/	
	
	zcat $(TAXON_MAP) | head -n11 > dist/taxonMapFirst10.tsv
	zcat $(TAXON_CACHE) | head -n11 > dist/taxonCacheFirst10.tsv

	cat $(BUILD_DIR)/names_sorted.tsv | gzip > dist/names.tsv.gz
	md5sum dist/names.tsv.gz | cut -d " " -f1 > dist/names.tsv.gz.md5
	cp $(BUILD_DIR)/term_unresolved.tsv.gz dist/namesUnresolved.tsv.gz
	md5sum dist/namesUnresolved.tsv.gz | cut -d " " -f1 > dist/namesUnresolved.tsv.gz.md5
 
	cd dist && tar cvzf taxon-graph.tar.gz README taxonMap* taxonCache* names* prefixes.tsv
		
	
package: $(TAXON_GRAPH_ARCHIVE)
