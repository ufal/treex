package Treex::Block::A2N::EN::DistinguishPersonalNames;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use Lexicon::EN::First_names;

# Czech morphology used as an additional resource for gender detections
use Lexicon::Generation::CS;
my $generator = Lexicon::Generation::CS->new();

my %GENDER_OF_ROLE = (
    'Mr.'  => 'm',
    Mr     => 'm',
    sir    => 'm',
    king   => 'm',
    lord   => 'm',
    'Mrs.' => 'f',
    'Ms.'  => 'f',
    Mrs    => 'f',
    Ms     => 'f',
    queen  => 'f',
    lady   => 'f',
);

sub process_zone {
    my ( $self, $zone ) = @_;

    return if not $zone->has_ntree;
    my $n_root = $zone->get_ntree;
    my @n_p = grep { $_->get_attr('ne_type') eq 'p_' } $n_root->get_descendants();
    foreach my $n_node (@n_p) {
        process_personal_nnode($n_node);
    }
    return;
}

sub process_personal_nnode {
    my ($n_node) = @_;
    my @a_nodes = $n_node->get_anodes();
    my @lemmas = map { $_->lemma } @a_nodes;
    my $gender;

    # Roles (like sir, queen,...) are not part or the named entity
    # so let's look at previous m-node
    if ( my $prev_anode = $a_nodes[0]->get_prev_node() ) {
        my $prev_lemma = $prev_anode->lemma;
        $gender = $GENDER_OF_ROLE{$prev_lemma};
    }
    my @genders = map { guess_gender($_) } @lemmas;

    if ( !$gender ) {
        $gender = first { $_ ne '?' } @genders;
    }
    $n_node->set_attr( 'ne_type', !$gender ? 'P' : $gender eq 'f' ? 'PF' : 'PM' );

    my $was_first_name = 0;
    for my $i ( 0 .. $#a_nodes ) {
        my $a_node = $a_nodes[$i];
        my $type   = 'p_';
        if ( $GENDER_OF_ROLE{ $lemmas[$i] } ) {
            $type = 'pd';
        }
        elsif ( $genders[$i] =~ /[fm]/ ) {
            if ( !$was_first_name ) {
                $type           = 'pf';
                $was_first_name = 1;
            }
            else {
                $type = 'pm';
            }
        }
        elsif ( $i == $#a_nodes ) {
            $type = 'ps';
        }
        my $new_nnode = $n_node->create_child(
            normalized_name => $lemmas[$i],
            ne_type         => $type,
        );
        $new_nnode->set_attr( 'a.rf', [ $a_node->id ] );
    }

    return;
}

# Stanford NER considers "Mr." or "Mrs." a part of NE
# so let's check also for GENDER_OF_ROLE.
sub guess_gender {
    my ($lemma) = @_;
    return $GENDER_OF_ROLE{$lemma}                    || Lexicon::EN::First_names::gender_of($lemma)
        || firstname_gender_from_czech_morpho($lemma) || '?';
}

# HACK: m-layer has no ord attribute, so $tmt_node->get_prev_node does not work.
#sub get_prev_mnode {
#    my $tmt_mnode = shift;
#    my $fs_mnode  = $tmt_mnode->get_tied_fsnode();
#    my $fs_prev   = $fs_mnode->lbrother() or return;
#    return TectoMT::Node->_fsnode2tmt_node($fs_prev);
#}

sub firstname_gender_from_czech_morpho {
    my ($lemma) = shift;
    my ($gender) = map { $_->get_tag =~ /^..(.)/; lc($1) }
        grep { $_->get_lemma =~ /;[Y]/ }
        $generator->forms_of_lemma( $lemma, { tag_regex => 'N..S1.+' } );
    return $gender;
}

1;

=over

=item Treex::Block::A2N::EN::DistinguishPersonalNames

Named entities (stored in C<SEnglishN> trees) with type
C<p_> = I<personal name with unspecified subtype>
are further classified as:
C<PF> = I<female name>,
C<PM> = I<male name>.
This named enitity node serves as a container:
its children are one-word entities with types:
C<pd> = abbreviated title (I<Mr., Ms.>),
C<pf> = first name,
C<pm> = middle name,
C<ps> = surname,
C<p_> = unrecognized.

=back

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

