package Treex::Block::T2A::RU::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %M_GENDER_FOR = (
    anim => 'M',
    inan => 'I',
    fem  => 'F',
    neut => 'N',
);

my %M_NUMBER_FOR = (
    pl => 'P',
    sg => 'S',
);

my %M_DEGREE_FOR = (
    'pos'  => '1',
    'comp' => '2',
    'sup'  => '3',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    # Initialize all categories to '.' so it can be used in regexes
    $a_node->reset_morphcat();

    # Skip coordinations, apositions, rhematizers etc.
    # convention: POS="!" means that the word will not be further inflected
    if ( $t_node->nodetype =~ /coap|atom/ ) {
        $a_node->set_attr( 'morphcat/pos', '!' );
        return;
    }

    # == Person ==
    my $person = $t_node->gram_person;
    if (not defined $person or $person eq 'inher') {
        $person = '.';
    }
    $a_node->set_attr( 'morphcat/person', $person );

    # == Number, Gender ==
    my $number = $t_node->gram_number || '';
    $a_node->set_attr( 'morphcat/number', $M_NUMBER_FOR{$number} || '.' );

    if ($number ne 'pl') {
        my $gender = $t_node->gram_gender || '';
        $a_node->set_attr( 'morphcat/gender', $M_GENDER_FOR{$gender} || '.' );
    }

    # == Case ==
    if ( $a_node->get_attr('morphcat/case') eq '.' ){
        my $formeme = $t_node->formeme;
        if ( $formeme =~ /(\d)/ ) {
            $a_node->set_attr( 'morphcat/case', $1 );
        }
        elsif ( $formeme eq 'drop' ){
            $a_node->set_attr( 'morphcat/case', '1' );
        }
    }

    # == Verbal voice ==
    my $sempos = $t_node->gram_sempos || '';
    if ( $sempos =~ /^v/ ) {
        my $voice = $t_node->voice || '';
        if ( $voice eq 'active' ) {
            $a_node->set_attr( 'morphcat/voice', 'A' );
        }
        elsif ( $voice eq 'passive' ) {
            $a_node->set_attr( 'morphcat/voice', 'P' );
        }
    }

    # == Tense ==
    my $tense = $t_node->gram_tense || '';
    if ( $tense eq 'sim' ){
       $a_node->set_attr( 'morphcat/tense', '[PH]');
    } elsif ($tense eq 'ant') {
       $a_node->set_attr( 'morphcat/tense', '[R]');
    }

    return;
}


1;

__END__

=over

=item Treex::Block::T2A::RU::InitMorphcat

Fill morphological categories (members of structure morphcat) with
values simply derived from values of grammatemes, formeme, sempos etc.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
