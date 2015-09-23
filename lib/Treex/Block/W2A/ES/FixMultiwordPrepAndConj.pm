package Treex::Block::W2A::ES::FixMultiwordPrepAndConj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# viceslovne spojky nejcetnejsi v BNC (rucne profiltrovano, neco pridano):
my $MULTI_CONJ = qr/^(a la vez que|a el igual que|a el par que|a el paso que|a el punto que|a el tiempo que|a medida que|a menos que|a no ser que|a poco que|a tal punto que|a vez que|bien entendido que|bien sabe Dios que|casi que|como quiera que|con objeto que|con solo que|con tal que|dado que|de modo que|desde el momento en que|de suerte que|de tal manera que|en cuanto que|en el supuesto que|en tanto que|entre tanto que|excepto que|hasta tanto que|lo malo es que|luego que|maguer que|merced a que|mientras que|ni que|no sea que|por la cuenta que|por mucho que|pues sí que|según que|so pena que|supuesto que|tal y como|tal como|tan pronto como|tanto más que|tanto menos que|una vez que|ya que)$/;

# viceslovne predlozky nejcetnejsi v BNC (rucne profiltrovano):
my $MULTI_PREP = qr/^(a base de|a cambio de|a cargo de|a causa de|a cerca de|acerca de|a condición de|a consecuencia de|a continuación de|a cuenta de|además de|a despecho de|a diferencia de|a distinción de|a dos dedos de|a efecto de|a efectos de|a eso de|a espaldas de|a excepción de|a expensas de|a favor de|a fin de|a fines de|a fuerza de|a guisa de|a juzgar por|a el abrigo de|a la busca de|a la espera de|a la manera de|a la mitad de|a la siga de|a la usanza de|a la vuelta de|a la zona de|a el cabo de|a el calor de|a el cargo de|a el compás de|a el conjuro de|a el decir de|a el derredor de|a el frente de|a el gusto de|a el interior de|allende de|a el modo de|a lo ancho de|a el objeto de|a lo largo y ancho de|a el olor de|a el socaire de|a el tanto de|a el tenor de|alrededor de|a manera de|a mediados de|a mitad de|a modo de|a nombre de|anteriormente a|antes de|aparte de|a partir de|a pesar de|a petición de|a principios de|a propósito de|a prueba de|a punto de|a raíz de|a ras de|a razón de|a reserva de|a retaguardia de|a riesgo de|arriba de|a semejanza de|a suplicación de|a súplica de|a tenor de|a título de|a todo lo largo de|a través de|a trueco de|a usanza de|a vuelta de|con carácter de|con efecto desde|con excepción de|conforme a|con honores de|con la condición de|con lo que respecta a|con miras a|con objeto de|con ocasión de|con relación a|con respecto a|con respecto de|con tal de|con valor de|con vistas a|de acuerdo con|de a el lado de|debajo de|debido a|de cara a|de la mano de|delante de|dentro de|después de|detrás de|dirección a|en aras de|en atención a|en busca de|en calidad de|en cambio de|en caso de|encima de|en compañía de|en compensación de|en concepto de|en contra de|en cuanto a|en cuestión de|en defecto de|en demanda de|en derredor de|en dirección a|en el entorno de|en el interior de|en el otro lado de|en el plazo de|en el puesto de|en espera de|en evitación de|en favor de|enfrente de|en gracia a|en guisa de|en la necesidad de|en las cercanías de|en las proximidades de|en la temporada de|en la zona de|en lo concerniente a|en lugar de|en manos de|en materia de|en medio de|en memoria de|en menos de|en mitad de|en obligación de|en obsequio a|en obsequio de|en oposición a|en orden a|en parte por|en plan de|en pos de|en pro de|en prueba de|en razón de|en recuerdo de|en representación de|en señal de|en tiempo de|en torno a|en torno de|en vez de|en vías de|en virtud de|en vista de|frente a|fuera de|gracias a|hacia mediados de|junto a|junto con|lejos de|luego de|más allá de|pese a|por a el lado de|por causa de|por cuenta de|por el otro lado de|por este lado de|por medio de|por motivo de|por obra de|por obra y gracia de|por razón de|por virtud de|posteriormente a|precedentemente a|respecto a|respecto de|según el decir de|sin contar con|sin necesidad de|si no es por|sin perjuicio de|so pena de)$/;

sub process_atree {
    my ( $self, $a_root ) = @_;
    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    my %unproc_as_idxs_hash = ();

    my $starts_at;
    for ( $starts_at = 0; $starts_at <= $#anodes - 6; $starts_at++ ) {

        LENGTH_LOOP:
        foreach my $length (reverse(2..6)) {    # two- and three-word only so far
            my $string = join ' ', map { lc( $anodes[$_]->form ) } ( $starts_at .. $starts_at + $length - 1 );

            my ($conj) = $string =~ $MULTI_CONJ;
            my ($prep) = $string =~ $MULTI_PREP;
            if (!$conj && !$prep) {
                next LENGTH_LOOP;
            }
            $conj ||= '';
            my $first = $anodes[$starts_at];
            my @others = map { $anodes[$_] } ( $starts_at + 1 .. $starts_at + $length - 1 );

            #  nejdriv se prvni clen prevesi tam, kde byl z nich nejvyssi
            my ($highest) = sort { $a->get_depth <=> $b->get_depth } ( $first, @others );
            if ( $highest != $first ) {
                $first->set_parent( $highest->get_parent );
                $first->set_is_member( $highest->is_member );
		$highest->set_is_member(0);
            }

            # a pak se ostatni casti viceslovne spojky prevesi pod prvni
            foreach my $other (@others) {
                $other->set_afun( $conj ? 'AuxC' : 'AuxP' );
                $other->set_parent($first);
		$other->set_lemma($other->form);
		$other->set_iset('pos'=>'adp', 'adpostype'=>'prep');
		$other->set_is_member(0);
            }

            # a jejich deti se prevesi taky rovnou pod prvni
            foreach my $other (@others) {
                foreach my $child ( $other->get_children() ) {
                    $child->set_parent($first);
                }
            }

            # prevesit predlozky zavisle na predlozce, ktere ale nejsou soucasti viceslovne; mozna by to chtelo povysit
            my @to_rehang = grep {
                $_->tag eq 'IN' && ( $_->afun || '' ) !~ 'Aux[CP]'
            } $highest->get_children();
            foreach my $rehang (@to_rehang) {
                $rehang->set_parent( ( $highest->get_eparents() )[0] );
            }

            # Fill afun
            my $afun = $conj ? 'AuxC' : 'AuxP';
            $first->set_afun($afun);
	    $first->set_lemma($first->form);
	    $first->set_iset('pos'=>'adp', 'adpostype'=>'prep');

            # aby se ty viceslovne predlozky nahodou neprekryly
            $starts_at += $length;
            last LENGTH_LOOP;
        }
    }

    return 1;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::ES::FixMultiwordPrepAndConj

=head1 DESCRIPTION

Adaptation of 'W2A::EN::FixMultiwordPrepAndConj' to Spanish.

Normalizes the way how multiword prepositions (such as
'a causa de') and subordinating conjunctions (such as
'tan pronto como') are treated: first token
becomes the head and the other ones become its immediate
children, all marked with AuxC afun.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
