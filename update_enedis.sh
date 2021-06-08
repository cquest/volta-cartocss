#! /bin/bash

DB=osm

cd data

# mise à jour données Enedis 2021
wget -N http://files.opendatarchives.fr/data.enedis.fr/reseau-bt.geojson.gz
wget -N http://files.opendatarchives.fr/data.enedis.fr/reseau-hta.geojson.gz
wget -N http://files.opendatarchives.fr/data.enedis.fr/reseau-souterrain-hta.geojson.gz
wget -N http://files.opendatarchives.fr/data.enedis.fr/poste-electrique.geojson.gz
wget -N http://files.opendatarchives.fr/data.enedis.fr/poste-source.geojson.gz
wget -N http://files.opendatarchives.fr/data.enedis.fr/position-geographique-des-poteaux-hta-et-bt.geojson.gz
# les données BT souterraines sont indisponibles (téléchargement en erreur)

PG_USE_COPY=YES ogr2ogr -f pgdump /vsistdout/ /vsigzip/reseau-hta.geojson.gz -nln enedis_hta_line | psql $DB
PG_USE_COPY=YES ogr2ogr -f pgdump /vsistdout/ /vsigzip/reseau-souterrain-hta.geojson.gz -nln enedis_hta_cable | psql $DB
PG_USE_COPY=YES ogr2ogr -f pgdump /vsistdout/ /vsigzip/poste-electrique.geojson.gz -nln enedis_bt_poste | psql $DB
PG_USE_COPY=YES ogr2ogr -f pgdump /vsistdout/ /vsigzip/poste-source.geojson.gz -nln enedis_hta_poste | psql $DB
PG_USE_COPY=YES ogr2ogr -f pgdump /vsistdout/ /vsigzip/position-geographique-des-poteaux-hta-et-bt.geojson.gz -nln enedis_pole | psql $DB

# geojson trop gros pour ogr2ogr, donc on ruse avec jq
zcat reseau-bt.geojson.gz | jq -c .features[] | psql $DB -c "
CREATE TABLE IF NOT EXISTS tmp_json (j json);
TRUNCATE tmp_json;
COPY tmp_json FROM STDIN;
"

psql $DB -c "
delete from enedis_lignes where operator = 'Enedis';
insert into enedis_lignes select wkb_geometry as geom, true  as ht, false as underground, 'Enedis' as operator from enedis_hta_line;
insert into enedis_lignes select wkb_geometry as geom, true  as ht, true  as underground, 'Enedis' as operator from enedis_hta_cable;
insert into enedis_lignes select ST_geomfromgeojson(j->'geometry') as geom, false as ht, false as underground, 'Enedis' as operator from tmp_json;

delete from enedis_postes where operator='Enedis';
insert into enedis_postes select wkb_geometry as geom, false as source, 'Enedis' as operator from enedis_bt_poste;
insert into enedis_postes select wkb_geometry as geom, true as source, 'Enedis' as operator from enedis_hta_poste;


alter table enedis_pole drop ogc_fid;
alter table enedis_pole drop geo_point_2d;
cluster enedis_pole using enedis_pole_wkb_geometry_geom_idx;
cluster enedis_lignes;
cluster enedis_postes;
"

echo "Penser à supprimer le cache:  sudo rm -rf /var/lib/mod_tile/volta/*"
