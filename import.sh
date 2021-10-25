#! /bin/bash

PGDATABASE=osm

mkdir -p data && cd data


# données agrégées ORE
wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/reseau-aerien-basse-tension-bt.csv.gz
wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/reseau-aerien-moyenne-tension-hta.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/reseau-souterrain-basse-tension-bt.csv.gz
wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/reseau-souterrain-moyenne-tension-hta.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/postes-de-distribution-publique-postes-htabt.csv.gz

for RESEAU in reseau*.geojson.gz
do
    PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ "/vsigzip/$RESEAU" \
      -lco SPATIAL_INDEX=none -nln $(basename -s .geojson.gz $RESEAU)| psql
done

zcat reseau-souterrain-basse-tension-bt.csv.gz | psql -c "
CREATE TABLE IF NOT EXISTS reseau_souterrain_basse_tension_bt (geo_point text, geo_shape text, positio text, tension text, nom_grd text, code_insee text);
TRUNCATE reseau_souterrain_basse_tension_bt;
COPY reseau_souterrain_basse_tension_bt FROM STDIN WITH (format CSV, header true, delimiter ';');
"
zcat reseau-aerien-basse-tension-bt.csv.gz | psql -c "
CREATE TABLE IF NOT EXISTS reseau_aerien_basse_tension_bt (geo_point text, geo_shape text, positio text, tension text, nom_grd text, code_insee text);
TRUNCATE reseau_aerien_basse_tension_bt;
COPY reseau_aerien_basse_tension_bt FROM STDIN WITH (format CSV, header true, delimiter ';');
"

zcat postes-de-distribution-publique-postes-htabt.csv.gz | psql -c "
CREATE TABLE IF NOT EXISTS ore_postes (geo_point text, geo_shape text, nom text, operator text, code_insee text);
TRUNCATE ore_postes;
COPY ore_postes FROM STDIN WITH (format CSV, header true, delimiter ';');

CREATE TABLE IF NOT EXISTS volta_postes (geom geometry(Geometry,4326), nom text, operator text);
TRUNCATE volta_postes;
INSERT INTO volta_postes SELECT ST_GeomFromGeoJSON(geo_shape), nom, operator FROM ore_postes ORDER BY ST_GeomFromGeoJSON(geo_shape);
CREATE INDEX IF NOT EXISTS volta_postes_geom ON volta_postes USING GIST (geom);
DROP TABLE ore_postes;
"

# agrégation données BT/HTA ORE
psql -c "
CREATE TABLE IF NOT EXISTS volta_lignes (geom geometry(Geometry,4326), ht boolean, underground boolean, operator text, tension text);
TRUNCATE volta_lignes;
INSERT INTO volta_lignes select ST_GeomFromGeoJSON(geo_shape),false as ht, false as underground, nom_grd as operator, tension from reseau_aerien_basse_tension_bt ORDER BY ST_GeomFromGeoJSON(geo_shape);
INSERT INTO volta_lignes select ST_GeomFromGeoJSON(geo_shape),false as ht, true  as underground, nom_grd as operator, tension from reseau_souterrain_basse_tension_bt ORDER BY ST_GeomFromGeoJSON(geo_shape);
INSERT INTO volta_lignes select wkb_geometry,true  as ht, false as underground, nom_grd as operator, tension from reseau_aerien_moyenne_tension_hta ORDER BY wkb_geometry;
INSERT INTO volta_lignes select wkb_geometry,true  as ht, true  as underground, nom_grd as operator, tension from reseau_souterrain_moyenne_tension_hta ORDER BY wkb_geometry;

DROP TABLE reseau_aerien_basse_tension_bt;
DROP TABLE reseau_souterrain_basse_tension_bt;
DROP TABLE reseau_aerien_moyenne_tension_hta;
DROP TABLE reseau_souterrain_moyenne_tension_hta;

CREATE INDEX IF NOT EXISTS volta_lignes_geom ON volta_lignes USING GIST (geom);
" &

wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/distributeurs-denergie-par-commune.geojson.gz
zcat distributeurs-denergie-par-commune.geojson.gz | PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ /vsistdin/ -nln ore_distributeurs | psql


# données Enedis
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Postes%20source%20(postes%20HTBHTA).zip'
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Postes%20de%20distribution%20publique%20(postes%20HTABT).zip'
for ENEDIS in *.zip
do
    PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ "/vsizip/$ENEDIS" \
      -s_srs EPSG:2154 -t_SRS EPSG:4326 -lco SPATIAL_INDEX=none | psql
done

# regroupement des données (postes)
psql -c "
    ALTER TABLE poste_electrique RENAME TO enedis_postes;
    ALTER TABLE enedis_postes add column source boolean;
    ALTER TABLE enedis_postes add column operator text;
    ALTER TABLE enedis_postes drop column ogc_fid;
    INSERT INTO enedis_postes SELECT wkb_geometry, true FROM poste_source;
    DROP TABLE poste_source;
    CREATE INDEX ON enedis_postes USING gist(wkb_geometry);
