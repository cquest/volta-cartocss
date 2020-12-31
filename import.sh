#! /bin/bash

PGDATABASE=osm

# données Enedis
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Lignes%20a%C3%A9riennes%20moyenne%20tension%20(HTA).zip'
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Postes%20source%20(postes%20HTBHTA).zip'
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Lignes%20a%C3%A9riennes%20Basse%20Tension%20(BT).zip'
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Lignes%20souterraines%20Basse%20Tension%20(BT).zip'
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Lignes%20souterraines%20moyenne%20tension%20(HTA).zip'
wget -N -nv 'https://www.enedis.fr/contenu-html/opendata/Postes%20de%20distribution%20publique%20(postes%20HTABT).zip'
for ENEDIS in *.zip
do
    PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ "/vsizip/$ENEDIS" \
      -s_srs EPSG:2154 -t_SRS EPSG:4326 -lco SPATIAL_INDEX=none | psql
done

# regroupement des données (lignes et postes)
psql -c "CREATE TABLE enedis_lignes (geom geometry, ht boolean, underground boolean)"
for N in $(seq 0 9)
do
  psql -c "
    INSERT INTO enedis_lignes (select wkb_geometry, false, false from \"e_tronçon_aérien_bt_dpt_$N\");
    DROP TABLE \"e_tronçon_aérien_bt_dpt_$N\";
    INSERT INTO enedis_lignes (select wkb_geometry, false, true from \"e_tronçon_câble_bt_dpt_$N\");
    DROP TABLE \"e_tronçon_câble_bt_dpt_$N\";
  "
done
psql -c "
    INSERT INTO enedis_lignes (select wkb_geometry, true, false from tronconaerienhta_me_position);
    INSERT INTO enedis_lignes (select wkb_geometry, true, true from tronconcablehta_me_position);
    DROP TABLE tronconaerienhta_me_position;
    DROP TABLE tronconcablehta_me_position;

    ALTER TABLE poste_electrique RENAME TO enedis_postes;
    ALTER TABLE enedis_postes add column source boolean;
    ALTER TABLE enedis_postes drop column ogc_fid;
    INSERT INTO enedis_postes SELECT wkb_geometry, true FROM poste_source;
    DROP TABLE poste_source;
    CREATE INDEX ON enedis_postes USING gist(wkb_geometry);
"
psql -c "CREATE INDEX enedis_lignes_geom_idx ON enedis_lignes USING gist(geom); CLUSTER enedis_lignes USING enedis_lignes_geom_idx" &
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
  psql -c "ALTER TABLE $t drop column ogc_fid;"
  psql -c "CLUSTER $T USING "$T"_wkb_geometry_geom_idx" &
done

# données ORE
wget -N -nv http://files.opendatarchives.fr/opendata.agenceore.fr/distributeurs-denergie-par-commune.geojson.gz
zcat distributeurs-denergie-par-commune.geojson.gz | PG_USE_COPY=yes ogr2ogr -f pgdump /vsistdout/ /vsistdin/ -nln ore_distributeurs | psql

psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO public;"
wait


