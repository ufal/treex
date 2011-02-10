package Treex::Block::A2T::EN::MarkNamedEntities;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




use NER::Stanford::English;

my $DEBUG = 0;
$NER::Stanford::English::debug = $DEBUG;

my $ner;

sub BUILD {
    $ner = NER::Stanford::English->new();
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $a_root = $bundle->get_tree('SEnglishA');

    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    # skip empty sentence
    return if !@a_nodes;

    my @words = map { $_->form } @a_nodes;

    # BEWARE: $ner crashes on words like "." or "/", i.e. just punct  !!!
    my $test = join( '', @words );
    return if $test =~ /^[[:punct:]]*$/;

    my $types_rf = $ner->tag_forms( \@words );

    my %labels;
    my %groups;
    my $t = 'o';
    my $head;
    foreach my $i ( 0 .. $#a_nodes ) {
        my $type   = $types_rf->[$i];
        my $a_node = $a_nodes[$i];
        $type = lc($type);

        if ( $type eq 'na' ) {
            $type = 'o';
            my $form = $a_node->form;
            Report::warn "N/A named entity type for '$form'" if $DEBUG;
        }

        if ( $type ne 'o' ) {
            if ( $t ne $type ) {
                $head = $a_node;
                $labels{$a_node} = $type;
            }
            $groups{$a_node} = $head;
        }
        $t = $type;
    }

    my $t_root  = $bundle->get_tree('SEnglishT');
    my @t_nodes = $t_root->get_descendants();

    for my $t_node (@t_nodes) {
        my $a_lex = $t_node->get_lex_anode() or next;

        my $head = $groups{$a_lex};
        if ( defined $head ) {    # NE found
            my $number = $head->ord;
            $t_node->set_attr( 'named_entity/number', $number );
            $t_node->set_attr( 'named_entity/type',   $labels{$head} );
        }

    }
    return;
}

1;

=over

=item Treex::Block::A2T::EN::MarkNamedEntities

This block assigns the 'named_entity' attribute of t-nodes.
The named entities are highlighted in TMTTred according to the 
entity type: person, organization, or location.

Specify the model by setting the environment
variable TMT_PARAM_NER_EN_MODEL to the model file name (not the whole path). If undefined,
the default model is used and a warning is issued.

See module NER::Stanford::English.pm for more details.

Author: Vaclav Novak
=back

=cut

# Copyright 2008-2009 Vaclav Novak, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
