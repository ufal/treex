package Treex::Block::A2N::EN::DistinguishPersonalNames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::EN::First_names;

has generator => (
    is => 'ro',
    isa => 'Maybe[Treex::Tool::Lexicon::Generation::CS]',
    builder => '_build_generator',
    documentation => 'Czech morphology used as an additional resource for gender detections',
);

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

sub _build_generator {
    my $self = shift;
    my $generator;
    eval {
        require Treex::Tool::Lexicon::Generation::CS;
        $generator = Treex::Tool::Lexicon::Generation::CS->new();
        1;
    } or return;
    return $generator;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    return if not $zone->has_ntree;
    my $n_root = $zone->get_ntree;
    my @n_p = grep { $_->get_attr('ne_type') eq 'p_' } $n_root->get_descendants();
    foreach my $n_node (@n_p) {
        $self->process_personal_nnode($n_node);
    }
    return;
}

sub process_personal_nnode {
    my $self = shift;
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
    my @genders = map { $self->guess_gender($_) } @lemmas;

    if ( !$gender ) {
        $gender = first { $_ ne '?' } @genders;
    }
    $n_node->set_ne_type(!$gender ? 'P' : $gender eq 'f' ? 'PF' : 'PM' );
    $n_node->set_anodes();

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
        $new_nnode->set_anodes($a_node);
    }

    return;
}

# Stanford NER considers "Mr." or "Mrs." a part of NE
# so let's check also for GENDER_OF_ROLE.
sub guess_gender {
    my $self = shift;
    my ($lemma) = @_;
    return $GENDER_OF_ROLE{$lemma} || Treex::Tool::Lexicon::EN::First_names::gender_of($lemma)
        || $self->firstname_gender_from_czech_morpho($lemma) || '?';
}

sub firstname_gender_from_czech_morpho {
    my $self = shift;
    return if !defined $self->generator;
    my ($lemma) = shift;
    my ($gender) = map { $_->get_tag =~ /^..(.)/; lc($1) }
        grep { $_->get_lemma =~ /;[Y]/ }
        $self->generator->forms_of_lemma( $lemma, { tag_regex => 'N..S1.+' } );
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

