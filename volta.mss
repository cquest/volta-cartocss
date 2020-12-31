#enedis_lignes { 
    line-width: 2;
    line-color: magenta;
    [ ht = true ] {
        line-width: 6;
        line-join: round;
        line-cap: round;
    }
    [ underground = true ] {
        line-dasharray: 6,18 ;
        b/line-width: 0.5;
        b/line-color: magenta;
    }
}

#enedis_postes {
    marker-width: 8;
    marker-fill: blue;
    [ source = true ] {
        marker-width: 24;
    }
}

#rte_lignes_aeriennes { 
    ::line {
        line-width: 8;
        line-join: round;
        line-cap: round;
        line-color: darken(magenta,10%);
        b/line-width: 0.5;
        [ etat != 'EN EXPLOITATION' ] {
            line-opacity: 0.5;
        }
    }

    ::text [zoom < 18] {
        text-name: "[libelle]";
        text-fill: darken(magenta,10%);
        text-face-name: @bold-fonts;
        text-halo-radius: 1.5;
        text-placement: line;
        text-dy: 8;
        text-spacing: 400;
        text-avoid-edges: true;
    }
}

#rte_lignes_souterrainnes { 
    ::line {
        line-width: 8;
        line-join: round;
        line-cap: round;
        line-color: darken(magenta,10%);
        line-dasharray: 10,20;
        b/line-width: 0.5;
        [ etat != 'EN EXPLOITATION' ] {
            line-opacity: 0.5;
        }
    }

    ::text [zoom < 18] {
        text-name: "[libelle]";
        text-fill: darken(magenta,10%);
        text-face-name: @bold-fonts;
        text-halo-radius: 1.5;
        text-placement: line;
        text-dy: 8;
        text-wrap-width: 50;
        text-spacing: 400;
        text-avoid-edges: true;
    }
}

#rte_enceintes_de_poste {
    line-color: darken(magenta,20%);
    line-width: 2;
    text-name: "[nom_poste]";
    text-fill: darken(magenta,10%);
    text-face-name: @bold-fonts;
    text-halo-radius: 1.5;
    text-wrap-width: 50;
}

#rte_pylones {
    marker-fill: black;
    marker-width: 8;
    text-name: [libelle];
    text-face-name: @book-fonts;
    text-halo-radius: 1.5;
    text-dy: 6;
    text-placement-type: simple;
    text-placements: S,E,W,SE,SW;
    text-avoid-edges: true;
}

#ore_distributeurs {
    line-color: white;
    text-name: "[grd_elec]";
    text-face-name: @bold-fonts;
    text-fill: magenta;
    text-halo-radius: 1.5;
    text-dy: -6;
    text-wrap-width: 20;
    text-placement: line;
    text-spacing: 400;
}