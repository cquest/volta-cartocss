#! /bin/bash

PGDATABASE=osm

mkdir -p data && cd data

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
psql -c "CREATE TABLE enedis_lignes (geom geometry, ht boolean, underground boolean, operator text)"
for N in $(seq 0 9)
do
  psql -c "
    INSERT INTO enedis_lignes (select wkb_geometry, false, false, 'Enedis' from \"e_tronçon_aérien_bt_dpt_$N\");
    DROP TABLE \"e_tronçon_aérien_bt_dpt_$N\";
    INSERT INTO enedis_lignes (select wkb_geometry, false, true, 'Enedis' from \"e_tronçon_câble_bt_dpt_$N\");
    DROP TABLE \"e_tronçon_câble_bt_dpt_$N\";
  "
done
psql -c "
    INSERT INTO enedis_lignes (select wkb_geometry, true, false, 'Enedis' from tronconaerienhta_me_position);
    INSERT INTO enedis_lignes (select wkb_geometry, true, true, 'Enedis' from tronconcablehta_me_position);
    DROP TABLE tronconaerienhta_me_position;
    DROP TABLE tronconcablehta_me_position;

    ALTER TABLE poste_electrique RENAME TO enedis_postes;
    ALTER TABLE enedis_postes add column source boolean;
    ALTER TABLE enedis_postes add column operator text;
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