"
psql -c "CLUSTER enedis_postes USING poste_electrique_wkb_geometry_geom_idx" &




# données RTE
wget -N -nv http://files.opendatarchives.fr/opendata.reseaux-energies.fr/enceintes-de-poste-rte.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.reseaux-energies.fr/lignes-aeriennes-rte.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.reseaux-energies.fr/lignes-souterraines-rte.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.reseaux-energies.fr/points-passage-souterrains-rte.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.reseaux-energies.fr/postes-electriques-rte.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.reseaux-energies.fr/pylones-rte.geojson.gz
for RTE in *rte.geojson.gz
do
  T="rte_$(echo $RTE | sed 's/-/_/g;s/_rte.geojson.gz//')"
  zcat $RTE | PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ /vsistdin/ -nln $T | psql
  psql -c "ALTER TABLE $T drop column ogc_fid;"
  psql -c "CLUSTER $T USING "$T"_wkb_geometry_geom_idx" &
done
wait

psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO public;"

exit



# données srd (Vienne)
mkdir -p srd && pushd srd
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/lignes-aeriennes-basse-tension-bt.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/lignes-aeriennes-moyenne-tension-hta.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/lignes-moyenne-tension-hta-isolees.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/lignes-souterraines-basse-tension-bt.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/lignes-souterraines-moyenne-tension-hta.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/postes-de-distribution-publique-postes-htabt.geojson.gz
wget -N -nv http://files.opendatarchives.fr/opendata.srd-energies.fr/postes-sources-htbhta-et-postes-de-repartition-htahta.geojson.gz
for GEOJSON in *.geojson.gz
do
  T="srd_$(echo $GEOJSON | sed 's/-/_/g;s/.geojson.gz//')"
  zcat $GEOJSON | PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ /vsistdin/ -nln $T | psql
done
psql -c "
  INSERT into enedis_lignes SELECT wkb_geometry, true, true, 'SRD' FROM srd_lignes_souterraines_moyenne_tension_hta ORDER BY wkb_geometry;
  INSERT into enedis_lignes SELECT wkb_geometry, true, false, 'SRD' FROM srd_lignes_aeriennes_moyenne_tension_hta ORDER BY wkb_geometry;
  INSERT into enedis_lignes SELECT wkb_geometry, false, true, 'SRD' FROM srd_lignes_souterraines_basse_tension_bt ORDER BY wkb_geometry;
  INSERT into enedis_lignes SELECT wkb_geometry, false, false, 'SRD' FROM srd_lignes_aeriennes_basse_tension_bt ORDER BY wkb_geometry;
  INSERT into enedis_postes SELECT st_force2d(wkb_geometry), true, 'SRD' FROM srd_postes_sources_htbhta_et_postes_de_repartition_htahta ORDER BY wkb_geometry;
  INSERT into enedis_postes SELECT st_force2d(wkb_geometry), false, 'SRD' FROM srd_postes_de_distribution_publique_postes_htabt ORDER BY wkb_geometry;
"
popd

# données Gérédis
mkdir -p geredis && pushd geredis
for N in $(seq 1 6)
do
  URL="https://www.geredis.fr/IMG/zip/"$N"_geredis.zip"
  wget -N -nv $URL --user-agent="Mozilla/5.0 (Windows NT 10.0; WOW64; rv:45.0) Gecko/20100101 Firefox/45.0"
done

for ZIP in *.zip
do
  unzip -oj $ZIP
  for SHP in *.shp
  do
    PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ "$SHP" -t_SRS EPSG:4326 | psql
  done
  psql -c "
    INSERT into enedis_lignes SELECT wkb_geometry, true, true, 'Geredis' FROM RВseau_Вlectrique WHERE type_de_do='Réseau souterrain haute tension' ORDER BY wkb_geometry;
    INSERT into enedis_lignes SELECT wkb_geometry, true, false, 'Geredis' FROM RВseau_Вlectrique WHERE type_de_do='Réseau aérien haute tension'  ORDER BY wkb_geometry;
    INSERT into enedis_lignes SELECT wkb_geometry, false, true, 'Geredis' FROM RВseau_Вlectrique WHERE type_de_do='Réseau souterrain basse tension'  ORDER BY wkb_geometry;
    INSERT into enedis_lignes SELECT wkb_geometry, false, false, 'Geredis' FROM RВseau_Вlectrique WHERE type_de_do='Réseau aérien basse tension'  ORDER BY wkb_geometry;
    INSERT into enedis_postes SELECT st_force2d(wkb_geometry), true, 'Geredis' FROM Poste_source ORDER BY wkb_geometry;
    INSERT into enedis_postes SELECT st_force2d(wkb_geometry), false, 'Geredis' FROM Poste_Вlectrique ORDER BY wkb_geometry;
  "
done
popd

# finalisation...
psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO public;"
wait
